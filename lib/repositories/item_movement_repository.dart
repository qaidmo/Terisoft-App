// lib/repositories/item_movement_repository.dart
// مستودع مستقل لتقرير حركة الأصناف

import '../models/item_movement_models.dart';
import '../services/item_movement_api_service.dart';

class ItemMovementRepository {
  final ItemMovementApiService _apiService = ItemMovementApiService();

  /// جلب بيانات تقرير حركة الأصناف من السيرفر
  Future<ItemMovementResponse> getItemMovement({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    String transactionType = 'all',
    int? userId,
    int? departmentId,
    String? itemGroupId,
  }) async {
    final from = DateTime.parse(startDate);
    final to   = DateTime.parse(endDate);

    final request = ItemMovementRequest(
      fromDate:        from,
      toDate:          to,
      year:            year,
      branchId:        branchId,
      transactionType: transactionType,
      userId:          userId,
      departmentId:    departmentId,
      itemGroupId:     itemGroupId,
    );

    return await _apiService.fetchItemMovement(request);
  }

  /// جلب بيانات تقرير حركة الأصناف مع دعم الأوفلاين
  Future<(ItemMovementResponse?, String)> getItemMovementWithCache({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    String transactionType = 'all',
    int? userId,
    int? departmentId,
    String? itemGroupId,
  }) async {
    final from = DateTime.parse(startDate);
    final to   = DateTime.parse(endDate);

    final request = ItemMovementRequest(
      fromDate:        from,
      toDate:          to,
      year:            year,
      branchId:        branchId,
      transactionType: transactionType,
      userId:          userId,
      departmentId:    departmentId,
      itemGroupId:     itemGroupId,
    );

    return await _apiService.fetchItemMovementWithCache(request);
  }
}
