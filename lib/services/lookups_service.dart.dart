import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/models/sun_customer.dart';
import 'package:untitled4/models/sun_currency.dart';
// 1. إضافة استيراد موديلات الصندوق والمخزن
import 'package:untitled4/models/sun_box.dart';
import 'package:untitled4/models/sun_store.dart';
import 'package:untitled4/user_state.dart';

class LookupsService extends GetxService {
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final UserState _userState = Get.find<UserState>();

  final RxBool isLoading = true.obs;

  // القوائم الموجودة سابقاً
  final RxList<Map<String, dynamic>> allAvailableProducts = <Map<String, dynamic>>[].obs;
  final RxList<SunCustomer> allCustomers = <SunCustomer>[].obs;
  final RxList<Map<String, dynamic>> allCollectors = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> allAgents = <Map<String, dynamic>>[].obs;
  final RxList<SunCurrency> allCurrencies = <SunCurrency>[].obs;

  // 2. 🔥 إضافة قوائم الصناديق والمخازن للخزنة
  final RxList<SunBox> allBoxes = <SunBox>[].obs;
  final RxList<SunStore> allStores = <SunStore>[].obs;

  // Getters
  List<Map<String, dynamic>> get productsList => allAvailableProducts.toList();
  List<SunCustomer> get customersList => allCustomers.toList();
  List<Map<String, dynamic>> get collectorsList => allCollectors.toList();
  List<Map<String, dynamic>> get agentsList => allAgents.toList();
  List<SunCurrency> get currenciesList => allCurrencies.toList();

  // 3. Getters الجديدة
  List<SunBox> get boxesList => allBoxes.toList();
  List<SunStore> get storesList => allStores.toList();

  void adjustStockGlobally(String itemNo, double quantityChanged) {
    int index = allAvailableProducts.indexWhere((p) => p['item_no']?.toString() == itemNo);
    if (index != -1) {
      double currentStock = (allAvailableProducts[index]['total_stock'] as num?)?.toDouble() ?? 0.0;
      allAvailableProducts[index]['total_stock'] = currentStock + quantityChanged;
      allAvailableProducts.refresh();
    }
  }

  Future<void> loadAllLookupData() async {
    isLoading.value = true;
    print('🔄 [LookupsService] بدء تحميل كافة بيانات الخزنة...');

    try {
      // 4. إضافة طلبات الصناديق والمخازن للقائمة
      // G1: the product stock aggregate is scoped to the active branch/store.
      final activeBranch = _userState.safeUserBranch;
      final activeStore = _userState.safeUserStoreNo;
      final responses = await Future.wait([
        _lookupsRepository.fetchAllAvailableItems(
          branchId: activeBranch == 0 ? null : activeBranch,
          storeNo: activeStore == 0 ? null : activeStore,
        ), // index 0
        _lookupsRepository.fetchAllCustomers(),      // index 1
        _lookupsRepository.fetchAllCollectors(),     // index 2
        _lookupsRepository.fetchAllAgents(),         // index 3
        _lookupsRepository.fetchAllCurrencies(),     // index 4
        _lookupsRepository.fetchAllBoxes(),          // index 5 (تأكد ان الدالة موجودة في الريبوزيتوري)
        _lookupsRepository.fetchAllStores(),         // index 6 (تأكد ان الدالة موجودة في الريبوزيتوري)
      ]);

      allAvailableProducts.assignAll(List<Map<String, dynamic>>.from(responses[0]));
      allCustomers.assignAll(List<SunCustomer>.from(responses[1]));
      allCollectors.assignAll(List<Map<String, dynamic>>.from(responses[2]));
      allAgents.assignAll(List<Map<String, dynamic>>.from(responses[3]));
      allCurrencies.assignAll(List<SunCurrency>.from(responses[4]));

      // 5. تخزين الصناديق والمخازن
      allBoxes.assignAll(List<SunBox>.from(responses[5]));
      allStores.assignAll(List<SunStore>.from(responses[6]));

      print('✅ [LookupsService] تم ملء الخزنة بنجاح:');
      print('   - ${allAvailableProducts.length} صنف');
      print('   - ${allCustomers.length} عميل');
      print('   - ${allBoxes.length} صندوق'); // طباعة للتأكد
      print('   - ${allStores.length} مخزن');   // طباعة للتأكد

    } catch (e) {
      print('❌ [LookupsService] فشل تحميل بيانات الخزنة: $e');
      // محاولة صامتة أو إشعار حسب رغبتك، لكن يفضل عدم إزعاج المستخدم في البداية إلا إذا كانت البيانات حرجة
      Get.rawSnackbar(
        title: 'تنبيه',
        message: 'حدث خطأ أثناء تجهيز بعض البيانات، يرجى التحقق من الاتصال.',
        backgroundColor: Colors.orange.shade800,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void clearLookups() {
    allAvailableProducts.clear();
    allCustomers.clear();
    allCollectors.clear();
    allAgents.clear();
    allCurrencies.clear();
    allBoxes.clear();  // تنظيف
    allStores.clear(); // تنظيف
    print('🗑️ [LookupsService] تم تفريغ الخزنة.');
  }
}