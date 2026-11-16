// lib/models/sun_collector.dart

class SunCollector {
  final int id;
  final int collectorNo;
  final String collectorName;
  final String? phoneNumber;
  final String? accountId;
  final int? branchId;
  final String? sourceId;
  final DateTime? createdAt;

  // 1. 👇 الإضافة الجديدة
  final String? lastUpdated;

  SunCollector({
    required this.id,
    required this.collectorNo,
    required this.collectorName,
    this.phoneNumber,
    this.accountId,
    this.branchId,
    this.sourceId,
    this.createdAt,
    // 2. 👇 الإضافة في الكونستركتور
    this.lastUpdated,
  });

  // 1. استقبال البيانات من الـ API (JSON)
  factory SunCollector.fromJson(Map<String, dynamic> json) {
    return SunCollector(
      id: json['id'] as int? ?? 0,
      collectorNo: json['collector_no'] as int? ?? 0,
      collectorName: json['collector_name'] as String? ?? 'محصل غير معروف',
      phoneNumber: json['phone_number'] as String?,
      accountId: json['account_id'] as String?,
      branchId: json['branch_id'] as int?,
      sourceId: json['source_id']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
      // 3. 👇 استقبال التاريخ من السيرفر
      lastUpdated: json['last_updated'] as String?,
    );
  }

  // 2. قراءة البيانات من SQLite (Map)
  factory SunCollector.fromMap(Map<String, dynamic> map) {
    return SunCollector(
      id: map['id'] as int,
      collectorNo: map['collector_no'] as int,
      collectorName: map['collector_name'] as String,
      phoneNumber: map['phone_number'] as String?,
      accountId: map['account_id'] as String?,
      branchId: map['branch_id'] as int?,
      sourceId: map['source_id'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
      // 4. 👇 قراءة التاريخ من قاعدة البيانات المحلية
      lastUpdated: map['last_updated'] as String?,
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'collector_no': collectorNo,
      'collector_name': collectorName,
      'phone_number': phoneNumber,
      'account_id': accountId,
      'branch_id': branchId,
      'source_id': sourceId,
      'created_at': createdAt?.toIso8601String(),
      // 5. 👇 حفظ التاريخ في العمود الجديد
      'last_updated': lastUpdated,
    };
  }
}