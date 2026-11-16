// lib/models/sales_movement_models.dart
// تقرير حركة المبيعات - موديلات مستقلة تماماً عن Transaction History

class SalesMovementRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final String transactionType;
  final int? userId;
  final int? departmentId;

  SalesMovementRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    required this.transactionType,
    this.userId,
    this.departmentId,
  });

  Map<String, dynamic> toJson() => {
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'year': year,
        'branchId': branchId,
        'transactionType': transactionType,
        'userId': userId,
        'departmentId': departmentId,
      };
}

class SalesMovementItem {
  final String transactionId;
  final String transactionNumber;
  final String date;
  final String time;
  final String transactionTypeId;
  final String transactionTypeName;
  final String beneficiaryName;
  final String accountName;
  final String userName;
  final String branchName;
  final String departmentName;
  final double grossTotal;
  final double discountAmount;
  final double taxAmount;
  final double netValue;
  final double finalValue;

  SalesMovementItem({
    required this.transactionId,
    required this.transactionNumber,
    required this.date,
    required this.time,
    required this.transactionTypeId,
    required this.transactionTypeName,
    required this.beneficiaryName,
    required this.accountName,
    required this.userName,
    required this.branchName,
    required this.departmentName,
    required this.grossTotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.netValue,
    required this.finalValue,
  });

  factory SalesMovementItem.fromJson(Map<String, dynamic> json) =>
      SalesMovementItem(
        transactionId: json['transactionId']?.toString() ?? '',
        transactionNumber: json['transactionNumber']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        time: json['time']?.toString() ?? '',
        transactionTypeId: json['transactionTypeId']?.toString() ?? '',
        transactionTypeName: json['transactionTypeName']?.toString() ?? '',
        beneficiaryName: json['beneficiaryName']?.toString() ?? '',
        accountName: json['accountName']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        branchName: json['branchName']?.toString() ?? '',
        departmentName: json['departmentName']?.toString() ?? '',
        grossTotal: (json['grossTotal'] as num?)?.toDouble() ?? 0.0,
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
        netValue: (json['netValue'] as num?)?.toDouble() ?? 0.0,
        finalValue: (json['finalValue'] as num?)?.toDouble() ?? 0.0,
      );
}

class SalesMovementResponse {
  final int itemsCount;
  final double grandNetValue;
  final double grandFinalValue;
  final List<SalesMovementItem> items;

  SalesMovementResponse({
    required this.itemsCount,
    required this.grandNetValue,
    required this.grandFinalValue,
    required this.items,
  });

  factory SalesMovementResponse.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List? ?? [];
    return SalesMovementResponse(
      itemsCount: (json['itemsCount'] as num?)?.toInt() ?? 0,
      grandNetValue: (json['grandNetValue'] as num?)?.toDouble() ?? 0.0,
      grandFinalValue: (json['grandFinalValue'] as num?)?.toDouble() ?? 0.0,
      items: list.map((i) => SalesMovementItem.fromJson(i)).toList(),
    );
  }
}
