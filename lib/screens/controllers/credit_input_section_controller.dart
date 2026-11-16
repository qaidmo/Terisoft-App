import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/screens/controllers/credit_products_controller.dart';
import 'package:untitled4/screens/controllers/credit_sale_controller.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/models/sun_store.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../services/lookups_service.dart.dart';

class CreditInputSectionController extends GetxController {
  final LookupsService _lookupsService = Get.find<LookupsService>();
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final UserState _userState = Get.find<UserState>();

  final RxList<SunCurrency> currencies = <SunCurrency>[].obs;
  final RxList<SunStore> stores = <SunStore>[].obs;

  final RxString selectedCurrency = ''.obs;
  final RxString selectedStore = ''.obs;

  final RxDouble selectedExchangeRate = 1.0.obs;
  late final TextEditingController exchangeRateController;

  final RxBool isLoadingCurrencies = false.obs;
  final RxBool isLoadingStores = false.obs;

  List<String> get availableCurrencies => currencies.map((c) => c.currencyName).toList();
  List<String> get availableStores => stores.map((s) => s.nameStore).toList();

  final collectorNameController = TextEditingController();
  final agentNameController = TextEditingController();
  late var collectorSearchController = TextEditingController();
  var agentSearchController = TextEditingController();

  final Rxn<int> selectedCollectorId = Rxn<int>();
  final Rxn<int> selectedAgentId = Rxn<int>();

  final RxList<Map<String, dynamic>> allCollectors = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredCollectors = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> allAgents = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredAgents = <Map<String, dynamic>>[].obs;

  final String _tag;
  Timer? _debounce;

  CreditInputSectionController({required String controllerTag}) : _tag = controllerTag;

  @override
  void onInit() {
    super.onInit();
    exchangeRateController = TextEditingController();
    collectorSearchController = TextEditingController();
    agentSearchController = TextEditingController();

    collectorSearchController.addListener(() => _onSearchChanged(collectorSearchController.text, 'collector'));
    agentSearchController.addListener(() => _onSearchChanged(agentSearchController.text, 'agent'));

    _loadDataFromCache();
  }

  void _onSearchChanged(String query, String type) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (type == 'collector') {
        filterCollectors(query);
      } else if (type == 'agent') {
        filterAgents(query);
      }
    });
  }

  void _loadDataFromCache() {
    try {
      allCollectors.assignAll(_lookupsService.collectorsList);
      filteredCollectors.assignAll(allCollectors);

      allAgents.assignAll(_lookupsService.agentsList);
      filteredAgents.assignAll(allAgents);
    } catch (e) {
      debugPrint("Error loading cache in CreditInput: $e");
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    exchangeRateController.dispose();
    collectorNameController.dispose();
    agentNameController.dispose();
    collectorSearchController.dispose();
    agentSearchController.dispose();
    super.onClose();
  }

  Future<void> loadInitialData() async {
    if (!_userState.isLoggedIn) {
      AppSnackbar.showCustomSnackbar('خطأ', 'لم يتم العثور على بيانات المستخدم.', isError: true);
      return;
    }

    _loadDataFromCache();
    await _setStoreFromMemoryOrFetch();
  }

  Future<void> _setStoreFromMemoryOrFetch() async {
    isLoadingStores.value = true;
    try {
      final int? userStoreNo = _userState.userStoreNo;
      final String? userStoreName = _userState.userStoreName;

      if (userStoreNo != null) {
        final cachedStore = _lookupsService.allStores.firstWhereOrNull((s) => s.noStore == userStoreNo);

        if (cachedStore != null) {
          stores.assignAll([cachedStore]);
          selectedStore.value = cachedStore.nameStore;
        } else if (userStoreName != null) {
          String? fetchedAccountId;
          try {
            final fullStoreData = await _lookupsRepository.fetchStore(userStoreNo);
            fetchedAccountId = fullStoreData.inventoryAccountId;
          } catch (e) {
            debugPrint("Store account fetch error: $e");
          }

          final tempStore = SunStore(
              noStore: userStoreNo,
              nameStore: userStoreName,
              inventoryAccountId: fetchedAccountId
          );
          stores.assignAll([tempStore]);
          selectedStore.value = userStoreName;
        } else {
          final fetchedStore = await _lookupsRepository.fetchStore(userStoreNo);
          stores.assignAll([fetchedStore]);
          selectedStore.value = fetchedStore.nameStore;
        }
      } else {
        stores.clear();
        selectedStore.value = '';
      }
    } catch (e) {
      debugPrint("Error setting store: $e");
    } finally {
      isLoadingStores.value = false;
    }
  }

  void filterCollectors(String query) {
    if (query.isEmpty) {
      filteredCollectors.assignAll(allCollectors);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredCollectors.assignAll(allCollectors.where((c) {
        final nameMatch = (c['collector_name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final noMatch = (c['collector_no'] as int? ?? 0).toString().contains(lowerCaseQuery);
        return nameMatch || noMatch;
      }).toList());
    }
  }

  void filterAgents(String query) {
    if (query.isEmpty) {
      filteredAgents.assignAll(allAgents);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredAgents.assignAll(allAgents.where((a) {
        final nameMatch = (a['salesperson_name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final noMatch = (a['salesperson_no'] as int? ?? 0).toString().contains(lowerCaseQuery);
        return nameMatch || noMatch;
      }).toList());
    }
  }

  void selectCollector(int id, String name) {
    selectedCollectorId.value = id;
    collectorNameController.text = name;
    Get.back();
  }

  void selectAgent(int id, String name) {
    selectedAgentId.value = id;
    agentNameController.text = name;
    Get.back();
  }

  void clearCurrencies() {
    currencies.clear();
    selectedCurrency.value = '';
    selectedExchangeRate.value = 1.0;
    exchangeRateController.clear();
  }

  void loadCurrenciesForCustomer(List<SunCurrency> customerCurrencies) {
    isLoadingCurrencies.value = true;
    try {
      clearCurrencies();

      if (customerCurrencies.isNotEmpty) {
        currencies.assignAll(customerCurrencies);
        updateSelectedCurrency(currencies.first.currencyName);
      } else {
        AppSnackbar.showCustomSnackbar('تنبيه', 'هذا العميل غير مرتبط بأي عملات.', isError: false);
      }
    } catch (e) {
      debugPrint("Error loading currencies: $e");
    } finally {
      isLoadingCurrencies.value = false;
    }
  }

  void updateSelectedCurrency(String? newValue) {
    if (newValue != null) {
      final double oldRate = selectedExchangeRate.value;

      selectedCurrency.value = newValue;
      final selectedCurrencyObject = currencies.firstWhereOrNull((c) => c.currencyName == newValue);

      double newRate = 1.0;

      if (selectedCurrencyObject != null) {
        newRate = selectedCurrencyObject.currencyRate;
        selectedExchangeRate.value = newRate;
        exchangeRateController.text = newRate.toStringAsFixed(2);
      } else {
        selectedExchangeRate.value = 1.0;
        exchangeRateController.text = "1.00";
      }

      try {
        if (Get.isRegistered<CreditSaleController>(tag: _tag)) {
          final saleCtrl = Get.find<CreditSaleController>(tag: _tag);
          saleCtrl.productsController.convertPricesToNewCurrency(oldRate, newRate);
        } else {
          final productsCtrl = Get.find<CreditProductsController>(tag: _tag);
          productsCtrl.convertPricesToNewCurrency(oldRate, newRate);
        }
      } catch (e) {
        debugPrint("Error converting prices: $e");
      }
    }
  }

  void updateSelectedStore(String? newValue) {
    if (newValue != null) {
      selectedStore.value = newValue;
    }
  }

  Future<void> fetchAndAddMissingStore(int? storeNo, {String? fallbackName}) async {
    if (storeNo == null) return;

    final cachedStore = _lookupsService.allStores.firstWhereOrNull((s) => s.noStore == storeNo);
    if (cachedStore != null) {
      if (!stores.any((s) => s.noStore == storeNo)) stores.add(cachedStore);
      return;
    }

    if (stores.any((s) => s.noStore == storeNo)) return;
    try {
      stores.add(await _lookupsRepository.fetchStore(storeNo));
    } catch (e) {
      debugPrint("Error fetching missing store: $e");
      if (fallbackName != null) {
        stores.add(SunStore(noStore: storeNo, nameStore: fallbackName));
      }
    }
  }

  void resetDropdowns() {
    _setStoreFromMemoryOrFetch();
    clearCurrencies();
    collectorNameController.clear();
    agentNameController.clear();
    selectedCollectorId.value = null;
    selectedAgentId.value = null;

    filteredCollectors.assignAll(allCollectors);
    filteredAgents.assignAll(allAgents);
  }

  int? get selectedStoreNo {
    return stores.firstWhereOrNull((s) => s.nameStore == selectedStore.value)?.noStore;
  }

  String? get selectedStoreAccountId {
    return stores.firstWhereOrNull((s) => s.nameStore == selectedStore.value)?.inventoryAccountId;
  }
}