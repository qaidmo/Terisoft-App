import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/screens/controllers/station_products_controller.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/models/sun_box.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/models/sun_store.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/models/sun_customer.dart';
import '../../services/lookups_service.dart.dart';

class StationsCollectionInputSectionController extends GetxController {
  final LookupsService _lookupsService = Get.find<LookupsService>();
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final UserState _userState = Get.find<UserState>();

  final RxList<SunBox> boxes = <SunBox>[].obs;
  final RxList<SunCurrency> currencies = <SunCurrency>[].obs;
  final RxList<SunStore> stores = <SunStore>[].obs;

  late final TextEditingController customerNameController;
  late final TextEditingController subscriptionFeeController;
  final Rxn<SunCustomer> selectedCustomer = Rxn<SunCustomer>();

  final RxString selectedBox = ''.obs;
  final RxString selectedCurrency = ''.obs;
  final RxString selectedStore = ''.obs;

  final RxDouble selectedExchangeRate = 1.0.obs;
  late final TextEditingController exchangeRateController;

  final RxBool isLoadingBoxes = false.obs;
  final RxBool isLoadingCurrencies = false.obs;
  final RxBool isLoadingStores = false.obs;

  final meterNameController = TextEditingController();

  final RxList<Map<String, dynamic>> allPumps = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredPumps = <Map<String, dynamic>>[].obs;

  late final String? inputTag;
  Timer? _debounce;

  StationsCollectionInputSectionController({this.inputTag});

  @override
  void onInit() {
    super.onInit();
    exchangeRateController = TextEditingController(text: "1.00");
    customerNameController = TextEditingController();
    subscriptionFeeController = TextEditingController(text: "0.00");
    subscriptionFeeController.addListener(_onSubscriptionFeeChanged);
  }

  void _onSubscriptionFeeChanged() {
    final fee = double.tryParse(subscriptionFeeController.text) ?? 0.0;
    try {
      final productsCtrl = inputTag != null
          ? Get.find<StationsCollectionProductsController>(tag: inputTag)
          : Get.find<StationsCollectionProductsController>();
      productsCtrl.updateSubscriptionFee(fee);
    } catch (_) {}
  }

  List<Map<String, dynamic>> filterPumps(String query) {
    if (query.isEmpty) {
      return allPumps;
    } else {
      final lowerCaseQuery = query.toLowerCase();
      return allPumps.where((p) {
        final nameMatch = (p['name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final noMatch = (p['no']?.toString() ?? '').contains(lowerCaseQuery);
        return nameMatch || noMatch;
      }).toList();
    }
  }



  @override
  void onClose() {
    _debounce?.cancel();
    exchangeRateController.dispose();
    customerNameController.dispose();
    meterNameController.dispose();
    subscriptionFeeController.removeListener(_onSubscriptionFeeChanged);
    subscriptionFeeController.dispose();
    super.onClose();
  }

  int? get selectedBoxNo => boxes.firstWhereOrNull((b) => b.boxName == selectedBox.value)?.boxNo;
  int? get selectedStoreNo => stores.firstWhereOrNull((s) => s.nameStore == selectedStore.value)?.noStore;
  String? get selectedStoreAccountId => stores.firstWhereOrNull((s) => s.nameStore == selectedStore.value)?.inventoryAccountId;

  Future<void> loadInitialData() async {
    if (!_userState.isLoggedIn) return;
    await Future.wait([
      _initializeBoxData(),
      _initializeStoreData(),
      _initializePumpsData(),
    ]);
  }

  Future<void> _initializeBoxData() async {
    try {
      final int? userBoxNo = _userState.userBoxNo;
      if (userBoxNo != null) {
        final userBox = await _lookupsRepository.fetchBox(userBoxNo);
        if (!boxes.any((b) => b.boxNo == userBox.boxNo)) {
          boxes.add(userBox);
        }
        if (selectedBox.value.isEmpty) {
          selectedBox.value = userBox.boxName;
          await _fetchCurrenciesForBox(userBox.boxNo);
        }
      }
    } catch (e) {
      debugPrint('Error initializing box: $e');
    }
  }

  Future<void> _initializePumpsData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('sun_pumps');
      allPumps.assignAll(results.map((row) => {
        'no': row['m_no'],
        'name': row['m_name'],
        'reading': row['m_right']
      }).toList());
    } catch (e) {
      debugPrint('Error initializing pumps: $e');
    }
  }

  Future<void> _initializeStoreData() async {
    try {
      final int? userStoreNo = _userState.userStoreNo;
      final String? userStoreName = _userState.userStoreName;

      if (userStoreNo != null && userStoreName != null) {
        String? fetchedAccountId;
        try {
          final fullStoreData = await _lookupsRepository.fetchStore(userStoreNo);
          fetchedAccountId = fullStoreData.inventoryAccountId;
        } catch (e) {
          print("⚠️ تنبيه: لم يتم العثور على بيانات تفصيلية للمخزن رقم $userStoreNo في قاعدة البيانات");
        }

        final userStore = SunStore(
          noStore: userStoreNo,
          nameStore: userStoreName,
          inventoryAccountId: fetchedAccountId,
        );

        if (!stores.any((s) => s.noStore == userStore.noStore)) {
          stores.add(userStore);
        }

        if (selectedStore.value.isEmpty) {
          selectedStore.value = userStoreName;
        }
      }
    } catch (e) {
      debugPrint('Error initializing store: $e');
    }
  }

  Future<void> _fetchCurrenciesForBox(int? boxNo) async {
    if (boxNo == null) return;
    try {
      final currencyList = await _lookupsRepository.fetchCurrenciesForBox(boxNo);
      for (var currency in currencyList) {
        if (!currencies.any((c) => c.currencyNo == currency.currencyNo)) {
          currencies.add(currency);
        }
      }
      if (selectedCurrency.value.isEmpty && currencies.isNotEmpty) {
        final defaultCurrency = currencies.firstWhereOrNull((c) => c.currencyNo == _userState.userBoxCurrencyNo) ?? currencies.first;
        updateSelectedCurrency(defaultCurrency.currencyName);
      }
    } catch (e) {
      debugPrint('Error fetching currencies: $e');
    }
  }

  Future<void> fetchAndAddMissingBox(int? boxNo, {String? fallbackName}) async {
    if (boxNo == null) return;
    if (boxes.any((b) => b.boxNo == boxNo)) return;
    try {
      final box = await _lookupsRepository.fetchBox(boxNo);
      boxes.add(box);
    } catch (e) {
      debugPrint('Box $boxNo not found in local DB, creating virtual box...');
      boxes.add(SunBox(
        boxNo: boxNo,
        boxName: fallbackName ?? 'صندوق غير معرف ($boxNo)',
      ));
    }
  }

  Future<void> fetchAndAddMissingStore(int? storeNo, {String? fallbackName}) async {
    if (storeNo == null) return;
    if (stores.any((s) => s.noStore == storeNo)) return;
    try {
      final store = await _lookupsRepository.fetchStore(storeNo);
      stores.add(store);
    } catch (e) {
      debugPrint('Store $storeNo not found in local DB, creating virtual store...');
      stores.add(SunStore(
        noStore: storeNo,
        nameStore: fallbackName ?? 'مخزن غير معرف ($storeNo)',
      ));
    }
  }

  Future<void> fetchAndAddMissingCurrenciesForBox(int? boxNo, {String? fallbackCurrencyName, double? fallbackRate}) async {
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
          debugPrint('Currency $fallbackCurrencyName not found locally, creating virtual currency...');
          currencies.add(SunCurrency(
            currencyNo: 0,
            currencyName: fallbackCurrencyName,
            currencyRate: fallbackRate ?? 1.0,
            currencySymbol: '',
          ));
        }
      }
    } catch (e) {
      debugPrint('Error adding missing currencies: $e');
    }
  }


  void updateSelectedBox(String? newValue) {
    if (newValue != null) {
      selectedBox.value = newValue;
      final box = boxes.firstWhereOrNull((b) => b.boxName == newValue);
      if (box != null) _fetchCurrenciesForBox(box.boxNo);
    }
  }

  void updateSelectedCurrency(String? newValue) {
    if (newValue != null) {
      final double oldRate = selectedExchangeRate.value;
      selectedCurrency.value = newValue;
      final selectedCurrencyObject = currencies.firstWhereOrNull((c) => c.currencyName == newValue);
      double newRate = selectedCurrencyObject?.currencyRate ?? 1.0;
      selectedExchangeRate.value = newRate;
      exchangeRateController.text = newRate.toStringAsFixed(2);
      try {
        if (inputTag != null) {
          final productsCtrl = Get.find<StationsCollectionProductsController>(tag: inputTag);
          productsCtrl.convertPricesToNewCurrency(oldRate, newRate);
        }
      } catch (e) {
        debugPrint("Error during currency conversion: $e");
      }
    }
  }

  void updateSelectedStore(String? newValue) {
    if (newValue != null) selectedStore.value = newValue;
  }

  void resetDropdowns() {
    boxes.clear();
    stores.clear();
    currencies.clear();
    selectedBox.value = '';
    selectedStore.value = '';
    selectedCurrency.value = '';
    loadInitialData();
    customerNameController.clear();
    meterNameController.clear();
    clearSelectedCustomer();
  }

  void onCustomerSelected(SunCustomer customer) {
    selectedCustomer.value = customer;
    customerNameController.text = customer.customerName;
    final fee = customer.costRsom ?? 0.0;
    subscriptionFeeController.text = fee.toStringAsFixed(2);
    try {
      final productsCtrl = inputTag != null
          ? Get.find<StationsCollectionProductsController>(tag: inputTag)
          : Get.find<StationsCollectionProductsController>();
      productsCtrl.applyCustomerReadingsAndFee(customer.costNext, fee);
    } catch (e) {
      debugPrint("Error applying customer readings and fee: $e");
    }
  }

  void clearSelectedCustomer() {
    selectedCustomer.value = null;
    customerNameController.clear();
    subscriptionFeeController.text = "0.00";
    try {
      final productsCtrl = inputTag != null
          ? Get.find<StationsCollectionProductsController>(tag: inputTag)
          : Get.find<StationsCollectionProductsController>();
      productsCtrl.updateSubscriptionFee(0.0);
    } catch (_) {}
  }

  Future<List<SunCustomer>> searchCustomers(String query) async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (query.trim().isEmpty) {
        final results = await db.query('sun_customers', limit: 30);
        return results.map((row) => SunCustomer.fromMap(row)).toList();
      }
      final results = await db.query(
        'sun_customers',
        where: 'customer_name LIKE ? OR customer_no LIKE ? OR phone_number LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        limit: 30,
      );
      return results.map((row) => SunCustomer.fromMap(row)).toList();
    } catch (e) {
      debugPrint('Error searching customers: $e');
      return [];
    }
  }
}
