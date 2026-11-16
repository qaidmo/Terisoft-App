class GeneralLedgerPosting {
  final String id;
  final DateTime? createdAt;
  final String accountId;
  final String? accountName;
  final String? description;
  final double originalAmount;
  final int currencyId;
  final double exchangeRate;
  final double? debit;
  final double? credit;
  final DateTime transactionDate;
  final String? transactionId;
  final String? transactionType;
  final String? transactionRef;
  final String? beneficiaryName;
  final int? costCenterNo;
  final String? costCenterName;
  final String? entityName;
  // الحقل الجديد
  final String? controlAccountId;

  GeneralLedgerPosting({
    required this.id,
    this.createdAt,
    required this.accountId,
    this.accountName,
    this.description,
    required this.originalAmount,
    required this.currencyId,
    required this.exchangeRate,
    this.debit,
    this.credit,
    required this.transactionDate,
    this.transactionId,
    this.transactionType,
    this.transactionRef,
    this.beneficiaryName,
    this.costCenterNo,
    this.costCenterName,
    this.entityName,
    this.controlAccountId,
  });

  factory GeneralLedgerPosting.fromJson(Map<String, dynamic> json) {
    return GeneralLedgerPosting(
      id: json['id']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),

      // ممتاز: التعامل مع الحساب كنص لتجنب المشاكل السابقة
      accountId: json['account_id']?.toString() ?? '',
      accountName: json['account_name']?.toString(),

      description: json['description'] as String?,

      // تحويل آمن للأرقام العشرية
      originalAmount: double.tryParse(json['original_amount'].toString()) ?? 0.0,

      // تعديل هام: التحويل الآمن للأرقام الصحيحة لتجنب أي خطأ مستقبلي
      currencyId: int.tryParse(json['currency_id'].toString()) ?? 1,

      exchangeRate: double.tryParse(json['exchange_rate'].toString()) ?? 1.0,
      debit: json['debit'] != null ? double.tryParse(json['debit'].toString()) : null,
      credit: json['credit'] != null ? double.tryParse(json['credit'].toString()) : null,

      transactionDate: DateTime.parse(json['transaction_date'] as String),
      transactionId: json['transaction_id']?.toString(),
      transactionType: json['transaction_type'] as String?,
      transactionRef: json['transaction_ref'] as String?,
      beneficiaryName: json['beneficiary_name'] as String?,

      // تحويل آمن لمركز التكلفة
      costCenterNo: json['cost_center_no'] != null
          ? int.tryParse(json['cost_center_no'].toString())
          : null,

      costCenterName: json['cost_center_name']?.toString(),
      entityName: json['entity_name'] as String?,

      // الحقل الجديد
      controlAccountId: json['control_account_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty && int.tryParse(id) != null) 'id': int.parse(id),
      'created_at': createdAt?.toIso8601String(),
      'account_id': accountId,
      'description': description,
      'original_amount': originalAmount,
      'currency_id': currencyId,
      'exchange_rate': exchangeRate,
      'debit': debit,
      'credit': credit,
      'transaction_date': transactionDate.toIso8601String(),
      'transaction_id': transactionId != null ? int.tryParse(transactionId!) : null,
      'transaction_type': transactionType,
      'transaction_ref': transactionRef,
      'beneficiary_name': beneficiaryName,
      'cost_center_no': costCenterNo,
      'entity_name': entityName,
      'control_account_id': controlAccountId,
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': int.tryParse(id),
      'accountNo': accountId,
      'accountName': accountName,
      'description': description,
      'originalAmount': originalAmount,
      'currencyId': currencyId,
      'exchangeRate': exchangeRate,
      'debit': debit ?? 0.0,
      'credit': credit ?? 0.0,
      'costCenterNo': costCenterNo,
      'costCenterName': costCenterName,
      // الاسم المطابق للسيرفر C#
      'controlAccountId': controlAccountId,
    };
  }
}