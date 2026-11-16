// lib/screens/controllers/inventory_header_controller.dart

import 'package:get/get.dart';
import 'package:untitled4/repositories/auth_repository.dart';
import 'package:untitled4/user_state.dart';

class InventoryHeaderController extends GetxController {
  final UserState userState = Get.find<UserState>();
  final AuthRepository _authRepository = AuthRepository();

  // المتغيرات التفاعلية الخاصة بالجرد
  final RxString transactionNumber = 'جارٍ التحميل...'.obs;

  // 🔥 الفرق الجوهري: تاريخان بدلاً من واحد
  final Rx<DateTime> closingDate = DateTime.now().obs; // تاريخ الإغلاق (date)
  final Rx<DateTime> startDate = DateTime.now().obs;   // تاريخ البدء (start_date)

  // ثابت لنوع الحركة الخاص بالجرد
  static const String _inventoryTypeChar = 'م ض';

  @override
  void onInit() {
    super.onInit();
    // تهيئة التواريخ للوقت الحالي
    closingDate.value = DateTime.now();
    startDate.value = DateTime.now();
  }

  // توليد رقم محضر الجرد التالي
  Future<void> generateNextTransactionNumber() async {
    if (!userState.isLoggedIn || userState.id == null) {
      transactionNumber.value = '---';
      return;
    }

    transactionNumber.value = 'جارٍ التوليد...';

    try {
      final int userNo = userState.safeUserNo;

      // استخدام الرمز الخاص بالجرد 'م ض' مباشرة
      final String estimatedNumber = await _authRepository
          .getEstimatedTransactionNumber(userNo, _inventoryTypeChar);

      transactionNumber.value = estimatedNumber;

    } catch (e) {
      transactionNumber.value = '---';
      print('Error generating inventory number: $e');
    }
  }

  // دوال لتحديث التواريخ من الواجهة
  void updateClosingDate(DateTime newDate) {
    closingDate.value = newDate;
  }

  void updateStartDate(DateTime newDate) {
    startDate.value = newDate;
  }

  void resetHeader() {
    closingDate.value = DateTime.now();
    startDate.value = DateTime.now();
    generateNextTransactionNumber();
  }
}