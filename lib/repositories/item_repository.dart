import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import '../models/sun_item.dart';
import '../core/database_helper.dart';
import '../services/api_service.dart';

class ItemRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ApiService _apiService = ApiService();

  Future<void> syncMainGroups() async {
    const String tableName = 'sun_main_groups';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/Inventory/main-groups';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var json in data) {
      batch.insert(tableName, json, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/Inventory/active-main-group-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['source_id']);
      final List<String> idsToDelete = localData.map((row) => row['source_id'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'source_id = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error cleaning ghost main groups: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncItemGroups() async {
    const String tableName = 'sun_item_groups';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/Inventory/item-groups';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var json in data) {
      batch.insert(tableName, json, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/Inventory/active-item-group-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['source_id']);
      final List<String> idsToDelete = localData.map((row) => row['source_id'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'source_id = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error cleaning ghost item groups: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncItems() async {
    const String tableName = 'sun_items';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/Inventory/items';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);

    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final db = await _dbHelper.database;
    final batchUpsert = db.batch();

    for (var json in data) {
      final Map<String, dynamic> itemToSave = Map<String, dynamic>.from(json);
      itemToSave['categoryId'] = itemToSave['item_type_id']?.toString();
      itemToSave.remove('item_type_id');
      itemToSave['imageBase'] = itemToSave['image_base64'];
      itemToSave.remove('image_base64');

      batchUpsert.insert(
        tableName,
        itemToSave,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batchUpsert.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/Inventory/active-item-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['item_no']);
      final List<String> idsToDelete = localData.map((row) => row['item_no'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'item_no = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log(e.toString());
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncItemUnits() async {
    const String tableName = 'sun_itemsize';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/Inventory/item-units';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var json in data) {
      batch.insert(tableName, json, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/Inventory/active-item-unit-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['unit_id']);
      final List<String> idsToDelete = localData.map((row) => row['unit_id'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'unit_id = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error cleaning ghost item units: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncInventory() async {
    const String tableName = 'sun_stock';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/Inventory/stock-balances';
    if (lastSyncDate != null) {
      endpoint += '?lastSyncDate=$lastSyncDate';
    }

    final response = await _apiService.get(endpoint);

    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    if (data.isEmpty && lastSyncDate != null) {
      if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
      return;
    }

    final db = await _dbHelper.database;

    Map<String, Map<String, dynamic>> aggregatedMap = {};

    for (var json in data) {
      String batchNo = json['batch_no']?.toString() ?? '';
      String key = '${json['item_no']}_${json['store_no']}_${json['expiry_date']}_$batchNo';

      if (aggregatedMap.containsKey(key)) {
        var existing = aggregatedMap[key]!;

        double currentQty = (existing['quantity'] as num).toDouble();
        double newQty = (json['quantity'] as num).toDouble();
        existing['quantity'] = currentQty + newQty;

        existing['updated_at'] = json['updated_at'];
        existing['last_updated_str'] = json['last_updated_str'];

      } else {
        aggregatedMap[key] = Map<String, dynamic>.from(json);
      }
    }

    List<Map<String, dynamic>> consolidatedData = aggregatedMap.values.toList();

    await db.transaction((txn) async {
      if (lastSyncDate == null) {
        await txn.delete(tableName);
      }

      final batch = txn.batch();
      for (var json in consolidatedData) {
        json['batch_no'] = json['batch_no']?.toString() ?? '';
        json['expiry_date'] = json['expiry_date']?.toString() ?? '';
        
        batch.insert(
            tableName,
            json,
            conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
      await batch.commit(noResult: true);

      final List<Map<String, dynamic>> pendingItems = await txn.rawQuery('''
      SELECT 
        si.item_no, 
        s.store_no, 
        si.expiry_date,
        si.batch_no,
        SUM(
            si.quantity * COALESCE(si.pack_factor, 1) * CASE WHEN s.invoice_type_char LIKE 'ر%' THEN 1 ELSE -1 END
        ) as quantity_change
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.is_synced = 0
      GROUP BY si.item_no, s.store_no, si.expiry_date, si.batch_no
    ''');

      for (var item in pendingItems) {
        await txn.rawUpdate('''
         UPDATE sun_stock
         SET quantity = quantity + ?
         WHERE item_no = ? AND store_no = ? AND expiry_date = ? AND batch_no = ?
       ''', [
          item['quantity_change'],
          item['item_no'],
          item['store_no'],
          item['expiry_date'] ?? '',
          item['batch_no'] ?? ''
        ]);
      }
    });

    log("Inventory Synced. Items merged: ${data.length} -> ${consolidatedData.length}");

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<List<SunItem>> fetchAllItemsWithDetails() async {
    try {
      const sql = '''
      SELECT 
        i.*, 
        g.group_name,
        (SELECT SUM(s.quantity) FROM sun_stock s WHERE s.item_no = i.item_no) as total_stock
      FROM sun_items i
      LEFT JOIN sun_item_groups g ON i.item_group_no = g.group_no
    ''';

      final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(sql);

      return maps.map((data) {
        final itemMap = Map<String, dynamic>.from(data);

        itemMap['section_no'] = data['section_no']?.toString();
        itemMap['average_cost'] = data['average_cost']?.toString();
        itemMap['total_stock'] = (data['total_stock'] as num?)?.toDouble() ?? 0.0;

        itemMap['sun_item_groups'] = {
          'group_name': data['group_name']
        };
        return SunItem.fromJson(itemMap);
      }).toList();
    } catch (e) {
      log("Error in fetchAllItemsWithDetails: $e");
      rethrow;
    }
  }

  Future<String?> getNextItemCode(String groupNo, int groupLength) async {
    try {
      final List<Map<String, dynamic>> result = await _dbHelper.rawQuery(
          "SELECT MAX(item_no) as max_code FROM sun_items WHERE item_no LIKE '$groupNo-%'"
      );

      if (result.isNotEmpty && result.first['max_code'] != null) {
        String lastCode = result.first['max_code'];
        int lastNumber = int.parse(lastCode.replaceFirst('$groupNo-', ''));
        return '$groupNo-' + (lastNumber + 1).toString().padLeft(groupLength, '0');
      }

      return '$groupNo-' + '1'.padLeft(groupLength, '0');
    } catch (e) {
      log('Error getting next item code locally for group $groupNo: $e');
      rethrow;
    }
  }

  Future<void> updateItem(String itemNo, Map<String, dynamic> data) async {
    try {
      await _dbHelper.update(
          'sun_items',
          data,
          'item_no = ?',
          [itemNo]
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createNewItem(Map<String, dynamic> params) async {
    try {
      await _dbHelper.insert('sun_items', params);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteItem(String itemNo) async {
    try {
      await _dbHelper.delete(
          'sun_items',
          'item_no = ?',
          [itemNo]
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sends a new item to the server for insertion into SUNITEM.
  /// Returns the server's response map (contains 'success' and 'item_no').
  /// Throws on network error or non-2xx HTTP status.
  Future<Map<String, dynamic>> createItemOnServer(Map<String, dynamic> serverParams) async {
    try {
      final response = await _apiService.post('api/Inventory/create-item', serverParams, timeout: const Duration(seconds: 15));
      return response as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Sends updated item data to the server to UPDATE the existing SUNITEM record.
  /// Returns the server's response map (contains 'success' and 'item_no').
  /// Throws on network error or non-2xx HTTP status.
  Future<Map<String, dynamic>> updateItemOnServer(String itemNo, Map<String, dynamic> serverData) async {
    try {
      final body = {
        'ItemNo': itemNo,
        'ItemName': serverData['item_name'],
        'ItemBarcode': serverData['item_barcode'],
        'ItemUnit': serverData['item_unit'],
        'ItemPrice': serverData['item_price'],
        'CurrencyNo': serverData['currency_no'],
        'InventoryAccountId': serverData['inventory_account_id'],
        'CogsAccountId': serverData['cogs_account_id'],
        'SalesRevenueAccountId': serverData['sales_revenue_account_id'],
        'SalesDiscountAccountId': serverData['sales_discount_account_id'],
        'IsTaxable': serverData['is_taxable'] == true || serverData['is_taxable'] == 1,
        'TaxRate': serverData['tax_rate'] ?? 0.0,
        'IsDiscountable': serverData['is_discountable'] == true || serverData['is_discountable'] == 1,
        'DiscountRate': serverData['discount_rate'],
        'IsCashReserved': serverData['is_cash_reserved'] == true || serverData['is_cash_reserved'] == 1,
        'CostCenterNo': serverData['cost_center_no'],
      };
      final response = await _apiService.post('api/Inventory/update-item', body, timeout: const Duration(seconds: 15));
      return response as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> fetchDistinctUnits() async {
    try {
      const sql = '''
        SELECT DISTINCT unit_name 
        FROM sun_itemsize 
        WHERE is_active = 1 
          AND unit_name IS NOT NULL 
          AND unit_name != ''
      ''';
      final result = await _dbHelper.rawQuery(sql);
      return result.map((row) => row['unit_name'].toString()).toList();
    } catch (e) {
      log('Error getting distinct units: $e');
      return [];
    }
  }

  Future<double> getUnitConversionFactor(String unitName) async {
    try {
      final result = await _dbHelper.query(
        'sun_itemsize',
        columns: ['conversion_factor'],
        where: 'unit_name = ?',
        whereArgs: [unitName],
      );
      if (result.isNotEmpty) {
        return (result.first['conversion_factor'] as num?)?.toDouble() ?? 1.0;
      }
      return 1.0;
    } catch (e) {
      log('Error getting unit conversion factor: $e');
      return 1.0;
    }
  }

  Future<List<Map<String, dynamic>>> fetchItemsByCategory(String categoryId) async {
    try {
      const sql = '''
      SELECT 
        i.item_no, 
        i.item_name, 
        i.item_barcode, 
        i.item_price, 
        i.is_taxable, 
        i.tax_rate, 
        i.cost_center_no, 
        i.is_discountable, 
        i.discount_rate, 
        i.is_cash_reserved, 
        i.item_unit,
        i.section_no,
        i.average_cost,
        i.categoryId,
        i.imageBase,
        COALESCE(SUM(s.quantity), 0) as total_stock
      FROM sun_items i
      LEFT JOIN sun_stock s ON i.item_no = s.item_no
      WHERE i.categoryId = ?
      GROUP BY i.item_no
    ''';

      final result = await _dbHelper.rawQuery(sql, [categoryId]);

      const unitsSql = 'SELECT * FROM sun_itemsize WHERE is_active = 1';
      final unitsResult = await _dbHelper.rawQuery(unitsSql);

      final Map<String, List<Map<String, dynamic>>> unitsMap = {};
      for (var row in unitsResult) {
        final String itemNo = row['item_no'].toString();
        if (!unitsMap.containsKey(itemNo)) {
          unitsMap[itemNo] = [];
        }
        unitsMap[itemNo]!.add(Map<String, dynamic>.from(row));
      }

      return result.map((row) {
        final item = Map<String, dynamic>.from(row);
        item['section_no'] = row['section_no']?.toString();
        item['average_cost'] = row['average_cost']?.toString();
        item['total_stock'] = (row['total_stock'] as num?)?.toDouble() ?? 0.0;

        final String itemNo = item['item_no'].toString();
        item['units_list'] = unitsMap[itemNo] ?? [];

        return item;
      }).toList();
    } catch (e) {
      log('Error getting items by category locally: \$e');
      rethrow;
    }
  }
}
