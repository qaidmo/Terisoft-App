import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:get/get.dart';
import '../services/lookups_service.dart.dart';
import '../core/database_helper.dart';
import '../models/full_sales_invoice.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/general_ledger_posting.dart';
import 'package:uuid/uuid.dart';
import '../services/invoice_numbering_service.dart';
import '../core/exceptions.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static bool _isSyncing = false;

  // ---------------------------------------------------------------------------
  // 1. دوال جلب الفاتورة للعرض (تعمل كما هي للمحافظة على الواجهات)
  // ---------------------------------------------------------------------------

  Future<FullSalesInvoice> loadInvoice(String invoiceId) async {
    final db = await _dbHelper.database;

    try {
      final List<Map<String, dynamic>> saleResult = await db.query(
        'sales',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      if (saleResult.isEmpty) {
        throw Exception("Invoice not found locally");
      }

      final Map<String, dynamic> saleData = Map<String, dynamic>.from(saleResult.first);

      final List<Map<String, dynamic>> itemsResult = await db.rawQuery('''
        SELECT 
          si.*, 
          i.item_name, i.is_taxable, i.tax_rate, i.is_discountable, i.discount_rate, i.item_unit as original_unit, i.cost_center_no
        FROM sale_items si
        LEFT JOIN sun_items i ON si.item_no = i.item_no
        WHERE si.sale_id = ?
      ''', [invoiceId]);

      final List<Map<String, dynamic>> formattedItems = itemsResult.map((row) {
        final itemMap = Map<String, dynamic>.from(row);
        itemMap['sun_items'] = {
          'item_name': row['item_name'],
          'is_taxable': row['is_taxable'] == 1,
          'tax_rate': row['tax_rate'],
          'is_discountable': row['is_discountable'] == 1,
          'discount_rate': row['discount_rate'],
          'item_unit': row['original_unit'],
          'cost_center_no': row['cost_center_no'],
        };
        return itemMap;
      }).toList();

      saleData['sale_items'] = formattedItems;

      if (saleData['collector_id'] != null) {
        final colRes = await db.query('sun_collectors',
            where: 'collector_no = ?',
            whereArgs: [saleData['collector_id']]
        );
        if (colRes.isNotEmpty) saleData['collector'] = colRes.first;
      }

      if (saleData['agent_id'] != null) {
        final agtRes = await db.query('sun_salespeople',
            where: 'salesperson_no = ?',
            whereArgs: [saleData['agent_id']]
        );
        if (agtRes.isNotEmpty) saleData['agent'] = agtRes.first;
      }

      return FullSalesInvoice.fromJson(saleData);

    } catch (e) {
      log("Error in loadInvoice: $e");
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. دوال الحفظ والتحديث
  // ---------------------------------------------------------------------------

  int _getStockMultiplier(String invoiceTypeChar) {
    if (invoiceTypeChar.startsWith('ر')) {
      return 1;
    }
    return -1;
  }

  Future<Map<String, dynamic>> saveCompleteSale({
    required Map<String, dynamic> saleHeader,
    required List<Map<String, dynamic>> saleItems,
    required List<Map<String, dynamic>> ledgerPostings,
  }) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      try {
        final headerData = Map<String, dynamic>.from(saleHeader);
        if (headerData['id'] == null) headerData.remove('id');
        if (headerData['date'] is DateTime) {
          headerData['date'] = (headerData['date'] as DateTime).toIso8601String();
        }
        headerData['is_synced'] = 0;
        headerData['guid'] ??= const Uuid().v4();

        String transactionNumber = headerData['transaction_number']?.toString() ?? '';
        final String invoiceTypeChar = headerData['invoice_type_char'];

        await _assertStoreBelongsToBranch(txn, headerData['store_no'], headerData['branch_id']);

        if (transactionNumber.isEmpty) {
          final int userId = headerData['user_id'];
          headerData['invoice_type'] = _getInvoiceTypeName(invoiceTypeChar);
          transactionNumber = await _generateTransactionNumber(txn, userId, invoiceTypeChar);
          headerData['transaction_number'] = transactionNumber;
        }

        int newSaleId = await txn.insert('sales', headerData, conflictAlgorithm: ConflictAlgorithm.replace);

        final int stockMultiplier = _getStockMultiplier(invoiceTypeChar);
        final String storeNo = headerData['store_no'].toString();

        for (var item in saleItems) {
          final itemData = Map<String, dynamic>.from(item);
          itemData['sale_id'] = newSaleId;
          itemData.remove('sun_items');
          if (itemData['id'] == null || itemData['id'] is! int) itemData.remove('id');

          await txn.insert('sale_items', itemData);

          final double qty = (itemData['quantity'] as num).toDouble();
          final double packFactor = (itemData['pack_factor'] as num).toDouble();
          final double totalQty = qty * (packFactor > 0 ? packFactor : 1.0);
          
          double qtyChange;
          if (invoiceTypeChar == 'م ض') {
            final double diffQty = (itemData['diff_quantity'] as num?)?.toDouble() ?? 0.0;
            qtyChange = diffQty * (packFactor > 0 ? packFactor : 1.0);
          } else {
            qtyChange = totalQty * stockMultiplier;
          }

          // 1. تجهيز البيانات: تحويل القيم الفارغة إلى نص فارغ لتطابق قاعدة البيانات
          final String expiryDate = itemData['expiry_date'] ?? ''; 
          final String batchNo = itemData['batch_no'] ?? '';       
          final int storeNoInt = int.tryParse(headerData['store_no']?.toString() ?? '1') ?? 1;
          final int branchIdInt = int.tryParse(headerData['branch_id']?.toString() ?? '1') ?? 1;

          // 2. الاستعلام المعدل للخصم المباشر من المخزون بدون استعلام فرعي
          await txn.rawUpdate('''
            UPDATE sun_stock 
            SET quantity = quantity + ? 
            WHERE item_no = ? 
              AND store_no = ? 
              AND branch_id = ?
              AND expiry_date = ? 
              AND batch_no = ?
          ''', [qtyChange, itemData['item_no'].toString(), storeNoInt, branchIdInt, expiryDate, batchNo]);
          
          if (Get.isRegistered<LookupsService>()) {
            Get.find<LookupsService>().adjustStockGlobally(itemData['item_no'].toString(), qtyChange);
          }
        }

        for (var posting in ledgerPostings) {
          final postingData = Map<String, dynamic>.from(posting);
          postingData['transaction_id'] = newSaleId;
          if (postingData.containsKey('is_synced')) postingData.remove('is_synced');
          await txn.insert('sun_general_ledger_postings', postingData);
        }

        return {'id': newSaleId, 'transaction_number': transactionNumber};

      } catch (e) {
        log("Error saveCompleteSale: $e");
        throw Exception("Failed to save sale: $e");
      }
    });
  }

  Future<Map<String, dynamic>> saveRestaurantInvoiceLocally({
    required Map<String, dynamic> saleHeader,
    required List<Map<String, dynamic>> saleItems,
  }) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      try {
        final headerData = Map<String, dynamic>.from(saleHeader);
        if (headerData['id'] == null) headerData.remove('id');
        if (headerData['date'] is DateTime) {
          headerData['date'] = (headerData['date'] as DateTime).toIso8601String();
        }
        headerData['is_synced'] = 0;
        headerData['guid'] ??= const Uuid().v4();

        String transactionNumber = headerData['transaction_number']?.toString() ?? '';
        final String invoiceTypeChar = headerData['invoice_type_char'];

        await _assertStoreBelongsToBranch(txn, headerData['store_no'], headerData['branch_id']);

        if (transactionNumber.isEmpty) {
          final int userId = headerData['user_id'] ?? 1;
          headerData['invoice_type'] = _getInvoiceTypeName(invoiceTypeChar);
          transactionNumber = await _generateTransactionNumber(txn, userId, invoiceTypeChar);
          headerData['transaction_number'] = transactionNumber;
        }

        int newSaleId = await txn.insert('sales', headerData, conflictAlgorithm: ConflictAlgorithm.replace);

        final int stockMultiplier = _getStockMultiplier(invoiceTypeChar);
        final String storeNo = headerData['store_no'].toString();

        for (var item in saleItems) {
          final itemData = Map<String, dynamic>.from(item);
          itemData['sale_id'] = newSaleId;
          itemData.remove('sun_items');
          if (itemData['id'] == null || itemData['id'] is! int) itemData.remove('id');

          await txn.insert('sale_items', itemData);

          final double qty = (itemData['quantity'] as num).toDouble();
          final double packFactor = (itemData['pack_factor'] as num?)?.toDouble() ?? 1.0;
          final double totalQty = qty * (packFactor > 0 ? packFactor : 1.0);
          final double qtyChange = totalQty * stockMultiplier;

          final String expiryDate = itemData['expiry_date'] ?? ''; 
          final String batchNo = itemData['batch_no'] ?? '';       

          await txn.rawUpdate('''
            UPDATE sun_stock 
            SET quantity = quantity + ? 
            WHERE rowid = (
                 SELECT rowid 
                 FROM sun_stock 
                 WHERE item_no = ? 
                   AND store_no = ? 
                   AND expiry_date = ? 
                   AND batch_no = ?
                 LIMIT 1
             )
          ''', [qtyChange, itemData['item_no'], storeNo, expiryDate, batchNo]);
        }

        return {'id': newSaleId, 'transaction_number': transactionNumber};

      } catch (e) {
        log("Error saveRestaurantInvoiceLocally: $e");
        throw Exception("Failed to save restaurant invoice locally: $e");
      }
    });
  }

  Future<void> updateCompleteSale({
    required int invoiceId,
    required Map<String, dynamic> saleHeader,
    required List<Map<String, dynamic>> saleItems,
    required List<Map<String, dynamic>> ledgerPostings,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      try {
        final headerData = Map<String, dynamic>.from(saleHeader);
        headerData['is_synced'] = 0;
        headerData['updated_at'] = DateTime.now().toIso8601String();
        if (headerData['date'] is DateTime) {
          headerData['date'] = (headerData['date'] as DateTime).toIso8601String();
        }

        final String invoiceTypeChar = headerData['invoice_type_char'];
        final String storeNo = headerData['store_no'].toString();
        final int stockMultiplier = _getStockMultiplier(invoiceTypeChar);

        await _assertStoreBelongsToBranch(txn, headerData['store_no'], headerData['branch_id']);

        await txn.update('sales', headerData, where: 'id = ?', whereArgs: [invoiceId]);

        // ---------------------------------------------------------
        // 1. معالجة البنود القديمة (إرجاع تأثيرها للمخزون) - 🔴 التعديل هنا
        // ---------------------------------------------------------
        final List<Map<String, dynamic>> oldItems = await txn.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [invoiceId],
        );

        for (var oldItem in oldItems) {
          final double qty = (oldItem['quantity'] as num).toDouble();
          final double packFactor = (oldItem['pack_factor'] as num).toDouble();
          final double totalQty = qty * (packFactor > 0 ? packFactor : 1.0);

          // عكس التأثير السابق
          final double reverseQtyChange = totalQty * (stockMultiplier * -1);

          // تجهيز البيانات بشكل صحيح (توحيد التعامل مع الفراغات)
          final String oldExpiry = oldItem['expiry_date'] ?? '';
          final String oldBatchNo = oldItem['batch_no'] ?? '';
          final int storeNoInt = int.tryParse(headerData['store_no']?.toString() ?? '1') ?? 1;
          final int branchIdInt = int.tryParse(headerData['branch_id']?.toString() ?? '1') ?? 1;
          
          await txn.rawUpdate('''
          UPDATE sun_stock 
          SET quantity = quantity + ? 
          WHERE item_no = ? 
            AND store_no = ? 
            AND branch_id = ?
            AND expiry_date = ?
            AND batch_no = ?
        ''', [reverseQtyChange, oldItem['item_no'].toString(), storeNoInt, branchIdInt, oldExpiry, oldBatchNo]);
        }

        await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [invoiceId]);

        // 2. معالجة البنود الجديدة (خصمها من المخزون)
        for (var item in saleItems) {
          final itemData = Map<String, dynamic>.from(item);
          itemData['sale_id'] = invoiceId;
          itemData.remove('sun_items');
          if (itemData['id'] == null || itemData['id'] is! int) itemData.remove('id');

          await txn.insert('sale_items', itemData);

          final double qty = (itemData['quantity'] as num).toDouble();
          final double packFactor = (itemData['pack_factor'] as num).toDouble();
          final double totalQty = qty * (packFactor > 0 ? packFactor : 1.0);
          final double qtyChange = totalQty * stockMultiplier;

          // 1. تجهيز البيانات: تحويل القيم الفارغة إلى نص فارغ لتطابق قاعدة البيانات
          final String expiryDate = itemData['expiry_date'] ?? ''; 
          final String batchNo = itemData['batch_no'] ?? '';       
          final int storeNoInt = int.tryParse(headerData['store_no']?.toString() ?? '1') ?? 1;
          final int branchIdInt = int.tryParse(headerData['branch_id']?.toString() ?? '1') ?? 1;

          // 2. الاستعلام المعدل للخصم المباشر من المخزون بدون استعلام فرعي
          await txn.rawUpdate('''
            UPDATE sun_stock 
            SET quantity = quantity + ? 
            WHERE item_no = ? 
              AND store_no = ? 
              AND branch_id = ?
              AND expiry_date = ? 
              AND batch_no = ?
          ''', [qtyChange, itemData['item_no'].toString(), storeNoInt, branchIdInt, expiryDate, batchNo]);
        }

        await txn.delete('sun_general_ledger_postings', where: 'transaction_id = ?', whereArgs: [invoiceId]);
        for (var posting in ledgerPostings) {
          final postingData = Map<String, dynamic>.from(posting);
          postingData['transaction_id'] = invoiceId;
          if (postingData.containsKey('is_synced')) postingData.remove('is_synced');
          await txn.insert('sun_general_ledger_postings', postingData);
        }

      } catch (e) {
        log("Error updateCompleteSale: $e");
        throw Exception("Failed to update sale: $e");
      }
    });
  }
  // ---------------------------------------------------------------------------
  // 3. دوال المزامنة (Logic المعدل لدعم مراكز التكلفة الصحيحة والرول باك)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchUnsyncedCompleteInvoices({
    String? invoiceTypeChar,
    List<String>? allowedInvoiceTypes,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = 'is_synced = ?';
    List<dynamic> whereArgs = [0];

    if (allowedInvoiceTypes != null && allowedInvoiceTypes.isNotEmpty) {
      final placeholders = List.filled(allowedInvoiceTypes.length, '?').join(', ');
      whereClause += ' AND invoice_type_char IN ($placeholders)';
      whereArgs.addAll(allowedInvoiceTypes);
    } else if (invoiceTypeChar != null && invoiceTypeChar.isNotEmpty) {
      whereClause += ' AND invoice_type_char = ?';
      whereArgs.add(invoiceTypeChar);
    } else {
      // عزل تام: استثناء محضر الجرد وفواتير الخدمات من المزامنة العادية
      whereClause += ' AND invoice_type_char NOT IN (?, ?, ?)';
      whereArgs.addAll(['م ض', 'ك ن', 'ك ج']);
    }

    final List<Map<String, dynamic>> salesRows = await db.query(
      'sales',
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (salesRows.isEmpty) return [];

    List<Map<String, dynamic>> enrichedInvoices = [];

    for (var row in salesRows) {
      final saleHeader = Map<String, dynamic>.from(row);

      String currencyName = saleHeader['currency']?.toString() ?? '';
      dynamic currencyIdToSend = 1;
      String currencySymbolToSend = '';

      if (currencyName.isNotEmpty) {
        if (int.tryParse(currencyName) != null) {
          currencyIdToSend = int.parse(currencyName);
        } else {
          final curRes = await db.query('sun_currencies',
              columns: ['currency_no', 'currency_symbol'],
              where: 'currency_name = ?',
              whereArgs: [currencyName]);

          if (curRes.isNotEmpty) {
            currencyIdToSend = curRes.first['currency_no'];
            currencySymbolToSend = curRes.first['currency_symbol']?.toString() ?? '';
          }
        }
      }

      saleHeader['currency_id'] = currencyIdToSend;
      saleHeader['currency_symbol'] = currencySymbolToSend;

      // === متغيرات المطابقة والحقن (توحيد المنطق) ===
      String? customerChildAccIdForMatching; // متغير جديد للمطابقة (الابن)
      String? customerControlAccIdForPosting; // متغير الحقن (الأب)

      String? boxChildAccIdForMatching; // متغير المطابقة للصندوق (الابن)
      String? boxControlAccIdForPosting; // متغير الحقن للصندوق (الأب)

      // 1. تجهيز بيانات العميل
      if (saleHeader['account_no'] != null) {
        final customerRes = await db.query('sun_customers',
            columns: ['account_id', 'control_account_id'],
            where: 'customer_no = ?',
            whereArgs: [saleHeader['account_no']]);

        if (customerRes.isNotEmpty) {
          // تحديث الرأس بالابن (للعرض الصحيح)
          saleHeader['account_id'] = customerRes.first['account_id'];

          // حفظ القيم للمتغيرات لاستخدامها في القيود
          customerChildAccIdForMatching = customerRes.first['account_id']?.toString();
          customerControlAccIdForPosting = customerRes.first['control_account_id']?.toString();
        }
      }

      if (saleHeader['store_no'] != null) {
        final storeRes = await db.query('sun_store',
            columns: ['name_store'],
            where: 'no_store = ?',
            whereArgs: [saleHeader['store_no']]);
        if (storeRes.isNotEmpty) {
          saleHeader['store_name'] = storeRes.first['name_store'];
        }
      }

      // 2. تجهيز بيانات الصندوق
      if (saleHeader['box_no'] != null) {
        final boxRes = await db.query('sun_boxes',
            columns: ['box_name', 'control_account_id', 'account_id'],
            where: 'box_no = ?',
            whereArgs: [saleHeader['box_no']]);

        if (boxRes.isNotEmpty) {
          saleHeader['box_name'] = boxRes.first['box_name'];
          saleHeader['box_account_id'] = boxRes.first['account_id'];

          // حفظ رقم الابن للمطابقة
          boxChildAccIdForMatching = boxRes.first['account_id']?.toString();

          String? rawFatherId = boxRes.first['control_account_id']?.toString();

          if (rawFatherId != null && rawFatherId.isNotEmpty) {
            final fatherAccRes = await db.query('sun_account',
                columns: ['is_transactional'],
                where: 'id = ?',
                whereArgs: [rawFatherId]);

            if (fatherAccRes.isNotEmpty) {
              int isTransactional = int.tryParse(fatherAccRes.first['is_transactional'].toString()) ?? 0;
              if (isTransactional == 1) {
                boxControlAccIdForPosting = rawFatherId;
              } else {
                boxControlAccIdForPosting = boxChildAccIdForMatching;
              }
            } else {
              boxControlAccIdForPosting = boxChildAccIdForMatching;
            }
          } else {
            boxControlAccIdForPosting = boxChildAccIdForMatching;
          }
        }
      }

      if (saleHeader['user_id'] != null) {
        final userRes = await db.query('sun_users',
            columns: ['user_name'],
            where: 'user_no = ?',
            whereArgs: [saleHeader['user_id']]);
        if (userRes.isNotEmpty) {
          saleHeader['user_name'] = userRes.first['user_name'];
        }
      }

      if (saleHeader['collector_id'] != null) {
        final colRes = await db.query('sun_collectors',
            columns: ['collector_name'],
            where: 'collector_no = ?',
            whereArgs: [saleHeader['collector_id']]);
        if (colRes.isNotEmpty) {
          saleHeader['collector_name'] = colRes.first['collector_name'];
        }
      }

      if (saleHeader['agent_id'] != null) {
        final agtRes = await db.query('sun_salespeople',
            columns: ['salesperson_name'],
            where: 'salesperson_no = ?',
            whereArgs: [saleHeader['agent_id']]);
        if (agtRes.isNotEmpty) {
          saleHeader['agent_name'] = agtRes.first['salesperson_name'];
        }
      }

      final List<Map<String, dynamic>> itemsRows = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleHeader['id']],
      );

      final List<Map<String, dynamic>> enrichedItems = [];
      for (var itemRow in itemsRows) {
        final itemMap = Map<String, dynamic>.from(itemRow);

        itemMap['currency_id'] = currencyIdToSend;

        if (itemMap['item_no'] != null) {
          final itemRes = await db.query('sun_items',
              columns: ['item_name'],
              where: 'item_no = ?',
              whereArgs: [itemMap['item_no']]);
          if (itemRes.isNotEmpty) {
            itemMap['sun_items'] = {'item_name': itemRes.first['item_name']};
          }
        }
        enrichedItems.add(itemMap);
      }

      final String invoiceType = saleHeader['invoice_type'] ?? '';
      final List<Map<String, dynamic>> ledgerRows = await db.query(
        'sun_general_ledger_postings',
        where: 'transaction_id = ? AND transaction_type = ?',
        whereArgs: [saleHeader['id'], invoiceType],
      );

      final List<Map<String, dynamic>> enrichedLedgers = [];
      for (var ledgerRow in ledgerRows) {
        final ledgerMap = Map<String, dynamic>.from(ledgerRow);

        ledgerMap['currency_id'] = currencyIdToSend;

        final String currentLedgerAccountId = ledgerMap['account_id']?.toString() ?? '';

        // === تطبيق المنطق الموحد والآمن ===

        // 1. حقن حساب الأب للعميل (باستخدام متغير المطابقة الصريح)
        if (customerChildAccIdForMatching != null &&
            currentLedgerAccountId == customerChildAccIdForMatching) {
          ledgerMap['control_account_id'] = customerControlAccIdForPosting;
        }

        // 2. حقن حساب الأب للصندوق (باستخدام متغير المطابقة الصريح)
        if (boxChildAccIdForMatching != null &&
            currentLedgerAccountId == boxChildAccIdForMatching) {
          ledgerMap['control_account_id'] = boxControlAccIdForPosting;
        }

        if (ledgerMap['account_id'] != null) {
          final boxRes = await db.query('sun_boxes',
              columns: ['box_name'],
              where: 'account_id = ?',
              whereArgs: [ledgerMap['account_id']]);

          if (boxRes.isNotEmpty) {
            ledgerMap['account_name'] = boxRes.first['box_name'];
          } else {
            final accRes = await db.query('sun_account',
                columns: ['name'],
                where: 'account_number = ?',
                whereArgs: [ledgerMap['account_id']]);
            if (accRes.isNotEmpty) {
              ledgerMap['account_name'] = accRes.first['name'];
            }
          }
        }

        if (ledgerMap['cost_center_no'] != null) {
          try {
            final ccRes = await db.query('cost_centers',
                columns: ['center_name'],
                where: 'center_no = ?',
                whereArgs: [ledgerMap['cost_center_no']]);
            if (ccRes.isNotEmpty) {
              ledgerMap['cost_center_name'] = ccRes.first['center_name'];
            }
          } catch (_) {}
        }

        enrichedLedgers.add(ledgerMap);
      }

      enrichedInvoices.add({
        'sale': saleHeader,
        'items': enrichedItems,
        'postings': enrichedLedgers,
      });
    }

    return enrichedInvoices;
  }

  /// تم تغيير نوع الإرجاع إلى Future<int> لكي نعرف عدد الفواتير المرسلة
  Future<int> syncSalesToRemote(String apiUrl, String token, {String? invoiceTypeChar}) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    try {
      final List<Map<String, dynamic>> enrichedData =
      await fetchUnsyncedCompleteInvoices(invoiceTypeChar: invoiceTypeChar);

      if (enrichedData.isEmpty) {
        log("No unsynced sales found${invoiceTypeChar != null ? ' for type $invoiceTypeChar' : ''}.");
        return 0;
      }

      int successCount = 0;

      for (var data in enrichedData) {
        try {
          final Sale saleModel = Sale.fromJson(data['sale']);
          final List<SaleItem> itemsModels = (data['items'] as List).map((i) => SaleItem.fromJson(i)).toList();
          final List<GeneralLedgerPosting> postingsModels = (data['postings'] as List).map((p) => GeneralLedgerPosting.fromJson(p)).toList();

          final Map<String, dynamic> apiPayload = saleModel.toApiJson();
          apiPayload['items'] = itemsModels.map((i) => i.toApiJson()).toList();
          apiPayload['postings'] = postingsModels.map((p) => p.toApiJson()).toList();

          log("DATA TO SEND: ${jsonEncode(apiPayload)}");

          final response = await http.post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode(apiPayload),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            log("Sync Success: ${saleModel.transactionNumber}");
            if (saleModel.id.isNotEmpty) {
              await markSalesAsSynced([int.parse(saleModel.id)]);
              successCount++;
            }
          } else {
            // 🔥🔥 هذا هو السطر الجديد المهم جداً 🔥🔥
            log("SERVER ERROR BODY: ${response.body}");
            log("Sync Failed for ${saleModel.transactionNumber}: ${response.statusCode}");
          }
        } catch (e) {
          log("Error processing invoice inside loop: $e");
        }
      }
      return successCount;

    } catch (e) {
      log("Error during global sync process: $e");
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<int> syncUtilitySalesToRemote(String apiUrl, String token) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    try {
      final List<Map<String, dynamic>> enrichedData =
          await fetchUnsyncedCompleteInvoices(allowedInvoiceTypes: ['ك ن', 'ك ج']);

      if (enrichedData.isEmpty) {
        log("No unsynced utility sales found.");
        return 0;
      }

      int successCount = 0;

      for (var data in enrichedData) {
        try {
          final Sale saleModel = Sale.fromJson(data['sale']);
          final List<SaleItem> itemsModels = (data['items'] as List).map((i) => SaleItem.fromJson(i)).toList();
          final List<GeneralLedgerPosting> postingsModels = (data['postings'] as List).map((p) => GeneralLedgerPosting.fromJson(p)).toList();

          final Map<String, dynamic> apiPayload = saleModel.toApiJson();
          apiPayload['items'] = itemsModels.map((i) => i.toApiJson()).toList();
          apiPayload['postings'] = postingsModels.map((p) => p.toApiJson()).toList();

          log("UTILITY SYNC PAYLOAD: ${jsonEncode(apiPayload)}");

          final response = await http.post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode(apiPayload),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            log("Utility Sync Success: ${saleModel.transactionNumber}");
            if (saleModel.id.isNotEmpty) {
              await markSalesAsSynced([int.parse(saleModel.id)]);
              successCount++;
            }
          } else {
            log("UTILITY SERVER ERROR BODY: ${response.body}");
            log("Utility Sync Failed for ${saleModel.transactionNumber}: ${response.statusCode}");
          }
        } catch (e) {
          log("Error processing utility invoice inside loop: $e");
        }
      }
      return successCount;

    } catch (e) {
      log("Error during global utility sync process: $e");
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> markSalesAsSynced(List<int> saleIds) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      String idsString = saleIds.join(',');
      await txn.rawUpdate(
          'UPDATE sales SET is_synced = 1 WHERE id IN ($idsString)'
      );
    });
  }

// أضف هذه الدالة داخل كلاس SalesRepository

  Future<FullSalesInvoice> fetchInvoiceFromApi({
    required String serverUrl,
    required String token,
    required String transactionId,
    required int branchId,
    required String year,
  }) async {
    try {
      final Uri uri = Uri.parse('http://$serverUrl/api/Transaction/get-invoice-details').replace(queryParameters: {
        'transactionId': transactionId,
        'branchId': branchId.toString(),
        'year': year,
      });

      final http.Response response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, dynamic> saleData = data['sale'] ?? {};
        final List<dynamic> itemsData = data['items'] ?? [];

        dynamic getValue(Map<String, dynamic> map, String key) {
          if (map.containsKey(key)) return map[key];

          String pascalKey = key[0].toUpperCase() + key.substring(1);
          if (map.containsKey(pascalKey)) return map[pascalKey];

          String snakeKey = key.split(RegExp(r'(?=[A-Z])')).join('_').toLowerCase();
          if (map.containsKey(snakeKey)) return map[snakeKey];

          return null;
        }

        final Sale sale = Sale(
          id: getValue(saleData, 'id')?.toString() ?? transactionId,
          transactionNumber: getValue(saleData, 'transactionNumber')?.toString() ?? '',
          date: DateTime.tryParse(getValue(saleData, 'date')?.toString() ?? '') ?? DateTime.now(),
          invoiceTypeChar: getValue(saleData, 'invoiceTypeChar')?.toString() ?? 'ن',
          invoiceType: getValue(saleData, 'invoiceType')?.toString(),
          storeNo: int.tryParse(getValue(saleData, 'storeNo')?.toString() ?? '0'),
          storeName: getValue(saleData, 'storeName')?.toString(),
          accountNo: getValue(saleData, 'accountNo')?.toString() ?? '',
          accountId: getValue(saleData, 'accountId')?.toString(),
          customerName: getValue(saleData, 'customerName')?.toString(),
          boxNo: int.tryParse(getValue(saleData, 'boxNo')?.toString() ?? '0'),
          boxName: getValue(saleData, 'boxName')?.toString(),
          boxAccountId: getValue(saleData, 'boxAccountId')?.toString(),
          collectorId: int.tryParse(getValue(saleData, 'collectorId')?.toString() ?? '0'),
          collectorName: getValue(saleData, 'collectorName')?.toString(),
          collector: getValue(saleData, 'collectorName')?.toString(),
          agentId: int.tryParse(getValue(saleData, 'agentId')?.toString() ?? '0'),
          agentName: getValue(saleData, 'agentName')?.toString(),
          salesRep: getValue(saleData, 'agentName')?.toString(),
          total: (getValue(saleData, 'total') as num?)?.toDouble() ?? 0.0,
          discount: (getValue(saleData, 'discount') as num?)?.toDouble(),
          tax: (getValue(saleData, 'tax') as num?)?.toDouble(),
          netTotal: (getValue(saleData, 'netTotal') as num?)?.toDouble(),
          userId: int.tryParse(getValue(saleData, 'userId')?.toString() ?? '0'),
          userName: getValue(saleData, 'userName')?.toString(),
          currency: getValue(saleData, 'currency')?.toString() ?? '',
          currencyId: int.tryParse(getValue(saleData, 'currencyId')?.toString() ?? '1'),
          currencySymbol: getValue(saleData, 'currencySymbol')?.toString(),
          currencyRate: (getValue(saleData, 'currencyRate') as num?)?.toDouble() ?? 1.0,
          isSynced: true,
          sunYear: int.tryParse(year),
          branchId: branchId,
          departmentId: int.tryParse(getValue(saleData, 'departmentId')?.toString() ?? '1'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final List<SaleItem> items = itemsData.map((itemMap) {
          final Map<String, dynamic> item = itemMap as Map<String, dynamic>;
          return SaleItem(
            id: getValue(item, 'id')?.toString() ?? '0',
            saleId: sale.id,
            itemNo: getValue(item, 'itemNo')?.toString(),
            itemName: getValue(item, 'itemName')?.toString() ?? 'صنف غير معروف',
            itemUnit: getValue(item, 'itemUnit')?.toString() ?? '',
            quantity: (getValue(item, 'quantity') as num?)?.toDouble() ?? 0.0,
            bonusQuantity: (getValue(item, 'bonusQuantity') as num?)?.toInt(),
            itemPrice: (getValue(item, 'itemPrice') as num?)?.toDouble() ?? 0.0,
            total: (getValue(item, 'total') as num?)?.toDouble() ?? 0.0,
            itemDiscount: (getValue(item, 'itemDiscount') as num?)?.toDouble(),
            isTaxable: false,
            taxRate: 0.0,
            isDiscountable: false,
            discountRate: 0.0,
            packFactor: (getValue(item, 'packFactor') as num?)?.toDouble() ?? 1.0,
            expiryDate: getValue(item, 'expiryDate')?.toString(),
            batchNumber: getValue(item, 'batchNo')?.toString(),
            stockBalance: (getValue(item, 'stockBalance') as num?)?.toDouble() ?? 0.0,
            costPrice: (getValue(item, 'costPrice') as num?)?.toDouble(),
            diffQuantity: (getValue(item, 'diffQuantity') as num?)?.toDouble(),
          );
        }).toList();

        return FullSalesInvoice(
          sale: sale,
          items: items,
          collector: null,
          agent: null,
        );
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      log("Error fetching invoice from API: $e");
      throw Exception('تعذر جلب الفاتورة من السيرفر: $e');
    }
  }
  // ---------------------------------------------------------------------------
  // 4. دوال مساعدة
  // ---------------------------------------------------------------------------

  Future<String> _generateTransactionNumber(Transaction txn, int userId, String typeChar) async {
    return InvoiceNumberingService().allocateNextNumber(txn, userId, typeChar);
  }

  /// Layer B guard (D7): the store on the header must belong to the header's
  /// branch. `sun_stock` is keyed (item_no, store_no, branch_id, ...) and the
  /// deduction filters by both, so a store from another branch would make the
  /// `UPDATE sun_stock` a silent no-op → inventory drift. Reject instead.
  Future<void> _assertStoreBelongsToBranch(
    Transaction txn,
    Object? storeNo,
    Object? branchId,
  ) async {
    if (storeNo == null || branchId == null) return;

    final rows = await txn.rawQuery(
      'SELECT branch_id FROM sun_store WHERE no_store = ?',
      [int.tryParse(storeNo.toString())],
    );
    if (rows.isEmpty) {
      throw StoreBranchMismatchException(
        'المخزن المحدد غير موجود',
      );
    }
    final storeBranch = int.tryParse(rows.first['branch_id'].toString());
    final headerBranch = int.tryParse(branchId.toString());
    if (storeBranch != headerBranch) {
      throw StoreBranchMismatchException(
        'المخزن المحدد لا يتبع الفرع المختار',
      );
    }
  }

  String _getInvoiceTypeName(String char) {
    switch (char) {
      case 'ن': return 'فاتورة مبيعات نقدا';
      case 'ج': return 'فاتورة مبيعات اجل';
      case 'م': return 'فاتورة مبيعات نقدا معلقة';
      case 'رن': return 'فاتورة مردود مبيعات نقدا';
      case 'رج': return 'فاتورة مردود مبيعات اجل';
      case 'رم': return 'فاتورة مردود مبيعات نقدا معلقة';
      case 'م ض': return 'محضر جرد';
      case 'ت': return 'فاتورة بيع نقدا';
      default: return 'نوع غير معروف';
    }
  }

  /// يجلب أسماء مجموعة من الحسابات دفعة واحدة من الجدول المحلي [sun_account].
  ///
  /// تُستخدم بدلاً من البحث الفردي عن حسابات افتراضية مُشفّرة برقم ثابت، حيث أصبح
  /// كل صنف يحمل حساباته الخاصة (إيرادي / تكلفة). نمرّر لها معرّفات الحسابات
  /// المطلوبة فتُرجع خريطة (المعرّف -> الاسم)، وإذا لم يُعثر على اسم لحساب ما
  /// يعود التطبيق لاستخدام المعرّف نفسه كقيمة احتياطية.
  Future<Map<String, String>> fetchAccountNameMap(Set<String> accountIds) async {
    if (accountIds.isEmpty) return {};

    final db = await _dbHelper.database;
    final ids = accountIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return {};

    final String placeholders = List.filled(ids.length, '?').join(', ');
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      'SELECT id, name FROM sun_account WHERE id IN ($placeholders)',
      ids.toList(),
    );

    return {
      for (final row in rows)
        row['id'].toString(): (row['name']?.toString().isNotEmpty ?? false)
            ? row['name'].toString()
            : row['id'].toString(),
    };
  }

  // ---------------------------------------------------------------------------
  // 5. دوال مساعدة للواجهات (Missing Helper Methods for UI)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> fetchItemDetailsWithStock(String itemNo, int storeNo, int branchId) async {
    final db = await _dbHelper.database;

    try {
      // التعديل 1: إضافة i.average_cost و i.section_no لجملة الاستعلام
      final unitsResult = await db.rawQuery('''
      SELECT 
        u.*, 
        i.currency_no,
        i.average_cost,  -- 👈 التكلفة كنص (للحفاظ على الدقة الكاملة)
        i.section_no     -- 👈 رقم القسم
      FROM sun_itemsize u
      JOIN sun_items i ON u.item_no = i.item_no
      WHERE u.item_no = ? AND u.is_active = 1
      ORDER BY u.unit_index ASC
    ''', [itemNo]);

      final formattedUnits = unitsResult.map((u) {
        final map = Map<String, dynamic>.from(u);

        // التعديل 2: تمرير التكلفة والقسم ضمن بيانات الصنف
        map['item'] = {
          'currency_no': u['currency_no'],
          'average_cost': u['average_cost'], // سيصل كنص ولن يتم تقريبه أبداً
          'section_no': u['section_no']
        };

        return map;
      }).toList();

      // جلب رصيد المخزون (كما هو لم يتغير)
      final stockResult = await db.query(
        'sun_stock',
        columns: ['expiry_date', 'quantity', 'store_no', 'branch_id', 'cost_price', 'batch_no'],
        where: 'item_no = ? AND store_no = ? AND branch_id = ? AND quantity > 0',
        whereArgs: [itemNo, storeNo, branchId],
        orderBy: 'expiry_date ASC',
      );

      return {
        'units': formattedUnits,
        'stock': stockResult,
      };

    } catch (e) {
      log("Error fetching item details locally: $e");
      return {'units': [], 'stock': []};
    }
  }

  Future<void> deleteOldSyncedSales() async {
    final db = await _dbHelper.database;

    // ✅ العودة للوضع الطبيعي: حذف ما مر عليه 3 أيام فقط
    final String cutoffDate = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

    // يمكنك إبقاء الـ logs أو إزالتها حسب رغبتك، سأتركها لك للمراقبة
    log("--- بدء عملية التنظيف الدوري ---");

    await db.transaction((txn) async {
      // 1. البحث عن الفواتير
      final List<Map<String, dynamic>> targetInvoices = await txn.query(
        'sales',
        columns: ['id'],
        where: 'is_synced = ? AND date < ?',
        whereArgs: [1, cutoffDate],
      );

      if (targetInvoices.isEmpty) return;

      final List<int> idsToDelete = targetInvoices.map((row) => row['id'] as int).toList();

      if (idsToDelete.isEmpty) return;

      final String idsString = idsToDelete.join(',');

      // 2. حذف التفاصيل
      await txn.rawDelete(
          'DELETE FROM sale_items WHERE sale_id IN ($idsString)'
      );

      // 3. حذف القيود (الآمن)
      await txn.rawDelete('''
        DELETE FROM sun_general_ledger_postings 
        WHERE transaction_id IN ($idsString) 
        AND transaction_type IN (SELECT invoice_type FROM sales WHERE id IN ($idsString))
      ''');

      // 4. حذف الرأس
      await txn.rawDelete(
          'DELETE FROM sales WHERE id IN ($idsString)'
      );

      log("تم تنظيف ${idsToDelete.length} فاتورة قديمة بنجاح");
    });
  }

  // هذه الدالة أيضاً كانت موجودة في الكود الأصلي وتستخدم في شاشة المرتجعات
  Future<Map<String, dynamic>> loadOriginalInvoiceForReturn(String invoiceId) async {
    final db = await _dbHelper.database;
    try {
      final saleRes = await db.query('sales', where: 'id = ?', whereArgs: [invoiceId]);
      if (saleRes.isEmpty) throw Exception("Invoice not found");

      final Map<String, dynamic> saleMap = Map<String, dynamic>.from(saleRes.first);

      final itemsRes = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [invoiceId]);
      saleMap['sale_items'] = itemsRes;

      if (saleMap['collector_id'] != null) {
        final colRes = await db.query('sun_collectors',
            columns: ['collector_name'],
            where: 'collector_no = ?', whereArgs: [saleMap['collector_id']]);
        if (colRes.isNotEmpty) saleMap['collector'] = colRes.first;
      }

      if (saleMap['agent_id'] != null) {
        final agtRes = await db.query('sun_salespeople',
            columns: ['salesperson_name'],
            where: 'salesperson_no = ?', whereArgs: [saleMap['agent_id']]);
        if (agtRes.isNotEmpty) saleMap['agent'] = agtRes.first;
      }

      if (saleMap['user_id'] != null) {
        final userRes = await db.query('sun_users',
            columns: ['user_name'],
            where: 'user_no = ?', whereArgs: [saleMap['user_id']]);
        if (userRes.isNotEmpty) saleMap['creator'] = userRes.first;
      }

      return saleMap;
    } catch (e) {
      rethrow;
    }
  }
}