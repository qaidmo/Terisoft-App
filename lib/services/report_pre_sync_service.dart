import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database_helper.dart';
import 'report_cache_file_manager.dart';
import 'server_connectivity.dart';
import 'sync_service.dart';

/// خدمة المزامنة المسبقة للتقارير (Step 2)
/// تجلب تقارير وحركات السنة الكاملة وتخزنها في SQLite وملفات الكاش
/// لتمكين المستخدم من استعراض وفلترة أي مدة زمنية في وضع عدم الاتصال.
class ReportPreSyncService extends GetxController {
  final RxBool isSyncing = false.obs;
  final RxDouble progress = 0.0.obs;
  final RxString currentTask = ''.obs;
  final RxInt completedItems = 0.obs;
  final RxInt totalItems = 0.obs;
  final RxList<String> errors = <String>[].obs;

  bool _cancelRequested = false;

  void cancelSync() {
    _cancelRequested = true;
    currentTask.value = 'جاري إيقاف المزامنة...';
  }

  /// تشغيل المزامنة المسبقة تلقائياً عند فتح التطبيق لأول مرة (أو عند عدم اكتمالها سابقاً)
  /// وبعد اكتمالها، تجري تحديثاً دورياً في الخلفية كل 12 ساعة عند توفر الاتصال.
  Future<void> runInitialOfflineSyncIfNeeded({
    required String year,
    int? branchId,
    int? departmentId,
    Duration refreshInterval = const Duration(hours: 12),
  }) async {
    if (isSyncing.value) return;

    final prefs = await SharedPreferences.getInstance();
    final String scopeSuffix = '${year}_${branchId ?? 0}_${departmentId ?? 0}';
    final String doneKey = 'initial_offline_reports_sync_done_$scopeSuffix';
    final String lastAutoSyncKey = 'last_auto_offline_sync_$scopeSuffix';

    final bool isInitialDone = prefs.getBool(doneKey) == true;
    if (isInitialDone) {
      final String? lastStr = prefs.getString(lastAutoSyncKey);
      final DateTime? lastSync = lastStr != null ? DateTime.tryParse(lastStr) : null;
      if (lastSync != null &&
          DateTime.now().toUtc().difference(lastSync) < refreshInterval) {
        return;
      }
    }

    try {
      await ServerConnectivity.ensureServerReachable();
    } catch (_) {
      // لا يوجد اتصال بالسيرفر حالياً — سنعيد المحاولة في المرة القادمة
      return;
    }

    try {
      // التأكد من وجود الجداول الأساسية في SQLite قبل مزامنة التقارير
      final db = DatabaseHelper.instance;
      final accounts = await db.queryAll('sun_account');
      final branches = await db.queryAll('sun_branches');
      if ((accounts.isEmpty || branches.isEmpty) &&
          Get.isRegistered<SyncService>()) {
        currentTask.value = 'جاري مزامنة البيانات الأساسية...';
        await Get.find<SyncService>().syncAllMasterData(isSilent: true);
      }

      await syncAllReportsForOffline(
        year: year,
        branchId: branchId,
        departmentId: departmentId,
        skipRecentlySynced: true,
      );

      if (!_cancelRequested && errors.isEmpty) {
        await prefs.setBool(doneKey, true);
        await prefs.setString(
          lastAutoSyncKey,
          DateTime.now().toUtc().toIso8601String(),
        );
      }
    } catch (_) {
      // تم تسجيل الخطأ في errors ولن يتم تعليم المزامنة كمكتملة لتُعاد لاحقاً
    }
  }

  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('server_address');
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('يرجى ضبط عنوان السيرفر في الإعدادات أولاً.');
    }
    baseUrl = baseUrl.trim();
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'http://$baseUrl';
    }
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  /// تحويل التاريخ من dd/MM/yyyy (أو ISO) إلى yyyy-MM-dd للفرز والفلترة في SQLite
  static String toIsoDateOnly(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return '1900-01-01';
    if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      if (parts.length == 3) {
        final d = parts[0].padLeft(2, '0');
        final m = parts[1].padLeft(2, '0');
        final y = parts[2].substring(0, 4);
        return '$y-$m-$d';
      }
    }
    if (trimmed.length >= 10 && trimmed[4] == '-' && trimmed[7] == '-') {
      return trimmed.substring(0, 10);
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }
    return '1900-01-01';
  }

  /// مزامنة كل التقارير للسنة والفرع المحددين (أو كل الفروع النشطة)
  Future<void> syncAllReportsForOffline({
    required String year,
    int? branchId,
    int? departmentId,
    int concurrency = 4,
    bool skipRecentlySynced = false,
    Duration freshThreshold = const Duration(hours: 6),
  }) async {
    if (isSyncing.value) return;

    _cancelRequested = false;
    isSyncing.value = true;
    progress.value = 0.0;
    completedItems.value = 0;
    totalItems.value = 0;
    errors.clear();

    try {
      await ServerConnectivity.ensureServerReachable();
      final baseUrl = await _getBaseUrl();
      final db = DatabaseHelper.instance;

      final branches = branchId != null
          ? [
              {'branch_id': branchId}
            ]
          : await db.queryAll('sun_branches');
      final currencies = await db.queryAll('sun_currencies');
      final accounts = await db.query(
        'sun_account',
        where: 'is_transactional = 1 AND is_active = 1',
      );
      final items = await db.queryAll('sun_items');
      final costCenters = await db.queryAll('cost_centers');

      final int defaultCurrencyId = currencies.isNotEmpty
          ? (currencies.first['currency_no'] as num).toInt()
          : 1;

      // بناء خريطة عملات كل حساب من كافة الجداول المرتبطة لضمان مزامنة كل عملات الحساب أوفلاين
      final Map<String, Set<int>> accountCurrenciesMap = {};
      try {
        final accCurRows = await db.queryAll('sun_account_currencies');
        for (final row in accCurRows) {
          final String accId = row['account_id']?.toString().trim() ?? '';
          final int? cId = (row['currency_id'] as num?)?.toInt();
          if (accId.isNotEmpty && cId != null && cId > 0) {
            accountCurrenciesMap.putIfAbsent(accId, () => <int>{}).add(cId);
          }
        }
        final boxCurRows = await db.rawQuery('''
          SELECT b.account_id, bc.currency_id
          FROM sun_boxes b
          JOIN sun_box_currencies bc ON b.box_no = bc.box_no
          WHERE b.account_id IS NOT NULL
        ''');
        for (final row in boxCurRows) {
          final String accId = row['account_id']?.toString().trim() ?? '';
          final int? cId = (row['currency_id'] as num?)?.toInt();
          if (accId.isNotEmpty && cId != null && cId > 0) {
            accountCurrenciesMap.putIfAbsent(accId, () => <int>{}).add(cId);
          }
        }
        final custCurRows = await db.rawQuery('''
          SELECT c.account_id, cc.currency_no AS currency_id
          FROM sun_customers c
          JOIN sun_customer_currencies cc ON c.customer_no = cc.customer_no
          WHERE c.account_id IS NOT NULL
        ''');
        for (final row in custCurRows) {
          final String accId = row['account_id']?.toString().trim() ?? '';
          final int? cId = (row['currency_id'] as num?)?.toInt();
          if (accId.isNotEmpty && cId != null && cId > 0) {
            accountCurrenciesMap.putIfAbsent(accId, () => <int>{}).add(cId);
          }
        }
      } catch (_) {}

      // تجهيز قائمة أزواج (حساب + عملة) للمزامنة الكاملة
      final List<Map<String, dynamic>> accountCurrencyPairs = [];
      for (final acc in accounts) {
        final String accountId = acc['id'].toString().trim();
        final Set<int> linkedCurrencies = accountCurrenciesMap[accountId] ?? <int>{};
        if (linkedCurrencies.isEmpty) {
          final int fallbackCur =
              (acc['default_currency_id'] as num?)?.toInt() ?? defaultCurrencyId;
          linkedCurrencies.add(fallbackCur);
        }
        for (final int cId in linkedCurrencies) {
          accountCurrencyPairs.add({
            'accountId': accountId,
            'currencyId': cId,
          });
        }
      }

      final int parsedYear = int.tryParse(year) ?? DateTime.now().year;
      final DateTime yearStart = DateTime(parsedYear, 1, 1);
      final DateTime yearEnd = DateTime(parsedYear, 12, 31, 23, 59, 59);

      // حساب إجمالي المهام التقريبي لشريط التقدم
      final int accountTasksCount = branches.length * accountCurrencyPairs.length;
      final int summaryTasksCount =
          branches.length * (6 + (currencies.length * 2) + costCenters.length);
      final int itemTasksCount = branches.length * items.length;
      totalItems.value = accountTasksCount + summaryTasksCount + itemTasksCount;

      for (final branch in branches) {
        if (_cancelRequested) break;
        final int bId = (branch['branch_id'] as num).toInt();

        // 1. التقارير الإجمالية للفرع
        await _syncSummaryReport(
          baseUrl: baseUrl,
          endpoint: '/api/Reports/account-balances',
          reportType: 'AccountBalances',
          branchId: bId,
          year: year,
          body: {
            'fromDate': yearStart.toIso8601String(),
            'toDate': yearEnd.toIso8601String(),
            'year': year,
            'branchId': bId,
            'departmentId': departmentId,
            'currencyId': null,
            'groupingMode': 'account',
          },
          skipIfFresh: skipRecentlySynced,
          freshThreshold: freshThreshold,
        );
        _stepDone();

        await _syncSummaryReport(
          baseUrl: baseUrl,
          endpoint: '/api/ItemBalances/get-report',
          reportType: 'ItemBalances',
          branchId: bId,
          year: year,
          body: {
            'toDate': yearEnd.toIso8601String(),
            'year': year,
            'branchId': bId,
            'departmentId': departmentId,
          },
          skipIfFresh: skipRecentlySynced,
          freshThreshold: freshThreshold,
        );
        _stepDone();

        await _syncSummaryReport(
          baseUrl: baseUrl,
          endpoint: '/api/Reports/sales-movement',
          reportType: 'SalesMovement',
          branchId: bId,
          year: year,
          body: {
            'fromDate': yearStart.toIso8601String(),
            'toDate': yearEnd.toIso8601String(),
            'year': year,
            'branchId': bId,
            'departmentId': departmentId,
          },
          skipIfFresh: skipRecentlySynced,
          freshThreshold: freshThreshold,
        );
        _stepDone();

        await _syncSummaryReport(
          baseUrl: baseUrl,
          endpoint: '/api/ProfitMargin/get-report',
          reportType: 'ProfitMargin',
          branchId: bId,
          year: year,
          body: {
            'fromDate': yearStart.toIso8601String(),
            'toDate': yearEnd.toIso8601String(),
            'year': year,
            'branchId': bId,
            'departmentId': departmentId,
          },
          skipIfFresh: skipRecentlySynced,
          freshThreshold: freshThreshold,
        );
        _stepDone();

        // تقارير الحركات الإضافية للفرع
        final String branchDeptEntity = '${bId}_${departmentId ?? 0}';
        await _syncSummaryReport(
          baseUrl: baseUrl,
          endpoint: '/api/Reports/sales-movement',
          reportType: 'SalesMovementNew',
          branchId: bId,
          year: year,
          entityId: branchDeptEntity,
          body: {
            'fromDate': yearStart.toIso8601String(),
            'toDate': yearEnd.toIso8601String(),
            'year': year,
            'branchId': bId,
            'transactionType': 'all',
            'userId': null,
            'departmentId': departmentId,
          },
          skipIfFresh: skipRecentlySynced,
          freshThreshold: freshThreshold,
        );
        _stepDone();

        await _syncSummaryReport(
          baseUrl: baseUrl,
          endpoint: '/api/Reports/transaction-history',
          reportType: 'TransactionHistory',
          branchId: bId,
          year: year,
          entityId: branchDeptEntity,
          customParamsHash: 'all_$year',
          body: {
            'fromDate': yearStart.toIso8601String(),
            'toDate': yearEnd.toIso8601String(),
            'year': year,
            'branchId': bId,
            'departmentId': departmentId,
            'transactionType': 'all',
            'userId': null,
          },
          skipIfFresh: skipRecentlySynced,
          freshThreshold: freshThreshold,
        );
        _stepDone();

        await _syncSummaryReport(
          baseUrl: baseUrl,
          endpoint: '/api/ItemMovement/get-report',
          reportType: 'ItemMovement',
          branchId: bId,
          year: year,
          body: {
            'fromDate': yearStart.toIso8601String(),
            'toDate': yearEnd.toIso8601String(),
            'year': year,
            'branchId': bId,
            'transactionType': 'all',
            'userId': null,
            'departmentId': departmentId,
            'itemGroupId': null,
          },
          skipIfFresh: skipRecentlySynced,
          freshThreshold: freshThreshold,
        );
        _stepDone();

        // حركة العملاء وحركة الموردين لكل عملة
        for (final curr in currencies) {
          if (_cancelRequested) break;
          final int cId = (curr['currency_no'] as num).toInt();

          await _syncSummaryReport(
            baseUrl: baseUrl,
            endpoint: '/api/Reports/customer-activity',
            reportType: 'CustomerActivity',
            branchId: bId,
            year: year,
            currencyId: cId.toString(),
            body: {
              'fromDate': yearStart.toIso8601String(),
              'toDate': yearEnd.toIso8601String(),
              'year': year,
              'branchId': bId,
              'departmentId': departmentId,
              'currencyId': cId,
              'userId': null,
            },
            skipIfFresh: skipRecentlySynced,
            freshThreshold: freshThreshold,
          );
          _stepDone();

          await _syncSummaryReport(
            baseUrl: baseUrl,
            endpoint: '/api/Reports/supplier-activity',
            reportType: 'SupplierMovement',
            branchId: bId,
            year: year,
            currencyId: cId.toString(),
            body: {
              'fromDate': yearStart.toIso8601String(),
              'toDate': yearEnd.toIso8601String(),
              'year': year,
              'branchId': bId,
              'departmentId': departmentId,
              'currencyId': cId,
              'userId': null,
              'isDetailedMode': false,
            },
            skipIfFresh: skipRecentlySynced,
            freshThreshold: freshThreshold,
          );
          _stepDone();
        }

        // تقارير مراكز التكلفة
        for (final cc in costCenters) {
          if (_cancelRequested) break;
          final int centerNo = (cc['center_no'] as num).toInt();
          await _syncSummaryReport(
            baseUrl: baseUrl,
            endpoint: '/api/Reports/cost-center',
            reportType: 'CostCenter',
            branchId: bId,
            year: year,
            entityId: centerNo.toString(),
            body: {
              'costCenterNo': centerNo,
              'fromDate': yearStart.toIso8601String(),
              'toDate': yearEnd.toIso8601String(),
            },
            skipIfFresh: skipRecentlySynced,
            freshThreshold: freshThreshold,
          );
          _stepDone();
        }

        // 2. كشوف الحسابات على دفعات (Batching) لكل حساب وجميع عملاته المرتبطة
        for (int i = 0; i < accountCurrencyPairs.length; i += concurrency) {
          if (_cancelRequested) break;
          final batch = accountCurrencyPairs.skip(i).take(concurrency).toList();
          currentTask.value =
              'مزامنة كشوف الحسابات (${i + 1}/${accountCurrencyPairs.length})...';

          await Future.wait(batch.map((pair) async {
            final String accountId = pair['accountId'] as String;
            final int currencyId = pair['currencyId'] as int;

            await _syncAccountLedger(
              baseUrl: baseUrl,
              accountId: accountId,
              currencyId: currencyId,
              branchId: bId,
              departmentId: departmentId ?? 0,
              year: year,
              fromDate: yearStart,
              toDate: yearEnd,
            );
            _stepDone();
          }));
        }

        await _upsertSyncStatus(
          reportType: 'AccountStatement',
          branchId: bId,
          year: year,
          totalRecords: accountCurrencyPairs.length,
          status: _cancelRequested ? 'cancelled' : 'completed',
        );

        // 3. بطاقات الأصناف على دفعات
        for (int i = 0; i < items.length; i += concurrency) {
          if (_cancelRequested) break;
          final batch = items.skip(i).take(concurrency).toList();
          currentTask.value = 'مزامنة حركات الأصناف (${i + 1}/${items.length})...';

          await Future.wait(batch.map((item) async {
            final String itemId = item['item_no'].toString();
            await _syncItemCard(
              baseUrl: baseUrl,
              itemId: itemId,
              branchId: bId,
              departmentId: departmentId,
              year: year,
              fromDate: yearStart,
              toDate: yearEnd,
            );
            _stepDone();
          }));
        }

        await _upsertSyncStatus(
          reportType: 'ItemCard',
          branchId: bId,
          year: year,
          totalRecords: items.length,
          status: _cancelRequested ? 'cancelled' : 'completed',
        );
      }

      currentTask.value = _cancelRequested
          ? 'تم إيقاف المزامنة'
          : 'اكتملت مزامنة التقارير للعمل بدون اتصال';
    } catch (e) {
      errors.add(e.toString());
      currentTask.value = 'حدث خطأ أثناء المزامنة: $e';
      rethrow;
    } finally {
      isSyncing.value = false;
    }
  }

  void _stepDone() {
    completedItems.value++;
    if (totalItems.value > 0) {
      progress.value = (completedItems.value / totalItems.value).clamp(0.0, 1.0);
    }
  }

  Future<void> _syncAccountLedger({
    required String baseUrl,
    required String accountId,
    required int currencyId,
    required int branchId,
    required int departmentId,
    required String year,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final db = DatabaseHelper.instance;
      final existing = await db.query(
        'offline_ledger_opening_balances',
        where:
            'report_scope = ? AND entity_id = ? AND currency_id = ? AND branch_id = ? AND department_id = ? AND year = ?',
        whereArgs: ['AccountStatement', accountId, currencyId, branchId, departmentId, year],
      );

      final String lastSync = existing.isNotEmpty
          ? (existing.first['last_sync_timestamp']?.toString() ?? '2000-01-01T00:00:00.000Z')
          : '2000-01-01T00:00:00.000Z';
      final String? signature =
          existing.isNotEmpty ? existing.first['ledger_signature']?.toString() : null;

      final payload = <String, dynamic>{
        'accountId': accountId,
        'currencyId': currencyId,
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'year': year,
        'branchId': branchId,
        'departmentId': departmentId == 0 ? null : departmentId,
        'lastSyncTimestamp': lastSync,
        if (signature != null && signature.isNotEmpty) 'ledgerSignature': signature,
      };

      final response = await ServerConnectivity.client
          .post(
            Uri.parse('$baseUrl/api/ReportsSync/delta-account-statement'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 304) {
        return; // البيانات لم تتغير على السيرفر
      }
      if (response.statusCode != 200) {
        errors.add('Account $accountId: HTTP ${response.statusCode}');
        return;
      }

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      final double opening = (data['openingBalance'] as num?)?.toDouble() ?? 0.0;
      final String newSig = data['ledgerSignature']?.toString() ?? '';
      final List<dynamic> txList = (data['transactions'] as List<dynamic>?) ?? const [];
      final String nowIso = DateTime.now().toUtc().toIso8601String();

      final rawDb = await db.database;
      await rawDb.transaction((txn) async {
        await txn.insert(
          'offline_ledger_opening_balances',
          {
            'report_scope': 'AccountStatement',
            'entity_id': accountId,
            'currency_id': currencyId,
            'branch_id': branchId,
            'department_id': departmentId,
            'year': year,
            'opening_balance': opening,
            'ledger_signature': newSig,
            'last_sync_timestamp': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.delete(
          'offline_ledger_entries',
          where:
              'report_scope = ? AND entity_id = ? AND currency_id = ? AND branch_id = ? AND department_id = ? AND year = ?',
          whereArgs: ['AccountStatement', accountId, currencyId, branchId, departmentId, year],
        );

        final batch = txn.batch();
        for (final tx in txList) {
          final m = tx as Map<String, dynamic>;
          final String txType = m['type']?.toString() ?? '';
          // عدم تخزين سطر "رصيد مرحل" المولّد من السيرفر داخل جدول الحركات لتفادي مضاعفة الرصيد الافتتاحي أوفلاين
          if (txType == 'رصيد مرحل') continue;

          final displayDate = m['date']?.toString() ?? '';
          batch.insert('offline_ledger_entries', {
            'report_scope': 'AccountStatement',
            'entity_id': accountId,
            'currency_id': currencyId,
            'branch_id': branchId,
            'department_id': departmentId,
            'year': year,
            'tra_id': m['traId']?.toString() ?? '',
            'tra_no': m['traNo']?.toString() ?? '',
            'tra_lst_id': (m['traLstId'] ?? m['tra_lst_id'] ?? '').toString(),
            'trans_date': toIsoDateOnly(displayDate),
            'display_date': displayDate,
            'trans_type': txType,
            'description': m['description']?.toString() ?? '',
            'beneficiary': m['beneficiary']?.toString() ?? '',
            'debit': (m['debit'] as num?)?.toDouble() ?? 0.0,
            'credit': (m['credit'] as num?)?.toDouble() ?? 0.0,
            'balance': (m['balance'] as num?)?.toDouble() ?? 0.0,
          });
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      errors.add('Account $accountId: $e');
    }
  }

  Future<void> _syncItemCard({
    required String baseUrl,
    required String itemId,
    required int branchId,
    int? departmentId,
    required String year,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    try {
      final response = await ServerConnectivity.client
          .post(
            Uri.parse('$baseUrl/api/ItemCard/get-report'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({
              'itemId': itemId,
              'fromDate': fromDate.toIso8601String(),
              'toDate': toDate.toIso8601String(),
              'year': year,
              'branchId': branchId,
              'departmentId': departmentId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      final List<dynamic> rows = decoded is List
          ? decoded
          : (decoded is Map<String, dynamic>
              ? (decoded['transactions'] ?? decoded['rows'] ?? decoded['items'] ?? const [])
                  as List<dynamic>
              : const []);

      final rawDb = await DatabaseHelper.instance.database;
      await rawDb.transaction((txn) async {
        await txn.delete(
          'offline_item_movements',
          where: 'report_scope = ? AND item_id = ? AND branch_id = ? AND year = ?',
          whereArgs: ['ItemCard', itemId, branchId, year],
        );

        final batch = txn.batch();
        for (final row in rows) {
          final m = row as Map<String, dynamic>;
          final displayDate = (m['date'] ?? m['transDate'] ?? '').toString();
          batch.insert('offline_item_movements', {
            'report_scope': 'ItemCard',
            'item_id': itemId,
            'store_id': (m['storeId'] ?? m['storeName'] ?? '').toString(),
            'branch_id': branchId,
            'year': year,
            'tra_id': (m['traId'] ?? '').toString(),
            'tra_no': (m['traNo'] ?? m['docNo'] ?? '').toString(),
            'trans_date': toIsoDateOnly(displayDate),
            'display_date': displayDate,
            'trans_type': (m['type'] ?? m['transType'] ?? '').toString(),
            'entity_name': (m['customerName'] ?? m['beneficiary'] ?? '').toString(),
            'unit_name': (m['unit'] ?? m['unitName'] ?? '').toString(),
            'qty_in': (m['qtyIn'] ?? m['inQty'] as num?)?.toDouble() ?? 0.0,
            'qty_out': (m['qtyOut'] ?? m['outQty'] as num?)?.toDouble() ?? 0.0,
            'price': (m['price'] as num?)?.toDouble() ?? 0.0,
            'total': (m['total'] as num?)?.toDouble() ?? 0.0,
            'cost': (m['cost'] as num?)?.toDouble() ?? 0.0,
            'profit': (m['profit'] as num?)?.toDouble() ?? 0.0,
            'extra_json': jsonEncode(m),
          });
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      errors.add('Item $itemId: $e');
    }
  }

  Future<void> _syncSummaryReport({
    required String baseUrl,
    required String endpoint,
    required String reportType,
    required int branchId,
    required String year,
    required Map<String, dynamic> body,
    String entityId = 'ALL',
    String currencyId = '0',
    String? customParamsHash,
    bool skipIfFresh = false,
    Duration freshThreshold = const Duration(hours: 6),
  }) async {
    try {
      final String paramsHash = customParamsHash ?? 'YEAR_${year}_B$branchId';

      if (skipIfFresh) {
        final existing = await DatabaseHelper.instance.query(
          'Offline_ReportsCache',
          columns: ['LastSyncTimestamp'],
          where:
              'ReportType = ? AND EntityIdentifier = ? AND CurrencyId = ? AND ParametersHash = ?',
          whereArgs: [reportType, entityId, currencyId, paramsHash],
        );
        if (existing.isNotEmpty) {
          final ts = DateTime.tryParse(
              existing.first['LastSyncTimestamp']?.toString() ?? '');
          if (ts != null &&
              DateTime.now().toUtc().difference(ts) < freshThreshold) {
            return;
          }
        }
      }

      currentTask.value = 'مزامنة $reportType...';
      final response = await ServerConnectivity.client
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        errors.add('$reportType: HTTP ${response.statusCode}');
        return;
      }

      final String filePath = await ReportCacheFileManager.saveReportJson(
        reportType: reportType,
        entityId: entityId,
        currencyId: currencyId,
        paramsHash: paramsHash,
        rawJson: response.body,
      );

      final String nowIso = DateTime.now().toUtc().toIso8601String();
      await DatabaseHelper.instance.insertOrUpdate(
        'Offline_ReportsCache',
        {
          'ReportType': reportType,
          'EntityIdentifier': entityId,
          'CurrencyId': currencyId,
          'ParametersHash': paramsHash,
          'file_path': filePath,
          'ledger_signature': '',
          'LastSyncTimestamp': nowIso,
        },
        'ReportType',
      );

      await _upsertSyncStatus(
        reportType: reportType,
        branchId: branchId,
        year: year,
        totalRecords: 1,
        status: 'completed',
      );
    } catch (e) {
      errors.add('$reportType: $e');
    }
  }

  Future<void> _upsertSyncStatus({
    required String reportType,
    required int branchId,
    required String year,
    required int totalRecords,
    required String status,
    String? errorMessage,
  }) async {
    await DatabaseHelper.instance.insertOrUpdate(
      'offline_reports_sync_status',
      {
        'report_type': reportType,
        'branch_id': branchId,
        'year': year,
        'last_sync_at': DateTime.now().toUtc().toIso8601String(),
        'total_records': totalRecords,
        'status': status,
        'error_message': errorMessage,
      },
      'report_type',
    );
  }
}
