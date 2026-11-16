// lib/models/sun_item_group.dart

class SunItemGroup {
  final String groupNo;
  final String groupName;
  final String? mainGroupNo;
  final String? sourceId;
  final int? groupLength;

  // 1. 👇 الإضافة الجديدة: حقل تاريخ التعديل
  final String? lastUpdated;

  SunItemGroup({
    required this.groupNo,
    required this.groupName,
    this.mainGroupNo,
    this.sourceId,
    this.groupLength,
    // 2. 👇 الإضافة في الكونستركتور
    this.lastUpdated,
  });

  // 1. استقبال البيانات من الـ API (JSON)
  factory SunItemGroup.fromJson(Map<String, dynamic> json) {
    return SunItemGroup(
      groupNo: json['group_no']?.toString() ?? '',
      groupName: json['group_name'] as String? ?? 'مجموعة غير معروفة',
      mainGroupNo: json['main_group_no']?.toString(),
      sourceId: json['source_id']?.toString(),
      groupLength: json['group_length'] != null ? int.tryParse(json['group_length'].toString()) : null,
      // 3. 👇 استقبال التاريخ من السيرفر
      lastUpdated: json['last_updated'] as String?,
    );
  }

  // 2. قراءة البيانات من SQLite (Map)
  factory SunItemGroup.fromMap(Map<String, dynamic> map) {
    return SunItemGroup(
      groupNo: map['group_no']?.toString() ?? '',
      groupName: map['group_name'] as String,
      mainGroupNo: map['main_group_no']?.toString(),
      sourceId: map['source_id'] as String?,
      groupLength: map['group_length'] as int?,
      // 4. 👇 قراءة التاريخ من قاعدة البيانات المحلية
      lastUpdated: map['last_updated'] as String?,
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'group_no': groupNo,
      'group_name': groupName,
      'main_group_no': mainGroupNo,
      'source_id': sourceId,
      // 5. 👇 حفظ التاريخ في العمود الجديد
      'last_updated': lastUpdated,
    };
  }
}