// lib/repositories/profit_margin_repository.dart
// مستودع مستقل لتقرير هامش الربح

import '../models/profit_margin_models.dart';
import '../services/profit_margin_api_service.dart';

class ProfitMarginRepository {
  final ProfitMarginApiService _apiService = ProfitMarginApiService();

  /// جلب بيانات تقرير هامش الربح من السيرفر
  Future<ProfitMarginResponse> getProfitMargin({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    String groupBy = 'item',
    int? userId,
    int? departmentId,
    String? itemGroupId,
    bool negativeMarginOnly = false,
    bool includeBranch = false,
    bool includeDepartment = false,
    bool includeBatch = false,
    bool includeCostCenter = false,
  }) async {
    final from = DateTime.parse(startDate);
    final to   = DateTime.parse(endDate);

    final request = ProfitMarginRequest(
      fromDate:          from,
      toDate:            to,
      year:              year,
      branchId:          branchId,
      groupBy:           groupBy,
      userId:            userId,
      departmentId:      departmentId,
      itemGroupId:       itemGroupId,
      negativeMarginOnly:negativeMarginOnly,
      includeBranch:     includeBranch,
      includeDepartment: includeDepartment,
      includeBatch:      includeBatch,
      includeCostCenter: includeCostCenter,
    );

    return await _apiService.fetchProfitMargin(request);
  }

  /// جلب بيانات تقرير هامش الربح مع دعم الأوفلاين
  Future<(ProfitMarginResponse?, String)> getProfitMarginWithCache({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    String groupBy = 'item',
    int? userId,
    int? departmentId,
    String? itemGroupId,
    bool negativeMarginOnly = false,
    bool includeBranch = false,
    bool includeDepartment = false,
    bool includeBatch = false,
    bool includeCostCenter = false,
  }) async {
    final from = DateTime.parse(startDate);
    final to   = DateTime.parse(endDate);

    final request = ProfitMarginRequest(
      fromDate:          from,
      toDate:            to,
      year:              year,
      branchId:          branchId,
      groupBy:           groupBy,
      userId:            userId,
      departmentId:      departmentId,
      itemGroupId:       itemGroupId,
      negativeMarginOnly:negativeMarginOnly,
      includeBranch:     includeBranch,
      includeDepartment: includeDepartment,
      includeBatch:      includeBatch,
      includeCostCenter: includeCostCenter,
    );

    return await _apiService.fetchProfitMarginWithCache(request);
  }
}
