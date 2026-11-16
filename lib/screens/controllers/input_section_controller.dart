import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/screens/controllers/products_controller.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/models/sun_box.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/models/sun_store.dart';
import 'package:untitled4/user_state.dart';
import '../../services/lookups_service.dart.dart';

class InputSectionController extends GetxController {
  final LookupsService _lookupsService = Get.find<LookupsService>();
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final UserState _userState = Get.find<UserState>();

  final RxList<SunBox> boxes = <SunBox>[].obs;
  final RxList<SunCurrency> currencies = <SunCurrency>[].obs;
  final RxList<SunStore> stores = <SunStore>[].obs;

  late final TextEditingController customerNameController;

  final RxString selectedBox = ''.obs;
  final RxString selectedCurrency = ''.obs;
  final RxString selectedStore = ''.obs;

  final RxDouble selectedExchangeRate = 1.0.obs;
  late final TextEditingController exchangeRateController;

  final RxBool isLoadingBoxes = false.obs;
  final RxBool isLoadingCurrencies = false.obs;
  final RxBool isLoadingStores = false.obs;

  final collectorNameController = TextEditingController();
  final agentNameController = TextEditingController();
  final collectorSearchController = TextEditingController();
  final agentSearchController = TextEditingController();

  final Rxn<int> selectedCollectorId = Rxn<int>();
  final Rxn<int> selectedAgentId = Rxn<int>();

  final RxList<Map<String, dynamic>> allCollectors = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredCollectors = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> allAgents = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredAgents = <Map<String, dynamic>>[].obs;

  late final String? inputTag;
  Timer? _debounce;

  InputSectionController({this.inputTag});

  @override
  void onInit() {
    super.onInit();
    exchangeRateController = TextEditingController(text: "1.00");
    customerNameController = TextEditingController();

    collectorSearchController.addListener(() => _onSearchChanged(collectorSearchController.text, 'collector'));
    agentSearchController.addListener(() => _onSearchChanged(agentSearchController.text, 'agent'));

    _loadLookupsFromCache();
  }

  void _onSearchChanged(String query, String type) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      switch (type) {
        case 'collector': filterCollectors(query); break;
        case 'agent': filterAgents(query); break;
      }
    });
  }

  void _loadLookupsFromCache() {
    try {
      allCollectors.assignAll(_lookupsService.collectorsList);
      filteredCollectors.assignAll(allCollectors);
      allAgents.assignAll(_lookupsService.agentsList);
      filteredAgents.assignAll(allAgents);
    } catch (e) {
      debugPrint("Error loading cache: $e");
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    exchangeRateController.dispose();
    customerNameController.dispose();
    collectorNameController.dispose();
    agentNameController.dispose();
    collectorSearchController.dispose();
    agentSearchController.dispose();
    super.onClose();
  }

  int? get selectedBoxNo => boxes.firstWhereOrNull((b) => b.boxName == selectedBox.value)?.boxNo;
  int? get selectedStoreNo => stores.firstWhereOrNull((s) => s.nameStore == selectedStore.value)?.noStore;
  String? get selectedStoreAccountId => stores.firstWhereOrNull((s) => s.nameStore == selectedStore.value)?.inventoryAccountId;

  Future<void> loadInitialData() async {
    if (!_userState.isLoggedIn) return;
    _loadLookupsFromCache();
    await Future.wait([
      _initializeBoxData(),
      _initializeStoreData(),
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

  Future<void> _initializeStoreData() async {
    try {
      final int? userStoreNo = _userState.userStoreNo;
      final String? userStoreName = _userState.userStoreName;

      if (userStoreNo != null && userStoreName != null) {

        // 1. خطوة جديدة: محاولة جلب رقم الحساب الحقيقي من قاعدة البيانات لهذا المخزن
        String? fetchedAccountId;
        try {
          // نطلب من المستودع جلب بيانات المخزن الكاملة لنأخذ منها رقم الحساب فقط
          final fullStoreData = await _lookupsRepository.fetchStore(userStoreNo);
          fetchedAccountId = fullStoreData.inventoryAccountId;
        } catch (e) {
          // إذا فشل الجلب (المخزن غير موجود في الـ DB)، سيبقى رقم الحساب null
          print("⚠️ تنبيه: لم يتم العثور على بيانات تفصيلية للمخزن رقم $userStoreNo في قاعدة البيانات");
        }

        // 2. إنشاء الكائن يدوياً (كما هو في الكود الأصلي) ولكن مع إضافة رقم الحساب الذي جلبناه
        final userStore = SunStore(
          noStore: userStoreNo,
          nameStore: userStoreName,
          inventoryAccountId: fetchedAccountId, // ✅ تم تمرير رقم الحساب هنا
        );

        // بقية الكود كما هو تماماً
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
      // ✅ الحل هنا: إذا لم يجد الصندوق، ننشئ واحداً مؤقتاً بالاسم القادم من السيرفر
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
      // ✅ الحل هنا: إنشاء مخزن مؤقت لضمان الظهور في الواجهة
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

      // ✅ الإضافة الذكية: إذا كان اسم العملة القادم من السيرفر غير موجود في القائمة، أضفه كعملة افتراضية
      if (fallbackCurrencyName != null && fallbackCurrencyName.isNotEmpty) {
        if (!currencies.any((c) => c.currencyName == fallbackCurrencyName)) {
          debugPrint('Currency $fallbackCurrencyName not found locally, creating virtual currency...');
          currencies.add(SunCurrency(
            currencyNo: 0, // معرف افتراضي
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
  void filterCollectors(String query) {
    if (query.isEmpty) {
      filteredCollectors.assignAll(allCollectors);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      final results = allCollectors.where((c) {
        final nameMatch = (c['collector_name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final noMatch = (c['collector_no'] as int? ?? 0).toString().contains(lowerCaseQuery);
        return nameMatch || noMatch;
      }).toList();
      filteredCollectors.assignAll(results);
    }
  }

  void filterAgents(String query) {
    if (query.isEmpty) {
      filteredAgents.assignAll(allAgents);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      final results = allAgents.where((a) {
        final nameMatch = (a['salesperson_name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final noMatch = (a['salesperson_no'] as int? ?? 0).toString().contains(lowerCaseQuery);
        return nameMatch || noMatch;
      }).toList();
      filteredAgents.assignAll(results);
    }
  }

  void selectCollector(int id, String name) {
    selectedCollectorId.value = id;
    collectorNameController.text = name;
    if (Get.isDialogOpen == true) Get.back();
  }

  void selectAgent(int id, String name) {
    selectedAgentId.value = id;
    agentNameController.text = name;
    if (Get.isDialogOpen == true) Get.back();
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
          final productsCtrl = Get.find<ProductsController>(tag: inputTag);
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
    collectorNameController.clear();
    agentNameController.clear();
    selectedCollectorId.value = null;
    selectedAgentId.value = null;
    filteredCollectors.assignAll(allCollectors);
    filteredAgents.assignAll(allAgents);
  }
}