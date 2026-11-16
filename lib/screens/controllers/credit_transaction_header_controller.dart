// lib/screens/controllers/credit_transaction_header_controller.dart

import 'package:get/get.dart';
import 'package:untitled4/repositories/auth_repository.dart';
import 'package:untitled4/user_state.dart';
// لم نعد بحاجة لـ snackbar_helper هنا لأننا لن نعرض رسائل خطأ مزعجة

class CreditTransactionHeaderController extends GetxController {
  final UserState userState = Get.find<UserState>();
  final AuthRepository _authRepository = AuthRepository();

  final RxString transactionNumber = 'جارٍ التحميل...'.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    selectedDate.value = DateTime.now();
    // 🛑 تم إيقاف الاستدعاء التلقائي هنا لمنع التكرار مع الكنترولر الرئيسي
  }

  /// توليد رقم الحركة التالي (تقديري فقط للواجهة الأمامية)
  Future<void> generateAndSetNextTransactionNumber() async {
    if (!userState.isLoggedIn || userState.id == null) {
      transactionNumber.value = '---';
      return;
    }

    transactionNumber.value = 'جارٍ التوليد...';

    try {
      final int userNo = userState.safeUserNo;
      // 🔒 نوع الفاتورة ثابت 'ج' للبيع الآجل
      const String invoiceTypeChar = 'ج';

      final String estimatedNumber = await _authRepository
          .getEstimatedTransactionNumber(userNo, invoiceTypeChar);

      transactionNumber.value = estimatedNumber;

    } catch (e) {
      // رسائل خطأ صامتة (Silent Fail) لعدم إزعاج المستخدم
      transactionNumber.value = '---';
      print('Error getting estimated sequence (Credit): ${e.toString()}');
    }
  }

  void resetHeader() {
    selectedDate.value = DateTime.now();
    generateAndSetNextTransactionNumber();
  }
}