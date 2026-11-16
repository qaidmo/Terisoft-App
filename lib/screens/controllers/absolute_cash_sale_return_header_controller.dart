import 'package:get/get.dart';
import 'package:untitled4/repositories/auth_repository.dart';
import 'package:untitled4/user_state.dart';
// لم نعد بحاجة لـ snackbar_helper ولا supabase_flutter هنا

class AbsoluteCashSaleReturnHeaderController extends GetxController {
  final UserState userState = Get.find<UserState>();
  final AuthRepository _authRepository = AuthRepository();

  final RxString transactionNumber = 'جارٍ التحميل...'.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    selectedDate.value = DateTime.now();
    // 🛑 تم إيقاف الاستدعاء التلقائي هنا لمنع تكرار الطلب مع الكنترولر الرئيسي
  }

  Future<void> generateAndSetNextTransactionNumber() async {
    if (!userState.isLoggedIn || userState.id == null) {
      transactionNumber.value = '---';
      return;
    }

    transactionNumber.value = 'جارٍ التوليد...';

    try {
      final int userNo = userState.safeUserNo;
      // 🔒 ثابتة لأن هذا الكنترولر مخصص لمردود البيع المعلق
      const String invoiceTypeChar = 'رم';

      final String estimatedNumber = await _authRepository
          .getEstimatedTransactionNumber(userNo, invoiceTypeChar);

      transactionNumber.value = estimatedNumber;

    } catch (e) {
      // فشل صامت (Silent Fail) لعدم إزعاج المستخدم
      transactionNumber.value = '---';
      print('Error getting estimated sequence (Absolute Return): ${e.toString()}');
    }
  }

  void resetHeader() {
    selectedDate.value = DateTime.now();
    generateAndSetNextTransactionNumber();
  }
}