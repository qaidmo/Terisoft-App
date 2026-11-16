// ============================================================
// نماذج بيانات تقرير هامش أرباح مراكز التكلفة
// ============================================================

class CostCenterProfitMarginRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final int? departmentId;

  const CostCenterProfitMarginRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    this.departmentId,
  });

  Map<String, dynamic> toJson() => {
    'fromDate':     fromDate.toIso8601String(),
    'toDate':       toDate.toIso8601String(),
    'year':         year,
    'branchId':     branchId,
    'departmentId': departmentId,
  };
}

// ------------------------------------------------------------

class CostCenterProfitMarginRow {
  final String costCenterId;
  final String costCenterName;
  final double netCogs;      // صافي المنصرف مخزنياً
  final double grossSales;   // المبيعات الإجمالية
  final double returns;      // المردودات
  final double netSales;     // صافي المبيعات
  final double netProfit;    // صافي الربح
  final double profitPct;    // نسبة الربح %

  const CostCenterProfitMarginRow({
    required this.costCenterId,
    required this.costCenterName,
    required this.netCogs,
    required this.grossSales,
    required this.returns,
    required this.netSales,
    required this.netProfit,
    required this.profitPct,
  });

  factory CostCenterProfitMarginRow.fromJson(Map<String, dynamic> json) =>
      CostCenterProfitMarginRow(
        costCenterId:   (json['costCenterId']   ?? '').toString(),
        costCenterName: (json['costCenterName'] ?? '').toString(),
        netCogs:        _toDouble(json['netCogs']),
        grossSales:     _toDouble(json['grossSales']),
        returns:        _toDouble(json['returns']),
        netSales:       _toDouble(json['netSales']),
        netProfit:      _toDouble(json['netProfit']),
        profitPct:      _toDouble(json['profitPct']),
      );

  static double _toDouble(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
}

// ------------------------------------------------------------

class CostCenterProfitMarginResponse {
  final List<CostCenterProfitMarginRow> rows;
  final int    rowCount;
  final double grandNetCogs;
  final double grandGrossSales;
  final double grandReturns;
  final double grandNetSales;
  final double grandNetProfit;

  const CostCenterProfitMarginResponse({
    required this.rows,
    required this.rowCount,
    required this.grandNetCogs,
    required this.grandGrossSales,
    required this.grandReturns,
    required this.grandNetSales,
    required this.grandNetProfit,
  });

  factory CostCenterProfitMarginResponse.fromJson(Map<String, dynamic> json) {
    final rawRows = json['rows'] as List<dynamic>? ?? [];
    return CostCenterProfitMarginResponse(
      rows:           rawRows.map((e) => CostCenterProfitMarginRow.fromJson(e as Map<String, dynamic>)).toList(),
      rowCount:       (json['rowCount'] as num?)?.toInt() ?? 0,
      grandNetCogs:    _toDouble(json['grandNetCogs']),
      grandGrossSales: _toDouble(json['grandGrossSales']),
      grandReturns:    _toDouble(json['grandReturns']),
      grandNetSales:   _toDouble(json['grandNetSales']),
      grandNetProfit:  _toDouble(json['grandNetProfit']),
    );
  }

  static double _toDouble(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
}
