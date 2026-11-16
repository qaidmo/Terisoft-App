// lib/models/sun_permissions.dart

class SunPermissions {
  final int? permissionId;
  final int? userNo;
  final String screenName;

  final bool canAccess;
  final bool canAdd;
  final bool canEdit;
  final bool canSearch;
  final bool canPrint;
  final bool canChangePrice;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  SunPermissions({
    this.permissionId,
    this.userNo,
    required this.screenName,
    required this.canAccess,
    required this.canAdd,
    required this.canEdit,
    required this.canSearch,
    required this.canPrint,
    required this.canChangePrice,
    this.createdAt,
    this.updatedAt,
  });

  factory SunPermissions.fromJson(Map<String, dynamic> json) {
    return SunPermissions(
      permissionId: json['permission_id'] != null ? json['permission_id'] as int : null,
      userNo: json['user_no'] as int?,
      screenName: json['screen_name'] as String,
      canAccess: json['can_access'] as bool? ?? false,
      canAdd: json['can_add'] as bool? ?? false,
      canEdit: json['can_edit'] as bool? ?? false,
      canSearch: json['can_search'] as bool? ?? false,
      canPrint: json['can_print'] as bool? ?? false,
      canChangePrice: json['can_change_price'] as bool? ?? false,

      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.tryParse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (permissionId != null) 'permission_id': permissionId,
      'user_no': userNo,
      'screen_name': screenName,
      'can_access': canAccess ? 1 : 0,
      'can_add': canAdd ? 1 : 0,
      'can_edit': canEdit ? 1 : 0,
      'can_search': canSearch ? 1 : 0,
      'can_print': canPrint ? 1 : 0,
      'can_change_price': canChangePrice ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}