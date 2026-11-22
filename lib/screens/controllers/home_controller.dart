import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/menu_item.dart';
import '../../repositories/auth_repository.dart';
import '../../services/lookups_service.dart.dart';
import '../../services/report_pre_sync_service.dart';
import '../../user_state.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/trial_period_manager.dart';
import '../../views/screens/restaurant_pos_screen.dart';

class HomeController extends GetxController {
  final UserState userState = Get.find<UserState>();
  final AuthRepository _authRepository = AuthRepository();
  final LookupsService _lookupsService = Get.find<LookupsService>();
  final ReportPreSyncService reportPreSyncService =
      Get.isRegistered<ReportPreSyncService>()
          ? Get.find<ReportPreSyncService>()
          : Get.put(ReportPreSyncService());

  final companyName = ' '.obs;
  final isLicensed = false.obs;
  final isLoading = false.obs;
  final activationError = ''.obs;

  // Biometric state
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _secureStorage = const FlutterSecureStorage();
  static const String _kBiometricEnabledKey = 'biometric_enabled';
  static const String _kSecurePasswordKey = 'secure_password';
  final isBiometricEnabled = false.obs;
  final canCheckBiometrics = false.obs;

  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final isPasswordObscured = true.obs;

  final Map<String, String> screenKeyToCharMap = {
    'CashSaleScreen': 'ن',
    'CreditSaleScreen': 'ج',
    'AbsoluteCashSaleScreen': 'م',
    'ReceiptScreen': 'ق',
    'CashPaymentVoucherScreen': 'ص',
    'CashSaleReturnScreen': 'رن',
    'CreditSaleReturnScreen': 'رج',
    'AbsoluteCashSaleReturnScreen': 'رم',
    'StationCollectionScreen': 'ت',
    'InventoryCountScreen': 'م ض',
    'RestaurantPosScreen': '801',
  };

  final List<MenuItem> menuItems = const [
    MenuItem(title: 'بيع نقداً', icon: Icons.shopping_cart_checkout_rounded, screenNameKey: 'CashSaleScreen', color: Colors.green),
    MenuItem(title: 'مردود بيع نقدي', icon: Icons.assignment_return_rounded, screenNameKey: 'CashSaleReturnScreen', color: Colors.redAccent),
    MenuItem(title: 'بيع أجل', icon: Icons.handshake_rounded, screenNameKey: 'CreditSaleScreen', color: Colors.teal),
    MenuItem(title: 'مردود بيع آجل', icon: Icons.history_toggle_off_rounded, screenNameKey: 'CreditSaleReturnScreen', color: Colors.deepOrange),
    MenuItem(title: 'بيع نقداً معلق', icon: Icons.pause_circle_filled_rounded, screenNameKey: 'AbsoluteCashSaleScreen', color: Colors.amber),
    MenuItem(title: 'مردود بيع معلق', icon: Icons.restore_page_rounded, screenNameKey: 'AbsoluteCashSaleReturnScreen', color: Colors.deepOrangeAccent),
    MenuItem(title: 'سند قبض نقداً', icon: Icons.price_check_rounded, screenNameKey: 'ReceiptScreen', color: Colors.lightBlue),
    MenuItem(title: 'سند صرف نقداً', icon: Icons.outbox_rounded, screenNameKey: 'CashPaymentVoucherScreen', color: Colors.indigo),
    MenuItem(title: 'كاشير المطعم', icon: Icons.dining_rounded, screenNameKey: 'RestaurantPosScreen', color: Colors.orange),
    MenuItem(title: 'فاتورة بيع المحطات', icon: Icons.ev_station_rounded, screenNameKey: 'StationCollectionScreen', color: Colors.blueGrey),
    MenuItem(title: 'محضر جرد', icon: Icons.inventory_2_rounded, screenNameKey: 'InventoryCountScreen', color: Colors.brown),
    MenuItem(title: 'التقارير', icon: Icons.analytics_rounded, screenNameKey: 'ReportsScreen', color: Colors.purple),
  ];

  @override
  void onInit() {
    super.onInit();
    _loadCompanyName();
    _checkConnection();
    _checkLicenseStatus();
    _loadBiometricState();
    _triggerInitialOfflineSync();
  }

  Future<void> _triggerInitialOfflineSync() async {
    String year = userState.safeFinancialYearName;
    if (year == 'غير محددة' || year.isEmpty) {
      year = DateTime.now().year.toString();
    }
    // للأدمن: branchId = null لمزامنة كافة الفروع النشطة و departmentId = null لكافة الأقسام
    final int? branchId = userState.isAdmin
        ? null
        : (userState.safeUserBranch > 0 ? userState.safeUserBranch : null);
    final int? departmentId = userState.isAdmin
        ? null
        : (userState.safeUserDepartment > 0
            ? userState.safeUserDepartment
            : null);

    await reportPreSyncService.runInitialOfflineSyncIfNeeded(
      year: year,
      branchId: branchId,
      departmentId: departmentId,
    );
  }

  @override
  void onClose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }

  Future<void> _loadCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    companyName.value = prefs.getString('saved_company_name') ?? ' ';
  }

  Future<void> _checkConnection() async {
    try {
      await _authRepository.checkDatabaseConnection();
    } catch (e) {
      AppSnackbar.showCustomSnackbar(
          'خطأ في الاتصال', 'فشل الاتصال بقاعدة البيانات: ${e.toString()}', isError: true);
    }
  }

  Future<void> _checkLicenseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    isLicensed.value = prefs.getBool('is_licensed') ?? false;
  }

  Future<void> _loadBiometricState() async {
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

  Future<void> showFingerprintActivationDialog() async {
    if (!canCheckBiometrics.value) {
      AppSnackbar.showCustomSnackbar(
          'غير مدعوم',
          'جهازك لا يدعم تسجيل الدخول بالبصمة.',
          isError: true);
      return;
    }

    final passwordTec = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final obscure = true.obs;
    final isActivating = false.obs; // Local state isolated from the shared isLoading

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, color: Color.fromARGB(255, 1, 90, 163), size: 28),
            SizedBox(width: 10),
            Text('تفعيل الدخول بالبصمة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أدخل كلمة المرور الحالية لتفعيل الدخول السريع بالبصمة.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Obx(() => TextFormField(
                controller: passwordTec,
                obscureText: obscure.value,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure.value ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => obscure.value = !obscure.value,
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'كلمة المرور مطلوبة' : null,
              )),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        actions: [
          OutlinedButton(
            onPressed: () => Get.back(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('إلغاء'),
          ),
          Obx(() => ElevatedButton(
            onPressed: isActivating.value ? null : () async {
              if (!formKey.currentState!.validate()) return;
              isActivating.value = true;
              try {
                final enteredPassword = passwordTec.text.trim();
                final base64Password = base64.encode(utf8.encode(enteredPassword));
                final passwordLength = enteredPassword.length.toString();
                final storedHash = await _authRepository.fetchUserPasswordHash(userState.safeUserNo);
                final matches = storedHash != null &&
                    storedHash.endsWith(base64Password) &&
                    storedHash.startsWith(passwordLength);
                if (matches) {
                  await _secureStorage.write(key: _kSecurePasswordKey, value: enteredPassword);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_kBiometricEnabledKey, true);
                  isBiometricEnabled.value = true;
                  Get.back();
                  AppSnackbar.showCustomSnackbar('نجاح', 'تم تفعيل الدخول السريع بالبصمة بنجاح.');
                } else {
                  AppSnackbar.showCustomSnackbar('خطأ', 'كلمة المرور غير صحيحة.', isError: true);
                }
              } catch (e) {
                AppSnackbar.showCustomSnackbar('خطأ', 'فشل التحقق: ${e.toString()}', isError: true);
              } finally {
                isActivating.value = false;
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 1, 90, 163),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: isActivating.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('تفعيل'),
          )),
        ],
      ),
    );
  }

  Future<void> disableFingerprint() async {
    try {
      await _secureStorage.delete(key: _kSecurePasswordKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBiometricEnabledKey, false);
      isBiometricEnabled.value = false;
      AppSnackbar.showCustomSnackbar('تم', 'تم تعطيل الدخول بالبصمة.');
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تعطيل البصمة: ${e.toString()}', isError: true);
    }
  }

  void onLicenseIconTap() {
    showActivationDialog();
  }

  void showActivationDialog() {
    final TextEditingController codeController = TextEditingController();
    activationError.value = '';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Obx(() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Color.fromARGB(255, 201, 180, 56),
                child: Icon(Icons.vpn_key, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 20),
              const Text(
                'ترخيص التطبيق',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'يرجى إدخال كود التفعيل لتنشيط نسختك.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: codeController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'كود التفعيل',
                  errorText: activationError.value.isEmpty ? null : activationError.value,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isLoading.value ? null : () {
                  _handleActivation(codeController.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 1, 90, 163),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading.value
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('تفعيــل', style: TextStyle(fontSize: 16)),
              ),
            ],
          )),
        ),
      ),
      barrierDismissible: !isLoading.value,
    );
  }

  Future<void> _handleActivation(String activationCode) async {
    activationError.value = '';
    if (activationCode.trim().isEmpty) {
      activationError.value = 'يرجى إدخال كود التفعيل.';
      return;
    }

    final deviceInfo = DeviceInfoPlugin();
    String deviceId, deviceName;
    if (GetPlatform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
      deviceName = androidInfo.model;
    } else if (GetPlatform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? 'unknown_ios';
      deviceName = iosInfo.name;
    } else {
      deviceId = 'unknown_platform';
      deviceName = 'unknown_platform';
    }

    const fixedPassword = "123456";
    final url = Uri.parse(
        'https://www.terasoftit.net/mobile/check.php?pwd=$fixedPassword&key=$activationCode&deviceid=$deviceName&macaddress=$deviceId'
    );

    try {
      isLoading.value = true;
      final response = await http.get(url);

      if (response.statusCode == 200 && response.body.trim().startsWith('success')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_licensed', true);
        isLicensed.value = true;

        Get.back();

        String successMessage = response.body.trim().contains('new')
            ? 'تم تفعيل التطبيق بنجاح!'
            : 'تم تحديث الترخيص بنجاح!';
        AppSnackbar.showCustomSnackbar('نجاح', successMessage);

      } else {
        if (response.body.trim() == 'Error:full useage') {
          activationError.value = 'هذا الترخيص مستخدم بالكامل ووصل للحد الأقصى.';
        } else {
          activationError.value = 'كود التفعيل غير صحيح أو حدث خطأ.';
        }
      }
    } catch (e) {
      activationError.value = 'فشل الاتصال بالخادم، يرجى التحقق من الإنترنت.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onMenuItemTap(MenuItem item) async {
    if (!canAccessScreen(item.screenNameKey)) {
      AppSnackbar.showCustomSnackbar(
        'صلاحيات', 'ليس لديك صلاحية الوصول إلى "${item.title}".',
      );
      return;
    }

    if (isLicensed.value) {
      Get.toNamed('/${item.screenNameKey}');
      return;
    }

    final invoiceChar = screenKeyToCharMap[item.screenNameKey];
    if (invoiceChar == null) {
      Get.toNamed('/${item.screenNameKey}');
      return;
    }

    isLoading.value = true;
    try {
      final canEnter = await TrialPeriodManager.checkOnEntry(invoiceTypeChar: invoiceChar);

      if (canEnter) {
        Get.toNamed('/${item.screenNameKey}');
      } else {
        AppSnackbar.showCustomSnackbar(
          'الفترة التجريبية انتهت',
          'لقد استنفدت الحركات التجريبية لشاشة "${item.title}". يرجى تفعيل التطبيق.',
          isError: true,
        );
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل التحقق من الفترة التجريبية: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  void onSettingsTap() {
    if (userState.isAdmin) {
      Get.toNamed('/admin');
    } else {
      AppSnackbar.showCustomSnackbar(
          'صلاحيات',
          'ليس لديك صلاحيات مدير النظام.'
      );
    }
  }

  bool canAccessScreen(String? screenNameKey) {
    if (screenNameKey == null) return false;
    
    if (screenNameKey == 'RestaurantPosScreen') {
      return userState.isAdmin || 
             userState.canAccessScreen('RestaurantCashScreen') || 
             userState.canAccessScreen('RestaurantCreditScreen');
    }
    
    return userState.isAdmin || userState.canAccessScreen(screenNameKey);
  }

  void onProfileIconTap() {
    showUserProfileDialog();
  }

  void showUserProfileDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 45),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(userState.safeUserName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("مستخدم", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                  const SizedBox(height: 24),
                  _buildProfileInfoRow(Icons.business_outlined, "الفرع:", userState.safeUserBranchName),
                  const Divider(height: 24),
                  _buildProfileInfoRow(Icons.group_work_outlined, "القسم:", userState.safeUserDepartmentName),
                  const SizedBox(height: 32),
                  if (userState.isAdmin)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.lock_reset, size: 20),
                      label: const Text('تغيير كلمة السر', style: TextStyle(fontSize: 16)),
                      onPressed: () {
                        Get.back();
                        showChangePasswordDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 2,
                        backgroundColor: const Color.fromARGB(255, 1, 90, 163),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: const Color.fromARGB(255, 1, 90, 163).withOpacity(0.1),
                  child: const Icon(Icons.person, size: 55, color: Color.fromARGB(255, 1, 90, 163)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showChangePasswordDialog() {
    if (isClosed) return;

    oldPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    activationError.value = '';

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color.fromARGB(255, 2, 119, 212), Color.fromARGB(255, 1, 90, 163)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.lock_reset_outlined, color: Colors.white, size: 45),
                    SizedBox(height: 10),
                    Text('تغيير كلمة السر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Obx(() => Column(
                  children: [
                    TextField(controller: oldPasswordController, obscureText: isPasswordObscured.value, decoration: _buildPasswordInputDecoration('كلمة السر الحالية')),
                    const SizedBox(height: 16),
                    TextField(controller: newPasswordController, obscureText: isPasswordObscured.value, decoration: _buildPasswordInputDecoration('كلمة السر الجديدة')),
                    const SizedBox(height: 16),
                    TextField(controller: confirmPasswordController, obscureText: isPasswordObscured.value, decoration: _buildPasswordInputDecoration('تأكيد كلمة السر الجديدة')),
                    if (activationError.value.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Text(activationError.value, style: const TextStyle(color: Colors.red, fontSize: 14))),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading.value ? null : _handleChangePassword,
                      style: ElevatedButton.styleFrom(
                        elevation: 2,
                        backgroundColor: const Color.fromARGB(255, 1, 90, 163),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading.value
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : const Text('حفظ التغييرات', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    isLoading.value = true;
    activationError.value = '';

    final oldPass = oldPasswordController.text.trim();
    final newPass = newPasswordController.text.trim();
    final confirmPass = confirmPasswordController.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      activationError.value = 'جميع الحقول مطلوبة.';
      isLoading.value = false;
      return;
    }
    if (newPass.length < 4) {
      activationError.value = 'كلمة السر الجديدة يجب أن تكون 4 أحرف على الأقل.';
      isLoading.value = false;
      return;
    }
    if (newPass != confirmPass) {
      activationError.value = 'كلمات السر الجديدة غير متطابقة.';
      isLoading.value = false;
      return;
    }

    try {
      final currentHashedPassword =
      await _authRepository.fetchUserPasswordHash(userState.safeUserNo);

      final enteredOldPasswordHashed = _hashPassword(oldPass);

      if (currentHashedPassword != enteredOldPasswordHashed) {
        activationError.value = 'كلمة السر الحالية غير صحيحة.';
        isLoading.value = false;
        return;
      }

      final newHashedPassword = _hashPassword(newPass);
      await _authRepository.updateUserPassword(
          userState.safeUserNo, newHashedPassword);

      Get.back();
      AppSnackbar.showCustomSnackbar('نجاح', 'تم تغيير كلمة السر بنجاح.');

    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ غير متوقع: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  InputDecoration _buildPasswordInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: IconButton(
        icon: Icon(isPasswordObscured.value ? Icons.visibility_off : Icons.visibility),
        onPressed: () => isPasswordObscured.value = !isPasswordObscured.value,
      ),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      ],
    );
  }

  String _hashPassword(String password) {
    final passwordBytes = utf8.encode(password);
    final base64Password = base64.encode(passwordBytes);
    final passwordLength = password.length.toString();
    final prefix = "${passwordLength}1";
    return prefix + base64Password;
  }

  Future<bool> showExitConfirmationDialog() async {
    final context = Get.context;
    if (context == null) return false;

    final result = await Get.dialog<bool>(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.red.withAlpha(25),
                child: const Icon(Icons.exit_to_app, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 20),
              const Text(
                'تأكيد الخروج',
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'هل أنت متأكد من رغبتك في الخروج من التطبيق؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'لا',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      userState.clearUser();
                      _lookupsService.clearLookups();

                      if (context.mounted) Navigator.of(context).pop();

                      Get.offAllNamed('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text('نعم، خروج', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return result ?? false;
  }
}