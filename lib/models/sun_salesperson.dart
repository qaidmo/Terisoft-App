// lib/models/sun_salesperson.dart

class SunSalesperson {
  final int id;
  final int salespersonNo;
  final String salespersonName;
  final String? phoneNumber;
  final double? percentage;
  final bool commissionsDisabled;
  final String? accountId;
  final String? expenseAccountId;
  final DateTime createdAt;
  final String? sourceId;

  // 1. 👇 الإضافة الجديدة: حقل تاريخ التعديل
  final String? lastUpdated;

  SunSalesperson({
    required this.id,
    required this.salespersonNo,
    required this.salespersonName,
    this.phoneNumber,
    this.percentage,
    required this.commissionsDisabled,
    this.accountId,
    this.expenseAccountId,
    required this.createdAt,
    this.sourceId,
    // 2. 👇 الإضافة في الكونستركتور
    this.lastUpdated,
  });

  // 1. استقبال البيانات من الـ API (JSON)
  factory SunSalesperson.fromJson(Map<String, dynamic> json) {
    return SunSalesperson(
      id: json['id'] as int? ?? 0,
      salespersonNo: json['salesperson_no'] as int? ?? 0,
      salespersonName: json['salesperson_name'] as String? ?? 'N/A',
      phoneNumber: json['phone_number'] as String?,
      percentage: (json['percentage'] as num?)?.toDouble(),
      commissionsDisabled: json['commissions_disabled'] == true,
      accountId: json['account_id'] as String?,
      expenseAccountId: json['expense_account_id'] as String?,
      createdAt: json['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(json['created_at'] as String),
      sourceId: json['source_id']?.toString(),
      // 3. 👇 استقبال التاريخ من السيرفر
      lastUpdated: json['last_updated'] as String?,
    );
  }

  // 2. قراءة البيانات من SQLite (Map)
  factory SunSalesperson.fromMap(Map<String, dynamic> map) {
    return SunSalesperson(
      id: map['id'] as int,
      salespersonNo: map['salesperson_no'] as int,
      salespersonName: map['salesperson_name'] as String,
      phoneNumber: map['phone_number'] as String?,
      percentage: map['percentage'] as double?,
      commissionsDisabled: map['commissions_disabled'] == 1,
      accountId: map['account_id'] as String?,
      expenseAccountId: map['expense_account_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      sourceId: map['source_id'] as String?,
      // 4. 👇 قراءة التاريخ من قاعدة البيانات المحلية
      lastUpdated: map['last_updated'] as String?,
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'salesperson_no': salespersonNo,
      'salesperson_name': salespersonName,
      'phone_number': phoneNumber,
      'percentage': percentage,
      'commissions_disabled': commissionsDisabled ? 1 : 0,
      'account_id': accountId,
      'expense_account_id': expenseAccountId,
      'created_at': createdAt.toIso8601String(),
      'source_id': sourceId,
      // 5. 👇 حفظ التاريخ في العمود الجديد
      'last_updated': lastUpdated,
    };
  }
}