class Sale {
  final String id;
  final String? guid;
  final String transactionNumber;
  final DateTime date;
  final String currency;
  final int? currencyId;
  final String? currencySymbol;
  final double? currencyRate;
  final String? customerName;
  final String? collector;
  final String? salesRep;
  final double total;
  final double? discount;
  final double? tax;
  final double? netTotal;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? userId;
  final String? userName;
  final String invoiceTypeChar;
  final String? invoiceType;
  final String accountNo;
  final String? accountId;
  final String? originalInvoiceRef;
  final int? boxNo;
  final String? boxName;
  final String? boxAccountId;
  final int? storeNo;
  final String? storeName;
  final int? collectorId;
  final String? collectorName;
  final int? agentId;
  final String? agentName;
  final bool isSynced;
  final int? sunYear;
  final int? branchId;
  final int? departmentId;
  final DateTime? startDate;
  final double? systemTotalValue;
  final double? traSrv;

  Sale({
    required this.id,
    this.guid,
    required this.transactionNumber,
    required this.date,
    required this.currency,
    this.currencyId,
    this.currencySymbol,
    this.currencyRate,
    this.customerName,
    this.collector,
    this.salesRep,
    required this.total,
    this.discount,
    this.tax,
    this.netTotal,
    this.createdAt,
    this.updatedAt,
    this.userId,
    this.userName,
    required this.invoiceTypeChar,
    this.invoiceType,
    required this.accountNo,
    this.accountId,
    this.originalInvoiceRef,
    this.boxNo,
    this.boxName,
    this.boxAccountId,
    this.storeNo,
    this.storeName,
    this.collectorId,
    this.collectorName,
    this.agentId,
    this.agentName,
    required this.isSynced,
    this.sunYear,
    this.branchId,
    this.departmentId,
    this.startDate,
    this.systemTotalValue,
    this.traSrv,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id']?.toString() ?? '',
      guid: json['guid']?.toString(),
      transactionNumber: json['transaction_number']?.toString() ?? '',
      date: DateTime.parse(json['date'] as String),
      currency: json['currency']?.toString() ?? '',
      currencyId: json['currency_id'] != null ? int.tryParse(json['currency_id'].toString()) : 1,
      currencySymbol: json['currency_symbol']?.toString(),
      currencyRate: (json['currency_rate'] as num?)?.toDouble(),
      customerName: json['customer_name'] is Map
          ? json['customer_name']['customer_name']?.toString()
          : json['customer_name']?.toString(),
      collector: json['collector']?.toString(),
      salesRep: json['sales_rep']?.toString(),
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble(),
      netTotal: (json['net_total'] as num?)?.toDouble(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'] as String),
      userId: json['user_id'] as int?,
      userName: json['user_name']?.toString(),
      invoiceTypeChar: json['invoice_type_char']?.toString() ?? '',
      invoiceType: json['invoice_type']?.toString(),
      accountNo: json['account_no']?.toString() ?? '',
      accountId: json['account_id']?.toString(),
      originalInvoiceRef: json['original_invoice_ref']?.toString(),
      boxNo: json['box_no'] as int?,
      boxName: json['box_name']?.toString(),
      boxAccountId: json['box_account_id']?.toString(),
      storeNo: json['store_no'] as int?,
      storeName: json['store_name']?.toString(),
      collectorId: json['collector_id'] as int?,
      collectorName: json['collector_name']?.toString(),
      agentId: json['agent_id'] as int?,
      agentName: json['agent_name']?.toString(),
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      sunYear: json['sun_year'] as int?,
      branchId: json['branch_id'] as int?,
      departmentId: json['department_id'] as int?,
      startDate: json['start_date'] == null
          ? null
          : DateTime.tryParse(json['start_date'] as String),
      systemTotalValue: (json['system_total_value'] as num?)?.toDouble(),
      traSrv: (json['tra_srv'] as num?)?.toDouble() ?? (json['traSrv'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty && int.tryParse(id) != null) 'id': int.parse(id),
      'guid': guid,
      'transaction_number': transactionNumber,
      'date': date.toIso8601String(),
      'currency': currency,
      'currency_rate': currencyRate,
      'customer_name': customerName,
      'collector': collector,
      'sales_rep': salesRep,
      'total': total,
      'discount': discount,
      'tax': tax,
      'net_total': netTotal,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'user_id': userId,
      'user_name': userName,
      'invoice_type_char': invoiceTypeChar,
      'invoice_type': invoiceType,
      'account_no': accountNo,
      'account_id': accountId,
      'original_invoice_ref': originalInvoiceRef,
      'box_no': boxNo,
      'box_name': boxName,
      'box_account_id': boxAccountId,
      'store_no': storeNo,
      'store_name': storeName,
      'collector_id': collectorId,
      'collector_name': collectorName,
      'agent_id': agentId,
      'agent_name': agentName,
      'is_synced': isSynced ? 1 : 0,
      'sun_year': sunYear,
      'branch_id': branchId,
      'department_id': departmentId,
      'start_date': startDate?.toIso8601String(),
      'system_total_value': systemTotalValue,
      'tra_srv': traSrv ?? 0.0,
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': int.tryParse(id) ?? 0,
      'guid': guid,
      'transactionNumber': transactionNumber,
      'date': date.toIso8601String(),
      'boxNo': boxNo,
      'boxName': boxName,
      'boxAccountId': boxAccountId,
      'storeNo': storeNo,
      'storeName': storeName,
      'currency': currency,
      'currencyId': currencyId ?? 1,
      'currencySymbol': currencySymbol ?? '',
      'currencyRate': currencyRate,
      'customerName': customerName,
      'accountNo': accountNo,
      'accountId': accountId,
      'collectorId': collectorId,
      'collectorName': collectorName,
      'agentId': agentId,
      'agentName': agentName,
      'total': total,
      'tax': tax,
      'discount': discount ?? 0.0,
      'netTotal': netTotal ?? 0.0,
      'userId': userId,
      'userName': userName,
      'invoiceTypeChar': invoiceTypeChar,
      'invoiceType': invoiceType ?? _getInvoiceTypeName(invoiceTypeChar),
      'sunYear': sunYear,
      'branchId': branchId,
      'departmentId': departmentId,
      'sourceLastUpdatedAt': updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'isSynced': isSynced,
      'traSrv': traSrv ?? 0.0,
    };
  }

  String _getInvoiceTypeName(String char) {
    switch (char) {
      case 'ن': return 'فاتورة مبيعات نقدا';
      case 'ج': return 'فاتورة مبيعات اجل';
      case 'م': return 'فاتورة مبيعات نقدا معلقة';
      case 'ق': return 'سند قبض';
      case 'ص': return 'سند صرف';
      case 'رن': return 'فاتورة مردود مبيعات نقدا';
      case 'رج': return 'فاتورة مردود مبيعات اجل';
      case 'رم': return 'فاتورة مردود مبيعات نقدا معلقة';
      case 'م ض': return 'محضر جرد';
      case 'ت': return 'فاتورة بيع نقدا';
      case 'ك ن': return 'فاتورة بيع نقداً';
      case 'ك ج': return 'فاتورة بيع اجل';
      default: return 'نوع غير معروف';
    }
  }
}