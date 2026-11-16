// lib/models/sun_branch.dart

class SunBranch {
  final int branchId;
  final String branchName;
  final String? sourceId; // 👈 مضاف للمزامنة وفصل المهام
  final DateTime? createdAt;

  const SunBranch({
    required this.branchId,
    required this.branchName,
    this.sourceId,
    this.createdAt,
  });

  // 1. استقبال البيانات من الـ API (JSON)
  factory SunBranch.fromJson(Map<String, dynamic> json) {
    return SunBranch(
      branchId: json['branch_id'] as int? ?? 0,
      branchName: json['branch_name'] as String? ?? 'فرع غير محدد',
      sourceId: json['source_id']?.toString(), // تحويل آمن لنص
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }

  // 2. قراءة البيانات من SQLite (Map)
  factory SunBranch.fromMap(Map<String, dynamic> map) {
    return SunBranch(
      branchId: map['branch_id'] as int,
      branchName: map['branch_name'] as String,
      sourceId: map['source_id'] as String?,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'branch_id': branchId,
      'branch_name': branchName,
      'source_id': sourceId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  // تحويل لـ JSON (اختياري لاستخدامات الـ API)
  Map<String, dynamic> toJson() => toMap();
}