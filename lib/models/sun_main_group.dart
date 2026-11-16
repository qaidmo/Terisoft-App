// lib/models/sun_main_group.dart

class SunMainGroup {
  final String mainGroupNo;
  final String mainGroupName;
  final String? sourceId;

  // 1. 👇 الإضافة الجديدة: حقل تاريخ التعديل
  final String? lastUpdated;

  SunMainGroup({
    required this.mainGroupNo,
    required this.mainGroupName,
    this.sourceId,
    // 2. 👇 الإضافة في الكونستركتور
    this.lastUpdated,
  });

  factory SunMainGroup.fromJson(Map<String, dynamic> json) {
    return SunMainGroup(
      mainGroupNo: json['main_group_no']?.toString() ?? '',
      mainGroupName: json['main_group_name'] as String? ?? 'N/A',
      sourceId: json['source_id']?.toString(),
      // 3. 👇 استقبال التاريخ من السيرفر
      lastUpdated: json['last_updated'] as String?,
    );
  }

  factory SunMainGroup.fromMap(Map<String, dynamic> map) {
    return SunMainGroup(
      mainGroupNo: map['main_group_no']?.toString() ?? '',
      mainGroupName: map['main_group_name'] as String,
      sourceId: map['source_id'] as String?,
      // 4. 👇 قراءة التاريخ من قاعدة البيانات المحلية
      lastUpdated: map['last_updated'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'main_group_no': mainGroupNo,
      'main_group_name': mainGroupName,
      'source_id': sourceId,
      // 5. 👇 حفظ التاريخ في العمود الجديد
      'last_updated': lastUpdated,
    };
  }
}