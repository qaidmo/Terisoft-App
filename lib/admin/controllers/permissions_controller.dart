import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'dart:convert';

class PermissionsController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  final RxBool isLoading = false.obs;
  final RxnInt selectedUserNo = RxnInt();

  final userNoController = TextEditingController();
  final userNameController = TextEditingController();
  final branchNameController = TextEditingController();
  final departmentNameController = TextEditingController();
  final boxNameController = TextEditingController();
  final storeNameController = TextEditingController();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final RxBool isAdmin = false.obs;
  final RxBool isAccountActive = true.obs;

  final RxBool passwordObscured = true.obs;

  final RxList<Map<String, dynamic>> usersList = <Map<String, dynamic>>[].obs;

  final RxList<Map<String, dynamic>> filteredUsers = <Map<String, dynamic>>[].obs;

  final userSearchController = TextEditingController();

  final RxMap<String, Map<String, bool>> currentPermissions = <String, Map<String, bool>>{}.obs;
  final List<Map<String, String>> allScreens = [
    {'display': 'شاشة بيع نقداً', 'name': 'CashSaleScreen'},
    {'display': 'شاشة بيع آجل', 'name': 'CreditSaleScreen'},
    {'display': 'شاشة بيع نقداً معلق', 'name': 'AbsoluteCashSaleScreen'},
    {'display': 'شاشة مردود البيع نقدا', 'name': 'CashSaleReturnScreen'},
    {'display': 'شاشة مردود البيع الاجل', 'name': 'CreditSaleReturnScreen'},
    {'display': 'شاشة مردود البيع المعلق', 'name': 'AbsoluteCashSaleReturnScreen'},
    {'display': 'شاشة سند قبض نقداً', 'name': 'ReceiptScreen'},
    {'display': 'شاشة سند صرف نقداً', 'name': 'CashPaymentVoucherScreen'},
    {'display': 'شاشة صفحة التقارير', 'name': 'ReportsScreen'},
    {'display': 'شاشة كشف حساب', 'name': 'AccountStatementScreen'},
    {'display': 'شاشة حركة المبيعات', 'name': 'SalesMovementScreen'},
    {'display': 'شاشة حركة العملاء', 'name': 'ClientsMovementScreen'},
    {'display': 'شاشة تقارير مراكز التكلفة', 'name': 'CostCenterScreen'},

    // تقرير حركة المبيعات (التقارير العامة)
    {'display': 'تقرير حركة المبيعات',   'name': 'SalesMovementNewScreen'},

    // تقارير الأصناف والمخزون
    {'display': 'تقرير حركة الأصناف',    'name': 'ItemMovementScreen'},
    {'display': 'تقرير هامش الربح',       'name': 'ProfitMarginScreen'},
    {'display': 'تقرير أرصدة الأصناف',   'name': 'ItemBalancesScreen'},

    // تقرير حركة الموردين (التقارير العامة)
    {'display': 'تقرير حركة الموردين',    'name': 'SupplierMovementScreen'},
  ];

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
    clearForm();
    userSearchController.addListener(() => filterUsers(userSearchController.text));
  }

  @override
  void onClose() {
    userNoController.dispose();
    userNameController.dispose();
    branchNameController.dispose();
    departmentNameController.dispose();
    boxNameController.dispose();
    storeNameController.dispose();
    userSearchController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  void clearForm() {
    isLoading.value = false;
    selectedUserNo.value = null;
    userNoController.clear();
    userNameController.clear();
    branchNameController.clear();
    departmentNameController.clear();
    boxNameController.clear();
    storeNameController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    isAdmin.value = false;
    isAccountActive.value = true;
    initializePermissionsMap();
  }

  Future<void> fetchInitialData() async {
    try {
      final responses = await Future.wait([
        _supabase.from('sun_users').select('user_no, user_name').order('user_no'),
      ]);
      usersList.assignAll(List<Map<String, dynamic>>.from(responses[0]));
      filteredUsers.assignAll(usersList);
    } catch (e) {
      _showMessage('خطأ في جلب قائمة المستخدمين: $e', isError: true);
    }
  }

  Future<void> saveChanges() async {
    if (selectedUserNo.value == null) {
      _showMessage('يرجى البحث عن مستخدم واختياره أولاً قبل الحفظ.', isError: true);
      return;
    }

    if (passwordController.text.isNotEmpty) {
      if (passwordController.text.length < 4) {
        _showMessage('كلمة السر يجب أن تكون 4 أحرف على الأقل', isError: true);
        return;
      }
      if (passwordController.text != confirmPasswordController.text) {
        _showMessage('كلمات السر غير متطابقة', isError: true);
        return;
      }
    }

    isLoading.value = true;
    try {
      String? finalPassword;
      if (passwordController.text.isNotEmpty) {
        final String originalPassword = passwordController.text.trim();
        final passwordBytes = utf8.encode(originalPassword);
        final base64Password = base64.encode(passwordBytes);
        final passwordLength = originalPassword.length.toString();
        final prefix = "${passwordLength}1";
        finalPassword = prefix + base64Password;
      }

      final userData = <String, dynamic>{
        'user_status': isAccountActive.value ? 'active' : 'inactive',
        if (finalPassword != null) 'password_hash': finalPassword,
        'modified_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('sun_users').update(userData).eq('user_no', selectedUserNo.value!);

      await _supabase.from('sun_permissions').delete().eq('user_no', selectedUserNo.value!);
      final List<Map<String, dynamic>> permissionsToInsert = [];
      currentPermissions.forEach((screenName, perms) {
        if (perms.values.any((v) => v == true)) {
          permissionsToInsert.add({
            'user_no': selectedUserNo.value!, 'screen_name': screenName,
            'can_access': perms['access']!, 'can_add': perms['add']!,
            'can_edit': perms['edit']!, 'can_search': perms['search']!,
            'can_print': perms['print']!,
            'can_change_price': perms['change_price']!,
          });
        }
      });

      if (permissionsToInsert.isNotEmpty) {
        await _supabase.from('sun_permissions').insert(permissionsToInsert);
      }

      _showMessage('تم حفظ التغييرات بنجاح', isError: false);
      clearForm();

    } catch (e) {
      _showMessage('حدث خطأ أثناء حفظ التغييرات: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadUserForEditing(int userNo) async {
    isLoading.value = true;
    try {
      final userResponse = await _supabase
          .from('sun_users')
          .select('*, sun_branches(branch_name), sun_departments(department_name), sun_boxes(box_name), sun_store(name_store)')
          .eq('user_no', userNo)
          .single();
      final permissionsResponse = await _supabase.from('sun_permissions').select('*').eq('user_no', userNo);

      selectedUserNo.value = userResponse['user_no'];
      userNoController.text = userResponse['user_no'].toString();
      userNameController.text = userResponse['user_name'];
      isAdmin.value = userResponse['user_type'] == 'admin';
      isAccountActive.value = userResponse['user_status'] == 'active';
      branchNameController.text = userResponse['sun_branches']?['branch_name'] ?? 'غير محدد';
      departmentNameController.text = userResponse['sun_departments']?['department_name'] ?? 'غير محدد';
      boxNameController.text = userResponse['sun_boxes']?['box_name'] ?? 'غير محدد';
      storeNameController.text = userResponse['sun_store']?['name_store'] ?? 'غير محدد';
      passwordController.clear();
      confirmPasswordController.clear();

      initializePermissionsMap();
      for (var p in permissionsResponse) {
        if (currentPermissions.containsKey(p['screen_name'])) {
          currentPermissions[p['screen_name']] = {
            'access': p['can_access'] ?? false, 'add': p['can_add'] ?? false,
            'edit': p['can_edit'] ?? false, 'search': p['can_search'] ?? false,
            'print': p['can_print'] ?? false,
            'change_price': p['can_change_price'] ?? false,
          };
        }
      }
      currentPermissions.refresh();

    } catch (e) {
      _showMessage('خطأ في تحميل بيانات المستخدم: $e', isError: true);
      clearForm();
    } finally {
      isLoading.value = false;
    }
  }

  void filterUsers(String query) {
    if (query.isEmpty) {
      filteredUsers.assignAll(usersList);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredUsers.assignAll(usersList.where((user) {
        return user['user_name'].toString().toLowerCase().contains(lowerCaseQuery);
      }).toList());
    }
  }

  void initializePermissionsMap() {
    currentPermissions.clear();
    for (var screen in allScreens) {
      currentPermissions[screen['name']!] = {
        'access': false, 'add': false, 'edit': false, 'search': false, 'print': false,
        'change_price': false
      };
    }
    currentPermissions.refresh();
  }

  void setAllPermissions(bool value) {
    for (var screenName in currentPermissions.keys) {
      currentPermissions[screenName]!['access'] = value;
      currentPermissions[screenName]!['add'] = value;
      currentPermissions[screenName]!['edit'] = value;
      currentPermissions[screenName]!['search'] = value;
      currentPermissions[screenName]!['print'] = value;
      currentPermissions[screenName]!['change_price'] = value;
    }
    currentPermissions.refresh();
  }

  void togglePasswordObscure() {
    passwordObscured.value = !passwordObscured.value;
  }

  void _showMessage(String message, {bool isError = false}) {
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }
}