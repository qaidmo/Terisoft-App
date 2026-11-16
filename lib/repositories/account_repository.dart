import 'dart:developer';
import 'package:sqflite/sqflite.dart';
import '../models/sun_account_model.dart';
import '../models/sun_currency.dart';
import '../models/sun_account_currency.dart';
import '../models/sun_customer.dart';
import '../models/sun_customer_currency.dart';
import '../models/sun_supplier.dart';
import '../core/database_helper.dart';
import '../services/api_service.dart';

class AccountRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ApiService _apiService = ApiService();

  Future<void> syncCurrencies() async {
    const String tableName = 'sun_currencies';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/CoreData/currencies';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final List<SunCurrency> currencies = data.map((json) => SunCurrency.fromJson(json)).toList();

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var currency in currencies) {
      batch.insert(tableName, currency.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/CoreData/active-currency-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['currency_no']);
      final List<String> idsToDelete = localData.map((row) => row['currency_no'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'currency_no = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error cleaning ghost currencies: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncAccounts() async {
    const String tableName = 'sun_account';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/CoreData/accounts';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    List<SunAccount> accounts = data.map((json) => SunAccount.fromJson(json)).toList();
    accounts.sort((a, b) => a.accountNumber.length.compareTo(b.accountNumber.length));

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var account in accounts) {
      batch.insert(tableName, account.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/CoreData/active-account-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['id']);
      final List<String> idsToDelete = localData.map((row) => row['id'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) batchDelete.delete(tableName, where: 'id = ?', whereArgs: [id]);
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log("Error cleaning ghost accounts: $e");
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncAccountCurrencies() async {
    const String tableName = 'sun_account_currencies';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/CoreData/account-currencies';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final List<SunAccountCurrency> links = data.map((json) => SunAccountCurrency.fromJson(json)).toList();

    await _dbHelper.clearTable(tableName);

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var link in links) {
      batch.insert(tableName, link.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncCustomers() async {
    const String tableName = 'sun_customers';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/People/customers';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final List<SunCustomer> customers = data.map((json) => SunCustomer.fromJson(json)).toList();

    final db = await _dbHelper.database;
    final batchUpsert = db.batch();
    for (var customer in customers) {
      batchUpsert.insert(tableName, customer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batchUpsert.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/People/active-customer-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final List<Map<String, dynamic>> localData = await db.query(tableName, columns: ['customer_no', 'source_id']);
      final List<String> idsToDelete = [];
      for (var row in localData) {
        final localId = row['customer_no'].toString();
        final sourceId = row['source_id']?.toString();
        if (sourceId != null && !serverIdsSet.contains(sourceId)) {
          idsToDelete.add(localId);
        }
      }
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete(tableName, where: 'customer_no = ?', whereArgs: [id]);
        }
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log(e.toString());
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncSuppliers() async {
    const String tableName = 'sun_suppliers';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/People/suppliers';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final List<SunSupplier> suppliers = data.map((json) => SunSupplier.fromJson(json)).toList();

    final db = await _dbHelper.database;
    final batchUpsert = db.batch();
    for (var supplier in suppliers) {
      batchUpsert.insert(tableName, supplier.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batchUpsert.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/People/active-supplier-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final List<Map<String, dynamic>> localData = await db.query(tableName, columns: ['supplier_no', 'source_id']);
      final List<String> idsToDelete = [];
      for (var row in localData) {
        final localId = row['supplier_no'].toString();
        final sourceId = row['source_id']?.toString();
        if (sourceId != null && !serverIdsSet.contains(sourceId)) {
          idsToDelete.add(localId);
        }
      }
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete(tableName, where: 'supplier_no = ?', whereArgs: [id]);
        }
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log(e.toString());
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncCustomerCurrencies() async {
    const String tableName = 'sun_customer_currencies';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/People/customer-currencies';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);
    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final List<SunCustomerCurrency> links = data.map((json) => SunCustomerCurrency.fromJson(json)).toList();

    await _dbHelper.clearTable(tableName);

    final db = await _dbHelper.database;
    final batch = db.batch();
    for (var link in links) {
      batch.insert(tableName, link.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<List<SunAccount>> fetchAllAccounts() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.queryAll(
        'sun_account',
        orderBy: 'account_number ASC'
    );
    return maps.map((data) => SunAccount.fromMap(data)).toList();
  }

  Future<List<String>> getParentIdsByNumbers(List<String> accountNumbers) async {
    if (accountNumbers.isEmpty) return [];
    String placeholders = accountNumbers.map((e) => "'$e'").join(',');
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(
        'SELECT id FROM sun_account WHERE account_number IN ($placeholders)'
    );
    return maps.map((e) => e['id'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getTransactionalChildrenOfParents(List<String> parentIds) async {
    if (parentIds.isEmpty) return [];
    String placeholders = parentIds.map((e) => "'$e'").join(',');
    return await _dbHelper.rawQuery(
        'SELECT id, name, account_number FROM sun_account WHERE parent_id IN ($placeholders) AND is_transactional = 1'
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionalChildrenOfParent(String parentId) async {
    if (parentId.isEmpty) return [];
    return await _dbHelper.query(
        'sun_account',
        where: 'parent_id = ? AND is_transactional = ?',
        whereArgs: [parentId, 1],
        columns: ['id', 'name', 'account_number']
    );
  }

  Future<Map<String, dynamic>?> getAccountByTrimmedNumber(String accNo) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.query(
      'sun_account',
      where: 'account_number = ?',
      whereArgs: [accNo.trim()],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<Map<String, dynamic>> createCustomerOnServer(SunCustomer customer, String appUserName) async {
    final body = {
      "Name": customer.customerName,
      "ForeignName": customer.customerForeignName,
      "Phone": customer.phoneNumber,
      "Address": customer.address,
      "Email": customer.email,
      "AppUserName": appUserName,
      "CostData": customer.costData,
      "CostNext": customer.costNext?.toString(),
      "CostRsom": customer.costRsom?.toString(),
    };

    final response = await _apiService.post('api/People/create', body);
    return response;
  }

  Future<Map<String, dynamic>> updateCustomerOnServer(SunCustomer customer, String appUserName) async {
    final body = {
      "CustomerNo": customer.sourceId ?? customer.customerNo.toString(),
      "Name": customer.customerName,
      "ForeignName": customer.customerForeignName,
      "Phone": customer.phoneNumber,
      "Address": customer.address,
      "Email": customer.email,
      "CostData": customer.costData,
      "CostNext": customer.costNext?.toString(),
      "CostRsom": customer.costRsom?.toString(),
    };

    final response = await _apiService.post('api/People/update', body);
    return response;
  }

  Future<void> updateLocalCustomerIds(int localCustomerNo, String newSourceId, String newAccountId) async {
    final db = await _dbHelper.database;

    await db.update(
      'sun_customers',
      {
        'source_id': newSourceId,
        'account_id': newAccountId,
        'last_updated': DateTime.now().toString()
      },
      where: 'customer_no = ?',
      whereArgs: [localCustomerNo],
    );
  }
}