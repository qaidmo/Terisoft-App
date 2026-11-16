// lib/models/full_user_data.dart

import 'sun_user.dart';
import 'sun_branch.dart';
import 'sun_department.dart';
import 'sun_permissions.dart';
import 'sun_box.dart';
import 'sun_store.dart';

// هذا الكلاس يجمع كل بيانات المستخدم التي نحتاجها بعد تسجيل الدخول
class FullUserData {
  final SunUser user;
  final SunBranch? branch;
  final SunDepartment? department;
  final SunBox? box;
  final SunStore? store;
  final List<SunPermissions> permissions;
  final int? userBoxCurrencyNo;
  final String? userBoxCurrencySymbol;

  FullUserData({
    required this.user,
    this.branch,
    this.department,
    this.box,
    this.store,
    this.permissions = const [],
    this.userBoxCurrencyNo,
    this.userBoxCurrencySymbol,
  });

  factory FullUserData.fromJson(Map<String, dynamic> json) {
    final SunUser userData = SunUser.fromJson(json);

    final SunBranch? branchData =
    json['sun_branches'] != null && json['sun_branches'] is Map
        ? SunBranch.fromJson(json['sun_branches'])
        : null;

    final SunDepartment? departmentData =
    json['sun_departments'] != null && json['sun_departments'] is Map
        ? SunDepartment.fromJson(json['sun_departments'])
        : null;

    final SunBox? boxData = json['sun_boxes'] != null && json['sun_boxes'] is Map
        ? SunBox.fromJson(json['sun_boxes'])
        : null;

    final SunStore? storeData =
    json['sun_store'] != null && json['sun_store'] is Map
        ? SunStore.fromJson(json['sun_store'])
        : null;

    final List<SunPermissions> permissionsList =
    (json['sun_permissions'] as List<dynamic>? ?? [])
        .map((perm) => SunPermissions.fromJson(perm as Map<String, dynamic>))
        .toList();

    int? currencyNo;
    String? currencySymbol;
    final boxCurrenciesList =
    json['sun_boxes']?['sun_box_currencies'] as List<dynamic>?;

    if (boxCurrenciesList != null && boxCurrenciesList.isNotEmpty) {
      final firstCurrencyLink = boxCurrenciesList.first as Map<String, dynamic>;
      final currencyData =
      firstCurrencyLink['sun_currencies'] as Map<String, dynamic>?;
      currencyNo = currencyData?['currency_no'] as int?;
      currencySymbol = currencyData?['currency_symbol'] as String?;
    }

    return FullUserData(
      user: userData,
      branch: branchData,
      department: departmentData,
      box: boxData,
      store: storeData,
      permissions: permissionsList,
      userBoxCurrencyNo: currencyNo,
      userBoxCurrencySymbol: currencySymbol,
    );
  }
}