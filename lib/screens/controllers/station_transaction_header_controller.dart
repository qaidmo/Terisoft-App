// lib/screens/controllers/station_transaction_header_controller.dart

import 'package:get/get.dart';
import 'package:untitled4/repositories/auth_repository.dart';
import 'package:untitled4/user_state.dart';

class StationsCollectionTransactionHeaderController extends GetxController {
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

      const String invoiceTypeChar = 'ت';

      final String estimatedNumber = await _authRepository
          .getEstimatedTransactionNumber(userNo, invoiceTypeChar);

      transactionNumber.value = estimatedNumber;

    } catch (e) {
      transactionNumber.value = '---';
      print('Error generating transaction number: $e');
    }
  }

  void resetHeader() {
    selectedDate.value = DateTime.now();
    generateAndSetNextTransactionNumber(); 
  }
}
