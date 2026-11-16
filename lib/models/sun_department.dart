// lib/models/sun_department.dart

class SunDepartment {
  final int departmentId;
  final String departmentName;
  final String? sourceId; // 👈 مضاف للمزامنة وفصل المهام
  final DateTime? createdAt;

  const SunDepartment({
    required this.departmentId,
    required this.departmentName,
    this.sourceId,
    this.createdAt,
  });

  // 1. استقبال البيانات من الـ API (JSON)
  factory SunDepartment.fromJson(Map<String, dynamic> json) {
    return SunDepartment(
      departmentId: json['department_id'] as int? ?? 0,
      departmentName: json['department_name'] as String? ?? 'قسم غير محدد',
      sourceId: json['source_id']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }

  // 2. قراءة البيانات من SQLite (Map)
  factory SunDepartment.fromMap(Map<String, dynamic> map) {
    return SunDepartment(
      departmentId: map['department_id'] as int,
      departmentName: map['department_name'] as String,
      sourceId: map['source_id'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'department_id': departmentId,
      'department_name': departmentName,
      'source_id': sourceId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // (اختياري) تحويل لـ JSON لإرساله مستقبلاً
  Map<String, dynamic> toJson() => toMap();
}