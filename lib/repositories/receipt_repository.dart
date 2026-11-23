import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../core/database_helper.dart';
import '../models/full_receipt.dart';
import '../models/sun_receipt.dart';
import '../models/receipt_payment_item.dart';
import '../models/general_ledger_posting.dart';
import 'package:uuid/uuid.dart';
import '../services/invoice_numbering_service.dart';

class ReceiptRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static bool _isSyncing = false;

  Future<FullReceipt> loadReceipt(int receiptId) async {
    final db = await _dbHelper.database;

    try {
      final List<Map<String, dynamic>> receiptResult = await db.query(
        'sun_receipt',
        where: 'id = ?',
        whereArgs: [receiptId],
      );

      if (receiptResult.isEmpty) {
        throw Exception("Receipt not found locally");
      }

      final Map<String, dynamic> receiptData = Map<String, dynamic>.from(receiptResult.first);

      final List<Map<String, dynamic>> itemsResult = await db.query(
        'receipt_payment_items',
        where: 'receipt_payment_id = ?',
        whereArgs: [receiptId],
      );

      receiptData['receipt_payment_items'] = itemsResult;

      if (receiptData['collector_no'] != null) {
        final colRes = await db.query('sun_collectors',
            where: 'collector_no = ?',
            whereArgs: [receiptData['collector_no']]);
        if (colRes.isNotEmpty) receiptData['collector'] = colRes.first;
      }

      if (receiptData['user_id'] != null) {
        final userRes = await db.query('sun_users',
            where: 'user_no = ?',
            whereArgs: [receiptData['user_id']]);
        if (userRes.isNotEmpty) receiptData['creator'] = userRes.first;
      }

      return FullReceipt.fromJson(receiptData);

    } catch (e) {
      log("Error inside loadReceipt: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveCompleteReceipt({
    required Map<String, dynamic> receiptHeader,
    required List<Map<String, dynamic>> receiptItems,
    required List<Map<String, dynamic>> ledgerPostings,
  }) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      try {
        final headerData = Map<String, dynamic>.from(receiptHeader);

        if (headerData['id'] == null) headerData.remove('id');
        headerData['is_synced'] = 0;
        headerData['guid'] ??= const Uuid().v4();
        if (!headerData.containsKey('created_at')) {
          headerData['created_at'] = DateTime.now().toIso8601String();
        }

        if (headerData['date'] is DateTime) {
          headerData['date'] = (headerData['date'] as DateTime).toIso8601String();
        }

        String transactionNumber = headerData['transaction_number']?.toString() ?? '';
        if (transactionNumber.isEmpty) {
          final int userId = headerData['user_id'];
          final String invoiceTypeChar = headerData['invoice_type_char'];

          headerData['invoice_type'] = _getInvoiceTypeName(invoiceTypeChar);

          transactionNumber = await _generateTransactionNumber(txn, userId, invoiceTypeChar);
          headerData['transaction_number'] = transactionNumber;
        }

        int newReceiptId = await txn.insert(
          'sun_receipt',
          headerData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (var item in receiptItems) {
          final itemData = Map<String, dynamic>.from(item);

          itemData['receipt_payment_id'] = newReceiptId;

          if (itemData['id'] == null) itemData.remove('id');

          await txn.insert('receipt_payment_items', itemData);
        }

        for (var posting in ledgerPostings) {
          final postingData = Map<String, dynamic>.from(posting);

          postingData['transaction_id'] = newReceiptId;
          if (postingData.containsKey('is_synced')) postingData.remove('is_synced');

          await txn.insert('sun_general_ledger_postings', postingData);
        }

        return {
          'id': newReceiptId,
          'transaction_number': transactionNumber,
        };

      } catch (e) {
        log("Error saveCompleteReceipt: $e");
        throw Exception("Failed to save receipt: $e");
      }
    });
  }

  Future<void> updateCompleteReceipt({
    required int receiptId,
    required Map<String, dynamic> receiptHeader,
    required List<Map<String, dynamic>> receiptItems,
    required List<Map<String, dynamic>> ledgerPostings,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      try {
        final headerData = Map<String, dynamic>.from(receiptHeader);
        headerData['is_synced'] = 0;
        headerData['updated_at'] = DateTime.now().toIso8601String();

        if (headerData['date'] is DateTime) {
          headerData['date'] = (headerData['date'] as DateTime).toIso8601String();
        }

        await txn.update(
          'sun_receipt',
          headerData,
          where: 'id = ?',
          whereArgs: [receiptId],
        );

        await txn.delete(
          'receipt_payment_items',
          where: 'receipt_payment_id = ?',
          whereArgs: [receiptId],
        );

        for (var item in receiptItems) {
          final itemData = Map<String, dynamic>.from(item);
          itemData['receipt_payment_id'] = receiptId;
          if (itemData['id'] == null) itemData.remove('id');

          await txn.insert('receipt_payment_items', itemData);
        }

        await txn.delete(
          'sun_general_ledger_postings',
          where: 'transaction_id = ?',
          whereArgs: [receiptId],
        );

        for (var posting in ledgerPostings) {
          final postingData = Map<String, dynamic>.from(posting);
          postingData['transaction_id'] = receiptId;
          if (postingData.containsKey('is_synced')) postingData.remove('is_synced');

          await txn.insert('sun_general_ledger_postings', postingData);
        }

      } catch (e) {
        log("Error updateCompleteReceipt: $e");
        throw Exception("Failed to update receipt: $e");
      }
    });
  }

  Future<List<Map<String, dynamic>>> fetchUnsyncedCompleteReceipts({String? invoiceTypeChar}) async {
    final db = await _dbHelper.database;

    String whereClause = 'is_synced = ?';
    List<dynamic> whereArgs = [0];

    if (invoiceTypeChar != null && invoiceTypeChar.isNotEmpty) {
      whereClause += ' AND invoice_type_char = ?';
      whereArgs.add(invoiceTypeChar);
    }

    final List<Map<String, dynamic>> receiptRows = await db.query(
      'sun_receipt',
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (receiptRows.isEmpty) return [];

    List<Map<String, dynamic>> enrichedReceipts = [];

    Map<String, Map<String, dynamic>> currencyCache = {};
    Map<String, String> boxCache = {};
    Map<int, String> collectorCache = {};
    Map<String, String> customerControlAccCache = {};
    Map<int, String> costCenterCache = {};
    Map<String, String> accountNameCache = {};

    for (var row in receiptRows) {
      final receiptHeader = Map<String, dynamic>.from(row);

      String currencyName = receiptHeader['currency']?.toString() ?? '';
      int currencyIdToSend = 1;
      double currencyRateToSend = 1.0;
      String currencySymbolToSend = '';

      if (currencyName.isNotEmpty) {
        if (int.tryParse(currencyName) != null) {
          currencyIdToSend = int.parse(currencyName);
        } else {
          if (currencyCache.containsKey(currencyName)) {
            final cachedCur = currencyCache[currencyName]!;
            currencyIdToSend = cachedCur['id'];
            currencySymbolToSend = cachedCur['symbol'];
            currencyRateToSend = cachedCur['rate'];
          } else {
            final curRes = await db.query('sun_currencies',
                columns: ['currency_no', 'currency_symbol', 'currency_rate'],
                where: 'currency_name = ?',
                whereArgs: [currencyName]);

            if (curRes.isNotEmpty) {
              currencyIdToSend = int.tryParse(curRes.first['currency_no'].toString()) ?? 1;
              currencySymbolToSend = curRes.first['currency_symbol']?.toString() ?? '';
              currencyRateToSend = (curRes.first['currency_rate'] as num?)?.toDouble() ?? 1.0;

              currencyCache[currencyName] = {
                'id': currencyIdToSend,
                'symbol': currencySymbolToSend,
                'rate': currencyRateToSend
              };
            }
          }
        }
      }

      receiptHeader['currency_id'] = currencyIdToSend;
      receiptHeader['currency_symbol'] = currencySymbolToSend;
      receiptHeader['currency_rate'] = currencyRateToSend;

      if (receiptHeader['cash_box'] != null) {
        String boxName = receiptHeader['cash_box'].toString();
        if (boxCache.containsKey(boxName)) {
          receiptHeader['box_account_id'] = boxCache[boxName];
        } else {
          final boxRes = await db.query('sun_boxes',
              columns: ['account_id'],
              where: 'box_name = ?',
              whereArgs: [boxName]);
          if (boxRes.isNotEmpty) {
            String accId = boxRes.first['account_id']?.toString() ?? '';
            if (accId.isNotEmpty) {
              receiptHeader['box_account_id'] = accId;
              boxCache[boxName] = accId;
            }
          }
        }
      }

      if (receiptHeader['user_id'] != null) {
        final userRes = await db.query('sun_users',
            columns: ['user_name'],
            where: 'user_no = ?',
            whereArgs: [receiptHeader['user_id']]);

        if (userRes.isNotEmpty) {
          receiptHeader['user_name'] = userRes.first['user_name'];
        }
      }

      if (receiptHeader['collector_no'] != null) {
        int colNo = int.tryParse(receiptHeader['collector_no'].toString()) ?? 0;

        if (colNo != 0) {
          if (collectorCache.containsKey(colNo)) {
            receiptHeader['collector_name'] = collectorCache[colNo];
          } else {
            final colRes = await db.query('sun_collectors',
                columns: ['collector_name'],
                where: 'collector_no = ?',
                whereArgs: [colNo]);
            if (colRes.isNotEmpty) {
              String cName = colRes.first['collector_name'].toString();
              receiptHeader['collector_name'] = cName;
              collectorCache[colNo] = cName;
            }
          }
        }
      }

      // ✅ التعديل هنا: جلب اسم مركز التكلفة لرأس السند
      if (receiptHeader['cost_center_no'] != null) {
        int ccNo = int.tryParse(receiptHeader['cost_center_no'].toString()) ?? 0;

        if (ccNo != 0) {
          if (costCenterCache.containsKey(ccNo)) {
            receiptHeader['cost_center'] = costCenterCache[ccNo];
          } else {
            final ccRes = await db.query('cost_centers',
                columns: ['center_name'],
                where: 'center_no = ?',
                whereArgs: [ccNo]);

            if (ccRes.isNotEmpty) {
              String ccName = ccRes.first['center_name'].toString();
              receiptHeader['cost_center'] = ccName;
              costCenterCache[ccNo] = ccName;
            }
          }
        }
      }

      final List<Map<String, dynamic>> itemsRows = await db.query(
        'receipt_payment_items',
        where: 'receipt_payment_id = ?',
        whereArgs: [receiptHeader['id']],
      );

      final List<Map<String, dynamic>> enrichedItems = [];
      for (var itemRow in itemsRows) {
        final itemMap = Map<String, dynamic>.from(itemRow);

        String itemCurName = itemMap['item_currency']?.toString() ?? '';
        int itemCurId = 1;

        if (itemCurName.isNotEmpty) {
          if (currencyCache.containsKey(itemCurName)) {
            itemCurId = currencyCache[itemCurName]!['id'];
            itemMap['item_currency'] = currencyCache[itemCurName]!['symbol'];
          } else {
            final curItemRes = await db.query('sun_currencies',
                columns: ['currency_no', 'currency_symbol', 'currency_rate'],
                where: 'currency_name = ?',
                whereArgs: [itemCurName]);

            if (curItemRes.isNotEmpty) {
              itemCurId = int.tryParse(curItemRes.first['currency_no'].toString()) ?? 1;
              String sym = curItemRes.first['currency_symbol']?.toString() ?? '';
              itemMap['item_currency'] = sym;

              currencyCache[itemCurName] = {
                'id': itemCurId,
                'symbol': sym,
                'rate': (curItemRes.first['currency_rate'] as num?)?.toDouble() ?? 1.0
              };
            }
          }
        }
        itemMap['item_currency_id'] = itemCurId;

        if (itemMap['account_no'] != null) {
          String accNo = itemMap['account_no'].toString();

          if (accNo.isNotEmpty) {
            if (customerControlAccCache.containsKey(accNo)) {
              itemMap['control_account_id'] = customerControlAccCache[accNo];
            } else {
              final custRes = await db.query('sun_customers',
                  columns: ['control_account_id'],
                  where: 'account_id = ?',
                  whereArgs: [accNo]);

              if (custRes.isNotEmpty) {
                String cId = custRes.first['control_account_id']?.toString() ?? '';
                if (cId.isNotEmpty) {
                  itemMap['control_account_id'] = cId;
                  customerControlAccCache[accNo] = cId;
                }
              }
            }
          }
        }

        enrichedItems.add(itemMap);
      }

      final String invoiceType = receiptHeader['invoice_type'] ?? '';
      final List<Map<String, dynamic>> ledgerRows = await db.query(
        'sun_general_ledger_postings',
        where: 'transaction_id = ? AND transaction_type = ?',
        whereArgs: [receiptHeader['id'], invoiceType],
      );

      final List<Map<String, dynamic>> enrichedLedgers = [];
      for (var ledgerRow in ledgerRows) {
        final ledgerMap = Map<String, dynamic>.from(ledgerRow);
        ledgerMap['currency_id'] = currencyIdToSend;

        if (ledgerMap['account_id'] != null) {
          String accId = ledgerMap['account_id'].toString();

          if (accId.isNotEmpty) {
            if (accountNameCache.containsKey(accId)) {
              ledgerMap['account_name'] = accountNameCache[accId];
            } else {
              final boxRes = await db.query('sun_boxes',
                  columns: ['box_name'],
                  where: 'account_id = ?',
                  whereArgs: [accId]);

              if (boxRes.isNotEmpty) {
                String bName = boxRes.first['box_name'].toString();
                ledgerMap['account_name'] = bName;
                accountNameCache[accId] = bName;
              } else {
                final accRes = await db.query('sun_account',
                    columns: ['name'],
                    where: 'account_number = ?',
                    whereArgs: [accId]);
                if (accRes.isNotEmpty) {
                  String aName = accRes.first['name'].toString();
                  ledgerMap['account_name'] = aName;
                  accountNameCache[accId] = aName;
                }
              }
            }

            if (customerControlAccCache.containsKey(accId)) {
              ledgerMap['control_account_id'] = customerControlAccCache[accId];
            } else {
              final custRes = await db.query('sun_customers',
                  columns: ['control_account_id'],
                  where: 'account_id = ?',
                  whereArgs: [accId]);

              if (custRes.isNotEmpty) {
                String cId = custRes.first['control_account_id']?.toString() ?? '';
                if (cId.isNotEmpty) {
                  ledgerMap['control_account_id'] = cId;
                  customerControlAccCache[accId] = cId;
                }
              }
            }
          }
        }

        if (ledgerMap['cost_center_no'] != null) {
          int ccNo = int.tryParse(ledgerMap['cost_center_no'].toString()) ?? 0;

          if (ccNo != 0) {
            if (costCenterCache.containsKey(ccNo)) {
              ledgerMap['cost_center_name'] = costCenterCache[ccNo];
            } else {
              try {
                final ccRes = await db.query('cost_centers',
                    columns: ['center_name'],
                    where: 'center_no = ?',
                    whereArgs: [ccNo]);
                if (ccRes.isNotEmpty) {
                  String ccName = ccRes.first['center_name'].toString();
                  ledgerMap['cost_center_name'] = ccName;
                  costCenterCache[ccNo] = ccName;
                }
              } catch (_) {}
            }
          }
        }

        enrichedLedgers.add(ledgerMap);
      }

      enrichedReceipts.add({
        'receipt': receiptHeader,
        'items': enrichedItems,
        'postings': enrichedLedgers,
      });
    }

    return enrichedReceipts;
  }

  static String _normalizeServerBaseUrl(String rawUrl) {
    String trimmed = rawUrl.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Future<int> syncReceiptsToRemote(String apiUrl, String token, {String? invoiceTypeChar}) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    try {
      String normalizedApiUrl = apiUrl.trim();
      if (normalizedApiUrl.startsWith('http://http://')) {
        normalizedApiUrl = normalizedApiUrl.replaceFirst('http://http://', 'http://');
      } else if (normalizedApiUrl.startsWith('http://https://')) {
        normalizedApiUrl = normalizedApiUrl.replaceFirst('http://https://', 'https://');
      } else if (!normalizedApiUrl.startsWith('http://') && !normalizedApiUrl.startsWith('https://')) {
        normalizedApiUrl = 'http://$normalizedApiUrl';
      }

      final List<Map<String, dynamic>> enrichedData =
      await fetchUnsyncedCompleteReceipts(invoiceTypeChar: invoiceTypeChar);

      if (enrichedData.isEmpty) {
        log("No unsynced receipts found.");
        return 0;
      }

      int successCount = 0;

      for (var data in enrichedData) {
        try {
          final SunReceipt receiptModel = SunReceipt.fromJson(data['receipt']);
          final List<ReceiptPaymentItem> itemsModels = (data['items'] as List).map((i) => ReceiptPaymentItem.fromJson(i)).toList();
          final List<GeneralLedgerPosting> postingsModels = (data['postings'] as List).map((p) => GeneralLedgerPosting.fromJson(p)).toList();

          final Map<String, dynamic> apiPayload = receiptModel.toApiJson();
          apiPayload['items'] = itemsModels.map((i) => i.toApiJson()).toList();
          apiPayload['postings'] = postingsModels.map((p) => p.toApiJson()).toList();

          log("RECEIPT TO SEND: ${jsonEncode(apiPayload)}");

          final response = await http.post(
            Uri.parse(normalizedApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode(apiPayload),
          ).timeout(const Duration(seconds: 25));

          if (response.statusCode == 200 || response.statusCode == 201) {
            log("Sync Success: ${receiptModel.transactionNumber}");
            if (receiptModel.id != null) {
              await markReceiptsAsSynced([receiptModel.id!]);
              successCount++;
            }
          } else {
            log("SERVER ERROR BODY: ${response.body}");
            log("Sync Failed for ${receiptModel.transactionNumber}: ${response.statusCode}");
          }
        } catch (e) {
          log("Error processing receipt inside loop: $e");
        }
      }
      return successCount;

    } catch (e) {
      log("Error during receipt sync process: $e");
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> markReceiptsAsSynced(List<int> receiptIds) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      String idsString = receiptIds.join(',');
      await txn.rawUpdate(
          'UPDATE sun_receipt SET is_synced = 1 WHERE id IN ($idsString)'
      );
    });
  }

  Future<FullReceipt> fetchReceiptFromApi({
    required String serverUrl,
    required String token,
    required String transactionId,
    required int branchId,
    required String year,
  }) async {
    try {
      // بناء الرابط مع الباراميترات
      final String baseUrl = _normalizeServerBaseUrl(serverUrl);
      final Uri uri = Uri.parse('$baseUrl/api/Receipt/get-receipt-details').replace(queryParameters: {
        'transactionId': transactionId,
        'branchId': branchId.toString(),
        'year': year,
      });

      // الاتصال بالسيرفر
      final http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // استخراج الكائنات من الرد
        final Map<String, dynamic> receiptData = data['receipt'] ?? {};
        final List<dynamic> itemsData = data['items'] ?? [];

        // دالة مساعدة لضمان قراءة المفاتيح بغض النظر عن حالة الأحرف
        dynamic getValue(Map<String, dynamic> map, String key) {
          if (map.containsKey(key)) return map[key];
          String pascalKey = key[0].toUpperCase() + key.substring(1);
          if (map.containsKey(pascalKey)) return map[pascalKey];
          String snakeKey = key.split(RegExp(r'(?=[A-Z])')).join('_').toLowerCase();
          if (map.containsKey(snakeKey)) return map[snakeKey];
          return null;
        }

        // 1. تحويل الرأس (Header)
        final SunReceipt receipt = SunReceipt(
          id: int.tryParse(getValue(receiptData, 'id')?.toString() ?? '0'),
          transactionNumber: getValue(receiptData, 'transactionNumber')?.toString() ?? '',
          date: DateTime.tryParse(getValue(receiptData, 'date')?.toString() ?? '') ?? DateTime.now(),

          cashBox: getValue(receiptData, 'cashBox')?.toString() ?? '',
          boxAccountId: getValue(receiptData, 'boxAccountId')?.toString(),

          currency: getValue(receiptData, 'currency')?.toString() ?? '',
          currencyId: int.tryParse(getValue(receiptData, 'currencyId')?.toString() ?? '1'),
          currencyRate: (getValue(receiptData, 'currencyRate') as num?)?.toDouble() ?? 1.0,

          accountName: getValue(receiptData, 'accountName')?.toString() ?? '',
          costCenter: getValue(receiptData, 'costCenter')?.toString(),
          costCenterNo: int.tryParse(getValue(receiptData, 'costCenterNo')?.toString() ?? '0'),

          description: getValue(receiptData, 'description')?.toString(),
          totalAmount: (getValue(receiptData, 'totalAmount') as num?)?.toDouble() ?? 0.0,
          amountInWords: getValue(receiptData, 'amountInWords')?.toString(),

          userId: int.tryParse(getValue(receiptData, 'userId')?.toString() ?? '0') ?? 0,
          userName: getValue(receiptData, 'userName')?.toString(),

          invoiceTypeChar: getValue(receiptData, 'invoiceTypeChar')?.toString() ?? 'ق',
          invoiceType: getValue(receiptData, 'invoiceType')?.toString() ?? '',

          // الحقول الإدارية
          isSynced: true,
          sunYear: int.tryParse(year),
          branchId: branchId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // 2. تحويل التفاصيل (Items)
        final List<ReceiptPaymentItem> items = itemsData.map((itemMap) {
          final Map<String, dynamic> item = itemMap as Map<String, dynamic>;
          return ReceiptPaymentItem(
            id: int.tryParse(getValue(item, 'id')?.toString() ?? '0'),
            receiptPaymentId: receipt.id ?? 0,

            accountNo: getValue(item, 'accountNo')?.toString() ?? '',
            accountName: getValue(item, 'accountName')?.toString() ?? '',

            amount: (getValue(item, 'amount') as num?)?.toDouble() ?? 0.0,

            itemCurrency: getValue(item, 'itemCurrency')?.toString() ?? '',
            itemCurrencyId: int.tryParse(getValue(item, 'itemCurrencyId')?.toString() ?? '1'),

            exchangeRate: (getValue(item, 'exchangeRate') as num?)?.toDouble() ?? 1.0,
            equivalentAmount: (getValue(item, 'equivalentAmount') as num?)?.toDouble() ?? 0.0,

            controlAccountId: getValue(item, 'controlAccountId')?.toString(),
            createdAt: DateTime.now(),
          );
        }).toList();

        // 3. الإرجاع النهائي (تم التصحيح هنا)
        return FullReceipt(
          receipt: receipt,
          items: items,
        );

      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      log("Error fetching receipt from API: $e");
      throw Exception('تعذر جلب السند من السيرفر: $e');
    }
  }

  Future<void> deleteOldSyncedReceipts() async {
    final db = await _dbHelper.database;
    final String cutoffDate = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

    await db.transaction((txn) async {
      final List<Map<String, dynamic>> targetReceipts = await txn.query(
        'sun_receipt',
        columns: ['id'],
        where: 'is_synced = ? AND date < ?',
        whereArgs: [1, cutoffDate],
      );

      if (targetReceipts.isEmpty) return;

      final List<int> idsToDelete = targetReceipts.map((row) => row['id'] as int).toList();
      if (idsToDelete.isEmpty) return;

      final String idsString = idsToDelete.join(',');

      // حذف تفاصيل السند
      await txn.rawDelete(
          'DELETE FROM receipt_payment_items WHERE receipt_payment_id IN ($idsString)'
      );

      // حذف القيود
      await txn.rawDelete('''
        DELETE FROM sun_general_ledger_postings 
        WHERE transaction_id IN ($idsString) 
        AND transaction_type IN (SELECT invoice_type FROM sun_receipt WHERE id IN ($idsString))
      ''');

      // حذف رأس السند
      await txn.rawDelete(
          'DELETE FROM sun_receipt WHERE id IN ($idsString)'
      );
    });
  }

  Future<String> _generateTransactionNumber(Transaction txn, int userId, String typeChar) async {
    return InvoiceNumberingService().allocateNextNumber(txn, userId, typeChar);
  }

  String _getInvoiceTypeName(String char) {
    switch (char) {
      case 'ق': return 'سند قبض';
      case 'ص': return 'سند صرف';
      default: return 'سند غير معروف';
    }
  }

  Future<Map<String, dynamic>> getSystemAccount(String accountNumber) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'sun_account',
      columns: ['id', 'name'],
      where: 'account_number = ?',
      whereArgs: [accountNumber],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    } else {
      throw Exception("Account not found: $accountNumber");
    }
  }
}