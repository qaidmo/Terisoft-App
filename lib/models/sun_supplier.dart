// lib/models/sun_supplier.dart

class SunSupplier {
  final int supplierNo;
  final String supplierName;
  final String? supplierForeignName;
  final String? phoneNumber;
  final String? address;
  final String? email;
  final String? accountId;
  final String? controlAccountId;
  final String? sourceId;
  final String? lastUpdated;

  String? accountName;
  String? accountNumber;
  List<int> currencyNos;

  SunSupplier({
    required this.supplierNo,
    required this.supplierName,
    this.supplierForeignName,
    this.phoneNumber,
    this.address,
    this.email,
    this.accountId,
    this.controlAccountId,
    this.sourceId,
    this.lastUpdated,
    this.accountName,
    this.accountNumber,
    this.currencyNos = const [],
  });

  factory SunSupplier.fromJson(Map<String, dynamic> json) {
    return SunSupplier(
      supplierNo: json['supplier_no'] as int,
      supplierName: json['supplier_name'] as String? ?? 'N/A',
      supplierForeignName: json['supplier_foreign_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      address: json['address'] as String?,
      email: json['email'] as String?,
      accountId: json['account_id']?.toString(),
      controlAccountId: json['control_account_id']?.toString(),
      sourceId: json['source_id']?.toString(),
      lastUpdated: json['last_updated'] as String?,
    );
  }

  factory SunSupplier.fromMap(Map<String, dynamic> map) {
    return SunSupplier(
      supplierNo: map['supplier_no'] as int,
      supplierName: map['supplier_name'] as String,
      supplierForeignName: map['supplier_foreign_name'] as String?,
      phoneNumber: map['phone_number'] as String?,
      address: map['address'] as String?,
      email: map['email'] as String?,
      accountId: map['account_id']?.toString(),
      controlAccountId: map['control_account_id']?.toString(),
      sourceId: map['source_id']?.toString(),
      lastUpdated: map['last_updated'] as String?,

      accountNumber: map['account_number']?.toString(),
      accountName: map['acc_name']?.toString() ?? map['account_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplier_no': supplierNo,
      'supplier_name': supplierName,
      'supplier_foreign_name': supplierForeignName,
      'phone_number': phoneNumber,
      'address': address,
      'email': email,
      'account_id': accountId,
      'control_account_id': controlAccountId,
      'source_id': sourceId,
      'last_updated': lastUpdated,
    };
  }
}
