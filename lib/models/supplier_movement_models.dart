// lib/models/supplier_movement_models.dart
// نماذج تقرير حركة الموردين — مستقلة تماماً

// =========================================================================
// Request
// =========================================================================
class SupplierMovementRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final int departmentId;
  final int currencyId;
  final int? userId;

  final bool isDetailedMode;

  const SupplierMovementRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    required this.departmentId,
    required this.currencyId,
    this.userId,
    this.isDetailedMode = false,
  });

  Map<String, dynamic> toJson() => {
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'year': year,
        'branchId': branchId,
        'departmentId': departmentId,
        'currencyId': currencyId,
        if (userId != null) 'userId': userId,
        'isDetailedMode': isDetailedMode,
      };
}

// =========================================================================
// Single row item
// =========================================================================
class SupplierMovementItem {
  final String accountNumber;
  final String accountName;
  final String supplierName;
  final String departmentId;
  final String branchId;
  final double openingBalance;
  final double totalPurchases;
  final double totalReturns;
  final double netPurchases;
  final double totalPayments;
  final double totalAdjustments;
  final double balance;
  final double inventoryValue;
  final double difference;
  final String lastPaymentDate;

  final String invoiceDate;
  final String invoiceNumber;

  const SupplierMovementItem({
    required this.accountNumber,
    required this.accountName,
    required this.supplierName,
    required this.departmentId,
    required this.branchId,
    required this.openingBalance,
    required this.totalPurchases,
    required this.totalReturns,
    required this.netPurchases,
    required this.totalPayments,
    required this.totalAdjustments,
    required this.balance,
    required this.inventoryValue,
    required this.difference,
    required this.lastPaymentDate,
    this.invoiceDate = '',
    this.invoiceNumber = '',
  });

  factory SupplierMovementItem.fromJson(Map<String, dynamic> json) {
    return SupplierMovementItem(
      accountNumber:    (json['accountNumber']    ?? '').toString(),
      accountName:      (json['accountName']      ?? '').toString(),
      supplierName:     (json['supplierName']     ?? '').toString(),
      departmentId:     (json['departmentId']     ?? '').toString(),
      branchId:         (json['branchId']         ?? '').toString(),
      openingBalance:   _toDouble(json['openingBalance']),
      totalPurchases:   _toDouble(json['totalPurchases']),
      totalReturns:     _toDouble(json['totalReturns']),
      netPurchases:     _toDouble(json['netPurchases']),
      totalPayments:    _toDouble(json['totalPayments']),
      totalAdjustments: _toDouble(json['totalAdjustments']),
      balance:          _toDouble(json['balance']),
      inventoryValue:   _toDouble(json['inventoryValue']),
      difference:       _toDouble(json['difference']),
      lastPaymentDate:  (json['lastPaymentDate']  ?? '').toString(),
      invoiceDate:      (json['invoiceDate']       ?? '').toString(),
      invoiceNumber:    (json['invoiceNumber']     ?? '').toString(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

// =========================================================================
// Response wrapper
// =========================================================================
class SupplierMovementResponse {
  final List<SupplierMovementItem> data;
  final double grandOpeningBalance;
  final double grandTotalPurchases;
  final double grandTotalReturns;
  final double grandNetPurchases;
  final double grandTotalPayments;
  final double grandTotalAdjustments;
  final double grandBalance;

  const SupplierMovementResponse({
    required this.data,
    required this.grandOpeningBalance,
    required this.grandTotalPurchases,
    required this.grandTotalReturns,
    required this.grandNetPurchases,
    required this.grandTotalPayments,
    required this.grandTotalAdjustments,
    required this.grandBalance,
  });

  factory SupplierMovementResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] as List<dynamic>? ?? [];
    return SupplierMovementResponse(
      data: rawList
          .map((e) => SupplierMovementItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      grandOpeningBalance:   SupplierMovementItem._toDouble(json['grandOpeningBalance']),
      grandTotalPurchases:   SupplierMovementItem._toDouble(json['grandTotalPurchases']),
      grandTotalReturns:     SupplierMovementItem._toDouble(json['grandTotalReturns']),
      grandNetPurchases:     SupplierMovementItem._toDouble(json['grandNetPurchases']),
      grandTotalPayments:    SupplierMovementItem._toDouble(json['grandTotalPayments']),
      grandTotalAdjustments: SupplierMovementItem._toDouble(json['grandTotalAdjustments']),
      grandBalance:          SupplierMovementItem._toDouble(json['grandBalance']),
    );
  }
}
