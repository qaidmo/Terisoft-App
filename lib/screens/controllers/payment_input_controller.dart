import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/screens/controllers/payment_items_controller.dart';
import 'package:untitled4/models/sun_box.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/user_state.dart';
import '../../utils/snackbar_helper.dart';

class PaymentInputController extends GetxController {
  final UserState _userState = Get.find<UserState>();
  final LookupsRepository _lookupsRepository = LookupsRepository();

  final RxList<SunBox> boxes = <SunBox>[].obs;
  final RxList<SunCurrency> currencies = <SunCurrency>[].obs;

  final RxString selectedBox = ''.obs;
  final RxString selectedCurrency = ''.obs;
  final RxDouble selectedExchangeRate = 1.0.obs;
  late final TextEditingController exchangeRateController;

  final RxBool isLoadingBoxes = true.obs;
  final RxBool isLoadingCurrencies = false.obs;

  final RxnString selectedBoxAccountId = RxnString();

  final RxBool isBoxEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    exchangeRateController = TextEditingController();
  }

  @override
  void onClose() {
    exchangeRateController.dispose();
    super.onClose();
  }

  Future<void> loadInitialData() async {
    await fetchCashBoxes();

    final int? userPaymentBoxNo = _userState.paymentBoxNo;
    final String? userPaymentBoxName = _userState.paymentBoxName;

    if (userPaymentBoxNo != null) {
      isBoxEnabled.value = false;
      await fetchAndAddMissingBox(userPaymentBoxNo, fallbackName: userPaymentBoxName);
      if (userPaymentBoxName != null) {
        await updateSelectedBox(userPaymentBoxName);
      } else {
        final box = boxes.firstWhereOrNull((b) => b.boxNo == userPaymentBoxNo);
        if (box != null) {
          await updateSelectedBox(box.boxName);
        }
      }
    } else {
      isBoxEnabled.value = true;
      if (boxes.isNotEmpty && selectedBox.value.isEmpty) {
        await updateSelectedBox(boxes.first.boxName);
      }
    }
  }

  Future<void> fetchCashBoxes() async {
    isLoadingBoxes.value = true;
    try {
      final List<SunBox> response = await _lookupsRepository.fetchAllBoxes();
      boxes.assignAll(response);
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تحميل بيانات الصناديق',
          isError: true);
    } finally {
      isLoadingBoxes.value = false;
    }
  }

  Future<void> fetchAndAddMissingBox(int? boxNo, {String? fallbackName}) async {
    if (boxNo == null) return;
    if (boxes.any((b) => b.boxNo == boxNo)) return;
    try {
      final box = await _lookupsRepository.fetchBox(boxNo);
      boxes.add(box);
    } catch (e) {
      boxes.add(SunBox(
        boxNo: boxNo,
        boxName: fallbackName ?? 'صندوق غير معرف ($boxNo)',
      ));
    }
  }

  Future<void> fetchAndAddMissingCurrenciesForBox(int? boxNo,
      {String? fallbackCurrencyName, double? fallbackRate}) async {
    if (boxNo == null) return;
    try {
      final currencyList = await _lookupsRepository.fetchCurrenciesForBox(boxNo);
      for (var currency in currencyList) {
        if (!currencies.any((c) => c.currencyNo == currency.currencyNo)) {
          currencies.add(currency);
        }
      }

      if (fallbackCurrencyName != null && fallbackCurrencyName.isNotEmpty) {
        if (!currencies.any((c) => c.currencyName == fallbackCurrencyName)) {
          currencies.add(SunCurrency(
            currencyNo: 0,
            currencyName: fallbackCurrencyName,
            currencyRate: fallbackRate ?? 1.0,
            currencySymbol: '',
          ));
        }
      }
    } catch (e) {
      if (fallbackCurrencyName != null && fallbackCurrencyName.isNotEmpty) {
        currencies.add(SunCurrency(
          currencyNo: 0,
          currencyName: fallbackCurrencyName,
          currencyRate: fallbackRate ?? 1.0,
          currencySymbol: '',
        ));
      }
    }
  }

  Future<void> updateSelectedBox(String? newValue) async {
    if (newValue == null) return;

    selectedBox.value = newValue;
    final SunBox? selectedBoxObject =
    boxes.firstWhereOrNull((box) => box.boxName == newValue);

    if (selectedBoxObject == null) {
      selectedBoxAccountId.value = null;
      currencies.clear();
      updateSelectedCurrency(null);
      return;
    }

    selectedBoxAccountId.value = selectedBoxObject.accountId;

    isLoadingCurrencies.value = true;
    try {
      if (selectedBoxObject.boxNo != null) {
        final List<SunCurrency> response =
        await _lookupsRepository.fetchCurrenciesForBox(selectedBoxObject.boxNo!);
        currencies.assignAll(response);
      } else {
        currencies.clear();
      }

      if (currencies.isNotEmpty) {
        String? targetCurrencyName;

        if (selectedBoxObject.boxNo == _userState.paymentBoxNo && _userState.paymentBoxCurrencyNo != null) {
          final userPreferredCurrency = currencies.firstWhereOrNull(
                  (c) => c.currencyNo == _userState.paymentBoxCurrencyNo
          );
          targetCurrencyName = userPreferredCurrency?.currencyName;
        }

        updateSelectedCurrency(targetCurrencyName ?? currencies.first.currencyName);
      } else {
        updateSelectedCurrency(null);
      }
    } catch (e) {
      currencies.clear();
      updateSelectedCurrency(null);
    } finally {
      isLoadingCurrencies.value = false;
    }
  }

  void updateSelectedCurrency(String? newValue) {
    if (newValue != null) {
      selectedCurrency.value = newValue;
      final selectedCurrencyObject =
      currencies.firstWhereOrNull((c) => c.currencyName == newValue);
      if (selectedCurrencyObject != null) {
        final rate = selectedCurrencyObject.currencyRate;
        selectedExchangeRate.value = rate;
        exchangeRateController.text = rate.toStringAsFixed(2);
      } else {
        selectedExchangeRate.value = 1.0;
        exchangeRateController.text = "1.00";
      }
    } else {
      selectedCurrency.value = '';
      selectedExchangeRate.value = 1.0;
      exchangeRateController.text = "1.00";
    }

    try {
      final itemsController = Get.find<PaymentItemsController>();
      itemsController.recalculateAllAmounts();
    } catch (e) {}
  }

  Future<void> resetDropdowns() async {
    final int? userPaymentBoxNo = _userState.paymentBoxNo;
    final String? userPaymentBoxName = _userState.paymentBoxName;

    if (userPaymentBoxNo != null && userPaymentBoxName != null) {
      if (boxes.any((b) => b.boxName == userPaymentBoxName)) {
        await updateSelectedBox(userPaymentBoxName);
      }
      isBoxEnabled.value = false;
    } else {
      isBoxEnabled.value = true;
      if (boxes.isNotEmpty) {
        await updateSelectedBox(boxes.first.boxName);
      } else {
        selectedBox.value = '';
        selectedBoxAccountId.value = null;
        currencies.clear();
        updateSelectedCurrency(null);
      }
    }
  }
}