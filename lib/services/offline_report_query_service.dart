import 'dart:convert';
import '../core/database_helper.dart';
import 'report_cache_file_manager.dart';

/// نتيجة استعلام التقرير المحلي من SQLite لوضع عدم الاتصال
class OfflineStatementQueryResult {
  final String rawJson;
  final String lastSyncTimestamp;

  const OfflineStatementQueryResult({
    required this.rawJson,
    required this.lastSyncTimestamp,
  });
}

/// خدمة الاستعلام والحساب المحلي للتقارير من SQLite (Step 3)
/// تتيح اختيار أي مدة زمنية (fromDate - toDate) وحساب الرصيد الافتتاحي
/// والختامي والرصيد التراكمي محلياً في وضع عدم الاتصال.
class OfflineReportQueryService {
  static String _toIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// استعلام كشف الحساب من SQLite لأي فترة زمنية وإرجاع JSON متوافق مع AccountStatementResponse
  static Future<OfflineStatementQueryResult?> queryAccountStatementAsJson({
    required String accountId,
    required int currencyId,
    required int branchId,
    int departmentId = 0,
    required String year,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final db = DatabaseHelper.instance;

    final openingRows = await db.query(
      'offline_ledger_opening_balances',
      where:
          'report_scope = ? AND entity_id = ? AND currency_id = ? AND branch_id = ? AND department_id = ? AND year = ?',
      whereArgs: ['AccountStatement', accountId, currencyId, branchId, departmentId, year],
    );

    if (openingRows.isEmpty) {
      return null;
    }

    final double yearOpening =
        (openingRows.first['opening_balance'] as num?)?.toDouble() ?? 0.0;
    final String ledgerSignature =
        openingRows.first['ledger_signature']?.toString() ?? '';
    final String lastSync =
        openingRows.first['last_sync_timestamp']?.toString() ?? '';

    final String fromIso = _toIsoDate(fromDate);
    final String toIso = _toIsoDate(toDate);

    // 1. حساب الرصيد الافتتاحي للفترة = رصيد بداية السنة + صافي الحركات قبل fromDate
    final priorSumRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(debit - credit), 0) AS prior_net
      FROM offline_ledger_entries
      WHERE report_scope = ?
        AND entity_id = ?
        AND currency_id = ?
        AND branch_id = ?
        AND department_id = ?
        AND year = ?
        AND trans_date < ?
      ''',
      ['AccountStatement', accountId, currencyId, branchId, departmentId, year, fromIso],
    );

    final double priorNet = priorSumRows.isNotEmpty
        ? ((priorSumRows.first['prior_net'] as num?)?.toDouble() ?? 0.0)
        : 0.0;
    final double periodOpeningBalance = yearOpening + priorNet;

    // 2. جلب حركات الفترة المطلوبة مرتبة زمنياً
    final txRows = await db.rawQuery(
      '''
      SELECT tra_id, tra_no, display_date, trans_type, description, beneficiary, debit, credit
      FROM offline_ledger_entries
      WHERE report_scope = ?
        AND entity_id = ?
        AND currency_id = ?
        AND branch_id = ?
        AND department_id = ?
        AND year = ?
        AND trans_date BETWEEN ? AND ?
      ORDER BY trans_date ASC, id ASC
      ''',
      ['AccountStatement', accountId, currencyId, branchId, departmentId, year, fromIso, toIso],
    );

    double runningBalance = periodOpeningBalance;
    double totalPeriodDebit = 0.0;
    double totalPeriodCredit = 0.0;

    final List<Map<String, dynamic>> transactions = [];
    for (final row in txRows) {
      final double debit = (row['debit'] as num?)?.toDouble() ?? 0.0;
      final double credit = (row['credit'] as num?)?.toDouble() ?? 0.0;
      totalPeriodDebit += debit;
      totalPeriodCredit += credit;
      runningBalance += (debit - credit);

      transactions.add({
        'traId': row['tra_id']?.toString() ?? '',
        'traNo': row['tra_no']?.toString() ?? '',
        'date': row['display_date']?.toString() ?? '',
        'type': row['trans_type']?.toString() ?? '',
        'description': row['description']?.toString() ?? '',
        'beneficiary': row['beneficiary']?.toString() ?? '',
        'debit': debit,
        'credit': credit,
        'balance': runningBalance,
      });
    }

    final Map<String, dynamic> responseMap = {
      'openingBalance': periodOpeningBalance,
      'closingBalance': runningBalance,
      'totalPeriodDebit': totalPeriodDebit,
      'totalPeriodCredit': totalPeriodCredit,
      'ledgerSignature': ledgerSignature,
      'transactions': transactions,
    };

    return OfflineStatementQueryResult(
      rawJson: jsonEncode(responseMap),
      lastSyncTimestamp: lastSync,
    );
  }

  /// استرجاع حركات بطاقة الصنف من SQLite لأي فترة زمنية
  static Future<List<Map<String, dynamic>>> queryItemCardMovements({
    required String itemId,
    required int branchId,
    required String year,
    required DateTime fromDate,
    required DateTime toDate,
    String? storeId,
  }) async {
    final db = DatabaseHelper.instance;
    final String fromIso = _toIsoDate(fromDate);
    final String toIso = _toIsoDate(toDate);

    final StringBuffer sql = StringBuffer('''
      SELECT * FROM offline_item_movements
      WHERE report_scope = ?
        AND item_id = ?
        AND branch_id = ?
        AND year = ?
        AND trans_date BETWEEN ? AND ?
    ''');
    final List<dynamic> args = ['ItemCard', itemId, branchId, year, fromIso, toIso];

    if (storeId != null && storeId.isNotEmpty) {
      sql.write(' AND store_id = ?');
      args.add(storeId);
    }
    sql.write(' ORDER BY trans_date ASC, id ASC');

    return await db.rawQuery(sql.toString(), args);
  }

  /// استرجاع التقرير الإجمالي المحفوظ مسبقاً (للسنة كاملة) من Offline_ReportsCache عند عدم توفر كاش مطابق
  static Future<OfflineStatementQueryResult?> queryPreSyncedSummaryCache({
    required String reportType,
    required int branchId,
    required String year,
  }) async {
    final db = DatabaseHelper.instance;
    final String paramsHash = 'YEAR_${year}_B$branchId';
    final cacheResult = await db.query(
      'Offline_ReportsCache',
      columns: ['LastSyncTimestamp', 'file_path'],
      where:
          'ReportType = ? AND EntityIdentifier = ? AND CurrencyId = ? AND ParametersHash = ?',
      whereArgs: [reportType, 'ALL', '0', paramsHash],
    );

    if (cacheResult.isEmpty) return null;

    final String? filePath = cacheResult.first['file_path']?.toString();
    final String syncTime = cacheResult.first['LastSyncTimestamp']?.toString() ?? '';
    if (filePath == null || filePath.isEmpty) return null;

    final String? rawJson = await ReportCacheFileManager.readReportJson(filePath);
    if (rawJson == null || rawJson.isEmpty) return null;

    return OfflineStatementQueryResult(
      rawJson: rawJson,
      lastSyncTimestamp: syncTime,
    );
  }

  /// البحث المرن عن كاش التقرير المحلي:
  /// 1. يبحث أولاً بالمفتاح الدقيق (ParametersHash)
  /// 2. ثم بالكاش السنوي المسبق (YEAR_{year}_B{branchId})
  /// 3. ثم بأحدث نسخة محفوظة لنفس ReportType و CurrencyId
  static Future<OfflineStatementQueryResult?> findCachedReportWithFallback({
    required String reportType,
    required String currencyId,
    required String exactParamsHash,
    String entityId = 'ALL',
    String? year,
    int? branchId,
  }) async {
    final db = DatabaseHelper.instance;

    // 1. مطابقة دقيقة
    var rows = await db.query(
      'Offline_ReportsCache',
      columns: ['LastSyncTimestamp', 'file_path'],
      where:
          'ReportType = ? AND EntityIdentifier = ? AND CurrencyId = ? AND ParametersHash = ?',
      whereArgs: [reportType, entityId, currencyId, exactParamsHash],
      orderBy: 'LastSyncTimestamp DESC',
    );

    // 2. الكاش السنوي المسبق
    if (rows.isEmpty && year != null && branchId != null) {
      final String yearHash = 'YEAR_${year}_B$branchId';
      rows = await db.query(
        'Offline_ReportsCache',
        columns: ['LastSyncTimestamp', 'file_path'],
        where:
            'ReportType = ? AND (EntityIdentifier = ? OR EntityIdentifier = ?) AND CurrencyId = ? AND ParametersHash = ?',
        whereArgs: [reportType, entityId, 'ALL', currencyId, yearHash],
        orderBy: 'LastSyncTimestamp DESC',
      );
    }

    // 3. أحدث نسخة متوفرة لنفس التقرير والعملة
    if (rows.isEmpty) {
      rows = await db.query(
        'Offline_ReportsCache',
        columns: ['LastSyncTimestamp', 'file_path'],
        where:
            'ReportType = ? AND (EntityIdentifier = ? OR EntityIdentifier = ?) AND CurrencyId = ?',
        whereArgs: [reportType, entityId, 'ALL', currencyId],
        orderBy: 'LastSyncTimestamp DESC',
      );
    }

    if (rows.isEmpty) return null;

    final String? filePath = rows.first['file_path']?.toString();
    final String syncTime = rows.first['LastSyncTimestamp']?.toString() ?? '';
    if (filePath == null || filePath.isEmpty) return null;

    final String? rawJson = await ReportCacheFileManager.readReportJson(filePath);
    if (rawJson == null || rawJson.isEmpty) return null;

    return OfflineStatementQueryResult(
      rawJson: rawJson,
      lastSyncTimestamp: syncTime,
    );
  }
}
