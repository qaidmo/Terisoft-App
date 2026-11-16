// lib/screens/controllers/absolute_input_section_controller.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled4/supabase_manager.dart';
import 'package:untitled4/models/sun_box.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/models/sun_store.dart';

class AbsoluteInputSectionController extends GetxController {
  final SupabaseClient _supabase = SupabaseManager.client;

  final RxList<SunBox> boxes = <SunBox>[].obs;
  final RxList<SunCurrency> currencies = <SunCurrency>[].obs;
  final RxList<SunStore> stores = <SunStore>[].obs;

  final RxString selectedBox = ''.obs;
  final RxString selectedCurrency = ''.obs;
  final RxString selectedStore = ''.obs;

  // ✨ --- بداية التغييرات --- ✨
  final RxDouble selectedExchangeRate = 1.0.obs; // متغير لحفظ سعر الصرف
  late final TextEditingController exchangeRateController; // متحكم حقل النص
  // ✨ --- نهاية التغييرات --- ✨

  final RxBool isLoadingBoxes = true.obs;
  final RxBool isLoadingCurrencies = true.obs;
  final RxBool isLoadingStores = true.obs;

  @override
  void onInit() {
    super.onInit();
    // ✨ تهيئة متحكم سعر الصرف
    exchangeRateController = TextEditingController();
  }

  // ✨ إضافة دالة onClose للتخلص من المتحكم
  @override
  void onClose() {
    exchangeRateController.dispose();
    super.onClose();
  }

  Future<void> loadInitialData() async {
    await Future.wait([
      fetchCashBoxes(),
      fetchCurrencies(),
      fetchStores(),
    ]);
  }

  Future<void> fetchCashBoxes() async {
    isLoadingBoxes.value = true;
    try {
      final List<dynamic> response = await _supabase.from('sun_boxes').select('box_no, box_name, account_id');
      boxes.assignAll(response.map((json) => SunBox.fromJson(json)).toList());

      if (boxes.isNotEmpty && selectedBox.value.isEmpty) {
        selectedBox.value = boxes.first.boxName;
      }
    } on PostgrestException catch (e) {
      print('❌ Supabase Error fetching cash boxes: ${e.message}');
      Get.snackbar('خطأ في تحميل الصناديق', 'فشل تحميل بيانات الصناديق: ${e.message}', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    } catch (e) {
      print('❌ General Error fetching cash boxes: $e');
      Get.snackbar('خطأ عام', 'حدث خطأ غير متوقع أثناء تحميل الصناديق: $e', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    } finally {
      isLoadingBoxes.value = false;
    }
  }

  Future<void> fetchCurrencies() async {
    isLoadingCurrencies.value = true;
    try {
      final List<dynamic> response = await _supabase.from('sun_currencies').select('*');
      currencies.assignAll(response.map((json) => SunCurrency.fromJson(json)).toList());

      if (currencies.isNotEmpty && selectedCurrency.value.isEmpty) {
        // ✨ استدعاء الدالة لتعيين سعر الصرف الافتراضي
        updateSelectedCurrency(currencies.first.currencyName);
      }
    } on PostgrestException catch (e) {
      print('❌ Supabase Error fetching currencies: ${e.message}');
      Get.snackbar('خطأ في تحميل العملات', 'فشل تحميل بيانات العملات: ${e.message}', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    } catch (e) {
      print('❌ General Error fetching currencies: $e');
      Get.snackbar('خطأ عام', 'حدث خطأ غير متوقع أثناء تحميل العملات: $e', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    } finally {
      isLoadingCurrencies.value = false;
    }
  }

  Future<void> fetchStores() async {
    isLoadingStores.value = true;
    try {
      final List<dynamic> response = await _supabase.from('sun_store').select('*');
      stores.assignAll(response.map((json) => SunStore.fromJson(json)).toList());

      if (stores.isNotEmpty && selectedStore.value.isEmpty) {
        selectedStore.value = stores.first.nameStore;
      }
    } on PostgrestException catch (e) {
      print('❌ Supabase Error fetching stores: ${e.message}');
      Get.snackbar('خطأ في تحميل المخازن', 'فشل تحميل بيانات المخازن: ${e.message}', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    } catch (e) {
      print('❌ General Error fetching stores: $e');
      Get.snackbar('خطأ عام', 'حدث خطأ غير متوقع أثناء تحميل المخازن: $e', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    } finally {
      isLoadingStores.value = false;
    }
  }

  void updateSelectedBox(String? newValue) {
    if (newValue != null) {
      selectedBox.value = newValue;
    }
  }

  // ✨ تعديل دالة تحديث العملة لتشمل سعر الصرف
  void updateSelectedCurrency(String? newValue) {
    if (newValue != null) {
      selectedCurrency.value = newValue;
      final selectedCurrencyObject = currencies.firstWhereOrNull((c) => c.currencyName == newValue);

      if (selectedCurrencyObject != null) {
        final rate = selectedCurrencyObject.currencyRate;
        selectedExchangeRate.value = rate;
        exchangeRateController.text = rate.toStringAsFixed(2);
      } else {
        selectedExchangeRate.value = 1.0;
        exchangeRateController.text = "1.00";
      }
    }
  }

  void updateSelectedStore(String? newValue) {
    if (newValue != null) {
      selectedStore.value = newValue;
    }
  }

  // ✨ تعديل دالة إعادة التعيين لتشمل سعر الصرف
  void resetDropdowns() {
    if (boxes.isNotEmpty) {
      selectedBox.value = boxes.first.boxName;
    } else {
      selectedBox.value = '';
    }
    if (currencies.isNotEmpty) {
      updateSelectedCurrency(currencies.first.currencyName);
    } else {
      selectedCurrency.value = '';
      selectedExchangeRate.value = 1.0;
      exchangeRateController.clear();
    }
    if (stores.isNotEmpty) {
      selectedStore.value = stores.first.nameStore;
    } else {
      selectedStore.value = '';
    }
  }
}