import 'dart:developer';
import 'package:sqflite/sqflite.dart';

import '../models/sun_store.dart';
import '../core/database_helper.dart';
import '../services/api_service.dart';

class StoreRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ApiService _apiService = ApiService();

  Future<void> syncStores() async {
    const String tableName = 'sun_store';
    final String? lastSyncDate = await _dbHelper.getLastSyncTime(tableName);
    try {
      String endpoint = 'api/CoreData/stores';
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
        final activeIdsResponse = await _apiService.get('api/CoreData/active-store-ids');
        final Set<String> serverIdsSet = (activeIdsResponse as List).map((e) => e.toString()).toSet();
        final localData = await db.query(tableName, columns: ['no_store']);
        final List<String> idsToDelete = localData.map((row) => row['no_store'].toString()).where((id) => !serverIdsSet.contains(id)).toList();
        if (idsToDelete.isNotEmpty) {
          final batchDelete = db.batch();
          for (var id in idsToDelete) {
            batchDelete.delete(tableName, where: 'no_store = ?', whereArgs: [id]);
          }
          await batchDelete.commit(noResult: true);
        }
      } catch (e) {
        log("Error cleaning ghost stores: $e");
      }

      if (serverTime != null) await _dbHelper.updateSyncTime(tableName, serverTime);
    } catch (e) {
      log("Error syncing stores: $e");
      rethrow;
    }
  }

  Future<List<SunStore>> fetchAllStoresWithDetails() async {
    try {
      const String sql = '''
        SELECT s.*, 
               a.account_number, a.name as account_name, a.name_en as account_name_en,
               a.account_type_id, a.nature, a.is_transactional, a.is_active,
               b.branch_name, b.created_at as branch_created_at, b.source_id as branch_source_id
        FROM sun_store s
        LEFT JOIN sun_account a ON s.inventory_account_id = a.id
        LEFT JOIN sun_branches b ON s.branch_id = b.branch_id
        ORDER BY s.no_store
      ''';

      final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(sql);

      return maps.map((row) {
        final storeData = Map<String, dynamic>.from(row);

        if (storeData['inventory_account_id'] != null) {
          storeData['sun_account'] = {
            'id': storeData['inventory_account_id'],
            'account_number': storeData['account_number'],
            'name': storeData['account_name'],
            'name_en': storeData['account_name_en'],
            'account_type_id': storeData['account_type_id'],
            'nature': storeData['nature'],
            'is_transactional': storeData['is_transactional'],
            'is_active': storeData['is_active'],
          };
        } else {
          storeData['sun_account'] = null;
        }

        if (storeData['branch_id'] != null) {
          storeData['sun_branches'] = {
            'branch_id': storeData['branch_id'],
            'branch_name': storeData['branch_name'],
            'created_at': storeData['branch_created_at'],
            'source_id': storeData['branch_source_id'],
          };
        } else {
          storeData['sun_branches'] = null;
        }

        return SunStore.fromJson(storeData);
      }).toList();
    } catch (e) {
      log("Error in fetchAllStoresWithDetails: $e");
      rethrow;
    }
  }
}