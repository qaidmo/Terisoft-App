// lib/models/sun_customer.dart

class SunCustomer {
  final int customerNo;
  final String customerName;
  final String? customerForeignName;
  final String? phoneNumber;
  final String? address;
  final String? email;
  final String? accountId;
  final String? controlAccountId;
  final String? sourceId;
  final String? lastUpdated;
  final String? costData;
  final double? costNext;
  final double? costRsom;

  String? accountName;
  String? accountNumber;
  List<int> currencyNos;

  SunCustomer({
    required this.customerNo,
    required this.customerName,
    this.customerForeignName,
    this.phoneNumber,
    this.address,
    this.email,
    this.accountId,
    this.controlAccountId,
    this.sourceId,
    // 2. 👇 إضافته في الكونستركتور
    this.lastUpdated,
    this.costData,
    this.costNext,
    this.costRsom,
    this.accountName,
    this.accountNumber,
    this.currencyNos = const [],
  });

  factory SunCustomer.fromJson(Map<String, dynamic> json) {
    return SunCustomer(
      customerNo: json['customer_no'] as int,
      customerName: json['customer_name'] as String? ?? 'N/A',
      customerForeignName: json['customer_foreign_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      address: json['address'] as String?,
      email: json['email'] as String?,
      accountId: json['account_id']?.toString(),
      controlAccountId: json['control_account_id']?.toString(),
      sourceId: json['source_id']?.toString(),
      lastUpdated: json['last_updated'] as String?,
      costData: json['cost_data']?.toString(),
      costNext: json['cost_next'] != null ? double.tryParse(json['cost_next'].toString()) : null,
      costRsom: json['cost_rsom'] != null ? double.tryParse(json['cost_rsom'].toString()) : null,
    );
  }

  factory SunCustomer.fromMap(Map<String, dynamic> map) {
    return SunCustomer(
      customerNo: map['customer_no'] as int,
      customerName: map['customer_name'] as String,
      customerForeignName: map['customer_foreign_name'] as String?,
      phoneNumber: map['phone_number'] as String?,
      address: map['address'] as String?,
      email: map['email'] as String?,
      accountId: map['account_id']?.toString(),
      controlAccountId: map['control_account_id']?.toString(),
      sourceId: map['source_id']?.toString(),
      lastUpdated: map['last_updated'] as String?,
      costData: map['cost_data']?.toString(),
      costNext: map['cost_next'] != null ? double.tryParse(map['cost_next'].toString()) : null,
      costRsom: map['cost_rsom'] != null ? double.tryParse(map['cost_rsom'].toString()) : null,

      // القراءة الخاصة بالحسابات المرتبطة (كما هي)
      accountNumber: map['account_number']?.toString(),
      accountName: map['acc_name']?.toString() ?? map['account_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customer_no': customerNo,
      'customer_name': customerName,
      'customer_foreign_name': customerForeignName,
      'phone_number': phoneNumber,
      'address': address,
      'email': email,
      'account_id': accountId,
      'control_account_id': controlAccountId,
      'source_id': sourceId,
      'last_updated': lastUpdated,
      'cost_data': costData,
      'cost_next': costNext,
      'cost_rsom': costRsom,
    };
  }

  SunCustomer copyWith({
    int? customerNo,
    String? customerName,
    String? customerForeignName,
    String? phoneNumber,
    String? address,
    String? email,
    String? accountId,
    String? controlAccountId,
    String? sourceId,
    String? lastUpdated,
    String? costData,
    double? costNext,
    double? costRsom,
    String? accountName,
    String? accountNumber,
    List<int>? currencyNos,
  }) {
    return SunCustomer(
      customerNo: customerNo ?? this.customerNo,
      customerName: customerName ?? this.customerName,
      customerForeignName: customerForeignName ?? this.customerForeignName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      email: email ?? this.email,
      accountId: accountId ?? this.accountId,
      controlAccountId: controlAccountId ?? this.controlAccountId,
      sourceId: sourceId ?? this.sourceId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      costData: costData ?? this.costData,
      costNext: costNext ?? this.costNext,
      costRsom: costRsom ?? this.costRsom,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
      currencyNos: currencyNos ?? this.currencyNos,
    );
  }
}