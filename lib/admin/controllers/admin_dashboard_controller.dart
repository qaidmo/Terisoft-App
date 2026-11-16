import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/models/sales_movement_models.dart';
import 'package:untitled4/models/transaction_history_models.dart';
import 'package:untitled4/services/reports_api_service.dart';
import 'package:untitled4/services/server_connectivity.dart';
import 'package:untitled4/user_state.dart';

class DashboardItem {
  final String title;
  final IconData icon;
  final String route;
  final Color color;

  const DashboardItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
  });
}

class AdminDashboardController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final ReportsApiService _reportsApiService = ReportsApiService();
  final UserState userState = Get.find<UserState>();

  // ---------------------------------------------------------------------------
  // 1. قائمة بطاقات لوحة المدير الـ 12 مع ألوانها المخصصة الفاخرة
  // ---------------------------------------------------------------------------
  final List<DashboardItem> items = const [
    DashboardItem(
      title: 'الصندوق',
      icon: Icons.account_balance,
      route: '/boxes',
      color: Color(0xFF00897B), // تيل زمردي مالي
    ),
    DashboardItem(
      title: 'المخازن',
      icon: Icons.inventory,
      route: '/store',
      color: Color(0xFF8D6E63), // بني مخزني
    ),
    DashboardItem(
      title: 'المحصلين',
      icon: Icons.payments,
      route: '/collectors',
      color: Color(0xFF2E7D32), // أخضر التحصيل
    ),
    DashboardItem(
      title: 'المناديب',
      icon: Icons.delivery_dining,
      route: '/agents',
      color: Color(0xFFE65100), // برتقالي التوزيع
    ),
    DashboardItem(
      title: 'العملات',
      icon: Icons.currency_exchange,
      route: '/currencies',
      color: Color(0xFFFFA000), // ذهبي الصرف
    ),
    DashboardItem(
      title: 'العملاء',
      icon: Icons.group,
      route: '/clients',
      color: Color(0xFF1970B7), // أزرق الثيم الأساسي
    ),
    DashboardItem(
      title: 'الأصناف',
      icon: Icons.category,
      route: '/item',
      color: Color(0xFF7E57C2), // بنفسجي التصنيفات
    ),
    DashboardItem(
      title: 'مراكز التكلفة',
      icon: Icons.corporate_fare,
      route: '/cost',
      color: Color(0xFF455A64), // رمادي أزرق محاسبي
    ),
    DashboardItem(
      title: 'الفروع',
      icon: Icons.apartment,
      route: '/branches',
      color: Color(0xFF00ACC1), // تركوازي المؤسسات
    ),
    DashboardItem(
      title: 'الأقسام',
      icon: Icons.diversity_3,
      route: '/departments',
      color: Color(0xFFD81B60), // وردي إداري
    ),
    DashboardItem(
      title: 'دليل الحسابات',
      icon: Icons.account_tree,
      route: '/account_screen',
      color: Color(0xFF00695C), // تيل داكن للأشجار المحاسبية
    ),
    DashboardItem(
      title: 'مجموعات الأصناف',
      icon: Icons.category,
      route: '/item_groups_screen',
      color: Color(0xFF8E24AA), // أرجواني المجموعات
    ),
  ];

  // ---------------------------------------------------------------------------
  // 2. حالة وإحصائيات البطاقة ثلاثية الأبعاد
  // ---------------------------------------------------------------------------
  final RxInt selectedPeriod = 0.obs; // 0: اليوم | 1: الشهر | 2: السنة
  final RxBool isStatsLoading = false.obs;
  final RxBool isServerOnline = false.obs;
  final RxString lastUpdatedText = ''.obs;

  // المؤشرات الأساسية
  final RxDouble netSales = 0.0.obs;
  final RxInt invoicesCount = 0.obs;
  final RxDouble receiptsTotal = 0.0.obs;
  final RxDouble paymentsTotal = 0.0.obs;
  final RxDouble stockValue = 0.0.obs;
  final RxInt pendingSyncCount = 0.obs;

  // شريط الأعداد النشطة
  final RxInt totalCustomers = 0.obs;
  final RxInt totalItems = 0.obs;
  final RxInt totalBoxes = 0.obs;
  final RxInt totalStores = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboardStats();
  }

  void navigateTo(String routeName) {
    Get.toNamed(routeName);
  }

  void onPeriodChanged(int index) {
    if (selectedPeriod.value == index) return;
    selectedPeriod.value = index;
    loadDashboardStats();
  }

  // ---------------------------------------------------------------------------
  // 3. منطق جلب الإحصائيات (Hybrid Data Resolution) أونلاين وأوفلاين
  // ---------------------------------------------------------------------------
  Future<void> loadDashboardStats() async {
    isStatsLoading.value = true;
    try {
      // فحص الاتصال بالسيرفر
      bool online = await ServerConnectivity.isServerReachable();
      isServerOnline.value = online;

      // حساب المؤشرات اللحظية المحلية دائماً (المخزون، المعلق، أعداد الكيانات)
      await _loadInstantLocalMetrics();

      // تحديد الفترة الزمنية المختارة
      DateTime now = DateTime.now();
      DateTime fromDate;
      DateTime toDate;
      String periodKey;

      if (selectedPeriod.value == 0) {
        // اليوم
        fromDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        periodKey = 'TODAY_${DateFormat('yyyyMMdd').format(now)}';
      } else if (selectedPeriod.value == 1) {
        // الشهر
        fromDate = DateTime(now.year, now.month, 1, 0, 0, 0);
        toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        periodKey = 'MONTH_${now.year}_${now.month}';
      } else {
        // السنة
        fromDate = DateTime(now.year, 1, 1, 0, 0, 0);
        toDate = DateTime(now.year, 12, 31, 23, 59, 59);
        periodKey = 'YEAR_${now.year}';
      }

      if (online) {
        // إذا كان متصلاً أونلاين: نجلب من السيرفر لكافة الفترات (حتى اليوم ليعكس كامل فروع وأجهزة الشركة)
        await _loadStatsOnline(fromDate, toDate, periodKey);
      } else {
        // إذا كان أوفلاين:
        if (selectedPeriod.value == 0) {
          // اليوم محلياً من SQLite (100% دقيق ولا يحذف إلا بعد 3 أيام)
          await _loadTodayStatsFromLocal();
          lastUpdatedText.value = 'أوفلاين (لحظي محلي)';
        } else {
          // الشهر أو السنة: استرجاع من Offline_ReportsCache مع دمج الدلتا المحلية غير المتزامنة
          await _loadHistoricalStatsFromCache(periodKey, fromDate, toDate);
        }
      }
    } catch (e) {
      debugPrint('Error in loadDashboardStats: $e');
      // عند حدوث خطأ غير متوقع، نلجأ للمحلي كـ Fallback آمن
      await _loadTodayStatsFromLocal();
      lastUpdatedText.value = 'أوفلاين (احتياطي)';
    } finally {
      isStatsLoading.value = false;
    }
  }

  // أ) حساب المؤشرات المحلية الفورية (المخزون + المعلق + أعداد الكيانات)
  Future<void> _loadInstantLocalMetrics() async {
    final db = await _dbHelper.database;
    final int? activeBranch = userState.userBranch;

    // 1. قيمة المخزون الحالية (مفلترة بالفرع إن وجد)
    String stockSql = 'SELECT SUM(quantity * cost_price) as total_val FROM sun_stock WHERE quantity > 0';
    List<dynamic> stockArgs = [];
    if (activeBranch != null && activeBranch > 0) {
      stockSql += ' AND branch_id = ?';
      stockArgs.add(activeBranch);
    }
    final stockRes = await db.rawQuery(stockSql, stockArgs);
    stockValue.value = (stockRes.first['total_val'] as num?)?.toDouble() ?? 0.0;

    // 2. العمليات المعلقة بانتظار المزامنة (is_synced = 0)
    final unsyncedSalesRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM sales WHERE is_synced = 0');
    final unsyncedReceiptsRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM sun_receipt WHERE is_synced = 0');
    int sCnt = (unsyncedSalesRes.first['cnt'] as int?) ?? 0;
    int rCnt = (unsyncedReceiptsRes.first['cnt'] as int?) ?? 0;
    pendingSyncCount.value = sCnt + rCnt;

    // 3. أعداد الكيانات النشطة في النظام
    final custRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM sun_customers');
    final itemsRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM sun_items');
    final boxesRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM sun_boxes');
    final storesRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM sun_store');

    totalCustomers.value = (custRes.first['cnt'] as int?) ?? 0;
    totalItems.value = (itemsRes.first['cnt'] as int?) ?? 0;
    totalBoxes.value = (boxesRes.first['cnt'] as int?) ?? 0;
    totalStores.value = (storesRes.first['cnt'] as int?) ?? 0;
  }

  // ب) حساب إحصائيات "اليوم" من قاعدة SQLite المحلية (مع استبعاد 'م ض' والفلترة بالفرع)
  Future<void> _loadTodayStatsFromLocal() async {
    final db = await _dbHelper.database;
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final int? activeBranch = userState.userBranch;

    // فواتير مبيعات اليوم (استبعاد محضر الجرد 'م ض' تماماً وفصل المردودات)
    String salesQuery = '''
      SELECT 
        SUM(CASE WHEN invoice_type_char NOT LIKE 'ر%' THEN net_total ELSE 0 END) as pos_sales,
        SUM(CASE WHEN invoice_type_char LIKE 'ر%' THEN net_total ELSE 0 END) as ret_sales,
        COUNT(id) as total_count
      FROM sales 
      WHERE date LIKE ? AND invoice_type_char != 'م ض'
    ''';
    List<dynamic> salesArgs = ['$todayStr%'];
    if (activeBranch != null && activeBranch > 0) {
      salesQuery += ' AND branch_id = ?';
      salesArgs.add(activeBranch);
    }

    final salesRes = await db.rawQuery(salesQuery, salesArgs);
    double posSales = (salesRes.first['pos_sales'] as num?)?.toDouble() ?? 0.0;
    double retSales = (salesRes.first['ret_sales'] as num?)?.toDouble() ?? 0.0;
    netSales.value = posSales - retSales;
    invoicesCount.value = (salesRes.first['total_count'] as int?) ?? 0;

    // سندات اليوم (قبض 'ق' vs صرف 'ص')
    String receiptQuery = '''
      SELECT 
        SUM(CASE WHEN invoice_type_char = 'ق' THEN total_amount ELSE 0 END) as total_in,
        SUM(CASE WHEN invoice_type_char = 'ص' THEN total_amount ELSE 0 END) as total_out
      FROM sun_receipt 
      WHERE date LIKE ?
    ''';
    List<dynamic> receiptArgs = ['$todayStr%'];
    if (activeBranch != null && activeBranch > 0) {
      receiptQuery += ' AND branch_id = ?';
      receiptArgs.add(activeBranch);
    }

    final receiptRes = await db.rawQuery(receiptQuery, receiptArgs);
    receiptsTotal.value = (receiptRes.first['total_in'] as num?)?.toDouble() ?? 0.0;
    paymentsTotal.value = (receiptRes.first['total_out'] as num?)?.toDouble() ?? 0.0;
  }

  // ج) جلب الإحصائيات أونلاين من السيرفر ودمج الدلتا المحلية وتخزينها في الكاش
  Future<void> _loadStatsOnline(
      DateTime fromDate, DateTime toDate, String periodKey) async {
    final String currentYear = userState.financialYearName ?? DateTime.now().year.toString();
    final int branchId = userState.safeUserBranch > 0 ? userState.safeUserBranch : 1;

    try {
      // 1. طلب تقرير حركة المبيعات من السيرفر
      final salesReq = SalesMovementRequest(
        fromDate: fromDate,
        toDate: toDate,
        year: currentYear,
        branchId: branchId,
        transactionType: 'all',
      );
      final salesMovement = await _reportsApiService.fetchSalesMovement(salesReq);
      double serverNetSales = salesMovement.grandNetValue;
      int serverInvoicesCount = salesMovement.itemsCount;

      // 2. طلب السندات من السيرفر عبر سجل الحركات
      double serverReceipts = 0.0;
      double serverPayments = 0.0;
      try {
        final histReq = TransactionHistoryRequest(
          fromDate: fromDate,
          toDate: toDate,
          year: currentYear,
          branchId: branchId,
          transactionType: 'all',
        );
        final histRes = await _reportsApiService.fetchTransactionHistory(histReq);
        for (var t in histRes.transactions) {
          if (t.transactionTypeId == '201') {
            serverReceipts += t.netTotal;
          } else if (t.transactionTypeId == '202') {
            serverPayments += t.netTotal;
          }
        }
      } catch (e) {
        debugPrint('Could not fetch server receipts/payments history: $e');
      }

      // 3. دمج العمليات المعلقة محلياً في الهاتف (is_synced = 0) التي لم تسجل في السيرفر بعد
      final db = await _dbHelper.database;
      final localUnsyncedSales = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN invoice_type_char NOT LIKE 'ر%' THEN net_total ELSE 0 END) as pos,
          SUM(CASE WHEN invoice_type_char LIKE 'ر%' THEN net_total ELSE 0 END) as ret,
          COUNT(id) as cnt
        FROM sales 
        WHERE is_synced = 0 
          AND invoice_type_char != 'م ض'
          AND date >= ? AND date <= ?
      ''', [fromDate.toIso8601String(), toDate.toIso8601String()]);

      double extraSales = ((localUnsyncedSales.first['pos'] as num?)?.toDouble() ?? 0.0) -
          ((localUnsyncedSales.first['ret'] as num?)?.toDouble() ?? 0.0);
      int extraCount = (localUnsyncedSales.first['cnt'] as int?) ?? 0;

      netSales.value = serverNetSales + extraSales;
      invoicesCount.value = serverInvoicesCount + extraCount;

      // دمج السندات غير المتزامنة محلياً
      final localUnsyncedReceipts = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN invoice_type_char = 'ق' THEN total_amount ELSE 0 END) as total_in,
          SUM(CASE WHEN invoice_type_char = 'ص' THEN total_amount ELSE 0 END) as total_out
        FROM sun_receipt 
        WHERE is_synced = 0 
          AND date >= ? AND date <= ?
      ''', [fromDate.toIso8601String(), toDate.toIso8601String()]);

      double extraIn = (localUnsyncedReceipts.first['total_in'] as num?)?.toDouble() ?? 0.0;
      double extraOut = (localUnsyncedReceipts.first['total_out'] as num?)?.toDouble() ?? 0.0;

      receiptsTotal.value = serverReceipts + extraIn;
      paymentsTotal.value = serverPayments + extraOut;

      // 4. حفظ الخلاصة في جدول Offline_ReportsCache
      final nowTime = DateTime.now().toIso8601String();
      final cachePayload = jsonEncode({
        'netSales': netSales.value,
        'invoicesCount': invoicesCount.value,
        'receiptsTotal': receiptsTotal.value,
        'paymentsTotal': paymentsTotal.value,
        'cachedAt': nowTime,
      });

      await db.insert(
        'Offline_ReportsCache',
        {
          'ReportType': 'AdminDashboardStats',
          'EntityIdentifier': periodKey,
          'CurrencyId': '1',
          'ParametersHash': 'B${branchId}_Y$currentYear',
          'PayloadJson': cachePayload,
          'LastSyncTimestamp': nowTime,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      lastUpdatedText.value = 'مباشر من السيرفر';
    } catch (e) {
      debugPrint('Online fetch failed, falling back to cache: $e');
      if (selectedPeriod.value == 0) {
        await _loadTodayStatsFromLocal();
        lastUpdatedText.value = 'أوفلاين (لحظي محلي)';
      } else {
        await _loadHistoricalStatsFromCache(periodKey, fromDate, toDate);
      }
    }
  }

  // د) استرجاع إحصائيات الشهر/السنة من الكاش عند انقطاع الاتصال مع دمج الدلتا غير المتزامنة
  Future<void> _loadHistoricalStatsFromCache(
      String periodKey, DateTime fromDate, DateTime toDate) async {
    final db = await _dbHelper.database;
    final String currentYear = userState.financialYearName ?? DateTime.now().year.toString();
    final int branchId = userState.safeUserBranch > 0 ? userState.safeUserBranch : 1;

    final cached = await db.query(
      'Offline_ReportsCache',
      where: 'ReportType = ? AND EntityIdentifier = ? AND ParametersHash = ?',
      whereArgs: ['AdminDashboardStats', periodKey, 'B${branchId}_Y$currentYear'],
    );

    if (cached.isNotEmpty) {
      final data = jsonDecode(cached.first['PayloadJson'] as String);
      double baseNetSales = (data['netSales'] as num?)?.toDouble() ?? 0.0;
      int baseInvoicesCount = (data['invoicesCount'] as int?) ?? 0;
      double baseReceipts = (data['receiptsTotal'] as num?)?.toDouble() ?? 0.0;
      double basePayments = (data['paymentsTotal'] as num?)?.toDouble() ?? 0.0;
      String cachedAt = data['cachedAt']?.toString() ?? cached.first['LastSyncTimestamp'].toString();

      // حساب الدلتا: إضافة الفواتير غير المتزامنة المنشأة محلياً بعد وقت التخزين المؤقت
      final newUnsyncedSales = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN invoice_type_char NOT LIKE 'ر%' THEN net_total ELSE 0 END) as pos,
          SUM(CASE WHEN invoice_type_char LIKE 'ر%' THEN net_total ELSE 0 END) as ret,
          COUNT(id) as cnt
        FROM sales 
        WHERE is_synced = 0 
          AND invoice_type_char != 'م ض'
          AND date > ?
          AND date >= ? AND date <= ?
      ''', [cachedAt, fromDate.toIso8601String(), toDate.toIso8601String()]);

      double extraSales = ((newUnsyncedSales.first['pos'] as num?)?.toDouble() ?? 0.0) -
          ((newUnsyncedSales.first['ret'] as num?)?.toDouble() ?? 0.0);
      int extraCount = (newUnsyncedSales.first['cnt'] as int?) ?? 0;

      // إضافة السندات غير المتزامنة المنشأة بعد وقت التخزين المؤقت
      final newUnsyncedReceipts = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN invoice_type_char = 'ق' THEN total_amount ELSE 0 END) as total_in,
          SUM(CASE WHEN invoice_type_char = 'ص' THEN total_amount ELSE 0 END) as total_out
        FROM sun_receipt 
        WHERE is_synced = 0 
          AND date > ?
          AND date >= ? AND date <= ?
      ''', [cachedAt, fromDate.toIso8601String(), toDate.toIso8601String()]);

      double extraIn = (newUnsyncedReceipts.first['total_in'] as num?)?.toDouble() ?? 0.0;
      double extraOut = (newUnsyncedReceipts.first['total_out'] as num?)?.toDouble() ?? 0.0;

      netSales.value = baseNetSales + extraSales;
      invoicesCount.value = baseInvoicesCount + extraCount;
      receiptsTotal.value = baseReceipts + extraIn;
      paymentsTotal.value = basePayments + extraOut;

      DateTime? dt = DateTime.tryParse(cachedAt);
      lastUpdatedText.value = dt != null
          ? 'أوفلاين (كاش: ${DateFormat('MM/dd HH:mm').format(dt)})'
          : 'أوفلاين (كاش محفوظ)';
    } else {
      // إذا لم يتوفر كاش سابق لهذه الفترة: نحسب ما هو متاح محلياً في SQLite
      final localSales = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN invoice_type_char NOT LIKE 'ر%' THEN net_total ELSE 0 END) as pos,
          SUM(CASE WHEN invoice_type_char LIKE 'ر%' THEN net_total ELSE 0 END) as ret,
          COUNT(id) as cnt
        FROM sales 
        WHERE invoice_type_char != 'م ض'
          AND date >= ? AND date <= ?
      ''', [fromDate.toIso8601String(), toDate.toIso8601String()]);

      netSales.value = ((localSales.first['pos'] as num?)?.toDouble() ?? 0.0) -
          ((localSales.first['ret'] as num?)?.toDouble() ?? 0.0);
      invoicesCount.value = (localSales.first['cnt'] as int?) ?? 0;

      final localReceipts = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN invoice_type_char = 'ق' THEN total_amount ELSE 0 END) as total_in,
          SUM(CASE WHEN invoice_type_char = 'ص' THEN total_amount ELSE 0 END) as total_out
        FROM sun_receipt 
        WHERE date >= ? AND date <= ?
      ''', [fromDate.toIso8601String(), toDate.toIso8601String()]);

      receiptsTotal.value = (localReceipts.first['total_in'] as num?)?.toDouble() ?? 0.0;
      paymentsTotal.value = (localReceipts.first['total_out'] as num?)?.toDouble() ?? 0.0;

      lastUpdatedText.value = 'أوفلاين (المحلي فقط)';
    }
  }
}