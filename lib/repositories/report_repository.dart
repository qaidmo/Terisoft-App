import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer_activity_models.dart';
import '../services/reports_api_service.dart';
import '../models/account_statement_models.dart';
import '../models/transaction_history_models.dart';
import '../models/cost_center_report_models.dart';
import '../models/sales_movement_models.dart';
import '../models/supplier_movement_models.dart';
import '../models/account_balances_models.dart';
import '../models/cost_center_profit_margin_models.dart';
import '../services/supplier_movement_api_service.dart';
import '../supabase_manager.dart';
import 'package:get/get.dart';
import '../user_state.dart';

class ReportRepository {
  // تعريف خدمات الـ API
  final ReportsApiService _apiService = ReportsApiService();
  final SupplierMovementApiService _supplierApiService = SupplierMovementApiService();

  // الإبقاء على عميل Supabase للدوال القديمة
  SupabaseClient get _supabase => SupabaseManager.client;

  // ==========================================================
  // 1. القسم الجديد: دوال تتصل بـ ASP.NET Core API
  // ==========================================================

  // --- دوال متوافقة مع الشاشات القديمة التي تحتاج لنموذج عادي فقط ---
  
  Future<AccountStatementResponse> getAccountStatement({
    required String accountId,
    required int currencyId,
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    int? departmentId,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = AccountStatementRequest(
      accountId: accountId, currencyId: currencyId,
      fromDate: from, toDate: to, year: year, branchId: branchId,
      departmentId: departmentId,
    );
    return await _apiService.fetchAccountStatement(request);
  }

  Future<TransactionHistoryResponse> getTransactionHistory({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    required String transactionType,
    int? userId,
    int? departmentId,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = TransactionHistoryRequest(
      fromDate: from, toDate: to, year: year, branchId: branchId,
      transactionType: transactionType, userId: userId, departmentId: departmentId,
    );
    return await _apiService.fetchTransactionHistory(request);
  }

  Future<CustomerActivityResponse> getCustomerActivitySummary({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    required int departmentId,
    required int currencyId,
    int? userId,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = CustomerActivityRequest(
      fromDate: from, toDate: to, year: year, branchId: branchId,
      departmentId: departmentId, currencyId: currencyId, userId: userId,
    );
    return await _apiService.fetchCustomerActivity(request);
  }

  // --- دوال تدعم الأوفلاين تُرجع (النموذج ومحتوى الـ JSON) ---

  Future<(AccountStatementResponse?, String)> getAccountStatementWithCache({
    required String accountId,
    required int currencyId,
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    int? departmentId,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = AccountStatementRequest(
      accountId: accountId, currencyId: currencyId,
      fromDate: from, toDate: to, year: year, branchId: branchId,
      departmentId: departmentId,
    );
    return await _apiService.fetchAccountStatementWithCache(request);
  }

  Future<(TransactionHistoryResponse?, String)> getTransactionHistoryWithCache({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    required String transactionType,
    int? userId,
    int? departmentId,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = TransactionHistoryRequest(
      fromDate: from, toDate: to, year: year, branchId: branchId,
      transactionType: transactionType, userId: userId, departmentId: departmentId,
    );
    return await _apiService.fetchTransactionHistoryWithCache(request);
  }

  Future<(CustomerActivityResponse?, String)> getCustomerActivitySummaryWithCache({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    required int departmentId,
    required int currencyId,
    int? userId,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = CustomerActivityRequest(
      fromDate: from, toDate: to, year: year, branchId: branchId,
      departmentId: departmentId, currencyId: currencyId, userId: userId,
    );
    return await _apiService.fetchCustomerActivityWithCache(request);
  }

  Future<CostCenterProfitMarginResponse> getCostCenterProfitMargin({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    int? departmentId,
  }) async {
    final from = DateTime.parse(startDate);
    final to   = DateTime.parse(endDate);
    final request = CostCenterProfitMarginRequest(
      fromDate: from, toDate: to, year: year,
      branchId: branchId, departmentId: departmentId,
    );
    return await _apiService.fetchCostCenterProfitMargin(request);
  }

  // ==========================================================
  // 2. القسم القديم: دوال تعتمد على Supabase (مبقية للتوافق)
  // ==========================================================

  /// جلب بيانات حركة العملاء
  Future<List<Map<String, dynamic>>> getCustomerMovement({
    required String fromDate,
    required String toDate,
    required String targetCurrencyName,
    int? userIdForFilter,
  }) async {
    try {
      final params = {
        'from_date': fromDate,
        'to_date': toDate,
        'p_target_currency_name': targetCurrencyName,
        'p_user_id': userIdForFilter,
      };

      final response = await _supabase.rpc('get_customer_movement', params: params);

      if (response != null && response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// جلب أنواع الحركات الديناميكية
  Future<Map<String, Set<String>>> getDynamicMovementTypes(int? userId) async {
    try {
      var salesQuery = _supabase.from('sales').select('invoice_type_char');
      var receiptQuery = _supabase.from('sun_receipt').select('invoice_type_char');

      if (userId != null) {
        salesQuery = salesQuery.eq('user_id', userId);
        receiptQuery = receiptQuery.eq('user_id', userId);
      }

      final salesResponse = await salesQuery;
      final receiptResponse = await receiptQuery;

      final Set<String> uniqueSalesChars = salesResponse.map((e) => e['invoice_type_char'] as String).toSet();
      final Set<String> uniqueReceiptChars = receiptResponse.map((e) => e['invoice_type_char'] as String).toSet();

      return {
        'sales': uniqueSalesChars,
        'receipt': uniqueReceiptChars,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// جلب حركات المبيعات (قديم)
  Future<List<Map<String, dynamic>>> fetchSalesMovements({
    required String fromDate,
    required String toDate,
    String? typeChar,
    int? userId,
    int? branchId,
    int? departmentId,
  }) async {
    var query = _supabase
        .from('sales')
        .select('id, transaction_number, date, customer_name, net_total, invoice_type_char, user:user_id(user_name)')
        .gte('date', fromDate)
        .lte('date', toDate);

    if (typeChar != null) {
      query = query.eq('invoice_type_char', typeChar);
    }
    if (userId != null) {
      query = query.eq('user_id', userId);
    }
    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }
    if (departmentId != null) {
      query = query.eq('department_id', departmentId);
    }

    final response = await query.order('date', ascending: false);
    return response.map((item) => {
      'id': item['id'],
      'transaction_number': item['transaction_number'],
      'date': item['date'],
      'customer_name': item['customer_name'],
      'net_total': item['net_total'],
      'invoice_type_char': item['invoice_type_char'],
      'user_name': (item['user'] as Map?)?['user_name'] ?? 'غير معروف',
      'source': 'sales',
    }).toList();
  }

  /// جلب حركات السندات (قديم)
  Future<List<Map<String, dynamic>>> fetchReceiptMovements({
    required String fromDate,
    required String toDate,
    String? typeChar,
    int? userId,
    int? branchId,
    int? departmentId,
  }) async {
    var query = _supabase
        .from('sun_receipt')
        .select('id, transaction_number, date, account_name, total_amount, invoice_type_char, user:user_id(user_name)')
        .gte('date', fromDate)
        .lte('date', toDate);

    if (typeChar != null) {
      query = query.eq('invoice_type_char', typeChar);
    }
    if (userId != null) {
      query = query.eq('user_id', userId);
    }
    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }
    if (departmentId != null) {
      query = query.eq('department_id', departmentId);
    }

    final response = await query.order('date', ascending: false);
    return response.map((item) => {
      'id': item['id'],
      'transaction_number': item['transaction_number'],
      'date': item['date'],
      'customer_name': item['account_name'],
      'net_total': item['total_amount'],
      'invoice_type_char': item['invoice_type_char'],
      'user_name': (item['user'] as Map?)?['user_name'] ?? 'غير معروف',
      'source': 'receipt',
    }).toList();
  }

  /// جلب حركات مركز التكلفة (مُحدّث ليعمل عبر API)
  Future<CostCenterReportResponse> getCostCenterTransactions({
    required int costCenterNo,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final request = CostCenterReportRequest(
        costCenterNo: costCenterNo,
        fromDate: DateTime.parse(fromDate),
        toDate: DateTime.parse(toDate),
        year: DateTime.parse(fromDate).year.toString(),
        branchId: Get.find<UserState>().userBranch ?? 1,
      );

      return await _apiService.fetchCostCenterTransactions(request);
    } catch (e) {
      rethrow;
    }
  }

  /// جلب حركات مركز التكلفة مع دعم الأوفلاين (يُرجع النموذج ونص JSON الخام)
  Future<(CostCenterReportResponse?, String)> getCostCenterTransactionsWithCache({
    required int costCenterNo,
    required String fromDate,
    required String toDate,
  }) async {
    final request = CostCenterReportRequest(
      costCenterNo: costCenterNo,
      fromDate: DateTime.parse(fromDate),
      toDate: DateTime.parse(toDate),
      year: DateTime.parse(fromDate).year.toString(),
      branchId: Get.find<UserState>().userBranch ?? 1,
    );
    return await _apiService.fetchCostCenterTransactionsWithCache(request);
  }

  // ==========================================================
  // تقرير حركة المبيعات الجديد - مستقل تماماً
  // ==========================================================
  Future<SalesMovementResponse> getSalesMovement({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    required String transactionType,
    int? userId,
    int? departmentId,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = SalesMovementRequest(
      fromDate: from,
      toDate: to,
      year: year,
      branchId: branchId,
      transactionType: transactionType,
      userId: userId,
      departmentId: departmentId,
    );
    return await _apiService.fetchSalesMovement(request);
  }

  // ==========================================================
  // تقرير حركة الموردين — مستقل تماماً
  // ==========================================================
  Future<SupplierMovementResponse> getSupplierMovement({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    required int departmentId,
    required int currencyId,
    int? userId,
    bool isDetailedMode = false,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = SupplierMovementRequest(
      fromDate: from,
      toDate: to,
      year: year,
      branchId: branchId,
      departmentId: departmentId,
      currencyId: currencyId,
      userId: userId,
      isDetailedMode: isDetailedMode,
    );
    return await _supplierApiService.fetchSupplierMovement(request);
  }

  // ---------------------------------------------------------------------------
  // WithCache wrappers — Sales Movement New + Supplier Movement
  // ---------------------------------------------------------------------------
  Future<(SalesMovementResponse?, String)> getSalesMovementWithCache({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    required String transactionType,
    int? userId,
    int? departmentId,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = SalesMovementRequest(
      fromDate: from,
      toDate: to,
      year: year,
      branchId: branchId,
      transactionType: transactionType,
      userId: userId,
      departmentId: departmentId,
    );
    return await _apiService.fetchSalesMovementWithCache(request);
  }

  Future<(SupplierMovementResponse?, String)> getSupplierMovementWithCache({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    required int departmentId,
    required int currencyId,
    int? userId,
    bool isDetailedMode = false,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = SupplierMovementRequest(
      fromDate: from,
      toDate: to,
      year: year,
      branchId: branchId,
      departmentId: departmentId,
      currencyId: currencyId,
      userId: userId,
      isDetailedMode: isDetailedMode,
    );
    return await _supplierApiService.fetchSupplierMovementWithCache(request);
  }

  // ==========================================================
  // تقرير أرصدة الحسابات — مستقل تماماً
  // ==========================================================
  Future<AccountBalancesResponse> getAccountBalances({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    int? departmentId,
    int? currencyId,
    required String groupingMode,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = AccountBalancesRequest(
      fromDate: from,
      toDate: to,
      year: year,
      branchId: branchId,
      departmentId: departmentId,
      currencyId: currencyId,
      groupingMode: groupingMode,
    );
    return await _apiService.fetchAccountBalances(request);
  }

  Future<(AccountBalancesResponse?, String)> getAccountBalancesWithCache({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    int? departmentId,
    int? currencyId,
    required String groupingMode,
  }) async {
    final from = DateTime.parse(startDate);
    final to = DateTime.parse(endDate);
    final request = AccountBalancesRequest(
      fromDate: from,
      toDate: to,
      year: year,
      branchId: branchId,
      departmentId: departmentId,
      currencyId: currencyId,
      groupingMode: groupingMode,
    );
    return await _apiService.fetchAccountBalancesWithCache(request);
  }
}