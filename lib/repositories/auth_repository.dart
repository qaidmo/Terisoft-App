import 'dart:developer';
import 'package:sqflite/sqflite.dart'; // 👈 ضروري لعمليات الـ Batch
import '../models/full_user_data.dart';
import '../core/database_helper.dart';
import '../models/sun_permissions.dart';
import '../services/api_service.dart';
import '../services/invoice_numbering_service.dart';

class AuthRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ApiService _apiService = ApiService();

  // ============================================================
  // أولاً: دوال المزامنة
  // ============================================================

  Future<void> syncUsers() async {
    const String tableName = 'sun_users';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/People/users';
    if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

    final response = await _apiService.get(endpoint);

    final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
    final List<dynamic> data = responseMap['data'];
    final String? serverTime = responseMap['server_sync_time'];

    final db = await _dbHelper.database;

    // Project the server payload onto the local columns. The backend may ship a
    // newer field (e.g. can_change_branch) before this client's schema bump
    // lands; unknown keys are dropped rather than crashing the raw insert.
    final Set<String> columns = (await db.rawQuery('PRAGMA table_info($tableName)'))
        .map((row) => row['name'].toString())
        .toSet();

    final batchUpsert = db.batch();

    for (var json in data) {
      final filtered = Map<String, dynamic>.from(json)
        ..removeWhere((key, _) => !columns.contains(key));

      // SQLite does not accept Dart booleans — only num, String, and
      // Uint8List are valid sqflite column value types. The server payload
      // includes `can_change_branch` as a JSON boolean (true/false), which
      // dart:convert decodes to a Dart bool. The one-liner below coerces
      // every bool in the filtered map to its integer equivalent
      // (true → 1, false → 0); all other types pass through unchanged.
      final sanitised = filtered.map(
        (k, v) => MapEntry(k, v is bool ? (v ? 1 : 0) : v),
      );

      batchUpsert.insert(
          tableName,
          sanitised,
          conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batchUpsert.commit(noResult: true);

    try {
      final activeIdsResponse = await _apiService.get('api/People/active-user-ids');
      final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
      final localData = await db.query(tableName, columns: ['user_no']);
      final List<String> idsToDelete = localData.map((row) => row['user_no'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete(tableName, where: 'user_no = ?', whereArgs: [id]);
        }
        await batchDelete.commit(noResult: true);
      }
    } catch (e) {
      log(e.toString());
    }

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }

  Future<void> syncPermissions() async {
    const String tableName = 'sun_permissions';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    String endpoint = 'api/People/permissions';
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
    final batch = db.batch();

    for (var json in data) {
      final permission = SunPermissions.fromJson(json);
      batch.insert(
        tableName,
        permission.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
  }
  // ============================================================
  // ثانياً: دوال العمليات (بدون تغيير)
  // ============================================================

  Future<FullUserData> fetchComplexUserData(
      String username, int branch, int department) async {
    try {
      // 1. جلب بيانات المستخدم الأساسية
      final List<Map<String, dynamic>> userMaps = await _dbHelper.query(
        'sun_users',
        where: 'user_name = ? AND user_branch = ? AND user_department = ?',
        whereArgs: [username, branch, department],
      );

      if (userMaps.isEmpty) throw Exception("User not found locally");

      final Map<String, dynamic> fullData = Map<String, dynamic>.from(userMaps.first);
      final int userNo = fullData['user_no'];
      final int? boxNo = fullData['box_no'];
      final int? storeNo = fullData['no_store'];

      // 2. جلب البيانات المرتبطة
      fullData['sun_branches'] = (await _dbHelper.query('sun_branches', where: 'branch_id = ?', whereArgs: [branch])).firstOrNull;
      fullData['sun_departments'] = (await _dbHelper.query('sun_departments', where: 'department_id = ?', whereArgs: [department])).firstOrNull;
      fullData['sun_permissions'] = await _dbHelper.query('sun_permissions', where: 'user_no = ?', whereArgs: [userNo]);
      fullData['sun_store'] = storeNo != null ? (await _dbHelper.query('sun_store', where: 'no_store = ?', whereArgs: [storeNo])).firstOrNull : null;

      // 3. جلب بيانات الصندوق وعملاته
      if (boxNo != null) {
        final boxMap = (await _dbHelper.query('sun_boxes', where: 'box_no = ?', whereArgs: [boxNo])).firstOrNull;
        if (boxMap != null) {
          final boxFull = Map<String, dynamic>.from(boxMap);
          const currenciesSql = '''
            SELECT c.* FROM sun_currencies c
            JOIN sun_box_currencies bc ON c.currency_no = bc.currency_id
            WHERE bc.box_no = ?
          ''';
          final currencies = await _dbHelper.rawQuery(currenciesSql, [boxNo]);

          boxFull['sun_box_currencies'] = currencies.map((c) => {'sun_currencies': c}).toList();
          fullData['sun_boxes'] = boxFull;
        }
      }

      return FullUserData.fromJson(fullData);
    } catch (e) {
      log("Error in fetchComplexUserData: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFinancialYears() async {
    return await _dbHelper.queryAll('sun_years', orderBy: 'year_name DESC');
  }

  Future<List<Map<String, dynamic>>> fetchSimpleUserList() async {
    return await _dbHelper.query(
        'sun_users',
        columns: ['user_name', 'user_branch', 'user_department', 'user_status'],
        orderBy: 'user_name ASC'
    );
  }

  // ============================================================
  // دالة جديدة: جلب تفاصيل صناديق سندات القبض والصرف
  // ============================================================
  Future<Map<String, dynamic>> fetchUserBondBoxes(int userNo) async {
    final db = await _dbHelper.database;

    // 1. جلب أرقام صناديق السندات للمستخدم من الجدول المحدث
    final List<Map<String, dynamic>> userResult = await db.query(
      'sun_users',
      columns: ['receipt_box_no', 'payment_box_no'],
      where: 'user_no = ?',
      whereArgs: [userNo],
    );

    if (userResult.isEmpty) return {};

    final row = userResult.first;
    // التأكد من تحويل البيانات إلى int بشكل آمن
    final int? receiptBoxId = row['receipt_box_no'] != null
        ? int.tryParse(row['receipt_box_no'].toString())
        : null;

    final int? paymentBoxId = row['payment_box_no'] != null
        ? int.tryParse(row['payment_box_no'].toString())
        : null;

    // 2. دالة داخلية مساعدة لجلب (الاسم + العملة) لأي صندوق
    Future<Map<String, dynamic>?> getBoxDetails(int? boxId) async {
      if (boxId == null) return null;

      try {
        // أ. جلب اسم الصندوق
        final List<Map<String, dynamic>> boxResult = await db.query(
          'sun_boxes',
          columns: ['box_name'],
          where: 'box_no = ?',
          whereArgs: [boxId],
        );

        if (boxResult.isEmpty) return null;
        final String boxName = boxResult.first['box_name'].toString();

        // ب. جلب عملة الصندوق (نأخذ العملة الأولى المرتبطة به)
        const String currencySql = '''
          SELECT c.currency_no, c.currency_symbol
          FROM sun_currencies c
          JOIN sun_box_currencies bc ON c.currency_no = bc.currency_id
          WHERE bc.box_no = ?
          LIMIT 1
        ''';

        final List<Map<String, dynamic>> currencyResult = await db.rawQuery(currencySql, [boxId]);

        int currencyNo = 0;
        String currencySymbol = '';

        if (currencyResult.isNotEmpty) {
          currencyNo = int.tryParse(currencyResult.first['currency_no'].toString()) ?? 0;
          currencySymbol = currencyResult.first['currency_symbol'].toString();
        }

        return {
          'box_no': boxId,
          'box_name': boxName,
          'currency_no': currencyNo,
          'currency_symbol': currencySymbol,
        };
      } catch (e) {
        log("Error getting details for box $boxId: $e");
        return null;
      }
    }

    // 3. تجميع النتائج وإعادتها
    return {
      'receipt_box': await getBoxDetails(receiptBoxId),
      'payment_box': await getBoxDetails(paymentBoxId),
    };
  }

  Future<bool> checkDatabaseConnection() async {
    try {
      await _apiService.get('api/CoreData/check-connection');
      return true;
    } catch (e) {
      log("Offline mode or API unreachable");
      return false;
    }
  }

  Future<String?> fetchUserPasswordHash(int userNo) async {
    final result = await _dbHelper.query(
        'sun_users',
        columns: ['password_hash'],
        where: 'user_no = ?',
        whereArgs: [userNo]
    );
    return result.isNotEmpty ? result.first['password_hash'] as String? : null;
  }

  Future<void> updateUserPassword(int userNo, String newHashedPassword) async {
    await _dbHelper.update(
        'sun_users',
        {'password_hash': newHashedPassword, 'modified_at': DateTime.now().toIso8601String()},
        'user_no = ?',
        [userNo]
    );
  }

  Future<String> getEstimatedTransactionNumber(int userNo, String invoiceTypeChar) async {
    try {
      return InvoiceNumberingService().previewNextNumber(userNo, invoiceTypeChar);
    } catch (e) {
      log("Error in getEstimatedTransactionNumber: $e");
      rethrow;
    }
  }

  Future<String?> fetchUserNameByUserNo(int userNo) async {
    final result = await _dbHelper.query(
        'sun_users',
        columns: ['user_name'],
        where: 'user_no = ?',
        whereArgs: [userNo]
    );
    return result.isNotEmpty ? result.first['user_name'] as String? : null;
  }
}