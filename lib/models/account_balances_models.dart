// lib/models/account_balances_models.dart
// موديلات تقرير أرصدة الحسابات — مستقل تماماً

class AccountBalancesRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final int? departmentId;
  final int? currencyId;
  final String groupingMode;

  AccountBalancesRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    this.departmentId,
    this.currencyId,
    required this.groupingMode,
  });

  Map<String, dynamic> toJson() => {
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'year': year,
        'branchId': branchId,
        'departmentId': departmentId,
        'currencyId': currencyId,
        'groupingMode': groupingMode,
      };
}

class AccountBalancesRow {
  final String entityId;
  final String entityName;
  final String accountName;
  final String beneficiaryName;
  final String costCenterName;
  final double openingDebit;
  final double openingCredit;
  final double periodDebit;
  final double periodCredit;
  final double totalDebit;
  final double totalCredit;
  final double balanceDebit;
  final double balanceCredit;
  final double netBalance;
  final double value;

  // Pre-formatted display strings (calculated in isolate for high performance)
  final String openingDebitStr;
  final String openingCreditStr;
  final String periodDebitStr;
  final String periodCreditStr;
  final String totalDebitStr;
  final String totalCreditStr;
  final String balanceDebitStr;
  final String balanceCreditStr;
  final String netBalanceStr;
  final String valueStr;
  final String col1;
  final String col2;

  AccountBalancesRow({
    required this.entityId,
    required this.entityName,
    required this.accountName,
    required this.beneficiaryName,
    required this.costCenterName,
    required this.openingDebit,
    required this.openingCredit,
    required this.periodDebit,
    required this.periodCredit,
    required this.totalDebit,
    required this.totalCredit,
    required this.balanceDebit,
    required this.balanceCredit,
    required this.netBalance,
    required this.value,
    this.openingDebitStr = '',
    this.openingCreditStr = '',
    this.periodDebitStr = '',
    this.periodCreditStr = '',
    this.totalDebitStr = '',
    this.totalCreditStr = '',
    this.balanceDebitStr = '',
    this.balanceCreditStr = '',
    this.netBalanceStr = '',
    this.valueStr = '',
    this.col1 = '',
    this.col2 = '',
  });

  factory AccountBalancesRow.fromJson(Map<String, dynamic> json) {
    return AccountBalancesRow(
      entityId: json['entityId']?.toString() ?? '',
      entityName: json['entityName']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      beneficiaryName: json['beneficiaryName']?.toString() ?? '',
      costCenterName: json['costCenterName']?.toString() ?? '',
      openingDebit: (json['openingDebit'] as num?)?.toDouble() ?? 0.0,
      openingCredit: (json['openingCredit'] as num?)?.toDouble() ?? 0.0,
      periodDebit: (json['periodDebit'] as num?)?.toDouble() ?? 0.0,
      periodCredit: (json['periodCredit'] as num?)?.toDouble() ?? 0.0,
      totalDebit: (json['totalDebit'] as num?)?.toDouble() ?? 0.0,
      totalCredit: (json['totalCredit'] as num?)?.toDouble() ?? 0.0,
      balanceDebit: (json['balanceDebit'] as num?)?.toDouble() ?? 0.0,
      balanceCredit: (json['balanceCredit'] as num?)?.toDouble() ?? 0.0,
      netBalance: (json['netBalance'] as num?)?.toDouble() ?? 0.0,
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      openingDebitStr: json['openingDebitStr']?.toString() ?? '',
      openingCreditStr: json['openingCreditStr']?.toString() ?? '',
      periodDebitStr: json['periodDebitStr']?.toString() ?? '',
      periodCreditStr: json['periodCreditStr']?.toString() ?? '',
      totalDebitStr: json['totalDebitStr']?.toString() ?? '',
      totalCreditStr: json['totalCreditStr']?.toString() ?? '',
      balanceDebitStr: json['balanceDebitStr']?.toString() ?? '',
      balanceCreditStr: json['balanceCreditStr']?.toString() ?? '',
      netBalanceStr: json['netBalanceStr']?.toString() ?? '',
      valueStr: json['valueStr']?.toString() ?? '',
      col1: json['col1']?.toString() ?? '',
      col2: json['col2']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'entityId': entityId,
        'entityName': entityName,
        'accountName': accountName,
        'beneficiaryName': beneficiaryName,
        'costCenterName': costCenterName,
        'openingDebit': openingDebit,
        'openingCredit': openingCredit,
        'periodDebit': periodDebit,
        'periodCredit': periodCredit,
        'totalDebit': totalDebit,
        'totalCredit': totalCredit,
        'balanceDebit': balanceDebit,
        'balanceCredit': balanceCredit,
        'netBalance': netBalance,
        'value': value,
      };
}


class AccountBalancesResponse {
  final List<AccountBalancesRow> rows;
  final int rowCount;
  final double grandOpeningDebit;
  final double grandOpeningCredit;
  final double grandPeriodDebit;
  final double grandPeriodCredit;
  final double grandTotalDebit;
  final double grandTotalCredit;
  final double grandBalanceDebit;
  final double grandBalanceCredit;
  final double grandNetBalance;
  final double grandValue;

  AccountBalancesResponse({
    required this.rows,
    required this.rowCount,
    required this.grandOpeningDebit,
    required this.grandOpeningCredit,
    required this.grandPeriodDebit,
    required this.grandPeriodCredit,
    required this.grandTotalDebit,
    required this.grandTotalCredit,
    required this.grandBalanceDebit,
    required this.grandBalanceCredit,
    required this.grandNetBalance,
    required this.grandValue,
  });

  factory AccountBalancesResponse.fromJson(Map<String, dynamic> json) {
    var list = json['rows'] as List?;
    List<AccountBalancesRow> rowsList =
        list != null ? list.map((i) => AccountBalancesRow.fromJson(i)).toList() : [];

    return AccountBalancesResponse(
      rows: rowsList,
      rowCount: (json['rowCount'] as num?)?.toInt() ?? 0,
      grandOpeningDebit: (json['grandOpeningDebit'] as num?)?.toDouble() ?? 0.0,
      grandOpeningCredit: (json['grandOpeningCredit'] as num?)?.toDouble() ?? 0.0,
      grandPeriodDebit: (json['grandPeriodDebit'] as num?)?.toDouble() ?? 0.0,
      grandPeriodCredit: (json['grandPeriodCredit'] as num?)?.toDouble() ?? 0.0,
      grandTotalDebit: (json['grandTotalDebit'] as num?)?.toDouble() ?? 0.0,
      grandTotalCredit: (json['grandTotalCredit'] as num?)?.toDouble() ?? 0.0,
      grandBalanceDebit: (json['grandBalanceDebit'] as num?)?.toDouble() ?? 0.0,
      grandBalanceCredit: (json['grandBalanceCredit'] as num?)?.toDouble() ?? 0.0,
      grandNetBalance: (json['grandNetBalance'] as num?)?.toDouble() ?? 0.0,
      grandValue: (json['grandValue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
