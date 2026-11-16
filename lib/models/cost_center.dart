// lib/models/cost_center.dart

class CostCenter {
  final int centerNo;
  final String centerName;
  final String? sourceId;

  // 1. 👇 الإضافة الجديدة
  final String? lastUpdated;

  CostCenter({
    required this.centerNo,
    required this.centerName,
    this.sourceId,
    // 2. 👇 الإضافة في الكونستركتور
    this.lastUpdated,
  });

  // 1. استقبال البيانات من الـ API (JSON)
  factory CostCenter.fromJson(Map<String, dynamic> json) {
    return CostCenter(
      centerNo: json['center_no'] as int? ?? json['cost_center_no'] as int? ?? 0,
      centerName: json['center_name'] as String? ?? 'مركز غير محدد',
      sourceId: json['source_id']?.toString(),
      // 3. 👇 استقبال التاريخ من السيرفر
      lastUpdated: json['last_updated'] as String?,
    );
  }

  // 2. قراءة البيانات من SQLite (Map)
  factory CostCenter.fromMap(Map<String, dynamic> map) {
    return CostCenter(
      centerNo: map['center_no'] as int,
      centerName: map['center_name'] as String,
      sourceId: map['source_id'] as String?,
      // 4. 👇 قراءة التاريخ من قاعدة البيانات المحلية
      lastUpdated: map['last_updated'] as String?,
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'center_no': centerNo,
      'center_name': centerName,
      'source_id': sourceId,
      // 5. 👇 حفظ التاريخ في العمود الجديد
      'last_updated': lastUpdated,
    };
  }
}