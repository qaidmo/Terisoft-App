import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/sun_box.dart';
import '../models/sun_currency.dart';
import '../models/sun_store.dart';
import '../models/sun_account_model.dart';
import '../models/sun_customer.dart';
import '../core/database_helper.dart';
import '../services/api_service.dart';

class LookupsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ApiService _apiService = ApiService();

  Future<void> syncBranches() async {
    const String tableName = 'sun_branches';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/CoreData/branches';
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
      final activeIdsResponse = await _apiService.get('api/CoreData/active-branch-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['branch_id']);
      final List<String> idsToDelete = localData.map((row) => row['branch_id'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'branch_id = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error cleaning ghost branches: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncDepartments() async {
    const String tableName = 'sun_departments';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/CoreData/departments';
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
      final activeIdsResponse = await _apiService.get('api/CoreData/active-department-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['department_id']);
      final List<String> idsToDelete = localData.map((row) => row['department_id'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'department_id = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error cleaning ghost departments: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncAccountTypes() async {
    const String tableName = 'sun_account_types';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/Account/account-types';
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

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncAccountMajorTypes() async {
    const String tableName = 'sun_account_major_types';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/Account/account-major-types';
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

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncAccountClassifications() async {
    const String tableName = 'sun_account_classifications';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/Account/account-classifications';
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

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncFinancialYears() async {
    const String tableName = 'sun_years';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/CoreData/financial-years';
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
      final activeIdsResponse = await _apiService.get('api/CoreData/active-financial-year-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['id']);
      final List<String> idsToDelete = localData.map((row) => row['id'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'id = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error cleaning ghost financial years: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncCostCenters() async {
    const String tableName = 'cost_centers';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/Inventory/cost-centers';
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
      final activeIdsResponse = await _apiService.get('api/Inventory/active-cost-center-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['center_no']);
      final List<String> idsToDelete = localData.map((row) => row['center_no'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'center_no = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error cleaning ghost cost centers: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncPumps() async {
    const String tableName = 'sun_pumps';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/CoreData/pumps';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['serverTime'];

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var json in data) {
      batch.insert(
          tableName,
          {
            'm_no': json['mNo']?.toString() ?? json['m_no']?.toString() ?? '',
            'm_name': json['mName']?.toString() ?? json['m_name']?.toString() ?? '',
            'm_right': double.tryParse(json['mRight']?.toString() ?? json['m_right']?.toString() ?? '0') ?? 0.0,
            'date_m_right': json['dateMRight']?.toString() ?? json['date_m_right']?.toString()
          },
          conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit(noResult: true);

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncSalespersons() async {
    const String tableName = 'sun_salespeople';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/People/salespersons';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final db = await _dbHelper.database;
    final batchUpsert = db.batch();

    for (var json in data) {
      batchUpsert.insert(
          tableName,
          json,
          conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batchUpsert.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/People/active-salesperson-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['salesperson_no']);
      final List<String> idsToDelete = localData.map((row) => row['salesperson_no'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete(tableName, where: 'salesperson_no = ?', whereArgs: [id]);
        }
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error during salespersons cleanup: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncCollectors() async {
    const String tableName = 'sun_collectors';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/People/collectors';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final db = await _dbHelper.database;
    final batchUpsert = db.batch();

    for (var json in data) {
      batchUpsert.insert(
          tableName,
          json,
          conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batchUpsert.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/People/active-collector-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['collector_no']);
      final List<String> idsToDelete = localData.map((row) => row['collector_no'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete(tableName, where: 'collector_no = ?', whereArgs: [id]);
        }
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error during collectors cleanup: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }


  // ============================================================
  // ثانياً: دوال الجلب المحلي (بنفس مسمياتك القديمة تماماً)
  // ============================================================

  Future<SunBox> fetchBox(int boxNo) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.query(
      'sun_boxes',
      where: 'box_no = ?',
      whereArgs: [boxNo],
    );
    if (maps.isEmpty) throw Exception("Box not found");
    return SunBox.fromJson(maps.first);
  }

  Future<SunStore> fetchStore(int storeNo) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.query(
      'sun_store',
      where: 'no_store = ?',
      whereArgs: [storeNo],
    );
    if (maps.isEmpty) throw Exception("Store not found");
    return SunStore.fromJson(maps.first);
  }

  Future<List<SunStore>> fetchAllStores() async {
    final maps = await _dbHelper.queryAll('sun_store', orderBy: 'no_store');
    return maps.map((json) => SunStore.fromJson(json)).toList();
  }

  Future<List<SunCurrency>> fetchCurrenciesForBox(int boxNo) async {
    const sql = '''
      SELECT c.* FROM sun_currencies c
      JOIN sun_box_currencies bc ON c.currency_no = bc.currency_id
      WHERE bc.box_no = ?
    ''';
    final List<Map<String, dynamic>> result = await _dbHelper.rawQuery(sql, [boxNo]);
    return result.map((json) => SunCurrency.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllCollectors() async {
    return await _dbHelper.query('sun_collectors', columns: ['id', 'collector_no', 'collector_name']);
  }

  Future<List<Map<String, dynamic>>> fetchAllAgents() async {
    return await _dbHelper.query('sun_salespeople', columns: ['id', 'salesperson_no', 'salesperson_name']);
  }

  Future<List<Map<String, dynamic>>> fetchAllAvailableItems({
    int? branchId,
    int? storeNo,
  }) async {
    // G1: scope the list-level stock aggregate to the active branch/store. The
    // per-item path was already branch-scoped; only this aggregate crossed
    // branches and becomes visibly misleading once branch selection ships.
    String stockJoin = 'LEFT JOIN sun_stock s ON i.item_no = s.item_no';
    final List<dynamic> args = <dynamic>[];
    if (branchId != null && storeNo != null) {
      stockJoin =
          'LEFT JOIN sun_stock s ON i.item_no = s.item_no AND s.branch_id = ? AND s.store_no = ?';
      args.addAll([branchId, storeNo]);
    } else if (branchId != null) {
      stockJoin =
          'LEFT JOIN sun_stock s ON i.item_no = s.item_no AND s.branch_id = ?';
      args.add(branchId);
    }

    final sql = '''
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
    i.sales_revenue_account_id,
    i.cogs_account_id,
    i.average_cost,
    COALESCE(SUM(s.quantity), 0) as total_stock
  FROM sun_items i
  $stockJoin
  GROUP BY i.item_no
''';

    final result = await _dbHelper.rawQuery(sql, args);

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
  }

  Future<List<SunCustomer>> fetchAllCustomers() async {
    // الاستعلام ممتاز ويجلب كل ما نحتاجه
    const sql = '''
      SELECT 
        c.*, 
        a.id as acc_id, 
        a.account_number, 
        a.name as acc_name
      FROM sun_customers c
      LEFT JOIN sun_account a ON c.account_id = a.id
    ''';

    final result = await _dbHelper.rawQuery(sql);

    // 👇 التعديل: نمرر النتائج مباشرة لـ fromMap المعدلة
    return result.map((row) => SunCustomer.fromMap(row)).toList();
  }

  Future<List<SunCurrency>> fetchAllCurrencies() async {
    final maps = await _dbHelper.queryAll('sun_currencies');
    return maps.map((json) => SunCurrency.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllCostCenters() async {
    return await _dbHelper.queryAll('cost_centers');
  }

  Future<List<SunBox>> fetchAllBoxes() async {
    final maps = await _dbHelper.query('sun_boxes', columns: ['box_no', 'box_name', 'account_id']);
    return maps.map((json) => SunBox.fromJson(json)).toList();
  }

  Future<List<SunBox>> fetchNetworkBoxes() async {
    final maps = await _dbHelper.query(
      'sun_boxes',
      where: "control_account_id LIKE '1213%'",
    );
    return maps.map((json) => SunBox.fromJson(json)).toList();
  }

  Future<List<SunAccount>> fetchAllAccounts() async {
    final maps = await _dbHelper.query(
        'sun_account',
        columns: ['id', 'account_number', 'name', 'name_en', 'parent_id', 'is_transactional', 'is_active']
    );
    return maps.map((json) => SunAccount.fromJson(json)).toList();
  }

  Future<List<SunCurrency>> fetchCurrenciesForAccount(String accountId) async {
    const accSql = '''
    SELECT c.* FROM sun_currencies c
    JOIN sun_account_currencies ac ON c.currency_no = ac.currency_id
    WHERE ac.account_id = ?
  ''';
    final accResult = await _dbHelper.rawQuery(accSql, [accountId]);

    if (accResult.isNotEmpty) {
      return accResult.map((e) => SunCurrency.fromJson(e)).toList();
    }

    int? boxNo = int.tryParse(accountId);

    if (boxNo != null) {
      const boxSql = '''
      SELECT c.* FROM sun_currencies c
      JOIN sun_box_currencies bc ON c.currency_no = bc.currency_id
      WHERE bc.box_no = ?
    ''';
      final boxResult = await _dbHelper.rawQuery(boxSql, [boxNo]);

      if (boxResult.isNotEmpty) {
        return boxResult.map((e) => SunCurrency.fromJson(e)).toList();
      }
    return [];
  }

    final List<Map<String, dynamic>> customerCheck = await _dbHelper.query(
        'sun_customers',
        columns: ['customer_no'],
        where: 'account_id = ?',
        whereArgs: [accountId]
    );

    if (customerCheck.isNotEmpty) {
      return await fetchCurrenciesForCustomer(customerCheck.first['customer_no'] as int);
    }

    return [];
  }

  Future<List<SunCurrency>> fetchCurrenciesForCustomer(int customerNo) async {
    const sql = '''
      SELECT c.* FROM sun_currencies c
      JOIN sun_customer_currencies cc ON c.currency_no = cc.currency_no
      WHERE cc.customer_no = ?
    ''';
    final result = await _dbHelper.rawQuery(sql, [customerNo]);
    return result.map((e) => SunCurrency.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllAccountTypes() async {
    return await _dbHelper.queryAll('sun_account_types');
  }

  Future<List<Map<String, dynamic>>> fetchAllMajorAccountTypes() async {
    return await _dbHelper.queryAll('sun_account_major_types');
  }

  Future<List<Map<String, dynamic>>> fetchAllAccountClassifications() async {
    return await _dbHelper.queryAll('sun_account_classifications');
  }

  Future<List<Map<String, dynamic>>> fetchCurrenciesForAccounts(List<String> accountIds) async {
    if (accountIds.isEmpty) return [];
    final placeholders = accountIds.map((id) => "'$id'").join(',');
    final sql = '''
      SELECT ac.account_id, c.currency_name 
      FROM sun_account_currencies ac
      JOIN sun_currencies c ON ac.currency_id = c.currency_no
      WHERE ac.account_id IN ($placeholders)
    ''';
    return await _dbHelper.rawQuery(sql);
  }

  Future<SunAccount?> fetchAccountById(int id) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.query(
      'sun_account',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return SunAccount.fromJson(maps.first);
    return null;
  }

  // البحث عن حساب بواسطة رقم الحساب (Account Number)
  Future<SunAccount?> fetchAccountByNumber(String accountNumber) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.query(
      'sun_account',
      where: 'account_number = ?',
      whereArgs: [accountNumber],
    );
    if (maps.isNotEmpty) return SunAccount.fromJson(maps.first);
    return null;
  }

  Future<List<Map<String, dynamic>>> getAllTransactionalAccounts() async {
    return await _dbHelper.query('sun_account', where: 'is_transactional = ?', whereArgs: [1]);
  }

  Future<List<Map<String, dynamic>>> fetchAllAgentsWithDetails() async {
    const sql = '''
      SELECT sp.*, a.name as account_name, ea.name as expense_account_name
      FROM sun_salespeople sp
      LEFT JOIN sun_account a ON sp.account_id = a.id
      LEFT JOIN sun_account ea ON sp.expense_account_id = ea.id
      ORDER BY sp.salesperson_no
    ''';
    return await _dbHelper.rawQuery(sql);
  }

  Future<List<Map<String, dynamic>>> fetchAllAccountNames() async {
    return await _dbHelper.query('sun_account', columns: ['id', 'name']);
  }

  Future<List<Map<String, dynamic>>> fetchAllBranches() async {
    return await _dbHelper.queryAll('sun_branches', orderBy: 'branch_id');
  }

  Future<List<Map<String, dynamic>>> fetchAllCollectorsWithDetails() async {
    const sql = '''
      SELECT sc.*, a.name as account_name, b.branch_name
      FROM sun_collectors sc
      LEFT JOIN sun_account a ON sc.account_id = a.id
      LEFT JOIN sun_branches b ON sc.branch_id = b.branch_id
      ORDER BY sc.collector_no
    ''';
    return await _dbHelper.rawQuery(sql);
  }

  /// جلب تفاصيل القسم (الاسم، العنوان، الشعار) من السيرفر
  Future<Map<String, dynamic>?> fetchDepartmentDetails(String departmentId) async {
    try {
      // 1. الحصول على عنوان السيرفر المخزن
      final prefs = await SharedPreferences.getInstance();
      final String? serverAddress = prefs.getString('server_address');

      if (serverAddress == null || serverAddress.isEmpty) {
        log("⚠️ Server address is missing.");
        return null;
      }

      // 2. تكوين الرابط (Endpoint)
      // تأكد أن المسار يطابق ما كتبناه في السيرفر: api/CoreData/department-details/{departmentId}
      final Uri uri = Uri.parse('http://$serverAddress/api/CoreData/department-details/$departmentId');

      // 3. إرسال الطلب
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      // 4. معالجة الاستجابة
      if (response.statusCode == 200) {
        // السيرفر يرجع JSON يحتوي على CompanyName, Address, LogoBase64
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        log("❌ Failed to fetch department details. Status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      log("❌ Error fetching department details: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllDepartments() async {
    return await _dbHelper.queryAll('sun_departments', orderBy: 'department_id');
  }

  Future<List<Map<String, dynamic>>> fetchAllItemGroups() async {
    return await _dbHelper.queryAll('sun_item_groups', orderBy: 'group_no');
  }

  Future<List<Map<String, dynamic>>> fetchAllMainGroups() async {
    return await _dbHelper.queryAll('sun_main_groups', orderBy: 'main_group_no');
  }
}