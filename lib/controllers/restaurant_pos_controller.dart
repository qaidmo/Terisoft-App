import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:untitled4/pdf/restaurant_pdf_design.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/store_repository.dart';
import 'package:untitled4/repositories/restaurant_repository.dart';
import 'package:untitled4/utils/trial_period_manager.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/utils/number_to_words_converter.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/services/sync_service.dart';

class RestaurantPosController extends GetxController {
  var isLoading = true.obs;
  var isLoadingItems = false.obs;
  var isSaving = false.obs;
  var categories = <Map<String, dynamic>>[].obs;
  var selectedCategory = RxMap<String, dynamic>();
  var itemsForSelectedCategory = <Map<String, dynamic>>[].obs;
  var stores = <Map<String, dynamic>>[].obs;
  var currencies = <Map<String, dynamic>>[].obs;
  var addedProducts = <Map<String, dynamic>>[].obs;
  var selectedRowIndex = Rxn<int>();
  var currentInvoiceNumber = ''.obs;
  var savedTraNo = Rxn<String>();
  var transactionDate = DateTime.now().obs;
  var lastSavedInvoiceData = Rxn<Map<String, dynamic>>();

  var isCreditSale = false.obs;
  var isNetworkSale = false.obs;

  var isInvoiceFinalized = false.obs;
  var customers = <Map<String, dynamic>>[].obs;
  var selectedCustomer = Rxn<Map<String, dynamic>>();

  var selectedNetworkBox = Rxn<Map<String, dynamic>>();
  double networkPaidAmount = 0.0;

  var isSearching = false.obs;
  var searchResults = <dynamic>[].obs;
  var isEditMode = false.obs;
  var isSearchingCreditInvoices = false.obs;
  var filteredItems = <Map<String, dynamic>>[].obs;
  var filteredCategories = <Map<String, dynamic>>[].obs;
  var isDiscountManuallyEdited = false.obs;
  bool _isUpdatingDiscountProgrammatically = false;

  // Print Configuration States
  final RxBool autoPrintCustomer = true.obs;
  final RxBool autoPrintWaiter = true.obs;
  final RxBool autoPrintKitchen = true.obs;

  final storeController = TextEditingController(text: 'جاري التحميل...');
  final boxController = TextEditingController();
  final orderNumberController = TextEditingController();
  final tableNumberController = TextEditingController();
  final customerNameController = TextEditingController(text: '. . .');
  final exchangeRateController = TextEditingController(text: '1.00');
  final discountController = TextEditingController(text: '0');
  final taxController = TextEditingController(text: '0');
  final itemSearchController = TextEditingController();
  final invoiceSearchController = TextEditingController();
  late final TextEditingController customerAccountController;
  final categorySearchController = TextEditingController();
  String selectedStoreId = '';
  RxString selectedCurrencyId = ''.obs;
  final List<TextEditingController> quantityControllers = [];
  final List<TextEditingController> notesControllers = [];
  var total = 0.obs;
  var totalQuantities = 0.0.obs;
  var netTotal = 0.obs;

  // final SettingsService _settingsService = SettingsService();
  final LookupsRepository _lookupsRepo = LookupsRepository();
  final StoreRepository _storeRepo = StoreRepository();
  final RestaurantRepository _restaurantRepo = RestaurantRepository();
  late final UserState _userState = Get.find<UserState>();
  // final LicenseService _licenseService = Get.find<LicenseService>();
  
  bool get canMakeCashSale {
    return _userState.isAdmin || 
          (_userState.canAccessScreen('RestaurantCashScreen') && _userState.canAdd('RestaurantCashScreen'));
  }

  bool get canMakeCreditSale {
    return _userState.isAdmin || 
          (_userState.canAccessScreen('RestaurantCreditScreen') && _userState.canAdd('RestaurantCreditScreen'));
  }

  @override
  void onInit() {
    super.onInit();

    customerAccountController = TextEditingController();
    ever(selectedCustomer, (customer) {
      customerAccountController.text = customer?['custname'] ?? '...';
    });

    // syncOfflineInvoices();
    loadInitialData();
    categorySearchController.addListener(_filterCategories);
    itemSearchController.addListener(_filterItems);
    discountController.addListener(_onDiscountChanged);

    _triggerBackgroundSync();

    Future.microtask(() async {
      final canEnter = await TrialPeriodManager.checkOnEntry(invoiceTypeChar: '801');
      if (!canEnter) {
        AppSnackbar.showCustomSnackbar('تنبيه', 'استنفدت الحركات التجريبية. يُرجى تفعيل الترخيص.', isError: true);
        Get.back();
      }
    });
  }

  @override
  void onClose() {
    invoiceSearchController.dispose();
    orderNumberController.dispose();
    tableNumberController.dispose();
    customerNameController.dispose();
    exchangeRateController.dispose();
    discountController.dispose();
    taxController.dispose();
    storeController.dispose();
    boxController.dispose();
    categorySearchController.dispose();
    itemSearchController.dispose();
    customerAccountController.dispose();

    for (var controller in quantityControllers) {
      controller.dispose();
    }
    for (var controller in notesControllers) {
      controller.dispose();
    }
    super.onClose();
  }

  bool _isInvoiceDataValid() {
    final activeProducts = addedProducts.asMap().entries;
    bool hasAtLeastOneRealProduct = false;

    if (activeProducts.isEmpty) {
      AppSnackbar.showCustomSnackbar('خطأ', 'يرجى إضافة أصناف إلى الفاتورة أولاً.', isError: true);
      return false;
    }

    for (var entry in activeProducts) {
      if (entry.value['isEmpty'] == true) continue;

      hasAtLeastOneRealProduct = true;
      final index = entry.key;
      final double quantity = double.tryParse(quantityControllers[index].text) ?? 0.0;

      if (quantity <= 0) {
        AppSnackbar.showCustomSnackbar(
            'خطأ في الكمية',
            'لا يمكن حفظ الفاتورة، كمية أحد الأصناف صفر أو غير صالحة.',
            isError: true
        );
        return false;
      }
    }

    if (!hasAtLeastOneRealProduct) {
      AppSnackbar.showCustomSnackbar('خطأ', 'يجب إضافة صنف واحد على الأقل.', isError: true);
      return false;
    }

    return true;
  }

  Future<void> _directPrintInvoice(Map<String, dynamic> invoiceData, String traNo, {int? pendingId}) async {
    try {
      final _invoiceTemplatesController = Get.isRegistered<InvoiceTemplatesController>() 
          ? Get.find<InvoiceTemplatesController>() 
          : Get.put(InvoiceTemplatesController());

      _invoiceTemplatesController.selectTemplate('RestaurantPosScreen');

      final String currentCompanyName = _invoiceTemplatesController.companyNameController.text.trim();
      if (currentCompanyName.isEmpty || currentCompanyName == 'اسم شركتك التجاري') {
        _invoiceTemplatesController.selectTemplate('CashSaleScreen');
      }

      Set<String> activePrints = {};
      if (autoPrintCustomer.value) activePrints.add('customer');
      if (autoPrintWaiter.value) activePrints.add('waiter');
      if (autoPrintKitchen.value) activePrints.add('kitchen');

      final pdfBytes = await PdfInventoryData.generateCompositeInvoice(
        receiptsToPrint: activePrints,
        headerL: _invoiceTemplatesController.companyNameController.text.isNotEmpty 
            ? _invoiceTemplatesController.companyNameController.text 
            : _userState.safeUserDepartmentName,
        headerR: _userState.safeUserBranchName,
        branchAddress: _invoiceTemplatesController.addressDetailsController.text,
        companyLogoBytes: _invoiceTemplatesController.pickedLogoBytes,
        logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
        showLogo: _invoiceTemplatesController.showLogo.value,
        transactionNumber: traNo,
        orderNumber: invoiceData['orderNumber'] ?? '',
        tableNumber: invoiceData['tableNumber'] ?? '',
        date: DateTime.tryParse(invoiceData['transactionDate'] ?? '') ?? DateTime.now(),
        customerName: invoiceData['customerName'] ?? '',
        products: List<Map<String, dynamic>>.from(invoiceData['details'] ?? []),
        discount: (invoiceData['discount'] as num?)?.toDouble() ?? 0.0,
        tax: (invoiceData['tax'] as num?)?.toDouble() ?? 0.0,
        netTotal: (invoiceData['netTotal'] as num?)?.toDouble() ?? 0.0,
        netTotalInWords: invoiceData['netTotalInWords'] ?? '',
        userName: invoiceData['userName'] ?? _userState.userName ?? '',
        orderTypeId: invoiceData['orderTypeId']?.toString() ?? '0',
        traLstId: invoiceData['traLstId']?.toString() ?? '801',
        currencyName: invoiceData['currencyName'] ?? 'ريال يمني',
      );

      final success = await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: 'Invoice-$traNo',
      );

      if (success) {
        AppSnackbar.showCustomSnackbar('نجاح', 'تم إرسال الفاتورة إلى الطابعة.');
        if (pendingId != null) {
          await _restaurantRepo.deleteFromPrintQueue(pendingId);
        }
      } else {
        throw Exception('فشل الطباعة أو تم الإلغاء بواسطة المستخدم.');
      }
    } catch (e) {
      debugPrint("Print exception: $e");
      AppSnackbar.showCustomSnackbar('فشل الطباعة', 'تمت إضافة الفاتورة إلى قائمة الانتظار.', isError: true);
      if (pendingId == null) {
        await _restaurantRepo.addInvoiceToPrintQueue(traNo, jsonEncode(invoiceData));
      }
    }
  }

  Future<void> checkAndPrintPendingInvoices() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final pending = await db.query('pending_prints');
      for (var row in pending) {
        final int id = row['id'] as int;
        final String traNo = row['tra_no'] as String;
        final Map<String, dynamic> data = jsonDecode(row['invoice_data'] as String);
        
        await Get.defaultDialog(
          title: 'فاتورة معلقة',
          middleText: 'هل تريد طباعة الفاتورة المعلقة رقم $traNo؟',
          barrierDismissible: true,
          textConfirm: 'طباعة فورية',
          textCancel: 'تخطي الآن',
          confirmTextColor: Colors.white,
          cancelTextColor: Colors.red,
          buttonColor: Colors.blue.shade800,
          onConfirm: () async {
            Get.back(); // close dialog
            await _directPrintInvoice(data, traNo, pendingId: id);
          },
          onCancel: () {},
        );
      }
    } catch (e) {
      debugPrint("Error checking print queue: $e");
    }
  }



  void _onDiscountChanged() {
    if (_isUpdatingDiscountProgrammatically) return;
    isDiscountManuallyEdited.value = true;
    calculateTotals();
  }

  Future<void> selectTransactionDate(BuildContext context) async {
    if ((_userState.id ?? '') != '0') {
      AppSnackbar.showCustomSnackbar(
        'غير مسموح',
        'فقط مدير النظام يمكنه تغيير تاريخ الفاتورة.',
        isError: false,
      );
      return;
    }
    DateTime firstDate = DateTime(2000, 1, 1);
    DateTime lastDate = DateTime(2100, 12, 31);
    DateTime initialDate = transactionDate.value;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('ar', 'SA'),
    );
    if (picked != null && picked != transactionDate.value) {
      transactionDate.value = picked;
    }
  }

  Future<void> loadInitialData() async {
    isLoading.value = true;
    boxController.text = _userState.safeUserBoxName;
    await resetForm();
    await _loadPrintSettings();

    // Eagerly initialize and fetch template/header data (matches Cash Sales pattern).
    // This ensures company name, logo, and address are loaded from SQLite
    // BEFORE any print action, preventing fallback to mock defaults.
    final invoiceTemplatesCtrl = Get.isRegistered<InvoiceTemplatesController>()
        ? Get.find<InvoiceTemplatesController>()
        : Get.put(InvoiceTemplatesController());
    await invoiceTemplatesCtrl.fetchInvoiceTemplates();

    await Future.wait([
      fetchCategories(),
      fetchStores(),
      fetchCurrencies(),
      fetchCustomers(),
    ]);
    isLoading.value = false;
  }

  Future<void> _updateInvoiceNumberPreview() async {
    final String userId = _userState.safeUserNo.toString();
    final String branchId = _userState.safeUserBranch.toString();
    final String sectionId = _userState.safeUserDepartment.toString();
    currentInvoiceNumber.value = await _restaurantRepo.getPreviewInvoiceNumber(userId, branchId, sectionId);
  }

  Future<void> fetchCustomers() async {
    try {
      final localCustomers = await _lookupsRepo.fetchAllCustomers();
      if (localCustomers.isNotEmpty) {
        customers.value = localCustomers.map((c) => {
          'id': c.customerNo.toString(),
          'name': c.customerName,
          'custname': c.customerName,
          'account_id': c.accountId,
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching customers: \$e');
    }
  }

  Future<void> fetchStores() async {
    try {
      final localStores = await _storeRepo.fetchAllStoresWithDetails();
      if (localStores.isNotEmpty) {
        stores.value = localStores.map((s) => {
          'id': s.noStore.toString(),
          'name': s.nameStore,
        }).toList();
        
        if (stores.isNotEmpty) {
          final userStoreId = _userState.safeUserStoreNo.toString();
          final selectedStore = stores.firstWhere(
                (store) => store['id'].toString() == userStoreId,
            orElse: () => stores.first,
          );
          storeController.text = selectedStore['name'] ?? '';
          selectedStoreId = selectedStore['id'];
        }
      }
    } catch (e) {
      storeController.text = 'خطأ في التحميل';
    }
  }

  Future<void> fetchCurrencies() async {
    try {
      final localCurrencies = await _lookupsRepo.fetchAllCurrencies();
      if (localCurrencies.isNotEmpty) {
        currencies.value = localCurrencies.map((c) => {
          'id': c.currencyNo.toString(),
          'name': c.currencyName,
          'symbol': c.currencySymbol,
          'exchangeRate': c.currencyRate,
        }).toList();
        if (currencies.isNotEmpty) onCurrencyChanged(currencies.first['id']);
      }
    } catch (e) {
      debugPrint('Error fetching currencies: \$e');
    }
  }

  Future<void> fetchCategories() async {
    try {
      final localGroups = await _restaurantRepo.fetchRestaurantCategories();
      if (localGroups.isNotEmpty) {
        categories.value = localGroups.map((g) => {
          'id': g['group_no'].toString(),
          'name': g['group_name'] ?? '',
        }).toList();
        categories.refresh();
        _filterCategories();
        if (categories.isNotEmpty && selectedCategory.isEmpty) {
          selectCategory(categories.first, fromApi: false);
        }
      }
    } catch (e) {
      debugPrint('Error fetching categories: \$e');
    }
  }

  Future<void> fetchItemsForCategory(String categoryId, {bool fromApi = false}) async {
    isLoadingItems.value = true;
    itemsForSelectedCategory.clear();
    
    try {
      final localItems = await _restaurantRepo.fetchRestaurantProducts(categoryId);
      itemsForSelectedCategory.value = localItems.map((item) {
        dynamic decodedImage;
        if (item['imageBase'] != null && item['imageBase'].toString().isNotEmpty) {
          try {
            decodedImage = base64Decode(item['imageBase'].toString());
          } catch(e) {
            decodedImage = null;
          }
        }
        return {
          'id': item['item_no'].toString(),
          'number': item['item_no'].toString(),
          'name': item['item_name'] ?? '',
          'unit': item['item_unit'] ?? '',
          'price': (item['item_price'] as num?)?.toDouble() ?? 0.0,
          'discount': (item['discount_rate'] as num?)?.toDouble() ?? 0.0,
          'tax': (item['tax_rate'] as num?)?.toDouble() ?? 0.0,
          'isTaxable': item['is_taxable'] == 1,
          'isDiscountable': item['is_discountable'] == 1,
          'stock': 0.0,
          'imageBase': decodedImage,
          'units_list': item['units_list'] ?? [],
        };
      }).where((item) => (item['price'] as num? ?? 0) > 0).toList();
      itemsForSelectedCategory.refresh();
    } catch (e) {
      debugPrint('Error fetching items for category: $e');
    }
    
    isLoadingItems.value = false;
    _filterItems();
  }

  void onCurrencyChanged(String? newCurrencyId) {
    if (newCurrencyId == null) return;
    selectedCurrencyId.value = newCurrencyId;
    final selected = currencies.firstWhere((c) => c['id'] == newCurrencyId, orElse: () => {});
    if (selected.isNotEmpty) {
      exchangeRateController.text = (selected['exchangeRate'] as num).toStringAsFixed(2);
    }
  }

  void selectCategory(Map<String, dynamic> category, {bool fromApi = true}) {
    selectedCategory.value = category;
    fetchItemsForCategory(category['id'], fromApi: fromApi);
  }

  void changeItemUnit(int index, String newUnitName) {
    if (addedProducts[index]['isEmpty'] == true) return;

    final List<dynamic> units = addedProducts[index]['units_list'] ?? [];
    dynamic selectedUnit;
    for (var u in units) {
      if (u['unit_name'] == newUnitName) {
        selectedUnit = u;
        break;
      }
    }

    if (selectedUnit != null) {
      addedProducts[index]['unit'] = newUnitName;
      addedProducts[index]['price'] = (selectedUnit['sale_price'] as num).toDouble();
      addedProducts.refresh();
      calculateTotals();
    }
  }

  void addItemToTable(Map<String, dynamic> item) {
    final newItem = {
      'id': item['id'],
      'number': item['id'].toString(),
      'name': item['name'],
      'unit': item['unit'],
      'price': (item['price'] as num).toDouble(),
      'discount': (item['discount'] as num? ?? 0).toDouble(),
      'tax': (item['tax'] as num? ?? 0).toDouble(),
      'categoryName': selectedCategory['name'],
      'units_list': item['units_list'] ?? [],
    };
    int existingIndex = addedProducts.indexWhere((p) => p['id'] == newItem['id']);
    if (existingIndex != -1) {
      double currentQty = double.tryParse(quantityControllers[existingIndex].text) ?? 0;
      quantityControllers[existingIndex].text = (currentQty + 1).toStringAsFixed(0);
    } else {
      int emptyIndex = addedProducts.indexWhere((p) => p['isEmpty'] == true);
      
      if (emptyIndex != -1) {
        addedProducts[emptyIndex] = newItem;
        quantityControllers[emptyIndex].text = '1';
        notesControllers[emptyIndex].clear();
        selectedRowIndex.value = emptyIndex;
      } else {
        addedProducts.add(newItem);
        final qtyController = TextEditingController(text: '1');
        qtyController.addListener(calculateTotals);
        quantityControllers.add(qtyController);
        notesControllers.add(TextEditingController());
        selectedRowIndex.value = addedProducts.length - 1;
      }
    }
    addedProducts.refresh();
    calculateTotals();
  }

  void onNumpadPress(String value) {
    if (selectedRowIndex.value == null || selectedRowIndex.value! >= addedProducts.length) return;

    final currentIndex = selectedRowIndex.value!;
    final controller = quantityControllers[currentIndex];
    if (value == 'C') {
      if (controller.text.isEmpty) {
        addedProducts.removeAt(currentIndex);
        quantityControllers[currentIndex].dispose();
        quantityControllers.removeAt(currentIndex);
        notesControllers[currentIndex].dispose();
        notesControllers.removeAt(currentIndex);
        selectedRowIndex.value = null;
        addedProducts.refresh();
      }
      else {
        controller.text = '';
      }
    }
    else if (value == '1/2' || value == '1/4' || value == '1/8') {
      final currentText = controller.text;
      String decimalValue;
      String fullValue;
      if (value == '1/2') {
        decimalValue = '.5';
        fullValue = '0.5';
      } else if (value == '1/4') {
        decimalValue = '.25';
        fullValue = '0.25';
      } else {
        decimalValue = '.125';
        fullValue = '0.125';
      }
      if (currentText.isNotEmpty && !currentText.contains('.')) {
        controller.text += decimalValue;
      } else {
        controller.text = fullValue;
      }
    }

    else {
      controller.text += value;
    }
    calculateTotals();
  }

  void calculateTotals() {
    double newTotal = 0.0;
    double newTotalQuantities = 0.0;
    double totalItemTax = 0.0;
    double totalItemDiscount = 0.0;

    for (int i = 0; i < addedProducts.length; i++) {
      final product = addedProducts[i];
      if (product['isEmpty'] != true) {
        final double quantity = double.tryParse(quantityControllers[i].text) ?? 0.0;
        final double price = product['price'] as double;
        final double itemTaxPercent = product['tax'] as double;
        final double itemDiscountPercent = product['discount'] as double;

        newTotal += price * quantity;
        newTotalQuantities += quantity;
        totalItemTax += (price * itemTaxPercent / 100) * quantity;
        totalItemDiscount += (price * itemDiscountPercent / 100) * quantity;
      }
    }

    if (!isDiscountManuallyEdited.value) {
      _isUpdatingDiscountProgrammatically = true;
      discountController.text = totalItemDiscount.toStringAsFixed(2);
      _isUpdatingDiscountProgrammatically = false;
    }

    final double finalDiscount = double.tryParse(discountController.text) ?? 0.0;

    taxController.text = totalItemTax.toStringAsFixed(2);

    total.value = newTotal.round();
    totalQuantities.value = newTotalQuantities;

    netTotal.value = (newTotal - finalDiscount + totalItemTax).round();
  }

  void _filterItems() {
    String query = itemSearchController.text.toLowerCase();

    if (query.isEmpty) {
      filteredItems.value = List<Map<String, dynamic>>.from(itemsForSelectedCategory);
    } else {
      filteredItems.value = itemsForSelectedCategory.where((item) {
        final itemName = (item['name'] as String).toLowerCase();
        return itemName.contains(query);
      }).toList();
    }
  }

  void _filterCategories() {
    String query = categorySearchController.text.toLowerCase();
    if (query.isEmpty) {
      filteredCategories.value = List<Map<String, dynamic>>.from(categories);
    } else {
      filteredCategories.value = categories.where((category) {
        final categoryName = (category['name'] as String).toLowerCase();
        return categoryName.contains(query);
      }).toList();
    }
  }


  Future<void> _updateInvoiceNumber() async {
    currentInvoiceNumber.value = await _generateNewInvoiceNumber();
  }

  Future<String> _generateNewInvoiceNumber() async {
    final userId = _userState.id ?? '';
    final r = DateTime.now().millisecondsSinceEpoch.toString();
    return "POS-$userId-${r.substring(r.length - 6)}";
  }



  Future<void> handleCashSale() async {
    if (isSaving.value || isInvoiceFinalized.value) return;
    if (!_isInvoiceDataValid()) {
      return;
    }


    isCreditSale.value = false;
    isNetworkSale.value = false;
    await _promptForOrderTypeAndSave();
  }

  Future<void> handleCreditSale() async {
    if (isSaving.value || isInvoiceFinalized.value) return;
    if (!_isInvoiceDataValid()) {
      return;
    }


    isCreditSale.value = true;
    isNetworkSale.value = false;
    final Map<String, dynamic>? chosenCustomer = await _showCustomerSelectionDialog();
    if (chosenCustomer != null) {
      selectedCustomer.value = chosenCustomer;
      await _promptForOrderTypeAndSave();
    } else {
      isCreditSale.value = false;
    }
  }

  Future<Map<String, dynamic>?> _showCustomerSelectionDialog() async {
    final searchController = TextEditingController();
    final filtered = <Map<String, dynamic>>[...customers].obs;

    return await Get.dialog<Map<String, dynamic>>(
      AlertDialog(
        title: const Text('اختيار الزبون'),
        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        content: SizedBox(
          width: 400,
          height: 500,
          child: Column(
            children: [
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث عن عميل...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (val) {
                  filtered.assignAll(customers.where((c) => (c['custname']?.toString() ?? c['name']?.toString() ?? '').contains(val)));
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Obx(() => ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    final customerName = c['custname']?.toString() ?? c['name']?.toString() ?? 'اسم غير معروف';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(customerName.isNotEmpty ? customerName[0] : '#')),
                        title: Text(customerName),
                        subtitle: Text(c['accountno']?.toString() ?? c['account_id']?.toString() ?? ''),
                        onTap: () => Get.back(result: c),
                      ),
                    );
                  },
                )),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
        ],
      )
    );
  }

  Future<void> handleNetworkSale() async {
    if (isSaving.value || isInvoiceFinalized.value) return;
    if (!_isInvoiceDataValid()) {
      return;
    }


    isCreditSale.value = false;
    isNetworkSale.value = true;

    await _showNetworkBoxSelectionDialog();
  }

  Future<void> _showNetworkBoxSelectionDialog() async {
    final netBoxes = await _lookupsRepo.fetchNetworkBoxes();
    final networkBoxes = netBoxes.map((box) => {
       'id': box.boxNo.toString(),
       'name': box.boxName,
       'account_id': box.accountId
    }).toList();
    if (networkBoxes.isEmpty) {
      isNetworkSale.value = false;
      AppSnackbar.showCustomSnackbar('تنبيه', 'لا توجد صناديق شبكات معرفة. يرجى المزامنة.', isError: true);
      return;
    }

    final selected = await Get.dialog<Map<String, dynamic>>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        elevation: 10,
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 400,
          constraints: BoxConstraints(
            maxHeight: Get.height * 0.7,
            minHeight: 300,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_tethering, size: 50, color: Colors.blueAccent),
              const SizedBox(height: 15),
              const Text(
                'اختر الشبكة البنكية',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              const Text(
                'يرجى تحديد البنك أو المحفظة لاستكمال العملية',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: networkBoxes.length,
                  itemBuilder: (context, index) {
                    final box = networkBoxes[index];
                    return Material(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () => Get.back(result: box),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                                radius: 25,
                                child: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  box['name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Get.back(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('إلغاء العملية', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );

    if (selected != null) {
      selectedNetworkBox.value = selected;
      await _promptForOrderTypeAndSave();
    } else {
      isNetworkSale.value = false;
    }
  }

  Future<void> _promptForOrderTypeAndSave() async {
    String? orderTypeId = await Get.dialog<String>(
      AlertDialog(
        title: const Text('نوع الطلبية', textAlign: TextAlign.center),
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        content: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          SizedBox(width: 100, height: 50, child: OutlinedButton(onPressed: () => Get.back(result: '1'), child: const Text('سفري', style: TextStyle(fontSize: 16)))),
          SizedBox(width: 100, height: 50, child: ElevatedButton(onPressed: () => Get.back(result: '0'), child: const Text('محلي', style: TextStyle(fontSize: 16)))),
        ]),
      ),
      barrierDismissible: false,
    );
    if (orderTypeId != null) {
      if (isNetworkSale.value) {
        await _showNetworkAmountDialog(orderTypeId);
      } else {
        await _saveInvoice(orderTypeId);
      }
    } else {
      isCreditSale.value = false;
      isNetworkSale.value = false;
    }
  }

  Future<void> _showNetworkAmountDialog(String orderTypeId) async {
    final TextEditingController amountController = TextEditingController(text: netTotal.value.toString());
    final RxDouble remainingAmount = 0.0.obs;
    final double totalRequired = netTotal.value.toDouble();

    amountController.addListener(() {
      final entered = double.tryParse(amountController.text) ?? 0.0;
      remainingAmount.value = totalRequired - entered;
    });

    await Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'إتمام الدفع الشبكي',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ الإجمالي:', style: TextStyle(fontSize: 16, color: Colors.black87)),
                    Text(
                      totalRequired.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع شبكة',
                  labelStyle: const TextStyle(fontSize: 16),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.credit_card),
                ),
              ),
              const SizedBox(height: 10),
              Obx(() {
                bool isFullPayment = remainingAmount.value <= 0;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isFullPayment ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isFullPayment ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3)
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFullPayment ? Icons.check_circle : Icons.info,
                        size: 18,
                        color: isFullPayment ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isFullPayment
                            ? 'تم سداد كامل المبلغ'
                            : 'المتبقي (نقداً): ${remainingAmount.value.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: isFullPayment ? Colors.green[700] : Colors.orange[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 15
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('إلغاء', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final entered = double.tryParse(amountController.text) ?? 0.0;
                        if (entered > totalRequired) {
                          AppSnackbar.showCustomSnackbar('خطأ', 'المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي.', isError: true);
                          return;
                        }
                        if (entered <= 0) {
                          AppSnackbar.showCustomSnackbar('خطأ', 'يجب إدخال مبلغ صحيح.', isError: true);
                          return;
                        }

                        networkPaidAmount = entered;

                        Get.back();
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (remainingAmount.value > 0) {
                          AppSnackbar.showCustomSnackbar('تنبيه', 'سيتم قيد المتبقي ${remainingAmount.value.toStringAsFixed(0)} على الصندوق النقدي.');
                        }
                        await _saveInvoice(orderTypeId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text('تأكيد الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    if (!Get.isDialogOpen! && networkPaidAmount == 0.0 && isSaving.isFalse) {
      isNetworkSale.value = false;
    }
  }

  Future<void> _saveInvoice(String orderTypeId) async {
    if (isSaving.value || isInvoiceFinalized.value) return;
    
    // Strict Pre-Flight Validation
    if (!_isInvoiceDataValid()) return;

    String traLstId = '801';
    if (isCreditSale.value) traLstId = '803';

    // Trial Period Pre-Save Barrier
    final checkResult = await TrialPeriodManager.checkOnSave(invoiceTypeChar: traLstId);
    if (checkResult != TrialSaveCheckResult.allow) {
       return; // Blocked or User Cancelled
    }

    isSaving.value = true;

    try {
      final String traNo = currentInvoiceNumber.value;

      String creditAccId = '';
      String creditAccName = '';
      if (isCreditSale.value && selectedCustomer.value != null) {
        creditAccId = selectedCustomer.value!['account_id'].toString();
        creditAccName = selectedCustomer.value!['custname'].toString();
      } else if (isNetworkSale.value && selectedNetworkBox.value != null) {
        creditAccId = selectedNetworkBox.value!['id'].toString();
        creditAccName = selectedNetworkBox.value!['name'].toString();
      }

      final double currentExchangeRate = double.tryParse(exchangeRateController.text) ?? 1.0;
      final double totalValue = double.parse(netTotal.value.toString());
      final double taxValue = double.tryParse(taxController.text) ?? 0.0;
      final double discountValue = double.tryParse(discountController.text) ?? 0.0;
      String currentCurrencyId = selectedCurrencyId.value;

      String traTitle = 'طلبية زبون نقدا';

      if (isCreditSale.value) {
        traTitle = 'طلبية زبون اجل';
      }

      final String currencyName = currencies.firstWhere(
        (c) => c['id'] == currentCurrencyId,
        orElse: () => {'name': 'ريال يمني'}
      )['name'] ?? 'ريال يمني';

      final String netTotalInWords = "${convertNumberToWordsArabic(totalValue)} $currencyName";

      String trueBoxNo = creditAccId;
      String trueBoxParentName = '';
      String workingBoxId = '';

      if (isCreditSale.value) {
        workingBoxId = creditAccId;
      } else {
        try {
          final db = await DatabaseHelper.instance.database;
          int? queryBoxNo;
          
          if (isNetworkSale.value) {
            workingBoxId = selectedNetworkBox.value?['id']?.toString() ?? '';
            queryBoxNo = int.tryParse(workingBoxId);
          } else {
            workingBoxId = _userState.safeUserBoxNo.toString();
            queryBoxNo = _userState.safeUserBoxNo;
          }

          if (queryBoxNo != null) {
            final List<Map<String, dynamic>> boxResult = await db.rawQuery('''
              SELECT account_id, box_name AS control_name
              FROM sun_boxes
              WHERE box_no = ?
            ''', [queryBoxNo]);
            
            if (boxResult.isNotEmpty) {
              trueBoxNo = boxResult.first['account_id']?.toString() ?? '';
              trueBoxParentName = boxResult.first['control_name']?.toString() ?? '';
            }
          }
        } catch (e) {
          debugPrint('Error looking up box account details: $e');
        }
      }

      String finalCustomerName = isCreditSale.value ? creditAccName : customerNameController.text;

      final Map<String, dynamic> isolatedHeader = {
        'invoiceNumber': traNo,
        'orderNumber': orderNumberController.text,
        'tableNumber': tableNumberController.text,
        'transactionDate': DateFormat('yyyy-MM-dd').format(transactionDate.value),
        'yearId': _userState.safeFinancialYearName.toString(),
        'userId': _userState.safeId, 
        'userName': _userState.safeUserName,
        'branchId': _userState.safeUserBranch.toString(),
        'sectionId': _userState.safeUserDepartment.toString(),
        'storeId': selectedStoreId,
        'storeName': storeController.text,
        'currencyId': currentCurrencyId,
        'currencyName': currencyName,
        'currencyValue': currentExchangeRate,
        'discount': discountValue,
        'tax': taxValue,
        'total': total.value.toDouble(),
        'netTotal': totalValue,
        'orderTypeId': orderTypeId,
        'netTotalInWords': netTotalInWords,
        'traLstId': traLstId,
        'traTitle': traTitle,
        'customerName': finalCustomerName,
        'isNetworkPayment': isNetworkSale.value ? 1 : 0,
        'paidAmount': isNetworkSale.value ? networkPaidAmount : totalValue,
        'boxId': workingBoxId,
        'boxNo': trueBoxNo,
        'boxName': isCreditSale.value ? creditAccName : (isNetworkSale.value ? (selectedNetworkBox.value?['name']?.toString() ?? '') : _userState.safeUserBoxName),
        'boxParentName': trueBoxParentName,
        'is_synced': 0,
        'notes': '',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Ensure NO empty rows slip through
      final List<Map<String, dynamic>> isolatedDetails = addedProducts.asMap().entries
        .where((e) => e.value['isEmpty'] != true)
        .map((e) {
          final index = e.key;
          final product = e.value;
          final qty = double.tryParse(quantityControllers[index].text) ?? 0.0;
          final price = (product['price'] as num).toDouble();
          return {
            'itemId': product['id']?.toString() ?? product['number']?.toString() ?? '',
            'itemName': product['name'],
            'unit': product['unit'] ?? '',
            'quantity': qty,
            'price': price,
            'total': price * qty,
            'notes': notesControllers[index].text,
            'categoryName': product['categoryName'] ?? '',
            'discount': product['discount'] ?? 0.0,
            'tax': product['tax'] ?? 0.0,
          };
      }).toList();

      if (isolatedDetails.isEmpty) {
         AppSnackbar.showCustomSnackbar('خطأ', 'لا يمكن حفظ فاتورة ديتايلز فارغة.', isError: true);
         return;
      }

      String finalInvoiceNumber = await _restaurantRepo.insertIsolatedRestaurantInvoice(
        header: isolatedHeader, 
        details: isolatedDetails
      );

      savedTraNo.value = finalInvoiceNumber;
      await _commitOrderNumber();
      
      Map<String, dynamic> printPayload = Map<String, dynamic>.from(isolatedHeader);
      printPayload['details'] = isolatedDetails;
      lastSavedInvoiceData.value = printPayload;

      isInvoiceFinalized.value = true;

      // Post-Save Increment for License System
      await TrialPeriodManager.handlePostSave(
        invoiceTypeChar: traLstId, 
        screenTitle: 'كاشير المطعم'
      );

    
      _triggerBackgroundSync();

      await handlePrint();
      await resetForm();

    } catch (e) {
      debugPrint("Save exception: $e");
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ أثناء الحفظ. يرجى المحاولة.', isError: true);
    } finally {
      isSaving.value = false;
      networkPaidAmount = 0.0;
    }
  }

  Future<void> _triggerBackgroundSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // FIX: Ensure we use 'server_address' as the system saves it here
      final baseUrl = prefs.getString('server_address') ?? '';
      final token = prefs.getString('auth_token') ?? '';
      
      if (baseUrl.isEmpty) {
        debugPrint('⚠️ [Restaurant Sync] Aborted: baseUrl is empty.');
        return;
      }

      // 🚀 Safely dispatch to the active telemetry-wrapped generic background SyncService
      final syncService = Get.find<SyncService>();
      syncService.syncPendingRestaurantInvoices(baseUrl, token);

    } catch (e) {
      debugPrint('Background sync initialization temporarily failed: $e');
    }
  }

  Future<void> handlePrint() async {
    if (savedTraNo.value == null || lastSavedInvoiceData.value == null) {
      if (isEditMode.value) {
      } else {
        AppSnackbar.showCustomSnackbar('خطأ', 'يرجى حفظ الفاتورة أولاً قبل الطباعة.', isError: true);
        return;
      }
    }

    final invoiceDataToPrint = isEditMode.value
        ? () {
      final totalValueStr = netTotal.value.toString();

      return {
        'orderNumber': orderNumberController.text,
        'tableNumber': tableNumberController.text,
        'transactionDate': DateFormat('yyyy-MM-dd').format(transactionDate.value),
        'customerName': customerNameController.text.isNotEmpty
            ? customerNameController.text
            : (isCreditSale.value ? customerAccountController.text : 'نقداً/أو آجل قديم'),
        'details': addedProducts.asMap().entries.map((e) {
          final index = e.key;
          final product = e.value;
          final qty = double.tryParse(quantityControllers[index].text) ?? 0.0;
          final price = product['price'] as double;
          return {
            'itemId': product['id'].toString(),
            'name': product['name'],
            'number': product['number'],
            'quantity': qty,
            'price': price,
            'unit': product['unit'] ?? '',
            'categoryName': product['categoryName'] ?? '',
            'discount': product['discount'] ?? 0.0,
            'tax': product['tax'] ?? 0.0,
            'notes': notesControllers[index].text,
            'total': price * qty,
          };
        }).toList(),
        'discount': double.tryParse(discountController.text) ?? 0.0,
        'tax': double.tryParse(taxController.text) ?? 0.0,
        'netTotal': double.parse(totalValueStr),
        'netTotalInWords': '', // Utils.tafqit(totalValueStr),
        'userName': _userState.userName ?? '',
        'orderTypeId': '0',
        'traLstId': isCreditSale.value ? '803' : '801',
        'currencyName': 'ريال يمني',
      };
    }()
        : lastSavedInvoiceData.value!;

    final printTraNo = isEditMode.value ? currentInvoiceNumber.value : savedTraNo.value!;

    await _directPrintInvoice(invoiceDataToPrint, printTraNo);
  }


  Future<void> resetForm({bool clearOrderSettings = false}) async {
    isSaving.value = false;
    isInvoiceFinalized.value = false;
    savedTraNo.value = null;
    lastSavedInvoiceData.value = null;
    isEditMode.value = false;
    isCreditSale.value = false;
    isNetworkSale.value = false;
    selectedCustomer.value = null;
    selectedNetworkBox.value = null;
    networkPaidAmount = 0.0;
    isDiscountManuallyEdited.value = false;

    if (!clearOrderSettings) {
      await _updateInvoiceNumberPreview();
      transactionDate.value = DateTime.now();
      await _fetchNextOrderNumber();
      tableNumberController.text = '';
      customerNameController.text = '';
    }

    _isUpdatingDiscountProgrammatically = true;
    discountController.text = '0';
    taxController.text = '0';
    _isUpdatingDiscountProgrammatically = false;

    addedProducts.clear();
    for (var controller in quantityControllers) {
      controller.dispose();
    }
    quantityControllers.clear();
    for (var controller in notesControllers) {
      controller.dispose();
    }
    notesControllers.clear();

    for (int i = 0; i < 4; i++) {
      addedProducts.add(<String, dynamic>{'isEmpty': true});
      quantityControllers.add(TextEditingController());
      notesControllers.add(TextEditingController());
    }

    selectedRowIndex.value = null;

    calculateTotals();
  }

  // --- Print Settings Management ---

  Future<void> _loadPrintSettings() async {
    final prefs = await SharedPreferences.getInstance();
    autoPrintCustomer.value = prefs.getBool('RESTAURANT_PRINT_CUSTOMER') ?? true;
    autoPrintWaiter.value = prefs.getBool('RESTAURANT_PRINT_WAITER') ?? true;
    autoPrintKitchen.value = prefs.getBool('RESTAURANT_PRINT_KITCHEN') ?? true;
  }

  Future<void> togglePrintSetting(String type, bool newValue) async {
    if (!newValue) {
      int activeCount = (autoPrintCustomer.value ? 1 : 0) +
                        (autoPrintWaiter.value ? 1 : 0) +
                        (autoPrintKitchen.value ? 1 : 0);
      if (activeCount <= 1) {
        AppSnackbar.showCustomSnackbar('خطأ', 'يجب تحديد خيار طباعة واحد على الأقل.', isError: true);
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    if (type == 'customer') {
      autoPrintCustomer.value = newValue;
      await prefs.setBool('RESTAURANT_PRINT_CUSTOMER', newValue);
    } else if (type == 'waiter') {
      autoPrintWaiter.value = newValue;
      await prefs.setBool('RESTAURANT_PRINT_WAITER', newValue);
    } else if (type == 'kitchen') {
      autoPrintKitchen.value = newValue;
      await prefs.setBool('RESTAURANT_PRINT_KITCHEN', newValue);
    }
  }

  void showPrintSettingsDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إعدادات الطباعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Obx(() => CheckboxListTile(
              title: const Text('طباعة فاتورة الزبون'),
              value: autoPrintCustomer.value,
              onChanged: (val) => togglePrintSetting('customer', val ?? true),
              activeColor: Colors.blue,
            )),
            Obx(() => CheckboxListTile(
              title: const Text('طباعة فاتورة المباشر'),
              value: autoPrintWaiter.value,
              onChanged: (val) => togglePrintSetting('waiter', val ?? true),
              activeColor: Colors.blue,
            )),
            Obx(() => CheckboxListTile(
              title: const Text('طباعة إيصالات المطبخ'),
              value: autoPrintKitchen.value,
              onChanged: (val) => togglePrintSetting('kitchen', val ?? true),
              activeColor: Colors.blue,
            )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.print_disabled, color: Colors.orange),
              title: const Text('طباعة الفواتير المعلقة'),
              onTap: () {
                Get.back(); // close bottom sheet
                checkAndPrintPendingInvoices(); // Trigger manual dialog
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- End Print Settings Management ---

  Future<void> _fetchNextOrderNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _userState.id ?? '0';
    final key = 'order_seq_$userId';
    int sequence = (prefs.getInt(key) ?? 0) + 1;
    orderNumberController.text = sequence.toString();
  }

  Future<void> _commitOrderNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _userState.id ?? '0';
    final key = 'order_seq_$userId';
    int sequence = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, sequence);
  }
}


