import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../services/invoice_numbering_service.dart';

class RestaurantRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static bool _isSyncing = false;

  Future<String> getPreviewInvoiceNumber(String userId, String branchId, String sectionId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT invoiceNumber FROM restaurant_invoices 
      WHERE userId = ? 
      ORDER BY id DESC LIMIT 1
    ''', [userId]);

    int lastSequence = 0;
    if (result.isNotEmpty) {
      String lastInvoiceNumber = result.first['invoiceNumber'] as String;
      if (lastInvoiceNumber.length > 7) {
        String sequenceStr = lastInvoiceNumber.substring(lastInvoiceNumber.length - 7);
        lastSequence = int.tryParse(sequenceStr) ?? 0;
      }
    }

    int newSequence = lastSequence + 1;
    String formattedSequence = newSequence.toString().padLeft(7, '0');
    // Prefix flows from the active branch for consistency with the sales path.
    final prefix = InvoiceNumberingService().buildPrefix(
      int.tryParse(userId) ?? 0,
      int.tryParse(branchId) ?? 0,
      int.tryParse(sectionId) ?? 0,
    );
    return "$prefix$formattedSequence";
  }

  Future<List<Map<String, dynamic>>> fetchRestaurantCategories() async {
    try {
      final db = await _dbHelper.database;
      const sql = '''
        SELECT DISTINCT g.* 
        FROM sun_item_groups g
        INNER JOIN sun_items i ON g.group_no = i.item_group_no
        WHERE CAST(i.categoryId AS TEXT) IN ('10', '18')
        ORDER BY g.group_no
      ''';
      return await db.rawQuery(sql);
    } catch (e) {
      print('--- DB ERROR (Categories): $e ---');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchRestaurantProducts(String groupId) async {
    try {
      final db = await _dbHelper.database;
      const sql = '''
        SELECT 
          item_no, 
          item_name, 
          item_price, 
          is_taxable, 
          tax_rate, 
          is_discountable, 
          discount_rate, 
          item_unit,
          imageBase
        FROM sun_items
        WHERE CAST(item_group_no AS TEXT) = ? AND CAST(categoryId AS TEXT) IN ('10', '18')
      ''';
      final products = await db.rawQuery(sql, [groupId]);
      List<Map<String, dynamic>> enrichedProducts = [];
      for (var p in products) {
        final itemNo = p['item_no'];
        final units = await db.rawQuery('SELECT unit_name, conversion_factor, sale_price FROM sun_itemsize WHERE item_no = ?', [itemNo]);
        enrichedProducts.add({...p, 'units_list': units});
      }
      return enrichedProducts;
    } catch (e) {
      print('--- DB ERROR (Products): $e ---');
      return [];
    }
  }

  /// Inserts a completely isolated RESTAURANT invoice offline.
  /// It intercepts the number generation logic using the legacy algorithm 
  /// explicitly targeting the `restaurant_invoices` table to ensure 
  /// standard sales tracking integers are not collided with or incremented.
  Future<String> insertIsolatedRestaurantInvoice({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> details,
  }) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      try {
        final headerData = Map<String, dynamic>.from(header);

        String invoiceNumber = headerData['invoiceNumber']?.toString() ?? '';

        if (invoiceNumber.isEmpty) {
          final String userId = headerData['userId']?.toString() ?? '1';
          final String branchId = headerData['branchId']?.toString() ?? '1';
          final String sectionId = headerData['sectionId']?.toString() ?? '1';

          // Extract the last generated sequence strictly for this user in the isolated table
          final List<Map<String, dynamic>> result = await txn.rawQuery('''
            SELECT invoiceNumber FROM restaurant_invoices 
            WHERE userId = ? 
            ORDER BY id DESC LIMIT 1
          ''', [userId]);

          int lastSequence = 0;
          if (result.isNotEmpty) {
            String lastInvoiceNumber = result.first['invoiceNumber'] as String;
            if (lastInvoiceNumber.length > 7) {
              String sequenceStr = lastInvoiceNumber.substring(lastInvoiceNumber.length - 7);
              lastSequence = int.tryParse(sequenceStr) ?? 0;
            }
          }

          int newSequence = lastSequence + 1;
          String formattedSequence = newSequence.toString().padLeft(7, '0');

          // Prefix flows from the active branch for consistency with the sales
          // path (legacy parity: "A" + UID + branch + section + 7-digit seq).
          final prefix = InvoiceNumberingService().buildPrefix(
            int.tryParse(userId) ?? 0,
            int.tryParse(branchId) ?? 0,
            int.tryParse(sectionId) ?? 0,
          );
          invoiceNumber = "$prefix$formattedSequence";

          headerData['invoiceNumber'] = invoiceNumber;
        }

        // 1. Insert Isolated Header
        await txn.insert('restaurant_invoices', headerData, conflictAlgorithm: ConflictAlgorithm.replace);

        // 2. Insert Isolated Details linked via invoiceNumber
        for (var item in details) {
          final itemData = Map<String, dynamic>.from(item);
          itemData['invoiceNumber'] = invoiceNumber;
          await txn.insert('restaurant_invoice_details', itemData);
        }

        return invoiceNumber;
      } catch (e) {
        log("Error inserting isolated restaurant invoice: $e");
        rethrow;
      }
    });
  }

  /// Appends a failed print payload into the pending queue offline
  Future<int> addInvoiceToPrintQueue(String traNo, String invoiceDataJson) async {
    final db = await _dbHelper.database;
    return await db.insert('pending_prints', {
      'tra_no': traNo,
      'invoice_data': invoiceDataJson,
    });
  }

  /// Discards a successful pending print payload off the queue
  Future<void> deleteFromPrintQueue(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'pending_prints',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> _buildUnsyncedPayloads() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> unsyncedInvoices = await db.query(
      'restaurant_invoices',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    if (unsyncedInvoices.isEmpty) return [];

    List<Map<String, dynamic>> enrichedPayloads = [];

    for (var header in unsyncedInvoices) {
      final List<Map<String, dynamic>> details = await db.query(
        'restaurant_invoice_details',
        where: 'invoiceNumber = ?',
        whereArgs: [header['invoiceNumber']],
      );

      final Map<String, dynamic> payload = {
        "invoiceNumber": header['invoiceNumber'],
        "orderNumber": header['orderNumber'],
        "customerName": header['customerName'],
        "traLstId": header['traLstId'] ?? "801",
        "traTitle": header['traTitle'] ?? "مبيعات مطعم",
        "boxId": header['boxId'],
        "boxName": header['boxName'],
        "boxNo": header['boxNo'],
        "boxParentName": header['boxParentName'],
        "storeId": header['storeId'],
        "storeName": header['storeName'],
        "currencyId": header['currencyId'],
        "currencyValue": header['currencyValue'],
        "discount": header['discount'],
        "tax": header['tax'],
        "total": header['total'],
        "netTotal": header['netTotal'],
        "netTotalInWords": header['netTotalInWords'],
        "userId": header['userId'],
        "userName": header['userName'],
        "branchId": header['branchId'],
        "sectionId": header['sectionId'],
        "yearId": header['yearId'],
        "transactionDate": header['transactionDate'] ?? header['created_at'],
        "orderTypeId": header['orderTypeId'],
        "isNetworkPayment": header['isNetworkPayment'] == 1 || header['isNetworkPayment'] == true || header['isNetworkPayment'] == 'true' || header['isNetworkPayment'] == '1',
        "paidAmount": header['paidAmount'],
        "createdAt": header['created_at'],
        "details": await Future.wait(details.map((d) async {
          // Lookup the real conversion factor from sun_itemsize
          double packFactor = 1.0;
          final String? itemId = d['itemId']?.toString();
          final String? unitName = d['unit']?.toString();
          if (itemId != null && unitName != null && unitName.isNotEmpty) {
            final unitRows = await db.query(
              'sun_itemsize',
              columns: ['conversion_factor'],
              where: 'item_no = ? AND unit_name = ? AND is_active = 1',
              whereArgs: [itemId, unitName],
              limit: 1,
            );
            if (unitRows.isNotEmpty) {
              packFactor = (unitRows.first['conversion_factor'] as num?)?.toDouble() ?? 1.0;
            }
          }
          return {
            "itemId": d['itemId'],
            "itemName": d['itemName'],
            "unit": d['unit'],
            "quantity": d['quantity'],
            "price": d['price'],
            "total": d['total'],
            "notes": d['notes'],
            "discount": d['discount'],
            "tax": d['tax'],
            "packFactor": packFactor,
          };
        }).toList()),
      };

      enrichedPayloads.add({
        'id': header['id'],
        'invoiceNumber': header['invoiceNumber'],
        'payload': payload
      });
    }

    return enrichedPayloads;
  }

  /// Syncs unpaid/unsynced restaurant invoices to the remote backend
  Future<int> syncRestaurantInvoicesToRemote(String apiUrl, String token) async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    
    int successCount = 0;
    try {
      final List<Map<String, dynamic>> enrichedData = await _buildUnsyncedPayloads();

      if (enrichedData.isEmpty) return 0;

      print('🚀 [Restaurant Sync] Found ${enrichedData.length} pending invoices to sync.');

      final url = Uri.parse('http://$apiUrl/api/RestaurantSync/sync-invoice');
      final db = await _dbHelper.database;

      for (var data in enrichedData) {
        try {
          final payload = data['payload'];
          print('📦 [Restaurant Sync] Sending Payload: ${jsonEncode(payload)}');
          
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            // STRICT RULE: Update locally ONLY on 200/201 success
            await db.update(
              'restaurant_invoices',
              {'is_synced': 1},
              where: 'id = ?',
              whereArgs: [data['id']],
            );
            successCount++;
            print('✅ [Restaurant Sync] Database updated: is_synced = 1 for ID ${data['id']}');
          } else {
            if (response.body.contains('Violation of PRIMARY KEY') || 
                response.body.contains('Cannot insert duplicate key')) {
              if (Get.isRegistered<GetMaterialController>() || Get.context != null) {
                Get.snackbar(
                  'تنبيه',
                  'تنبيه: رقم الفاتورة هذا (${data['invoiceNumber']}) موجود مسبقاً في النظام',
                  backgroundColor: const Color(0xFFD32F2F),
                  colorText: const Color(0xFFFFFFFF),
                  snackPosition: SnackPosition.TOP,
                );
              }
              log("CRITICAL: Aborting sync due to duplicate PK.");
              return successCount;
            }
            log("🌐 [Restaurant Sync] SERVER ERROR BODY: ${response.body}");
            log("Restaurant Sync failed for invoice ${data['invoiceNumber']}: ${response.statusCode}");
          }
        } catch (e) {
          log("Error processing invoice inside loop: $e");
        }
      }
    } catch (e) {
      log("Error during global restaurant sync process: $e");
    } finally {
      _isSyncing = false;
    }
    
    return successCount;
  }
}

