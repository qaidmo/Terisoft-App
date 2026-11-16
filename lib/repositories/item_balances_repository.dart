// lib/repositories/item_balances_repository.dart
// مستودع مستقل لتقرير أرصدة الأصناف

import '../models/item_balances_models.dart';
import '../services/item_balances_api_service.dart';

class ItemBalancesRepository {
  final ItemBalancesApiService _apiService = ItemBalancesApiService();

  /// جلب بيانات تقرير أرصدة الأصناف من السيرفر
  Future<ItemBalancesResponse> getItemBalances({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    int? userId,
    int? departmentId,
    bool includeBranch = false,
    bool includeDepartment = false,
    bool includeStore = false,
    bool includeExpiry = false,
    bool includeBatch = false,
    bool excludeZeros = false,
    bool negativeQtyOnly = false,
    bool excludePreviousBalance = false,
    bool zeroBalancesOnly = false,
  }) async {
    final from = DateTime.parse(startDate);
    final to   = DateTime.parse(endDate);

    final request = ItemBalancesRequest(
      fromDate:              from,
      toDate:                to,
      year:                  year,
      branchId:              branchId,
      userId:                userId,
      departmentId:          departmentId,
      includeBranch:         includeBranch,
      includeDepartment:     includeDepartment,
      includeStore:          includeStore,
      includeExpiry:         includeExpiry,
      includeBatch:          includeBatch,
      excludeZeros:          excludeZeros,
      negativeQtyOnly:       negativeQtyOnly,
      excludePreviousBalance:excludePreviousBalance,
      zeroBalancesOnly:      zeroBalancesOnly,
    );

    return await _apiService.fetchItemBalances(request);
  }

  /// جلب بيانات أرصدة الأصناف مع دعم الأوفلاين (يُرجع النموذج ونص JSON الخام)
  Future<(ItemBalancesResponse?, String)> getItemBalancesWithCache({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    int? userId,
    int? departmentId,
    bool includeBranch = false,
    bool includeDepartment = false,
    bool includeStore = false,
    bool includeExpiry = false,
    bool includeBatch = false,
    bool excludeZeros = false,
    bool negativeQtyOnly = false,
    bool excludePreviousBalance = false,
    bool zeroBalancesOnly = false,
  }) async {
    final from = DateTime.parse(startDate);
    final to   = DateTime.parse(endDate);

    final request = ItemBalancesRequest(
      fromDate:              from,
      toDate:                to,
      year:                  year,
      branchId:              branchId,
      userId:                userId,
      departmentId:          departmentId,
      includeBranch:         includeBranch,
      includeDepartment:     includeDepartment,
      includeStore:          includeStore,
      includeExpiry:         includeExpiry,
      includeBatch:          includeBatch,
      excludeZeros:          excludeZeros,
      negativeQtyOnly:       negativeQtyOnly,
      excludePreviousBalance:excludePreviousBalance,
      zeroBalancesOnly:      zeroBalancesOnly,
    );

    return await _apiService.fetchItemBalancesWithCache(request);
  }
}
