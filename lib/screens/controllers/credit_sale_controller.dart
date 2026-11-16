import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/models/full_sales_invoice.dart';
import 'package:untitled4/models/sun_customer.dart';
import 'package:untitled4/repositories/auth_repository.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/sales_repository.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/screens/controllers/credit_calculations_controller.dart';
import 'package:untitled4/screens/controllers/credit_input_section_controller.dart';
import 'package:untitled4/screens/controllers/credit_products_controller.dart';
import 'package:untitled4/screens/controllers/credit_transaction_header_controller.dart';
import 'package:untitled4/screens/pdf/pdf_view.dart';
import 'package:untitled4/screens/previous_invoices_screen.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/number_to_words_converter.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/utils/trial_period_manager.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:untitled4/utils/whatsapp_helper.dart';
import 'package:untitled4/screens/pdf/pdf_disegn.dart';
import '../../i_price_change_permission.dart';
import '../../services/lookups_service.dart.dart';

const String _kCurrentScreenName = 'CreditSaleScreen';

class CreditSaleController extends GetxController implements IPriceChangePermission {
  late final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController = Get.find<InvoiceTemplatesController>();
  final SalesRepository _salesRepository = SalesRepository();
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final AuthRepository _authRepository = AuthRepository();
  final ReportRepository _reportRepository = ReportRepository();
  final LookupsService _lookupsService = Get.find<LookupsService>();

  late final CreditTransactionHeaderController headerController;
  late final CreditInputSectionController inputController;
  late final CreditProductsController productsController;
  late final CreditCalculationsController calculationsController;

  final RxBool isLoading = false.obs;
  final RxBool isManualSyncing = false.obs;
  late TextEditingController customerNameController;
  final Rxn<SunCustomer> selectedCustomer = Rxn<SunCustomer>();
  final RxList<SunCustomer> allAvailableCustomers = <SunCustomer>[].obs;
  final RxnString currentInvoiceId = RxnString();
  final RxString invoiceCreatorName = ''.obs;

  final RxBool isReadOnly = false.obs;
  final RxBool showExpiryDate = true.obs;
  final RxBool showBatchNumber = true.obs;
  final RxBool showBonusQuantity = true.obs;

  final RxBool isAutoWhatsAppEnabled = false.obs;
  final RxString whatsappPackage = 'com.whatsapp'.obs;

  @override
  final RxBool canUserChangePrice = false.obs;

  late final String _tag;

  CreditSaleController({String? initialInvoiceId, required String controllerTag}) {
    _tag = controllerTag;

    if (initialInvoiceId != null) currentInvoiceId.value = initialInvoiceId;

    if (userState.canAccessScreen(_kCurrentScreenName)) {
      canUserChangePrice.value = userState.canChangePrice(_kCurrentScreenName);
    }

    headerController = Get.put(CreditTransactionHeaderController(), tag: _tag);
    inputController = Get.put(CreditInputSectionController(controllerTag: _tag), tag: _tag);
    calculationsController = Get.put(CreditCalculationsController(), tag: _tag);
    productsController = Get.put(CreditProductsController(controllerTag: _tag), tag: _tag);
  }

  @override
  void onInit() {
    super.onInit();
    customerNameController = TextEditingController();

    if (!userState.canAccessScreen(_kCurrentScreenName)) {
      showMessage('ليس لديك صلاحية الوصول.', isError: true);
      Future.delayed(Duration.zero, () => Get.back());
      return;
    }
    productsController.isReturnMode = false;

    _initializeScreenData();
    _triggerBackgroundSync();
    _loadTableSettings();
  }

  Future<void> _initializeScreenData() async {
    isLoading.value = true;
    try {
      await Future.wait([
        _invoiceTemplatesController.fetchInvoiceTemplates(),
        _ensureLookupsLoaded(),
      ]);

      final args = Get.arguments;
      if (args != null && args is Map && args['isRemote'] == true) {
        isReadOnly.value = true;
        await _loadRemoteInvoice(args);
      } else {
        isReadOnly.value = false;
        if (currentInvoiceId.value != null) {
          await _loadInvoiceForEditing(currentInvoiceId.value!);
        } else {
          await Future.wait([
            headerController.generateAndSetNextTransactionNumber(),
            Future.microtask(() => _loadDataFromCache()),
            inputController.loadInitialData(),
          ]);
          invoiceCreatorName.value = userState.safeUserName;
        }
      }
    } catch (e) {
      showMessage('حدث خطأ أثناء تجهيز الصفحة.', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadTableSettings() async {
    final prefs = await SharedPreferences.getInstance();
    showExpiryDate.value = prefs.getBool('showExpiryDate') ?? true;
    showBatchNumber.value = prefs.getBool('showBatchNumber') ?? true;
    showBonusQuantity.value = prefs.getBool('showBonusQuantity') ?? true;
    isAutoWhatsAppEnabled.value = prefs.getBool('isAutoWhatsAppEnabled') ?? false;
    whatsappPackage.value = prefs.getString('whatsappPackagePreference') ?? 'com.whatsapp';
  }

  Future<void> toggleTableSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'expiry':
        showExpiryDate.value = value;
        await prefs.setBool('showExpiryDate', value);
        break;
      case 'batch':
        showBatchNumber.value = value;
        await prefs.setBool('showBatchNumber', value);
        break;
      case 'bonus':
        showBonusQuantity.value = value;
        await prefs.setBool('showBonusQuantity', value);
        break;
      case 'autoWhatsApp':
        isAutoWhatsAppEnabled.value = value;
        await prefs.setBool('isAutoWhatsAppEnabled', value);
        break;
    }
    productsController.products.refresh();
  }

  Future<void> _loadRemoteInvoice(Map args) async {
    try {
      final String transactionId = args['invoiceId'].toString();
      final int branchId = int.parse(args['remoteBranchId'].toString());
      final String year = args['remoteYear'].toString();

      final prefs = await SharedPreferences.getInstance();
      final String? serverUrl = prefs.getString('server_address');

      if (serverUrl == null || serverUrl.isEmpty) {
        throw Exception('عنوان السيرفر غير محفوظ');
      }

      final FullSalesInvoice fullInvoice = await _salesRepository.fetchInvoiceFromApi(
        serverUrl: serverUrl,
        token: "",
        transactionId: transactionId,
        branchId: branchId,
        year: year,
      );

      final invoiceData = fullInvoice.sale;

      currentInvoiceId.value = invoiceData.id;
      headerController.transactionNumber.value = invoiceData.transactionNumber;
      headerController.selectedDate.value = invoiceData.date;
      invoiceCreatorName.value = invoiceData.userName ?? '';

      _loadDataFromCache();

      await Future.wait([
        inputController.fetchAndAddMissingStore(invoiceData.storeNo, fallbackName: invoiceData.storeName),
      ]);

      inputController.selectedStore.value = invoiceData.storeName ?? '';
      inputController.updateSelectedCurrency(invoiceData.currency);

      if (invoiceData.accountNo.isNotEmpty) {
        final localCustomer = allAvailableCustomers.firstWhereOrNull((c) => c.customerNo.toString() == invoiceData.accountNo);
        if (localCustomer != null) {
          await _selectCustomerAsync(localCustomer);
        } else {
          customerNameController.text = invoiceData.customerName ?? '';
        }
      } else {
        customerNameController.text = invoiceData.customerName ?? '';
      }

      _setCollectorAndAgent(invoiceData.collectorId, invoiceData.agentId);

      calculationsController.updateAll(
        total: invoiceData.total,
        tax: invoiceData.tax ?? 0.0,
        totalItemDiscount: invoiceData.discount ?? 0.0,
      );
      calculationsController.netTotal.value = invoiceData.netTotal ?? 0.0;

      await productsController.loadInvoiceProducts(fullInvoice.items.map((e) => {
        'item_no': e.itemNo,
        'item_name': e.itemName,
        'item_price': e.itemPrice,
        'quantity': e.quantity,
        'bonus_quantity': e.bonusQuantity,
        'item_discount': e.itemDiscount,
        'total_item': e.total,
        'is_taxable': e.isTaxable,
        'tax_rate': e.taxRate,
        'is_discountable': e.isDiscountable,
        'discount_rate': e.discountRate,
        'item_unit': e.itemUnit,
        'pack_factor': e.packFactor,
        'expiry_date': e.expiryDate,
        'batch_no': e.batchNumber,
        'stock_balance': e.stockBalance,
        'cost_center_no': e.costCenterNo,
        'cost_price': e.costPrice,
      }).toList());

    } catch (e) {
      showMessage('فشل جلب الفاتورة من السيرفر: $e', isError: true);
      Get.back();
    }
  }

  Future<void> _ensureLookupsLoaded() async {
    if (_lookupsService.productsList.isEmpty || _lookupsService.customersList.isEmpty) {
      try {
        await _lookupsService.loadAllLookupData();
      } catch (e) {
        showMessage('فشل تحميل البيانات الأساسية', isError: true);
      }
    }
  }

  @override
  void onClose() {
    customerNameController.dispose();
    Get.delete<CreditTransactionHeaderController>(tag: _tag, force: true);
    Get.delete<CreditInputSectionController>(tag: _tag, force: true);
    Get.delete<CreditCalculationsController>(tag: _tag, force: true);
    Get.delete<CreditProductsController>(tag: _tag, force: true);
    super.onClose();
  }

  void showMessage(String message, {bool isError = true}) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    final String title = isError ? 'تنبيه' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }

  void _loadDataFromCache() {
    try {
      allAvailableCustomers.assignAll(_lookupsService.customersList);
    } catch (e) {
    }
  }

  List<SunCustomer> filterCustomers(String query) {
    if (query.isEmpty) return allAvailableCustomers.toList();
    final lower = query.toLowerCase();
    return allAvailableCustomers.where((c) =>
    c.customerName.toLowerCase().contains(lower) ||
        c.customerNo.toString().contains(lower)
    ).toList();
  }

  void selectCustomer(SunCustomer customer) {
    _selectCustomerAsync(customer);
  }

  Future<void> _selectCustomerAsync(SunCustomer customer) async {
    if (isClosed) return;
    selectedCustomer.value = customer;
    customerNameController.text = customer.customerName;

    if (customer.accountId == null) {
      inputController.clearCurrencies();
      showMessage('هذا العميل غير مرتبط بحساب محاسبي.', isError: true);
      return;
    }

    inputController.isLoadingCurrencies.value = true;

    try {
      List<SunCurrency> customerCurrencies =
      await _lookupsRepository.fetchCurrenciesForCustomer(customer.customerNo);

      if (customerCurrencies.isEmpty) {
        showMessage('تنبيه: هذا العميل غير مرتبط بأي عملة (سيتم إظهار القائمة فارغة).', isError: false);
      }

      if (isClosed) return;

      inputController.loadCurrenciesForCustomer(customerCurrencies);

    } catch (e) {
      if (!isClosed) {
        showMessage('فشل تحميل عملات العميل.', isError: true);
        inputController.clearCurrencies();
      }
    } finally {
      inputController.isLoadingCurrencies.value = false;
    }
  }

  Future<void> _loadInvoiceForEditing(String invoiceId) async {
    if (isClosed) return;
    isLoading.value = true;

    try {
      await _ensureLookupsLoaded();

      final FullSalesInvoice fullInvoice = await _salesRepository.loadInvoice(invoiceId);
      if (isClosed) return;

      final invoiceData = fullInvoice.sale;

      if (invoiceData.userId != null) {
        _authRepository.fetchUserNameByUserNo(invoiceData.userId!).then((name) {
          if (!isClosed && name != null) invoiceCreatorName.value = name;
        });
      } else {
        if (!isClosed) invoiceCreatorName.value = 'مستخدم غير معروف';
      }

      _loadDataFromCache();

      final int? loadedStoreNo = invoiceData.storeNo;
      await inputController.loadInitialData();

      if (loadedStoreNo != null) {
        await inputController.fetchAndAddMissingStore(loadedStoreNo);
      }

      if (isClosed) return;

      currentInvoiceId.value = invoiceData.id;
      headerController.transactionNumber.value = invoiceData.transactionNumber;
      headerController.selectedDate.value = invoiceData.date;

      final String accountNo = invoiceData.accountNo;
      final foundCustomer = allAvailableCustomers.firstWhereOrNull(
              (cust) => cust.customerNo.toString() == accountNo
      );

      if (foundCustomer != null) {
        await _selectCustomerAsync(foundCustomer);
      } else {
        customerNameController.text =
            invoiceData.customerName ?? 'عميل غير معروف ($accountNo)';
        selectedCustomer.value = null;
      }

      final storeName = inputController.stores.firstWhereOrNull((s) => s.noStore == loadedStoreNo)?.nameStore;
      inputController.selectedStore.value = storeName ?? '';
      inputController.updateSelectedCurrency(invoiceData.currency);

      _setCollectorAndAgent(invoiceData.collectorId, invoiceData.agentId);

      calculationsController.updateAll(
        total: invoiceData.total,
        tax: 0.0,
        totalItemDiscount: invoiceData.discount ?? 0.0,
      );
      calculationsController.netTotal.value = invoiceData.netTotal ?? 0.0;

      final loadedItems = fullInvoice.items.map((item) {
        final productDetails = _lookupsService.productsList.firstWhereOrNull(
                (p) => p['item_no']?.toString() == item.itemNo?.toString());

        return {
          'item_no': item.itemNo,
          'item_name': item.itemName,
          'item_price': item.itemPrice,
          'quantity': item.quantity,
          'bonus_quantity': item.bonusQuantity,
          'item_discount': item.itemDiscount,
          'total_item': item.total,
          'is_taxable': item.isTaxable,
          'tax_rate': item.taxRate,
          'is_discountable': item.isDiscountable,
          'discount_rate': item.discountRate,
          'isEmpty': false,
          'item_unit': item.itemUnit,
          'cost_center_no': productDetails?['cost_center_no'],
          'pack_factor': item.packFactor,
          'expiry_date': item.expiryDate,
          'batch_no': item.batchNumber,
          'stock_balance': item.stockBalance,
          'cost_price': item.costPrice,
        };
      }).toList();

      await productsController.loadInvoiceProducts(loadedItems);

    } catch (e) {
      if (!isClosed) {
        showMessage('خطأ أثناء تحميل الفاتورة.', isError: true);
        resetForm();
      }
    } finally {
      if (!isClosed) isLoading.value = false;
    }
  }

  void _setCollectorAndAgent(int? collectorId, int? agentId) {
    if (inputController.allCollectors.isNotEmpty && collectorId != null) {
      inputController.collectorNameController.text = inputController.allCollectors.firstWhereOrNull(
              (c) => c['id'] == collectorId)?['collector_name'] ?? '';
    }
    if (inputController.allAgents.isNotEmpty && agentId != null) {
      inputController.agentNameController.text = inputController.allAgents.firstWhereOrNull(
              (a) => a['id'] == agentId)?['salesperson_name'] ?? '';
    }
    inputController.selectedCollectorId.value = collectorId;
    inputController.selectedAgentId.value = agentId;
  }

  Future<void> saveSale({bool showSuccessMessage = true}) async {
    if (isReadOnly.value) {
      showMessage('هذه الفاتورة للعرض فقط ولا يمكن تعديلها.', isError: true);
      return;
    }

    final actualProducts = productsController.products.where((item) => item['isEmpty'] != true).toList();

    if (actualProducts.isEmpty) {
      showMessage('أضف أصنافاً أولاً.', isError: true);
      return;
    }
    if (selectedCustomer.value == null || selectedCustomer.value!.accountId == null) {
      showMessage('يرجى اختيار عميل مرتبط بحساب.', isError: true);
      return;
    }
    if (inputController.selectedStore.value.isEmpty) {
      showMessage('يرجى اختيار المخزن.', isError: true);
      return;
    }
    if (inputController.selectedCurrency.value.isEmpty) {
      showMessage('يرجى اختيار العملة.', isError: true);
      return;
    }
    final bool hasZeroValue = actualProducts.any((item) {
      final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final double price = (item['item_price'] as num?)?.toDouble() ?? 0.0;
      return qty <= 0 || price <= 0;
    });
    if (hasZeroValue) {
      showMessage('لا يمكن حفظ الفاتورة. يوجد أصناف بكمية أو سعر يقل أو يساوي صفر.', isError: true);
      return;
    }

    isLoading.value = true;
    final isUpdate = currentInvoiceId.value != null;

    if (!isUpdate) {
      final checkResult = await TrialPeriodManager.checkOnSave(invoiceTypeChar: 'ج');
      if (checkResult != TrialSaveCheckResult.allow) {
        isLoading.value = false;
        return;
      }
    }

    try {
      final saleHeader = _prepareSaleHeader();
      final saleItems = _prepareSaleItems(actualProducts);
      final ledgerPostings = await _prepareLedgerPostings(actualProducts);

      if (!isUpdate) {
        if (!userState.canAdd(_kCurrentScreenName)) throw Exception('PERMISSION_DENIED');

        final result = await _salesRepository.saveCompleteSale(
          saleHeader: saleHeader,
          saleItems: saleItems,
          ledgerPostings: ledgerPostings,
        );

        final newSaleId = result['id'].toString();
        final newTransactionNumber = result['transaction_number'].toString();

        if (newSaleId.isNotEmpty) {
          currentInvoiceId.value = newSaleId;
          headerController.transactionNumber.value = newTransactionNumber;
        }

        await TrialPeriodManager.handlePostSave(invoiceTypeChar: 'ج', screenTitle: 'البيع الآجل');

        if (showSuccessMessage) {
          showMessage('تم الحفظ بنجاح. رقم الفاتورة: $newTransactionNumber', isError: false);
        }

      } else {
        if (!userState.canEdit(_kCurrentScreenName)) throw Exception('PERMISSION_DENIED');

        await _salesRepository.updateCompleteSale(
          invoiceId: int.parse(currentInvoiceId.value!),
          saleHeader: saleHeader,
          saleItems: saleItems,
          ledgerPostings: ledgerPostings,
        );

        if (showSuccessMessage) {
          showMessage('تم التحديث بنجاح', isError: false);
        }
      }

      _triggerBackgroundSync();

      if (!isUpdate && isAutoWhatsAppEnabled.value) {
        // Fire and forget
        _autoSendWhatsApp(headerController.transactionNumber.value);
      }

    } catch (e) {
      if (e.toString().contains('PERMISSION_DENIED')) {
        showMessage('ليس لديك صلاحية لإتمام العملية.', isError: true);
      } else {
        showMessage('فشلت العملية. يرجى التحقق من الاتصال.', isError: true);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Map<String, dynamic> _prepareSaleHeader() {
    final int? storeNoToSave = inputController.selectedStoreNo;
    if (storeNoToSave == null) throw Exception('المخزن غير صالح');

    final selectedCurrencyObj = inputController.currencies.firstWhereOrNull(
        (c) => c.currencyName == inputController.selectedCurrency.value);

    return {
      'transaction_number': currentInvoiceId.value == null ? '' : headerController.transactionNumber.value,
      'date': headerController.selectedDate.value.toIso8601String(),
      'account_no': selectedCustomer.value!.customerNo.toString(),
      'customer_name': selectedCustomer.value!.customerName,
      'currency': inputController.selectedCurrency.value,
      'currency_id': selectedCurrencyObj?.currencyNo ?? 1,
      'currency_rate': inputController.selectedExchangeRate.value,
      'store_no': storeNoToSave,
      'collector_id': inputController.selectedCollectorId.value,
      'agent_id': inputController.selectedAgentId.value,
      'total': calculationsController.total.value,
      'tax': calculationsController.tax.value,
      'discount': calculationsController.discount.value,
      'net_total': calculationsController.netTotal.value,
      'invoice_type_char': 'ج',
      'sun_year': userState.safeFinancialYearName,
      'branch_id': userState.userBranch,
      'department_id': userState.userDepartment,
      'source_last_updated_at': DateTime.now().toString(),
      'is_synced': 0,
      'user_id': userState.userNo,
    };
  }

  List<Map<String, dynamic>> _prepareSaleItems(List<Map<String, dynamic>> products) {
    return products.map((item) {
      final String? itemNoString = item['item_no']?.toString();
      if (itemNoString == null || itemNoString.isEmpty) return null;

      final productDetails = _lookupsService.productsList.firstWhereOrNull(
          (p) => p['item_no']?.toString() == itemNoString);
      final int itemCurrencyId = (productDetails?['currency_no'] as num?)?.toInt() ?? 1;

      final itemCurrencyObj = _lookupsService.currenciesList.firstWhereOrNull(
          (c) => c.currencyNo == itemCurrencyId);
      final double itemCurrencyRate = itemCurrencyObj?.currencyRate ?? 1.0;

      double calculatedStockBalance = 0.0;
      try {
        final List<dynamic> stockList = item['stock_list'] ?? [];
        final String? selectedExpiry = item['expiry_date'];
        final String? selectedBatch = item['batch_no'];
        final double packFactor = (item['pack_factor'] as num?)?.toDouble() ?? 1.0;

        final matchingBatch = stockList.firstWhereOrNull(
                (batch) => batch['expiry_date'] == selectedExpiry &&
                (selectedBatch == null || selectedBatch.isEmpty || (batch['batch_no']?.toString() ?? '') == selectedBatch)
        );

        if (matchingBatch != null) {
          final double baseQuantity = (matchingBatch['quantity'] as num?)?.toDouble() ?? 0.0;
          calculatedStockBalance = baseQuantity / (packFactor > 0 ? packFactor : 1.0);
        }
      } catch (e) {
        calculatedStockBalance = 0.0;
      }

      return {
        'item_no': itemNoString,
        'quantity': (item['quantity'] as num?)?.toInt() ?? 0,
        'bonus_quantity': (item['bonus_quantity'] as num?)?.toInt() ?? 0,
        'item_price': (item['item_price'] as num?)?.toDouble() ?? 0.0,
        'cost_price': (item['cost_price'] as num?)?.toDouble() ?? 0.0,
        'item_discount': (item['item_discount'] as num?)?.toDouble() ?? 0.0,
        'total': (item['total_item'] as num?)?.toDouble() ?? 0.0,
        'created_at': DateTime.now().toIso8601String(),
        'item_unit': item['item_unit']?.toString() ?? '',
        'pack_factor': (item['pack_factor'] as num?)?.toDouble() ?? 1.0,
        'expiry_date': item['expiry_date'] ?? '',
        'batch_no': item['batch_no']?.toString() ?? '',
        'stock_balance': calculatedStockBalance,
        'item_currency_id': itemCurrencyId,
        'item_currency_rate': itemCurrencyRate,
      };
    }).whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> _prepareLedgerPostings(List<Map<String, dynamic>> products) async {
    final customerAccountId = selectedCustomer.value!.accountId;
    if (customerAccountId == null) throw Exception('العميل غير مربوط بحساب.');

    // لا يوجد حساب افتراضي بديل: كل صنف يجب أن يحمل حسابه الإيرادي (وحساب
    // التكلفة عند وجود تكلفة له)، وإلا نوقف الحفظ برسالة تحدّد الصنف المشكل.
    for (final item in products) {
      final bool hasRevenueAccount =
          item['sales_revenue_account_id'] != null &&
          item['sales_revenue_account_id'].toString().trim().isNotEmpty;
      if (!hasRevenueAccount) {
        throw Exception('الصنف "${item['item_name']?.toString().trim()}" غير مرتبط بحساب إيرادي. يرجى تصحيح بيانات الصنف.');
      }

      final double unitCost = (item['cost_price'] as num?)?.toDouble() ?? 0.0;
      final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final bool needsCogsAccount = (qty * unitCost) > 0;
      final bool hasCogsAccount =
          item['cogs_account_id'] != null &&
          item['cogs_account_id'].toString().trim().isNotEmpty;
      if (needsCogsAccount && !hasCogsAccount) {
        throw Exception('الصنف "${item['item_name']?.toString().trim()}" غير مرتبط بحساب تكلفة. يرجى تصحيح بيانات الصنف.');
      }
    }

    // أسماء الحسابات تُجلب دفعة واحدة لاستخدامها في حقل [entity_name].
    final Set<String> accountIds = {};
    for (final item in products) {
      accountIds.add(item['sales_revenue_account_id'].toString());
      if ((item['cogs_account_id'] != null) &&
          item['cogs_account_id'].toString().trim().isNotEmpty) {
        accountIds.add(item['cogs_account_id'].toString());
      }
    }
    final Map<String, String> accountNames =
        await _salesRepository.fetchAccountNameMap(accountIds);

    final inventoryAccountId = inputController.selectedStoreAccountId;
    if (inventoryAccountId == null) {
      throw Exception('المخزن المختار غير مرتبط بحساب محاسبي');
    }

    if (inputController.currencies.isEmpty) throw Exception("العملات غير محملة.");

    final mainCurrency = inputController.currencies.firstWhereOrNull((c) => c.currencyName == inputController.selectedCurrency.value);
    if (mainCurrency == null) throw Exception("العملة المختارة غير صالحة.");

    final baseExchangeRate = inputController.selectedExchangeRate.value;
    final netTotalInBase = calculationsController.netTotal.value * baseExchangeRate;
    final transactionRef = headerController.transactionNumber.value;
    final transactionDate = headerController.selectedDate.value.toIso8601String();

    final String fixedDescription = (transactionRef.isEmpty)
        ? 'مقابل فاتورة بيع آجل (جديد)'
        : 'مقابل فاتورة بيع آجل رقم $transactionRef';

    List<Map<String, dynamic>> postings = [];

    postings.add({
      'account_id': customerAccountId,
      'debit': netTotalInBase,
      'credit': 0,
      'entity_name': selectedCustomer.value!.customerName,
      'description': fixedDescription,
      'transaction_date': transactionDate,
      'transaction_type': 'فاتورة مبيعات اجل',
      'transaction_ref': transactionRef,
      'beneficiary_name': selectedCustomer.value!.customerName,
      'original_amount': calculationsController.netTotal.value,
      'currency_id': mainCurrency.currencyNo,
      'exchange_rate': baseExchangeRate,
      'cost_center_no': null,
    });

    for (var item in products) {
      final double itemTotal = (item['total_item'] as num?)?.toDouble() ?? 0.0;
      final double itemTotalInBase = itemTotal * baseExchangeRate;

      final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final double unitCost = (item['cost_price'] as num?)?.toDouble() ?? 0.0;
      final double totalItemCost = qty * unitCost;
      final double totalItemCostInBase = totalItemCost; // Cost is already local base currency

      final itemRevenueAccountId = item['sales_revenue_account_id'].toString();
      final itemCogsAccountId = item['cogs_account_id'].toString();

      postings.add({
        'account_id': itemRevenueAccountId,
        'debit': 0,
        'credit': itemTotalInBase,
        'entity_name': accountNames[itemRevenueAccountId] ?? itemRevenueAccountId,
        'description': fixedDescription,
        'transaction_date': transactionDate,
        'transaction_type': 'فاتورة مبيعات اجل',
        'transaction_ref': transactionRef,
        'beneficiary_name': selectedCustomer.value!.customerName,
        'original_amount': itemTotal,
        'currency_id': mainCurrency.currencyNo,
        'exchange_rate': baseExchangeRate,
        'cost_center_no': item['cost_center_no'],
      });

      if (totalItemCostInBase > 0) {
        postings.add({
          'account_id': itemCogsAccountId,
          'debit': totalItemCostInBase,
          'credit': 0,
            'entity_name': accountNames[itemCogsAccountId] ?? itemCogsAccountId,
          'description': fixedDescription,
          'transaction_date': transactionDate,
          'transaction_type': 'فاتورة مبيعات اجل',
          'transaction_ref': transactionRef,
          'beneficiary_name': selectedCustomer.value!.customerName,
          'original_amount': totalItemCost,
          'currency_id': mainCurrency.currencyNo,
          'exchange_rate': baseExchangeRate,
          'cost_center_no': null,
        });

        postings.add({
          'account_id': inventoryAccountId,
          'debit': 0,
          'credit': totalItemCostInBase,
          'entity_name': inputController.selectedStore.value,
          'description': fixedDescription,
          'transaction_date': transactionDate,
          'transaction_type': 'فاتورة مبيعات اجل',
          'transaction_ref': transactionRef,
          'beneficiary_name': selectedCustomer.value!.customerName,
          'original_amount': totalItemCost,
          'currency_id': mainCurrency.currencyNo,
          'exchange_rate': baseExchangeRate,
          'cost_center_no': item['cost_center_no'],
        });
      }
    }
    return postings;
  }

  void resetForm() {
    productsController.resetProducts();
    customerNameController.clear();
    selectedCustomer.value = null;
    calculationsController.resetCalculations();
    headerController.resetHeader();
    inputController.resetDropdowns();
    currentInvoiceId.value = null;
    invoiceCreatorName.value = userState.safeUserName;
    isReadOnly.value = false;
  }

  Future<double> _fetchCustomerBalance() async {
    try {
      if (selectedCustomer.value == null || selectedCustomer.value!.accountId == null) return 0.0;

      final String accountId = selectedCustomer.value!.accountId!;

      final selectedCurrencyObj = inputController.currencies.firstWhereOrNull(
              (c) => c.currencyName == inputController.selectedCurrency.value
      );
      final int currencyId = selectedCurrencyObj?.currencyNo ?? 1;

      final String yearStr = userState.safeFinancialYearName;
      final DateTime fromDate = DateTime(int.tryParse(yearStr) ?? DateTime.now().year, 1, 1);
      final DateTime toDate = DateTime.now();

      final response = await _reportRepository.getAccountStatement(
        accountId: accountId,
        currencyId: currencyId,
        startDate: fromDate.toIso8601String(),
        endDate: toDate.toIso8601String(),
        year: yearStr,
        branchId: userState.safeUserBranch,
      );

      return response.totalPeriodDebit - response.totalPeriodCredit;

    } catch (e) {
      return 0.0;
    }
  }

  void printSale() async {
    try {
      if (!userState.canPrint(_kCurrentScreenName)) {
        showMessage('ليس لديك صلاحية للطباعة.', isError: true);
        return;
      }
      final actualProducts = productsController.products.where((item) => item['isEmpty'] != true).toList();
      if (actualProducts.isEmpty) {
        showMessage('أضف أصنافاً للطباعة أولاً.', isError: true);
        return;
      }

      _invoiceTemplatesController.selectTemplate(_kCurrentScreenName);
      if (_invoiceTemplatesController.companyNameController.text.isEmpty) {
        showMessage('يرجى ضبط قالب الفاتورة في الإعدادات.', isError: true);
        return;
      }

      if (inputController.selectedCurrency.value.isEmpty) {
        showMessage('يرجى اختيار العملة قبل الطباعة.', isError: true);
        return;
      }

      if (!isReadOnly.value) {
        await saveSale(showSuccessMessage: false);
      }

      if (currentInvoiceId.value == null) return;

      isLoading.value = true;
      final double customerCurrentBalance = await _fetchCustomerBalance();
      isLoading.value = false;

      final String netTotalInWords = convertNumberToWordsArabic(calculationsController.netTotal.value);
      final bool? shouldResetForm = await Get.to<bool?>(
            () => PdfView(
          saleId: currentInvoiceId.value,
          transactionNumber: headerController.transactionNumber.value,
          date: headerController.selectedDate.value,
          products: actualProducts,
          total: calculationsController.total.value,
          tax: calculationsController.tax.value,
          discount: calculationsController.discount.value,
          customerName: selectedCustomer.value?.customerName ?? 'عميل غير محدد',
          storeName: inputController.selectedStore.value,
          accountNo: selectedCustomer.value?.customerNo.toString() ?? '',
          currency: inputController.selectedCurrency.value,
          collector: inputController.collectorNameController.text.trim(),
          salesRep: inputController.agentNameController.text.trim(),
          netTotal: calculationsController.netTotal.value,
          userName: invoiceCreatorName.value.isNotEmpty ? invoiceCreatorName.value : userState.userName,
          invoiceTypeChar: 'ج',
          companyName: _invoiceTemplatesController.companyNameController.text,
          companyAddress: _invoiceTemplatesController.addressDetailsController.text,
          contactInfo: _invoiceTemplatesController.contactInfoController.text,
          thanksMessage: _invoiceTemplatesController.thanksMessageController.text,
          logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
          showLogo: _invoiceTemplatesController.showLogo.value,
          userBranchName: userState.safeUserBranchName,
          userDepartmentName: userState.safeUserDepartmentName,
          netTotalInWords: netTotalInWords,
          customerBalance: customerCurrentBalance,
          customerPhone: selectedCustomer.value?.phoneNumber,
        ),
      );

      if (shouldResetForm == true) {
        resetForm();
      }
    } catch (e) {
      isLoading.value = false;
      showMessage("حدث خطأ غير متوقع أثناء محاولة الطباعة.", isError: true);
    }
  }

  Future<bool?> navigateToPreviousInvoices() async {
    if (isReadOnly.value) {
      showMessage('لا يمكن البحث في الفواتير السابقة أثناء عرض فاتورة من السيرفر.', isError: true);
      return null;
    }

    if (userState.canSearch(_kCurrentScreenName)) {
      final dynamic result = await Get.to(() => const PreviousInvoicesScreen(), arguments: {'invoiceType': 'ج'});
      if (result != null && result is String) {
        await _loadInvoiceForEditing(result);
        return false;
      } else if (result == true) {
        return true;
      }
      return false;
    } else {
      showMessage('ليس لديك صلاحية للبحث.', isError: true);
      return null;
    }
  }

  bool canPerformAction(String action) {
    switch (action) {
      case 'add': return userState.canAdd(_kCurrentScreenName);
      case 'edit': return userState.canEdit(_kCurrentScreenName);
      case 'print': return userState.canPrint(_kCurrentScreenName);
      case 'search':
        if (isReadOnly.value) return false;
        return userState.canSearch(_kCurrentScreenName);
      default: return false;
    }
  }

  Future<void> performManualSync() async {
    if (isManualSyncing.value) return;

    isManualSyncing.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedAddress = prefs.getString('server_address');

      if (savedAddress != null && savedAddress.isNotEmpty) {
        final String fullApiUrl = 'http://$savedAddress/api/Transaction/sync-invoice';

        final int syncedCount = await _salesRepository.syncSalesToRemote(
            fullApiUrl,
            "",
            invoiceTypeChar: 'ج'
        );

        if (syncedCount > 0) {
          showMessage('تمت مزامنة $syncedCount فاتورة بنجاح', isError: false);
        } else {
          showMessage('لا توجد فواتير غير متزامنة حالياً', isError: false);
        }
      }
    } catch (e) {
      log("Error during manual sync: $e");
      showMessage('فشل الاتصال بالسيرفر', isError: true);
    } finally {
      isManualSyncing.value = false;
    }
  }

  void _triggerBackgroundSync() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? savedAddress = prefs.getString('server_address');

        if (savedAddress != null && savedAddress.isNotEmpty) {
          final String fullApiUrl = 'http://$savedAddress/api/Transaction/sync-invoice';

          await _salesRepository.syncSalesToRemote(
              fullApiUrl,
              "",
              invoiceTypeChar: 'ج'
          );
          await _salesRepository.deleteOldSyncedSales();
        }
      } catch (e) {
        log("Background sync error: $e");
      }
    });
  }

  Future<void> setWhatsAppPackage(String packageName) async {
    whatsappPackage.value = packageName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('whatsappPackagePreference', packageName);
  }

  Future<void> _autoSendWhatsApp(String transactionNumber) async {
    final phone = selectedCustomer.value?.phoneNumber;
    if (phone == null || phone.isEmpty) return; // Silent exit

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      _invoiceTemplatesController.selectTemplate(_kCurrentScreenName);
      final double customerCurrentBalance = await _fetchCustomerBalance();
      final String netTotalInWords = convertNumberToWordsArabic(calculationsController.netTotal.value);
      final actualProducts = productsController.products.where((item) => item['isEmpty'] != true).toList();

      final Uint8List pdfBytes = await PdfInventoryData.generate(
        pageType: PdfPageType.a4,
        transactionNumber: transactionNumber,
        date: headerController.selectedDate.value,
        products: actualProducts,
        total: calculationsController.total.value,
        cashBox: null,
        collector: inputController.collectorNameController.text.trim(),
        salesRep: inputController.agentNameController.text.trim(),
        currency: inputController.selectedCurrency.value,
        customerName: selectedCustomer.value?.customerName ?? 'عميل غير محدد',
        discount: calculationsController.discount.value,
        netTotal: calculationsController.netTotal.value,
        storeName: inputController.selectedStore.value,
        tax: calculationsController.tax.value,
        userName: invoiceCreatorName.value.isNotEmpty ? invoiceCreatorName.value : userState.userName,
        amountPaid: null,
        remainingAmount: null,
        invoiceTypeChar: 'ج',
        accountNo: selectedCustomer.value?.customerNo.toString() ?? '',
        companyName: _invoiceTemplatesController.companyNameController.text,
        companyAddress: _invoiceTemplatesController.addressDetailsController.text,
        contactInfo: _invoiceTemplatesController.contactInfoController.text,
        thanksMessage: _invoiceTemplatesController.thanksMessageController.text,
        logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
        showLogo: _invoiceTemplatesController.showLogo.value,
        userBranchName: userState.safeUserBranchName,
        userDepartmentName: userState.safeUserDepartmentName,
        netTotalInWords: netTotalInWords,
        customerBalance: customerCurrentBalance,
      );

      final String invoiceType = "مبيعات آجلة";
      final String safeInvoiceType = invoiceType.replaceAll(' ', '_');

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${safeInvoiceType}_$transactionNumber.pdf');
      await file.writeAsBytes(pdfBytes);

      final String companyName = _invoiceTemplatesController.companyNameController.text;
      final String date = headerController.selectedDate.value.toIso8601String().split('T').first;
      final String total = calculationsController.netTotal.value.toStringAsFixed(2);
      final String currency = inputController.selectedCurrency.value;

      final String generatedCaption = '''
Company: $companyName
Statement: $invoiceType #$transactionNumber
Date: $date
Total Amount: $total $currency
''';

      await WhatsAppHelper.sendPdf(
        pdfFile: file,
        phoneNumber: phone,
        packageName: whatsappPackage.value,
        caption: generatedCaption,
        showMessage: (msg) {
            log("WhatsApp Helper: $msg");
        },
      );
    } catch (e) {
      log('Auto-WhatsApp failed: $e');
    }
  }
}