class SunReceipt {
  final int? id;
  final String? guid;
  final DateTime createdAt;
  final String transactionNumber;
  final DateTime date;
  final String cashBox;
  final String? boxAccountId;
  final String currency;
  final int? currencyId;
  final String? currencySymbol;
  final double? currencyRate;
  final String accountName;
  final String? costCenter;
  final String? description;
  final double totalAmount;
  final String? amountInWords;
  final int userId;
  final String? userName;
  final String invoiceTypeChar;
  final String invoiceType;
  final String? collectorName;
  final int? costCenterNo;
  final bool isSynced;
  final int? sunYear;
  final int? branchId;
  final int? departmentId;
  final int? collectorNo;
  final DateTime? updatedAt;
  final DateTime? sourceLastUpdatedAt;

  SunReceipt({
    this.id,
    this.guid,
    required this.createdAt,
    required this.transactionNumber,
    required this.date,
    required this.cashBox,
    this.boxAccountId,
    required this.currency,
    this.currencyId,
    this.currencySymbol,
    this.currencyRate,
    required this.accountName,
    this.costCenter,
    this.description,
    required this.totalAmount,
    this.amountInWords,
    required this.userId,
    this.userName,
    required this.invoiceTypeChar,
    required this.invoiceType,
    this.collectorName,
    this.costCenterNo,
    required this.isSynced,
    this.sunYear,
    this.branchId,
    this.departmentId,
    this.collectorNo,
    this.updatedAt,
    this.sourceLastUpdatedAt,
  });

  factory SunReceipt.fromJson(Map<String, dynamic> json) {
    return SunReceipt(
      id: json['id'] as int?,
      guid: json['guid']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      transactionNumber: json['transaction_number']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      cashBox: json['cash_box']?.toString() ?? '',
      boxAccountId: json['box_account_id']?.toString(),
      currency: json['currency']?.toString() ?? '',
      currencyId: json['currency_id'] != null ? int.tryParse(json['currency_id'].toString()) : 1,
      currencySymbol: json['currency_symbol']?.toString(),
      currencyRate: (json['currency_rate'] as num?)?.toDouble(),
      accountName: json['account_name']?.toString() ?? '',
      costCenter: json['cost_center']?.toString(),
      description: json['description']?.toString(),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      amountInWords: json['amount_in_words']?.toString(),
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      userName: json['user_name']?.toString(),
      invoiceTypeChar: json['invoice_type_char']?.toString() ?? '',
      invoiceType: json['invoice_type']?.toString() ?? '',
      collectorName: json['collector_name']?.toString(),
      costCenterNo: (json['cost_center_no'] as num?)?.toInt(),
      isSynced: (json['is_synced'] as int?) == 1 || json['is_synced'] == true,
      sunYear: (json['sun_year'] as num?)?.toInt(),
      branchId: (json['branch_id'] as num?)?.toInt(),
      departmentId: (json['department_id'] as num?)?.toInt(),
      collectorNo: (json['collector_no'] as num?)?.toInt(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      sourceLastUpdatedAt: json['source_last_updated_at'] != null ? DateTime.tryParse(json['source_last_updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guid': guid,
      'created_at': createdAt.toIso8601String(),
      'transaction_number': transactionNumber,
      'date': date.toIso8601String(),
      'cash_box': cashBox,
      'box_account_id': boxAccountId,
      'currency': currency,
      'currency_id': currencyId,
      'currency_symbol': currencySymbol,
      'currency_rate': currencyRate,
      'account_name': accountName,
      'cost_center': costCenter,
      'description': description,
      'total_amount': totalAmount,
      'amount_in_words': amountInWords,
      'user_id': userId,
      'user_name': userName,
      'invoice_type_char': invoiceTypeChar,
      'invoice_type': invoiceType,
      'collector_name': collectorName,
      'cost_center_no': costCenterNo,
      'is_synced': isSynced ? 1 : 0,
      'sun_year': sunYear,
      'branch_id': branchId,
      'department_id': departmentId,
      'collector_no': collectorNo,
      'updated_at': updatedAt?.toIso8601String(),
      'source_last_updated_at': sourceLastUpdatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': id ?? 0,
      'guid': guid,
      'transactionNumber': transactionNumber,
      'date': date.toIso8601String(),
      'cashBox': cashBox,
      'boxAccountId': boxAccountId,
      'currency': currency,
      'currencyId': currencyId ?? 1,
      'currencyRate': currencyRate ?? 1.0,
      'accountName': accountName,
      'accountNo': '',
      'costCenter': costCenter,
      'costCenterNo': costCenterNo,
      'description': description,
      'totalAmount': totalAmount,
      'amountInWords': amountInWords,
      'userId': userId,
      'userName': userName,
      'invoiceTypeChar': invoiceTypeChar,
      'invoiceType': invoiceType.isNotEmpty ? invoiceType : _getInvoiceTypeName(invoiceTypeChar),
      'collectorName': collectorName,
      'collectorId': collectorNo,
      'sunYear': sunYear,
      'branchId': branchId,
      'departmentId': departmentId,
      'sourceLastUpdatedAt': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'isSynced': isSynced,
    };
  }

  String _getInvoiceTypeName(String char) {
    switch (char) {
      case 'ق': return 'سند قبض';
      case 'ص': return 'سند صرف';
      default: return 'سند غير معروف';
    }
  }
}