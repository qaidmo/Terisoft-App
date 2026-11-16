// lib/repositories/item_card_repository.dart
// مستودع مستقل لتقرير بطاقة الصنف

import '../models/item_card_models.dart';
import '../services/item_card_api_service.dart';

class ItemCardRepository {
  final ItemCardApiService _apiService = ItemCardApiService();

  /// جلب بيانات تقرير بطاقة الصنف من السيرفر
  Future<ItemCardResponse> getItemCard({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    String? itemName,
    String? batchNumber,
    String transactionType = 'all',
    bool excludeOpeningBalance = false,
    bool excludePreviousBalance = false,
    int? userId,
    int? departmentId,
  }) async {
    final from = DateTime.parse(startDate);
    final to   = DateTime.parse(endDate);

    final request = ItemCardRequest(
      fromDate:               from,
      toDate:                 to,
      year:                   year,
      branchId:               branchId,
      itemName:               itemName,
      batchNumber:            batchNumber,
      transactionType:        transactionType,
      excludeOpeningBalance:  excludeOpeningBalance,
      excludePreviousBalance: excludePreviousBalance,
      userId:                 userId,
      departmentId:           departmentId,
    );

    return await _apiService.fetchItemCard(request);
  }

  /// جلب بيانات تقرير بطاقة الصنف مع دعم الأوفلاين
  Future<(ItemCardResponse?, String)> getItemCardWithCache({
    required String startDate,
    required String endDate,
    required String year,
    required int branchId,
    String? itemName,
    String? batchNumber,
    String transactionType = 'all',
    bool excludeOpeningBalance = false,
    bool excludePreviousBalance = false,
    int? userId,
    int? departmentId,
  }) async {
    final from = DateTime.parse(startDate);
    final to   = DateTime.parse(endDate);

    final request = ItemCardRequest(
      fromDate:               from,
      toDate:                 to,
      year:                   year,
      branchId:               branchId,
      itemName:               itemName,
      batchNumber:            batchNumber,
      transactionType:        transactionType,
      excludeOpeningBalance:  excludeOpeningBalance,
      excludePreviousBalance: excludePreviousBalance,
      userId:                 userId,
      departmentId:           departmentId,
    );

    return await _apiService.fetchItemCardWithCache(request);
  }
}
