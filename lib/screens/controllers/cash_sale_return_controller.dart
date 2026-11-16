import 'dart:developer';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/models/full_sales_invoice.dart';
import 'package:untitled4/repositories/sales_repository.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/screens/controllers/input_section_controller.dart';
import 'package:untitled4/screens/controllers/products_controller.dart';
import 'package:untitled4/screens/controllers/calculations_controller.dart';
import 'package:untitled4/utils/trial_period_manager.dart';
import '../../i_price_change_permission.dart';
import '../pdf/pdf_view.dart';
import '../previous_invoices_screen.dart';
import 'cash_sale_return_header_controller.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/utils/number_to_words_converter.dart';
import 'package:untitled4/services/lookups_service.dart.dart';
import '../../utils/sales_payment_dialog_helper.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/core/database_helper.dart';

const String _kCurrentScreenName = 'CashSaleReturnScreen';

class CashSaleReturnController extends GetxController implements IPriceChangePermission {
  final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController = Get.find<InvoiceTemplatesController>();
  final SalesRepository _salesRepository = SalesRepository();
  final LookupsService _lookupsService = Get.find<LookupsService>();
  final LookupsRepository _lookupsRepository = LookupsRepository();

  late final CashSaleReturnHeaderController headerController;
  late final InputSectionController inputController;
  late final ProductsController productsController;
  late final CalculationsController calculationsController;

  final RxBool isLoading = false.obs;
  final RxBool isManualSyncing = false.obs;
  final RxnString originalInvoiceRef = RxnString();
  final RxnString currentInvoiceId = RxnString();
  final RxString invoiceCreatorName = ''.obs;
  final RxBool isReadOnly = false.obs;
  final RxBool showExpiryDate = true.obs;
  final RxBool showBatchNumber = true.obs;
  final RxBool showBonusQuantity = true.obs;

  final RxBool isNetworkSale = false.obs;
  final Rxn<Map<String, dynamic>> selectedNetworkBox = Rxn<Map<String, dynamic>>();
  double networkPaidAmount = 0.0;

  late final String _tag;

  @override
  final RxBool canUserChangePrice = false.obs;

  CashSaleReturnController({String? initialInvoiceId, required String controllerTag}) {
    _tag = controllerTag;

    if (initialInvoiceId != null) {
      currentInvoiceId.value = initialInvoiceId;
    }

    if (userState.canAccessScreen(_kCurrentScreenName)) {
      canUserChangePrice.value = userState.canChangePrice(_kCurrentScreenName);
    }

    calculationsController = Get.put(CalculationsController(), tag: _tag);
    headerController = Get.put(CashSaleReturnHeaderController(), tag: _tag);
    inputController = Get.put(InputSectionController(inputTag: _tag), tag: _tag);
    productsController = Get.put(ProductsController(controllerTag: _tag), tag: _tag);
  }

  @override
  void onInit() {
    super.onInit();
    if (!userState.canAccessScreen(_kCurrentScreenName)) {
      _showUserFriendlyMessage('عذراً، ليس لديك صلاحية الوصول إلى شاشة مردود بيع نقدي.', isError: true);
      Future.delayed(Duration.zero, () => Get.back());
      return;
    }

    productsController.isReturnMode = true;

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
            inputController.loadInitialData(),
          ]);
          invoiceCreatorName.value = userState.safeUserName;
        }
      }
    } catch (e) {
      _showUserFriendlyMessage('حدث خطأ أثناء تجهيز الصفحة، يرجى المحاولة مرة أخرى.', isError: true);
    } finally {
      isLoading.value = false;
    }
  }
  Future<void> _loadTableSettings() async {
    final prefs = await SharedPreferences.getInstance();
    showExpiryDate.value = prefs.getBool('showExpiryDate') ?? true;
    showBatchNumber.value = prefs.getBool('showBatchNumber') ?? true;
    showBonusQuantity.value = prefs.getBool('showBonusQuantity') ?? true;
  }

  // --- 4. دالة تغيير الإعداد وحفظه ---
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
    }
    // تحديث الجدول لإعادة الرسم فوراً
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
      originalInvoiceRef.value = invoiceData.originalInvoiceRef;
      invoiceCreatorName.value = invoiceData.userName ?? '';

      await Future.wait([
        inputController.fetchAndAddMissingBox(invoiceData.boxNo, fallbackName: invoiceData.boxName),
        inputController.fetchAndAddMissingStore(invoiceData.storeNo, fallbackName: invoiceData.storeName),
        inputController.fetchAndAddMissingCurrenciesForBox(
            invoiceData.boxNo,
            fallbackCurrencyName: invoiceData.currency,
            fallbackRate: invoiceData.currencyRate
        ),
      ]);

      inputController.selectedBox.value = invoiceData.boxName ?? '';
      inputController.selectedStore.value = invoiceData.storeName ?? '';
      inputController.updateSelectedCurrency(invoiceData.currency);

      inputController.customerNameController.text = invoiceData.customerName ?? '';

      inputController.collectorNameController.text = invoiceData.collector ?? '';
      inputController.agentNameController.text = invoiceData.salesRep ?? '';

      calculationsController.updateAll(
        total: invoiceData.total,
        tax: invoiceData.tax ?? 0.0,
        totalItemDiscount: invoiceData.discount ?? 0.0,
      );
      calculationsController.netTotal.value = invoiceData.netTotal ?? 0.0;

      productsController.loadInvoiceProducts(fullInvoice.items.map((e) => {
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
      _showUserFriendlyMessage('فشل جلب الفاتورة من السيرفر: $e', isError: true);
      Get.back();
    }
  }

  Future<void> _ensureLookupsLoaded() async {
    if (_lookupsService.productsList.isEmpty || _lookupsService.customersList.isEmpty) {
      try {
        await _lookupsService.loadAllLookupData();
      } catch (e) {
        throw Exception('فشل تحميل البيانات الأساسية');
      }
    }
  }

  @override
  void onClose() {
    Get.delete<CalculationsController>(tag: _tag, force: true);
    Get.delete<CashSaleReturnHeaderController>(tag: _tag, force: true);
    Get.delete<InputSectionController>(tag: _tag, force: true);
    Get.delete<ProductsController>(tag: _tag, force: true);
    super.onClose();
  }

  void _showUserFriendlyMessage(String message, {bool isError = true}) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    final String title = isError ? 'تنبيه' : 'عملية ناجحة';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }

  Future<void> _loadInvoiceForEditing(String invoiceId) async {
    isLoading.value = true;
    try {
      final FullSalesInvoice fullInvoice = await _salesRepository.loadInvoice(invoiceId);
      final invoiceData = fullInvoice.sale;
      final int? loadedBoxNo = invoiceData.boxNo;
      final int? loadedStoreNo = invoiceData.storeNo;

      await inputController.loadInitialData();

      await Future.wait([
        if (loadedBoxNo != null) inputController.fetchAndAddMissingBox(loadedBoxNo),
        if (loadedStoreNo != null) inputController.fetchAndAddMissingStore(loadedStoreNo),
        if (loadedBoxNo != null) inputController.fetchAndAddMissingCurrenciesForBox(loadedBoxNo),
      ]);

      currentInvoiceId.value = invoiceData.id;
      headerController.transactionNumber.value = invoiceData.transactionNumber;
      headerController.selectedDate.value = invoiceData.date;

      final boxName = inputController.boxes.firstWhereOrNull((b) => b.boxNo == loadedBoxNo)?.boxName;
      final storeName = inputController.stores.firstWhereOrNull((s) => s.noStore == loadedStoreNo)?.nameStore;

      inputController.selectedBox.value = boxName ?? '';
      inputController.selectedStore.value = storeName ?? '';
      inputController.updateSelectedCurrency(invoiceData.currency);

      _setCustomerForEditing(invoiceData.accountNo, invoiceData.customerName);
      _setCollectorAndAgent(invoiceData.collectorId, invoiceData.agentId);

      calculationsController.updateAll(
        total: invoiceData.total,
        tax: 0.0,
        totalItemDiscount: invoiceData.discount ?? 0.0,
      );
      calculationsController.netTotal.value = invoiceData.netTotal ?? 0.0;
      originalInvoiceRef.value = invoiceData.originalInvoiceRef;

      final db = await DatabaseHelper.instance.database;
      final postingsRows = await db.query(
        'sun_general_ledger_postings',
        where: 'transaction_id = ? AND description LIKE ?',
        whereArgs: [invoiceId, '%(شبكة)%'],
      );

      if (postingsRows.isNotEmpty) {
        isNetworkSale.value = true;
        final networkPosting = postingsRows.first;
        networkPaidAmount = (networkPosting['original_amount'] as num?)?.toDouble() ?? 0.0;
        selectedNetworkBox.value = {
          'account_id': networkPosting['account_id'],
          'name': networkPosting['entity_name'],
        };
      } else {
        isNetworkSale.value = false;
        networkPaidAmount = 0.0;
        selectedNetworkBox.value = null;
      }

      productsController.loadInvoiceProducts(fullInvoice.items.map((e) => {
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
      _showUserFriendlyMessage('تعذر تحميل الفاتورة المطلوبة، قد تكون حذفت أو تغيرت صلاحياتك.', isError: true);
      resetForm();
    } finally {
      isLoading.value = false;
    }
  }

  void _setCustomerForEditing(String accountNo, String? customerName) {
    inputController.customerNameController.text = customerName ?? '...';
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
      _showUserFriendlyMessage('هذه الفاتورة للعرض فقط ولا يمكن تعديلها.', isError: true);
      return;
    }

    final actualProducts = productsController.products.where((item) => item['isEmpty'] != true).toList();
    final int? boxNoToSave = inputController.selectedBoxNo;
    final int? storeNoToSave = inputController.selectedStoreNo;

    if (actualProducts.isEmpty) {
      _showUserFriendlyMessage('أضف أصنافاً أولاً قبل الحفظ.', isError: true);
      return;
    }
    final bool hasZeroValue = actualProducts.any((item) {
      final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final double price = (item['item_price'] as num?)?.toDouble() ?? 0.0;
      return qty <= 0 || price <= 0;
    });
    if (hasZeroValue) {
      _showUserFriendlyMessage('لا يمكن حفظ الفاتورة. يوجد أصناف بكمية أو سعر يقل أو يساوي صفر.', isError: true);
      return;
    }
    if (boxNoToSave == null || storeNoToSave == null) {
      _showUserFriendlyMessage('يرجى التأكد من اختيار الصندوق والمخزن.', isError: true);
      return;
    }
    if (inputController.selectedCurrency.value.isEmpty) {
      _showUserFriendlyMessage('يرجى اختيار العملة.', isError: true);
      return;
    }

    if (currentInvoiceId.value == null) {
      final paymentResult = await SalesPaymentDialogHelper.processPayment(
        totalRequired: calculationsController.netTotal.value,
        lookupsRepository: _lookupsRepository,
      );

      if (paymentResult == null) {
        return; // User cancelled
      }

      isNetworkSale.value = paymentResult.isNetwork;
      selectedNetworkBox.value = paymentResult.selectedNetworkBox;
      networkPaidAmount = paymentResult.networkPaidAmount;
    }

    await _executeSaveSale(showSuccessMessage: showSuccessMessage, actualProducts: actualProducts);
  }

  Future<void> _executeSaveSale({bool showSuccessMessage = true, required List<Map<String, dynamic>> actualProducts}) async {
    if (currentInvoiceId.value == null) {
      final checkResult = await TrialPeriodManager.checkOnSave(invoiceTypeChar: 'رن');
      if (checkResult != TrialSaveCheckResult.allow) return;
    }

    isLoading.value = true;
    try {
      final saleHeader = _prepareSaleHeader();
      final saleItems = _prepareSaleItems(actualProducts);
      final ledgerPostings = await _prepareLedgerPostings(actualProducts);

      if (currentInvoiceId.value == null) {
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

        if (showSuccessMessage) {
          _showUserFriendlyMessage('تم حفظ المردود بنجاح. رقم الحركة: $newTransactionNumber', isError: false);
        }

        await TrialPeriodManager.handlePostSave(invoiceTypeChar: 'رن', screenTitle: 'مردود البيع النقدي');

      } else {
        if (!userState.canEdit(_kCurrentScreenName)) throw Exception('PERMISSION_DENIED');

        await _salesRepository.updateCompleteSale(
          invoiceId: int.parse(currentInvoiceId.value!),
          saleHeader: saleHeader,
          saleItems: saleItems,
          ledgerPostings: ledgerPostings,
        );

        if (showSuccessMessage) {
          _showUserFriendlyMessage('تم تعديل المردود بنجاح.', isError: false);
        }
      }

      _triggerBackgroundSync();

    } catch (e) {
      if (e.toString().contains('PERMISSION_DENIED')) {
        _showUserFriendlyMessage('ليس لديك الصلاحية لإتمام العملية.', isError: true);
      } else {
        _showUserFriendlyMessage('حدث خطأ أثناء الحفظ: ${e.toString()}', isError: true);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Map<String, dynamic> _prepareSaleHeader() {
    final selectedCurrencyObj = inputController.currencies.firstWhereOrNull(
        (c) => c.currencyName == inputController.selectedCurrency.value);

    return {
      'transaction_number': currentInvoiceId.value == null ? '' : headerController.transactionNumber.value,
      'date': headerController.selectedDate.value.toIso8601String(),
      'box_no': inputController.selectedBoxNo,
      'store_no': inputController.selectedStoreNo,
      'currency': inputController.selectedCurrency.value,
      'currency_id': selectedCurrencyObj?.currencyNo ?? 1,
      'currency_rate': inputController.selectedExchangeRate.value,
      'customer_name': inputController.customerNameController.text.trim().isEmpty ? '...' : inputController.customerNameController.text.trim(),
      'account_no': '',
      'collector_id': inputController.selectedCollectorId.value,
      'agent_id': inputController.selectedAgentId.value,
      'total': calculationsController.total.value,
      'tax': calculationsController.tax.value,
      'discount': calculationsController.discount.value,
      'net_total': calculationsController.netTotal.value,
      'user_id': userState.userNo,
      'invoice_type_char': 'رن',
      'original_invoice_ref': originalInvoiceRef.value,
      'sun_year': userState.safeFinancialYearName,
      'branch_id': userState.userBranch,
      'department_id': userState.userDepartment,
      'source_last_updated_at': DateTime.now().toString(),
      'is_synced': 0,
    };
  }

  List<Map<String, dynamic>> _prepareSaleItems(List<Map<String, dynamic>> products) {
    return products.map((item) {
      final productDetails = _lookupsService.productsList.firstWhereOrNull(
          (p) => p['item_no']?.toString() == item['item_no']?.toString());
      final int itemCurrencyId = (productDetails?['currency_no'] as num?)?.toInt() ?? 1;

      final itemCurrencyObj = _lookupsService.currenciesList.firstWhereOrNull(
          (c) => c.currencyNo == itemCurrencyId);
      final double itemCurrencyRate = itemCurrencyObj?.currencyRate ?? 1.0;

      double calculatedStockBalance = 0.0;
      try {
        final List<dynamic> stockList = item['stock_list'] ?? [];
        final String? selectedExpiry = item['expiry_date'];
        // 1. تحديد رقم الدفعة المختار
        final String selectedBatchNo = item['batch_no']?.toString() ?? '';

        final double packFactor = (item['pack_factor'] as num?)?.toDouble() ?? 1.0;

        // 2. التعديل الجوهري هنا: البحث بناءً على التاريخ AND رقم الدفعة
        final matchingBatch = stockList.firstWhereOrNull(
                (batch) => batch['expiry_date'] == selectedExpiry &&
                (batch['batch_no']?.toString() ?? '') == selectedBatchNo
        );

        if (matchingBatch != null) {
          final double baseQuantity = (matchingBatch['quantity'] as num?)?.toDouble() ?? 0.0;
          calculatedStockBalance = baseQuantity / (packFactor > 0 ? packFactor : 1.0);
        }
      } catch (e) {
        print("⚠️ خطأ في حساب الرصيد: $e");
        calculatedStockBalance = 0.0;
      }

      return {
        'item_no': item['item_no'].toString(),
        'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
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

    final selectedCashBoxName = inputController.selectedBox.value;
    final selectedBoxObject = inputController.boxes.firstWhereOrNull((b) => b.boxName == selectedCashBoxName);

    if (selectedBoxObject == null || selectedBoxObject.accountId == null) {
      throw Exception('الصندوق غير مرتبط بحساب محاسبي');
    }

    final inventoryAccountId = inputController.selectedStoreAccountId;
    if (inventoryAccountId == null) {
      throw Exception('المخزن المختار غير مرتبط بحساب محاسبي');
    }

    final cashBoxAccountId = selectedBoxObject.accountId;
    final mainCurrency = inputController.currencies.firstWhere((c) => c.currencyName == inputController.selectedCurrency.value);
    final baseExchangeRate = inputController.selectedExchangeRate.value;
    final netTotalInBase = calculationsController.netTotal.value * baseExchangeRate;

    List<Map<String, dynamic>> postings = [];
    final beneficiaryName = inputController.customerNameController.text.trim().isEmpty ? '...' : inputController.customerNameController.text.trim();
    final transactionDate = headerController.selectedDate.value.toIso8601String();
    final transactionRef = currentInvoiceId.value == null ? '' : headerController.transactionNumber.value;

    final String fixedDescription = 'مقابل فاتورة مردود مبيعات نقدا رقم $transactionRef';

    final double networkAmountInBase = isNetworkSale.value ? (networkPaidAmount * baseExchangeRate) : 0.0;
    final double cashAmountInBase = netTotalInBase - networkAmountInBase;

    // 1. Process Cash Credit
    if (cashAmountInBase > 0) {
      postings.add({
        'account_id': cashBoxAccountId,
        'debit': 0,
        'credit': cashAmountInBase,
        'entity_name': selectedBoxObject.boxName,
        'description': fixedDescription,
        'transaction_date': transactionDate,
        'transaction_type': 'فاتورة مردود مبيعات نقدا',
        'transaction_ref': transactionRef,
        'beneficiary_name': beneficiaryName,
        'original_amount': cashAmountInBase / baseExchangeRate,
        'currency_id': mainCurrency.currencyNo,
        'exchange_rate': baseExchangeRate,
      });
    }

    // 2. Process Network Credit
    if (networkAmountInBase > 0 && selectedNetworkBox.value != null) {
      postings.add({
        'account_id': selectedNetworkBox.value!['account_id'].toString(),
        'debit': 0,
        'credit': networkAmountInBase,
        'entity_name': selectedNetworkBox.value!['name'].toString(),
        'description': fixedDescription + ' (شبكة)',
        'transaction_date': transactionDate,
        'transaction_type': 'فاتورة مردود مبيعات نقدا',
        'transaction_ref': transactionRef,
        'beneficiary_name': beneficiaryName,
        'original_amount': networkPaidAmount,
        'currency_id': mainCurrency.currencyNo,
        'exchange_rate': baseExchangeRate,
      });
    }

    for (var item in products) {
      final double itemTotal = (item['total_item'] as num?)?.toDouble() ?? 0.0;
      final double itemTotalInBase = itemTotal * baseExchangeRate;

      final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
      final double unitCost = (item['cost_price'] as num?)?.toDouble() ?? 0.0;
      final double totalItemCost = qty * unitCost;
      final double totalItemCostInBase = totalItemCost; // Cost is strictly local base currency!

      final itemRevenueAccountId = item['sales_revenue_account_id'].toString();
      final itemCogsAccountId = item['cogs_account_id'].toString();

      postings.add({
        'account_id': itemRevenueAccountId,
        'debit': itemTotalInBase,
        'credit': 0,
        'entity_name': accountNames[itemRevenueAccountId] ?? itemRevenueAccountId,
        'description': fixedDescription,
        'transaction_date': transactionDate,
        'transaction_type': 'فاتورة مردود مبيعات نقدا',
        'transaction_ref': transactionRef,
        'beneficiary_name': beneficiaryName,
        'original_amount': itemTotal,
        'currency_id': mainCurrency.currencyNo,
        'exchange_rate': baseExchangeRate,
        'cost_center_no': item['cost_center_no'],
      });

      if (totalItemCostInBase > 0) {
        postings.add({
          'account_id': itemCogsAccountId,
          'debit': 0,
          'credit': totalItemCostInBase,
            'entity_name': accountNames[itemCogsAccountId] ?? itemCogsAccountId,
          'description': fixedDescription,
          'transaction_date': transactionDate,
          'transaction_type': 'فاتورة مردود مبيعات نقدا',
          'transaction_ref': transactionRef,
          'beneficiary_name': beneficiaryName,
          'original_amount': totalItemCost,
          'currency_id': mainCurrency.currencyNo,
          'exchange_rate': baseExchangeRate,
          'cost_center_no': null,
        });

        postings.add({
          'account_id': inventoryAccountId,
          'debit': totalItemCostInBase,
          'credit': 0,
          'entity_name': inputController.selectedStore.value,
          'description': fixedDescription,
          'transaction_date': transactionDate,
          'transaction_type': 'فاتورة مردود مبيعات نقدا',
          'transaction_ref': transactionRef,
          'beneficiary_name': beneficiaryName,
          'original_amount': totalItemCost,
          'currency_id': mainCurrency.currencyNo,
          'exchange_rate': baseExchangeRate,
          'cost_center_no': item['cost_center_no'],
        });
      }
    }

    return postings;
  }

  Future<void> loadDataFromOriginalInvoice(String invoiceId) async {
    isLoading.value = true;
    try {
      await _ensureLookupsLoaded();

      final response = await _salesRepository.loadOriginalInvoiceForReturn(invoiceId);
      final invoiceData = response;

      final creatorData = invoiceData['creator'] as Map<String, dynamic>?;
      invoiceCreatorName.value = creatorData?['user_name'] ?? 'مستخدم غير معروف';

      final int? loadedBoxNo = invoiceData['box_no'];
      final int? loadedStoreNo = invoiceData['store_no'];

      await inputController.loadInitialData();

      await Future.wait([
        if (loadedBoxNo != null) inputController.fetchAndAddMissingBox(loadedBoxNo),
        if (loadedStoreNo != null) inputController.fetchAndAddMissingStore(loadedStoreNo),
        if (loadedBoxNo != null) inputController.fetchAndAddMissingCurrenciesForBox(loadedBoxNo),
      ]);

      originalInvoiceRef.value = invoiceData['transaction_number'];

      _setCustomerForEditing(invoiceData['account_no'] as String? ?? '', invoiceData['customer_name'] as String?);
      _setCollectorAndAgent(invoiceData['collector_id'], invoiceData['agent_id']);

      final boxName = inputController.boxes.firstWhereOrNull((b) => b.boxNo == loadedBoxNo)?.boxName;
      final storeName = inputController.stores.firstWhereOrNull((s) => s.noStore == loadedStoreNo)?.nameStore;

      inputController.selectedBox.value = boxName ?? '';
      inputController.selectedStore.value = storeName ?? '';
      inputController.updateSelectedCurrency(invoiceData['currency'] as String?);

      final List<dynamic>? saleItems = invoiceData['sale_items'];
      if (saleItems != null && saleItems.isNotEmpty) {
        final loadedItems = saleItems.map((item) {
          final productDetails = _lookupsService.productsList.firstWhereOrNull((p) =>
          p['item_no']?.toString() == item['item_no']?.toString());
          final dynamic rawIsTaxable = productDetails?['is_taxable'];
          final dynamic rawIsDiscountable = productDetails?['is_discountable'];
          return {
            'item_no': item['item_no'],
            'item_name': productDetails?['item_name']?.toString() ?? item['item_name'] ?? 'صنف غير معروف',
            'item_price': (item['item_price'] as num?)?.toDouble() ?? 0.0,
            'quantity': (item['quantity'] as num?)?.toInt() ?? 0,
            'bonus_quantity': (item['bonus_quantity'] as num?)?.toInt() ?? 0,
            'item_discount': (item['item_discount'] as num?)?.toDouble() ?? 0.0,
            'total_item': (item['total'] as num?)?.toDouble() ?? 0.0,
            'isEmpty': false,
            'cost_center_no': productDetails?['cost_center_no'],
            'is_taxable': (rawIsTaxable == 1 || rawIsTaxable == true),
            'tax_rate': (productDetails?['tax_rate'] as num?)?.toDouble() ?? 0.0,
            'is_discountable': (rawIsDiscountable == 1 || rawIsDiscountable == true),
            'discount_rate': (productDetails?['discount_rate'] as num?)?.toDouble() ?? 0.0,

            'item_unit': item['item_unit'] ?? productDetails?['item_unit'] ?? '',
            'pack_factor': (item['pack_factor'] as num?)?.toDouble() ?? 1.0,
            'expiry_date': item['expiry_date'],
            'batch_no': item['batch_no']?.toString() ?? '',
            'cost_price': (item['cost_price'] as num?)?.toDouble() ?? 0.0,
            'sales_revenue_account_id': productDetails?['sales_revenue_account_id'],
            'cogs_account_id': productDetails?['cogs_account_id'],
          };
        }).toList();

        productsController.loadInvoiceProducts(loadedItems);
      }
    } catch (e) {
      _showUserFriendlyMessage('فشل استيراد بيانات الفاتورة الأصلية.', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> searchOriginalInvoice() async {
    if (isReadOnly.value) {
      _showUserFriendlyMessage('لا يمكن البحث أثناء عرض فاتورة من السيرفر.', isError: true);
      return;
    }

    if (userState.canSearch(_kCurrentScreenName)) {
      final result = await Get.to(() => const PreviousInvoicesScreen(),
          arguments: {'invoiceType': 'ن', 'mode': 'select'});

      if (result != null && result is String) {
        await loadDataFromOriginalInvoice(result);
      }
    } else {
      _showUserFriendlyMessage('ليس لديك صلاحية للبحث.', isError: true);
    }
  }

  Future<void> navigateToPreviousReturns() async {
    if (isReadOnly.value) {
      _showUserFriendlyMessage('لا يمكن البحث في المردودات السابقة أثناء عرض فاتورة من السيرفر.', isError: true);
      return;
    }

    if (userState.canSearch(_kCurrentScreenName)) {
      final result = await Get.to(() => const PreviousInvoicesScreen(),
          arguments: {'invoiceType': 'رن'});
      if (result != null && result is String) {
        _loadInvoiceForEditing(result);
      }
    } else {
      _showUserFriendlyMessage('ليس لديك صلاحية للبحث.', isError: true);
    }
  }

  void resetForm() {
    productsController.resetProducts();
    calculationsController.resetCalculations();
    headerController.resetHeader();
    inputController.resetDropdowns();
    currentInvoiceId.value = null;
    originalInvoiceRef.value = null;
    invoiceCreatorName.value = userState.safeUserName;
    isReadOnly.value = false;
    headerController.generateAndSetNextTransactionNumber();
  }

  Future<void> printSale() async {
    if (!userState.canPrint(_kCurrentScreenName)) {
      _showUserFriendlyMessage('ليس لديك صلاحية للطباعة.', isError: true);
      return;
    }

    if (!isReadOnly.value) {
      await saveSale(showSuccessMessage: false);
    }

    if (currentInvoiceId.value == null) return;

    try {
      final String netTotalInWords = convertNumberToWordsArabic(calculationsController.netTotal.value);

      final String rawCustomerName = inputController.customerNameController.text.trim();
      final String printCustomerName = rawCustomerName.isEmpty ? '...' : rawCustomerName;

      final String printAccountNo = '';

      final bool? shouldResetForm = await Get.to<bool?>(() => PdfView(
        saleId: currentInvoiceId.value,
        transactionNumber: headerController.transactionNumber.value,
        date: headerController.selectedDate.value,
        products: productsController.products.where((item) => item['isEmpty'] != true).toList(),
        total: calculationsController.total.value,
        tax: calculationsController.tax.value,
        discount: calculationsController.discount.value,
        customerName: printCustomerName,
        accountNo: printAccountNo,
        storeName: inputController.selectedStore.value,
        cashBox: inputController.selectedBox.value,
        currency: inputController.selectedCurrency.value,
        collector: inputController.collectorNameController.text.trim(),
        salesRep: inputController.agentNameController.text.trim(),
        netTotal: calculationsController.netTotal.value,
        userName: invoiceCreatorName.value.isNotEmpty ? invoiceCreatorName.value : userState.userName,
        invoiceTypeChar: 'رن',
        companyName: _invoiceTemplatesController.companyNameController.text,
        companyAddress: _invoiceTemplatesController.addressDetailsController.text,
        contactInfo: _invoiceTemplatesController.contactInfoController.text,
        thanksMessage: _invoiceTemplatesController.thanksMessageController.text,
        logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
        showLogo: _invoiceTemplatesController.showLogo.value,
        userBranchName: userState.safeUserBranchName,
        userDepartmentName: userState.safeUserDepartmentName,
        netTotalInWords: netTotalInWords,
      ));

      if (shouldResetForm == true) {
        resetForm();
      }
    } catch (e) {
      _showUserFriendlyMessage('حدث خطأ أثناء الطباعة.', isError: true);
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
            invoiceTypeChar: 'رن'
        );

        if (syncedCount > 0) {
          _showUserFriendlyMessage('تمت مزامنة $syncedCount فاتورة بنجاح', isError: false);
        } else {
          _showUserFriendlyMessage('لا توجد فواتير غير متزامنة حالياً', isError: false);
        }
      }
    } catch (e) {
      log("Error during manual sync: $e");
      _showUserFriendlyMessage('فشل الاتصال بالسيرفر', isError: true);
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
              invoiceTypeChar: 'رن'
          );
          await _salesRepository.deleteOldSyncedSales();
        }
      } catch (e) {
        log("Background sync error: $e");
      }
    });
  }
}