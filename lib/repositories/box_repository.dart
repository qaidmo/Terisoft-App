import 'dart:developer';
import 'package:sqflite/sqflite.dart';

import '../models/sun_box.dart';
import '../core/database_helper.dart';
import '../services/api_service.dart';

class BoxRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ApiService _apiService = ApiService();

  // ============================================================
  // أولاً: دوال المزامنة
  // ============================================================

  Future<void> syncBoxes() async {
    const String tableName = 'sun_boxes';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    try {
      String endpoint = 'api/CoreData/boxes';
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
        final activeIdsResponse = await _apiService.get('api/CoreData/active-box-ids');
        final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
        final localData = await db.query(tableName, columns: ['box_no']);
        final List<String> idsToDelete = localData.map((row) => row['box_no'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
        if (idsToDelete.isNotEmpty) {
          final batchDelete = db.batch();
          for (var id in idsToDelete) batchDelete.delete(tableName, where: 'box_no = ?', whereArgs: [id]);
          await batchDelete.commit(noResult: true);
        }
      } catch (e) {
        log("Error cleaning ghost boxes: $e");
      }

      if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
    } catch (e) {
      log("Error syncing boxes: $e");
      rethrow;
    }
  }

  Future<void> syncBoxCurrencies() async {
    const String tableName = 'sun_box_currencies';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    try {
      String endpoint = 'api/CoreData/box-currencies';
      if (lastSyncDate != null) endpoint += '?lastSyncDate=$lastSyncDate';

      final response = await _apiService.get(endpoint);
      final Map<String, dynamic> responseMap = response as Map<String, dynamic>;
      final List<dynamic> data = responseMap['data'];
      final String? serverTime = responseMap['server_sync_time'];

      // مسح الروابط القديمة لضمان مطابقة السيرفر 100%
      await _dbHelper.clearTable(tableName);

      final db = await _dbHelper.database;
      final batch = db.batch();
      for (var json in data) {
        batch.insert(tableName, json, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
    } catch (e) {
      log("Error syncing box currencies: $e");
      rethrow;
    }
  }

  // ============================================================
  // ثانياً: دالة الجلب بالتفاصيل (بدون تغيير)
  // ============================================================

  Future<List<SunBox>> fetchAllBoxesWithDetails() async {
    try {
      // 1. جلب بيانات الصناديق مع بيانات الحسابات المرتبطة
      const String boxesSql = '''
        SELECT b.*, a.account_number, a.name as account_name, a.name_en as account_name_en,
               a.account_type_id, a.nature, a.is_transactional, a.is_active
        FROM sun_boxes b
        LEFT JOIN sun_account a ON b.account_id = a.id
        ORDER BY b.box_no
      ''';

      final List<Map<String, dynamic>> boxMaps = await _dbHelper.rawQuery(boxesSql);
      List<SunBox> boxesList = [];

      for (var boxRow in boxMaps) {
        final boxData = Map<String, dynamic>.from(boxRow);
        final int currentBoxNo = boxData['box_no'];

        // 2. إعادة بناء كائن الحساب المتداخل
        if (boxData['account_id'] != null) {
          boxData['sun_account'] = {
            'id': boxData['account_id'],
            'account_number': boxData['account_number'],
            'name': boxData['account_name'],
            'name_en': boxData['account_name_en'],
            'account_type_id': boxData['account_type_id'],
            'nature': boxData['nature'],
            'is_transactional': boxData['is_transactional'],
            'is_active': boxData['is_active'],
          };
        } else {
          boxData['sun_account'] = null;
        }

        // 3. جلب العملات المرتبطة بهذا الصندوق
        const String currenciesSql = '''
          SELECT currency_id as currency_no 
          FROM sun_box_currencies 
          WHERE box_no = ?
        ''';

        final List<Map<String, dynamic>> currencyRows = await _dbHelper.rawQuery(currenciesSql, [currentBoxNo]);

        // 4. تحويل العملات للشكل المتداخل
        boxData['sun_box_currencies'] = currencyRows.map((row) {
          return {
            'sun_currencies': {
              'currency_no': row['currency_no']
            }
          };
        }).toList();

        boxesList.add(SunBox.fromJson(boxData));
      }

      return boxesList;
    } catch (e) {
      log("Error in fetchAllBoxesWithDetails locally: $e");
      rethrow;
    }
  }
}