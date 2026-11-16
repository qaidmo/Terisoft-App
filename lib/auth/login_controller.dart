import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/database_helper.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/core/exceptions.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../services/lookups_service.dart.dart';
import '../repositories/auth_repository.dart';

class LoginController extends GetxController {
  final UserState _userState = Get.find<UserState>();
  final LookupsService _lookupsService = Get.find<LookupsService>();
  final AuthRepository _authRepository = AuthRepository();

  final GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController branchController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();

  /// Whether the typed-in user may switch branches (admin, or the server-side
  /// `UPRIVWINDOW[16]` flag synced onto the user row).
  final RxBool canSwitchBranch = false.obs;

  /// Branches available for selection (local `sun_branches`).
  final List<Map<String, dynamic>> branches = <Map<String, dynamic>>[];
  final Rxn<int> selectedBranchId = Rxn<int>();

  /// Departments loaded once for name resolution (local `sun_departments`).
  /// Mirrors [branches]; the department is fixed per UID (D1) and read-only.
  final List<Map<String, dynamic>> departments = <Map<String, dynamic>>[];

  final isLoading = false.obs;
  final obscurePassword = true.obs;

  final isLoadingYears = true.obs;
  final financialYears = <Map<String, dynamic>>[].obs;
  final selectedFinancialYearId = Rxn<int>();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final _secureStorage = const FlutterSecureStorage();
  final canCheckBiometrics = false.obs;
  final isBiometricEnabled = false.obs;

  static const String _kLastUsernameKey = 'last_username';
  static const String _kLastBranchKey = 'last_branch';
  static const String _kLastDepartmentKey = 'last_department';
  static const String _kLastBranchNameKey = 'last_branch_name';
  static const String _kLastDepartmentNameKey = 'last_department_name';

  static const String _kBiometricEnabledKey = 'biometric_enabled';
  static const String _kSecurePasswordKey = 'secure_password';

  final RxString loggedInBranchName = ''.obs;
  final RxString loggedInDepartmentName = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadLastLoginDetails();
    _fetchFinancialYears();
    _fetchBranches();
    _fetchDepartments();
    _checkBiometricsAndLoadPreference();
  }

  @override
  void onClose() {
    usernameController.dispose();
    passwordController.dispose();
    branchController.dispose();
    departmentController.dispose();
    super.onClose();
  }

  Future<void> _checkBiometricsAndLoadPreference() async {
    try {
      canCheckBiometrics.value = await _localAuth.canCheckBiometrics;
      if (canCheckBiometrics.value) {
        final prefs = await SharedPreferences.getInstance();
        isBiometricEnabled.value = prefs.getBool(_kBiometricEnabledKey) ?? false;
      }
    } on PlatformException catch (_) {
      canCheckBiometrics.value = false;
    }
  }

  Future<void> _fetchBranches() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> result =
          await db.query('sun_branches', orderBy: 'branch_id ASC');
      branches
        ..clear()
        ..addAll(result);

      // The lists land async; if an id was already restored (last-login
      // details) its name may still be unresolved. Re-resolve so the UI never
      // shows a blank name once the list is available.
      _rebindBranchName();
    } catch (_) {}
  }

  /// Sets the branch for this login and publishes both the id and the resolved
  /// name. Used by the screen's branch dropdown so the paired name field
  /// follows the selection without touching the read-only/override logic.
  void selectBranch(int? branchId) {
    selectedBranchId.value = branchId;
    if (branchId != null) {
      branchController.text = branchId.toString();
    }
    _rebindBranchName();
  }

  /// Re-resolves the branch name from the current selection. Safe to call any
  /// time: unknown ids resolve to an empty string rather than a stale name.
  void _rebindBranchName() {
    final branchId = selectedBranchId.value;
    loggedInBranchName.value = branchNameFor(branchId);
  }

  /// Resolves the department name for [departmentId] from the local list.
  /// Returns an empty string when unknown so the UI never shows a stale name.
  String departmentNameFor(int? departmentId) {
    if (departmentId == null) return '';
    final match = departments.firstWhereOrNull(
      (d) => int.tryParse(d['department_id'].toString()) == departmentId,
    );
    return match?['department_name']?.toString() ?? '';
  }

  /// Resolves the branch name for [branchId] from the local list.
  /// Returns an empty string when unknown so the UI never shows a stale name.
  String branchNameFor(int? branchId) {
    if (branchId == null) return '';
    final match = branches.firstWhereOrNull(
      (b) => int.tryParse(b['branch_id'].toString()) == branchId,
    );
    return match?['branch_name']?.toString() ?? '';
  }

  Future<void> _fetchDepartments() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> result =
          await db.query('sun_departments', orderBy: 'department_id ASC');
      departments
        ..clear()
        ..addAll(result);

      // Mirror the branches rebind: the department id may already be set when
      // the list arrives, so publish the name now that it can be resolved.
      _rebindDepartmentName();
    } catch (_) {}
  }

  /// Re-resolves the department name from the current department id.
  void _rebindDepartmentName() {
    final deptId = int.tryParse(departmentController.text.trim());
    loggedInDepartmentName.value = departmentNameFor(deptId);
  }

  /// Resolves the local user row for [username] and refreshes the derived login
  /// state: whether this user may switch branches (admin or the server-side
  /// `UPRIVWINDOW[16]` flag), the fixed department, and the default branch.
  /// Called as the user types / picks a user so the branch field can render
  /// enabled or read-only before submit.
  Future<void> refreshUserBranchState(String username) async {
    final trimmed = username.trim();
    canSwitchBranch.value = false;

    if (trimmed.isEmpty) {
      selectedBranchId.value = null;
      departmentController.clear();
      branchController.clear();
      loggedInDepartmentName.value = '';
      loggedInBranchName.value = '';
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> rows = await db.query(
        'sun_users',
        where: 'user_name = ?',
        whereArgs: [trimmed],
        limit: 1,
      );

      if (rows.isEmpty) {
        selectedBranchId.value = null;
        departmentController.clear();
        branchController.clear();
        loggedInDepartmentName.value = '';
        loggedInBranchName.value = '';
        return;
      }

      final row = rows.first;
      final bool isAdmin =
          (row['user_type'].toString().toLowerCase() == 'admin');
      final bool canChange = isAdmin || (row['can_change_branch'] == 1);
      canSwitchBranch.value = canChange;

      // Department is fixed per UID (D1) — always read from the row, both its
      // id and its name.
      final int userDepartment =
          int.tryParse(row['user_department'].toString()) ?? 0;
      departmentController.text = userDepartment.toString();
      loggedInDepartmentName.value = departmentNameFor(userDepartment);

      final int defaultBranch = int.tryParse(row['user_branch'].toString()) ?? 0;
      // Non-permitted users are pinned to their record's branch (read-only).
      // Permitted users default to it but may change it via the dropdown.
      selectedBranchId.value = defaultBranch;
      branchController.text = defaultBranch.toString();
      loggedInBranchName.value = branchNameFor(defaultBranch);
    } catch (_) {}
  }

  /// Re-validates only the branch-switching permission for [username] from the
  /// local `sun_users` row. Unlike [refreshUserBranchState] this method does
  /// **not** mutate [selectedBranchId], [branchController], or any name
  /// observable — a branch the user already selected in the dropdown is
  /// preserved across the call (D6-safe).
  Future<bool> _resolveCanSwitchBranch(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return false;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'sun_users',
        columns: ['user_type', 'can_change_branch'],
        where: 'user_name = ?',
        whereArgs: [trimmed],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final row = rows.first;
      final bool isAdmin = row['user_type'].toString().toLowerCase() == 'admin';
      final bool hasFlag = row['can_change_branch'] == 1;
      return isAdmin || hasFlag;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchFinancialYears() async {
    try {
      isLoadingYears.value = true;
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> result = await db.query('sun_years', orderBy: 'year_name DESC');

      financialYears.value = result.map((row) {
        return {
          'id': int.tryParse(row['id'].toString()) ?? 0,
          'year_name': row['year_name'].toString(),
        };
      }).toList();

      if (financialYears.isNotEmpty) {
        selectedFinancialYearId.value = financialYears.first['id'] as int?;
      }
    } catch (e) {
      financialYears.value = [{'id': 1, 'year_name': DateTime.now().year.toString()}];
      selectedFinancialYearId.value = 1;
    } finally {
      isLoadingYears.value = false;
    }
  }

  Future<void> _loadLastLoginDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUsername = prefs.getString(_kLastUsernameKey);
      final lastBranch = prefs.getInt(_kLastBranchKey);
      final lastDepartment = prefs.getInt(_kLastDepartmentKey);
      final lastBranchName = prefs.getString(_kLastBranchNameKey);
      final lastDepartmentName = prefs.getString(_kLastDepartmentNameKey);

      if (lastUsername != null) usernameController.text = lastUsername;
      if (lastBranch != null) {
        branchController.text = lastBranch.toString();
        selectedBranchId.value = lastBranch;
      }
      if (lastDepartment != null) departmentController.text = lastDepartment.toString();
      if (lastBranchName != null) loggedInBranchName.value = lastBranchName;
      if (lastDepartmentName != null) loggedInDepartmentName.value = lastDepartmentName;

      // Resolve the permission gate for the restored username.
      if (lastUsername != null) {
        await refreshUserBranchState(lastUsername);
      }
    } catch (_) {}
  }

  Future<void> _saveLastLoginDetails(String username, int branch, int department, String branchName, String departmentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastUsernameKey, username);
      await prefs.setInt(_kLastBranchKey, branch);
      await prefs.setInt(_kLastDepartmentKey, department);
      await prefs.setString(_kLastBranchNameKey, branchName);
      await prefs.setString(_kLastDepartmentNameKey, departmentName);
    } catch (_) {}
  }


  Future<void> handleBiometricLogin() async {
    if (!isBiometricEnabled.value) {
      AppSnackbar.showCustomSnackbar(
          'تنبيه',
          'الرجاء تفعيل الدخول السريع أولاً عن طريق تسجيل الدخول بكلمة المرور.',
          isError: true
      );
      return;
    }

    bool didAuthenticate = false;
    try {
      didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'الرجاء المصادقة لتسجيل الدخول',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      AppSnackbar.showCustomSnackbar(
          'خطأ',
          'حدث خطأ أثناء محاولة المصادقة: ${e.toString()}',
          isError: true
      );
      return;
    }

    if (didAuthenticate) {
      isLoading.value = true;
      try {
        final savedPassword = await _secureStorage.read(key: _kSecurePasswordKey);
        await _loadLastLoginDetails();

        if (savedPassword != null && savedPassword.isNotEmpty) {
          passwordController.text = savedPassword;
          await handleLogin();
        } else {
          isLoading.value = false;
          AppSnackbar.showCustomSnackbar(
              'تنبيه',
              'تغيرت بيانات الاعتماد أو لم يتم حفظها بشكل صحيح. يرجى الدخول بكلمة المرور مرة واحدة لتحديث البصمة.',
              isError: true
          );
        }
      } catch (e) {
        isLoading.value = false;
        AppSnackbar.showCustomSnackbar(
            'خطأ',
            'فشل استرداد بيانات الدخول الآمنة: ${e.toString()}',
            isError: true
        );
      }
    }
  }

  Future<void> handleLogin() async {
    if (!loginFormKey.currentState!.validate()) return;

    if (selectedFinancialYearId.value == null && financialYears.isNotEmpty) {
      AppSnackbar.showCustomSnackbar('خطأ', 'يرجى اختيار السنة المالية', isError: true);
      return;
    }

    isLoading.value = true;
    _lookupsService.clearLookups();

    try {
      final String enteredUsername = usernameController.text.trim();

      if (enteredUsername.isEmpty) {
        AppSnackbar.showCustomSnackbar('خطأ', 'يرجى إدخال اسم المستخدم', isError: true);
        isLoading.value = false;
        return;
      }

      final db = await DatabaseHelper.instance.database;

      // Single UID per user (D1): the lookup key is user_name only. Branch and
      // department are read from the row — department is fixed per UID.
      final List<Map<String, dynamic>> userResult = await db.query(
        'sun_users',
        where: 'user_name = ?',
        whereArgs: [enteredUsername],
        limit: 1,
      );

      if (userResult.isEmpty) {
        AppSnackbar.showCustomSnackbar('خطأ', 'المستخدم غير موجود', isError: true);
        isLoading.value = false;
        return;
      }

      final userRow = userResult.first;

      if (userRow['user_status'] != 'active') {
        AppSnackbar.showCustomSnackbar('خطأ', 'هذا الحساب غير نشط', isError: true);
        isLoading.value = false;
        return;
      }

      // Re-validate the branch-switching permission without resetting the
      // branch the user already selected in the dropdown (D6).
      // _resolveCanSwitchBranch reads only the permission columns — it does
      // NOT overwrite selectedBranchId, so the user's dropdown choice survives.
      final bool canChange = await _resolveCanSwitchBranch(enteredUsername);
      canSwitchBranch.value = canChange; // keep the observable in sync with UI
      final int defaultBranch = int.tryParse(userRow['user_branch'].toString()) ?? 0;
      final int selectedBranch = canChange ? (selectedBranchId.value ?? defaultBranch) : defaultBranch;

      final String? storedPasswordHash = userRow['password_hash'];
      final String enteredPassword = passwordController.text.trim();
      final base64Password = base64.encode(utf8.encode(enteredPassword));
      final String passwordLength = enteredPassword.length.toString();

      if (storedPasswordHash != null &&
          storedPasswordHash.endsWith(base64Password) &&
          storedPasswordHash.startsWith(passwordLength)) {

        String branchName = 'فرع غير معروف';
        try {
          final branchRes = await db.query('sun_branches',
              where: 'branch_id = ?', whereArgs: [defaultBranch]);
          if (branchRes.isNotEmpty) branchName = branchRes.first['branch_name'].toString();
        } catch (_) {}

        // The branch the user will actually work in this session.
        String selectedBranchName = branchName;
        if (selectedBranch != defaultBranch) {
          try {
            final branchRes = await db.query('sun_branches',
                where: 'branch_id = ?', whereArgs: [selectedBranch]);
            if (branchRes.isNotEmpty) selectedBranchName = branchRes.first['branch_name'].toString();
          } catch (_) {}
        }

        final int userDepartment = int.tryParse(userRow['user_department'].toString()) ?? 0;

        String departmentName = 'قسم غير معروف';
        try {
          final deptRes = await db.query('sun_departments',
              where: 'department_id = ?', whereArgs: [userRow['user_department']]);
          if (deptRes.isNotEmpty) departmentName = deptRes.first['department_name'].toString();
        } catch (_) {}

        int? boxNo = int.tryParse(userRow['box_no'].toString());
        String? boxName;
        if (boxNo != null) {
          final boxRes = await db.query('sun_boxes', where: 'box_no = ?', whereArgs: [boxNo]);
          if (boxRes.isNotEmpty) boxName = boxRes.first['box_name'].toString();
        }

        int? storeNo = int.tryParse(userRow['no_store'].toString());
        String? storeName;
        if (storeNo != null) {
          final storeRes = await db.query('sun_store', where: 'no_store = ?', whereArgs: [storeNo]);
          if (storeRes.isNotEmpty) storeName = storeRes.first['name_store'].toString();
        }

        int? currencyNo;
        String? currencySymbol;
        if (boxNo != null) {
          final boxCurRes = await db.query('sun_box_currencies',
              where: 'box_no = ?', whereArgs: [boxNo]);
          if (boxCurRes.isNotEmpty) {
            currencyNo = int.tryParse(boxCurRes.first['currency_id'].toString());
            if (currencyNo != null) {
              final curRes = await db.query('sun_currencies', where: 'currency_no = ?', whereArgs: [currencyNo]);
              if (curRes.isNotEmpty) currencySymbol = curRes.first['currency_symbol'].toString();
            }
          }
        }

        final int userNo = int.tryParse(userRow['user_no'].toString()) ?? 0;
        final bondBoxesData = await _authRepository.fetchUserBondBoxes(userNo);

        final receiptBoxData = bondBoxesData['receipt_box'];
        final paymentBoxData = bondBoxesData['payment_box'];

        int? receiptBoxNo = receiptBoxData != null ? receiptBoxData['box_no'] : null;
        String? receiptBoxName = receiptBoxData != null ? receiptBoxData['box_name'] : null;
        int? receiptBoxCurrencyNo = receiptBoxData != null ? receiptBoxData['currency_no'] : null;
        String? receiptBoxCurrencySymbol = receiptBoxData != null ? receiptBoxData['currency_symbol'] : null;

        int? paymentBoxNo = paymentBoxData != null ? paymentBoxData['box_no'] : null;
        String? paymentBoxName = paymentBoxData != null ? paymentBoxData['box_name'] : null;
        int? paymentBoxCurrencyNo = paymentBoxData != null ? paymentBoxData['currency_no'] : null;
        String? paymentBoxCurrencySymbol = paymentBoxData != null ? paymentBoxData['currency_symbol'] : null;

        Map<String, Map<String, bool>> userPermissions = {};
        final permRes = await db.query('sun_permissions',
            where: 'user_no = ?', whereArgs: [userRow['user_no']]);

        for (var perm in permRes) {
          userPermissions[perm['screen_name'].toString()] = {
            'access': perm['can_access'] == 1,
            'add': perm['can_add'] == 1,
            'edit': perm['can_edit'] == 1,
            'search': perm['can_search'] == 1,
            'print': perm['can_print'] == 1,
            'change_price': perm['can_change_price'] == 1,
          };
        }

        final selectedYearName = financialYears
            .firstWhere((year) => year['id'] == selectedFinancialYearId.value, orElse: () => {'year_name': ''})['year_name']
            .toString();

        _userState.setUser(
            userId: userRow['id'].toString(),
            userNumber: userNo,
            userBranch: defaultBranch,
            userDepartment: userDepartment,
            userType: userRow['user_type'].toString(),
            lastTransactionSequence: 0,
            userName: userRow['user_name'].toString(),
            userGroup: userRow['user_group'].toString(),
            canChangeBranch: canChange,
            screenPermissions: userPermissions,
            userBranchName: branchName,
            userDepartmentName: departmentName,
            userBoxNo: boxNo,
            userBoxName: boxName,
            userStoreNo: storeNo,
            userStoreName: storeName,
            userBoxCurrencyNo: currencyNo,
            userBoxCurrencySymbol: currencySymbol,
            receiptBoxNo: receiptBoxNo,
            receiptBoxName: receiptBoxName,
            receiptBoxCurrencyNo: receiptBoxCurrencyNo,
            receiptBoxCurrencySymbol: receiptBoxCurrencySymbol,
            paymentBoxNo: paymentBoxNo,
            paymentBoxName: paymentBoxName,
            paymentBoxCurrencyNo: paymentBoxCurrencyNo,
            paymentBoxCurrencySymbol: paymentBoxCurrencySymbol,
            financialYearId: selectedFinancialYearId.value!,
            financialYearName: selectedYearName
        );

        // Apply the branch override AFTER setUser (which seeds the defaults).
        // Resolves the store that belongs to the selected branch; a zero-store
        // branch blocks the login rather than leaving a null store (D7).
        if (selectedBranch != defaultBranch) {
          try {
            await _userState.applyBranchOverride(selectedBranch);
          } on BlockedBranchException catch (e) {
            _userState.clearUser();
            AppSnackbar.showCustomSnackbar(
                'لا يمكن الدخول', e.message, isError: true);
            isLoading.value = false;
            return;
          } catch (e) {
            _userState.clearUser();
            AppSnackbar.showCustomSnackbar(
                'خطأ', 'فشل تحديد الفرع: ${e.toString()}', isError: true);
            isLoading.value = false;
            return;
          }
        }

        if (isBiometricEnabled.value) {
          await _secureStorage.write(
              key: _kSecurePasswordKey,
              value: enteredPassword
          );
        }


        await _lookupsService.loadAllLookupData();
        await _saveLastLoginDetails(
          enteredUsername,
          selectedBranch,
          userDepartment,
          selectedBranch != defaultBranch ? selectedBranchName : branchName,
          departmentName,
        );

        Get.offAllNamed('/home');

      } else {
        AppSnackbar.showCustomSnackbar('خطأ', 'بيانات الدخول غير صحيحة', isError: true);
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ غير متوقع: ${e.toString()}', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> showUserSelectionSheet() async {
    isLoading.value = true;
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> users = await db.query('sun_users');
      isLoading.value = false;

      Get.bottomSheet(
        DraggableScrollableSheet(
          initialChildSize: 0.5, minChildSize: 0.25, maxChildSize: 0.9, expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('اختر المستخدم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final bool isActive = user['user_status'] == 'active';
                      return ListTile(
                        leading: Icon(
                          isActive ? Icons.person : Icons.person_off,
                          color: isActive ? Theme.of(context).primaryColor : Colors.grey,
                        ),
                        title: Text(
                          user['user_name'] ?? '',
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.grey,
                            decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text('الفرع: ${user['user_branch']}, القسم: ${user['user_department']}'),
                        trailing: isActive
                            ? null
                            : const Text('غير نشط', style: TextStyle(color: Colors.red)),
                        onTap: () {
                          usernameController.text = user['user_name'] ?? '';
                          passwordController.clear();
                          Navigator.of(context).pop();
                          // Resolve the permission gate + fixed department for
                          // the picked user (branch may render read-only).
                          refreshUserBranchState(user['user_name'] ?? '');
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        backgroundColor: Colors.white, isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      );
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تحميل قائمة المستخدمين', isError: true);
      isLoading.value = false;
    }
  }

  Future<void> handleFullSync() async {
    final prefs = await SharedPreferences.getInstance();
    final serverAddress = prefs.getString('server_address');

    if (serverAddress == null || serverAddress.isEmpty) {
      AppSnackbar.showCustomSnackbar(
        'تنبيه',
        'لم يتم العثور على إعدادات اتصال محفوظة. يرجى إعداد الاتصال بالسيرفر أولاً.',
        isError: true,
      );
      Get.toNamed('/connection-settings');
      return;
    }

    final context = Get.context;
    if (context == null) return;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 15),
            Icon(
              Icons.sync_rounded,
              size: 60,
              color: Theme.of(context).primaryColor.withAlpha(204),
            ),
            const SizedBox(height: 20),
            Text(
              'إعادة المزامنة الكلية',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'هل تريد إعادة مزامنة جميع البيانات من السيرفر؟ هذا قد يستغرق بعض الوقت.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تأكد من مزامنة جميع الفواتير والسندات قبل المتابعة، حيث قد تفقد الفواتير التي لم يتم رفعها إلى السيرفر.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        actions: [
          OutlinedButton(
            onPressed: () => Get.back(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.offAllNamed('/sync-data');
            },
            style: ElevatedButton.styleFrom(
              elevation: 2,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }
}