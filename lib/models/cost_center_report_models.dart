class CostCenterReportRequest {
  final int costCenterNo;
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;

  CostCenterReportRequest({
    required this.costCenterNo,
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
  });

  Map<String, dynamic> toJson() {
    return {
      'costCenterNo': costCenterNo,
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'year': year,
      'branchId': branchId,
    };
  }
}

class CostCenterReportResponse {
  final List<dynamic> transactions; // Keep it raw or parsed, but we will let CostCenterTransaction parse it

  CostCenterReportResponse({
    required this.transactions,
  });

  factory CostCenterReportResponse.fromJson(Map<String, dynamic> json) {
    return CostCenterReportResponse(
      transactions: json['transactions'] as List<dynamic>? ?? [],
    );
  }
}
