import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled4/repositories/auth_repository.dart';
import 'package:untitled4/user_state.dart';

import '../../utils/snackbar_helper.dart';

class PaymentHeaderController extends GetxController {
  final UserState userState = Get.find<UserState>();
  final AuthRepository _authRepository = AuthRepository();

  static const String _invoiceTypeChar = 'ص';

  final RxString screenTitle = 'سند صرف نقداً'.obs;
  final RxBool showPaymentId = false.obs;
  final RxString paymentId = ''.obs;

  final RxString transactionNumber = 'جارٍ جلب رقم الحركة...'.obs;

  final Rx<DateTime> selectedDate = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    selectedDate.value = DateTime.now();
    generateAndSetNextTransactionNumber();
  }

  Future<void> generateAndSetNextTransactionNumber() async {
    if (!userState.isLoggedIn || userState.id == null) {
      transactionNumber.value = 'خطأ في بيانات المستخدم';
      AppSnackbar.showCustomSnackbar('خطأ',
          'خطأ: بيانات المستخدم غير متوفرة لتوليد رقم حركة تقديري. يرجى تسجيل الدخول.',
          isError: true);
      return;
    }

    transactionNumber.value = 'جارٍ توليد رقم الحركة...';

    try {
      final int userNo = userState.safeUserNo;

      final String estimatedNumber = await _authRepository
          .getEstimatedTransactionNumber(userNo, _invoiceTypeChar);

      transactionNumber.value = estimatedNumber;
    } on PostgrestException catch (e) {
      transactionNumber.value = 'خطأ في التقدير';
      AppSnackbar.showCustomSnackbar('خطأ',
          'خطأ في قاعدة البيانات أثناء جلب تسلسل الحركة التقديري لسند الصرف: ${e.message}',
          isError: true);
      print(
          'Supabase Error getting estimated sequence for $_invoiceTypeChar: ${e.toString()}');
    } catch (e) {
      transactionNumber.value = 'خطأ غير متوقع';
      AppSnackbar.showCustomSnackbar('خطأ',
          'خطأ غير متوقع أثناء جلب تسلسل الحركة التقديري لسند الصرف: ${e.toString()}',
          isError: true);
      print(
          'Unexpected Error getting estimated sequence for $_invoiceTypeChar: ${e.toString()}');
    }
  }

  void resetHeader() {
    selectedDate.value = DateTime.now();
    transactionNumber.value = 'جارٍ جلب رقم الحركة...';
    screenTitle.value = 'سند صرف نقداً';
    showPaymentId.value = false;
    paymentId.value = '';
    generateAndSetNextTransactionNumber();
  }
}