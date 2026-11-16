// lib/screens/controllers/cash_sale_return_header_controller.dart

import 'package:get/get.dart';
import 'package:untitled4/repositories/auth_repository.dart';
import 'package:untitled4/user_state.dart';

class CashSaleReturnHeaderController extends GetxController {
  final UserState userState = Get.find<UserState>();
  final AuthRepository _authRepository = AuthRepository();

  final RxString transactionNumber = 'جارٍ التحميل...'.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    selectedDate.value = DateTime.now();
  }

  Future<void> generateAndSetNextTransactionNumber() async {
    if (!userState.isLoggedIn || userState.id == null) {
      transactionNumber.value = '---';
      return;
    }

    transactionNumber.value = 'جارٍ التوليد...';

    try {
      final int userNo = userState.safeUserNo;
      // 🔒 ثابتة لأن هذا الكنترولر مخصص للمردودات فقط
      const String invoiceTypeChar = 'رن';

      final String estimatedNumber = await _authRepository
          .getEstimatedTransactionNumber(userNo, invoiceTypeChar);

      transactionNumber.value = estimatedNumber;

    } catch (e) {
      // في حال الخطأ، نعرض شرطات بدلاً من رسالة خطأ مخيفة
      transactionNumber.value = '---';
      print('Error getting estimated sequence (Return): ${e.toString()}');
    }
  }

  void resetHeader() {
    selectedDate.value = DateTime.now();
    generateAndSetNextTransactionNumber();
  }
}