import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/models/cost_center.dart';
import 'package:untitled4/models/full_receipt.dart';
import 'package:untitled4/models/receipt_payment_item.dart';
import 'package:untitled4/models/sun_customer.dart';
import 'package:untitled4/screens/controllers/receipt_calculations_controller.dart';
import 'package:untitled4/screens/controllers/receipt_header_controller.dart';
import 'package:untitled4/screens/controllers/receipt_input_controller.dart';
import 'package:untitled4/screens/controllers/receipt_items_controller.dart';
import 'package:untitled4/screens/pdf_design/receipt_pdf_viewer_screen.dart';
import 'package:untitled4/screens/previous_receipts_screen.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/repositories/receipt_repository.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import '../../models/sun_currency.dart';
import '../../repositories/report_repository.dart';
import '../../utils/trial_period_manager.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:untitled4/utils/whatsapp_helper.dart';
import 'package:untitled4/screens/pdf_design/pdf_receipt_data.dart';
import 'dart:typed_data';

const String _kCurrentScreenName = 'ReceiptScreen';

class CashReceiptController extends GetxController {
  final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController = Get.find<InvoiceTemplatesController>();
  final ReceiptRepository _receiptRepository = ReceiptRepository();
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final ReportRepository _reportRepository = ReportRepository();

  late final ReceiptHeaderController headerController;
  late final ReceiptInputController inputController;
  late final ReceiptItemsController itemsController;
  late final ReceiptCalculationsController calculationsController;

  late final TextEditingController customerNameController;
  late final TextEditingController descriptionController;
  late final TextEditingController collectorController;

  late final TextEditingController costCenterNameController;
  final Rxn<CostCenter> selectedCostCenter = Rxn<CostCenter>();
  final RxList<CostCenter> allAvailableCostCenters = <CostCenter>[].obs;

  final Rxn<SunCustomer> selectedCustomer = Rxn<SunCustomer>();
  final RxList<SunCustomer> allAvailableCustomers = <SunCustomer>[].obs;

  final RxBool isLoading = false.obs;
  final RxBool isManualSyncing = false.obs;
  final RxnInt currentReceiptId = RxnInt();
  final RxBool isReadOnly = false.obs;

  final RxBool isAutoWhatsAppEnabled = false.obs;
  final RxString whatsappPackage = 'com.whatsapp'.obs;

  bool _didJustUpdate = false;

  CashReceiptController({int? initialReceiptId}) {
    if (initialReceiptId != null) {
      currentReceiptId.value = initialReceiptId;
    }
    calculationsController = Get.put(ReceiptCalculationsController());
    headerController = Get.put(ReceiptHeaderController());
    inputController = Get.put(ReceiptInputController());
    itemsController = Get.put(ReceiptItemsController(calculationsController: calculationsController));
    customerNameController = TextEditingController();
    descriptionController = TextEditingController();
    collectorController = TextEditingController();
    costCenterNameController = TextEditingController();
  }

  @override
  void onInit() {
    super.onInit();
    if (!userState.canAccessScreen(_kCurrentScreenName)) {
      showMessage('ليس لديك صلاحية الوصول إلى شاشة سند القبض.', isError: true);
      Future.delayed(Duration.zero, () => Get.back());
      return;
    }
    _initializeScreenData();
    _triggerBackgroundSync();
  }

  Future<void> _initializeScreenData() async {
    isLoading.value = true;
    try {
      await Future.wait([
        _invoiceTemplatesController.fetchInvoiceTemplates(),
        inputController.loadInitialData(),
        itemsController.loadAllAvailableAccounts(),
        itemsController.loadAllAvailableCurrencies(),
        loadAllAvailableCustomers(),
        _loadAllAvailableCostCenters(),
        _loadSettings(),
      ]);

      final args = Get.arguments;
      if (args != null && args is Map && args['isRemote'] == true) {
        isReadOnly.value = true;
        await _loadRemoteReceipt(args);
      } else {
        isReadOnly.value = false;
        if (currentReceiptId.value != null) {
          await loadReceiptForEditing(currentReceiptId.value!);
        } else {
          await headerController.generateAndSetNextTransactionNumber();
        }
      }
    } catch (e) {
      showMessage('فشل في تحميل البيانات: ${e.toString()}', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadRemoteReceipt(Map args) async {
    try {
      final String transactionId = args['transactionId'].toString();
      final int branchId = int.parse(args['remoteBranchId'].toString());
      final String year = args['remoteYear'].toString();

      final prefs = await SharedPreferences.getInstance();
      final String? serverUrl = prefs.getString('server_address');

      if (serverUrl == null || serverUrl.isEmpty) {
        throw Exception('عنوان السيرفر غير محفوظ');
      }

      final FullReceipt fullReceipt = await _receiptRepository.fetchReceiptFromApi(
        serverUrl: serverUrl,
        token: "",
        transactionId: transactionId,
        branchId: branchId,
        year: year,
      );

      final receiptData = fullReceipt.receipt;

      currentReceiptId.value = receiptData.id;
      headerController.transactionNumber.value = receiptData.transactionNumber;
      headerController.selectedDate.value = receiptData.date;
      customerNameController.text = receiptData.accountName;

      await inputController.updateSelectedBox(receiptData.cashBox);
      inputController.updateSelectedCurrency(receiptData.currency);

      collectorController.text = receiptData.collectorName ?? '';
      descriptionController.text = receiptData.description ?? '';
      calculationsController.updateTotal(receiptData.totalAmount);

      final int? costCenterNo = receiptData.costCenterNo;
      if (costCenterNo != null) {
        final foundCenter = allAvailableCostCenters
            .firstWhereOrNull((c) => c.centerNo == costCenterNo);
        if (foundCenter != null) {
          selectedCostCenter.value = foundCenter;
          costCenterNameController.text = foundCenter.centerName;
        } else {
          costCenterNameController.text = receiptData.costCenter ?? 'مركز خارجي ($costCenterNo)';
        }
      } else {
        clearSelectedCostCenter();
      }

      final List<ReceiptPaymentItem> receiptItems = fullReceipt.items;

      if (receiptItems.isNotEmpty) {
        for (var item in receiptItems) {
          final foundCustomer = allAvailableCustomers.firstWhereOrNull(
                  (c) => c.accountId == item.accountNo
          );

          if (foundCustomer != null) {
            selectedCustomer.value = foundCustomer;
            break;
          }
        }
      }

      if (receiptItems.isNotEmpty) {
        final loadedItems = receiptItems.map((item) {
          final currencyNameFromDb = item.itemCurrency.trim();

          var foundCurrency = itemsController.allAvailableCurrenciesList
              .firstWhereOrNull((c) =>
          c.currencyName == currencyNameFromDb ||
              c.currencySymbol == currencyNameFromDb);

          if (foundCurrency == null && currencyNameFromDb.isNotEmpty) {
            foundCurrency = SunCurrency(
              currencyNo: item.itemCurrencyId ?? 0,
              currencyName: currencyNameFromDb,
              currencySymbol: currencyNameFromDb,
              currencyRate: item.exchangeRate,
            );
            itemsController.allAvailableCurrenciesList.add(foundCurrency);
          }

          final account = itemsController.allAvailableAccountsList
              .firstWhereOrNull((acc) => acc.accountNumber == item.accountNo);

          return {
            'id': item.id,
            'account_id_link': account?.id,
            'account_no': item.accountNo,
            'account_name': item.accountName,
            'amount': item.amount,
            'item_currency': foundCurrency?.currencyNo ?? 1,
            'exchange_rate': item.exchangeRate,
            'equivalent_amount': item.equivalentAmount,
            'isEmpty': false,
            'allowed_currencies': <SunCurrency>[],
          };
        }).toList();

        itemsController.loadReceiptItems(loadedItems);
        for (var i = 0; i < itemsController.items.length; i++) {
          final accountId = itemsController.items[i]['account_id_link'];
          if (accountId != null) {
            await itemsController.fetchAllowedCurrenciesOnly(i, accountId);
          }
        }
      }

    } catch (e) {
      showMessage('فشل جلب السند من السيرفر: $e', isError: true);
      Get.back();
    }
  }

  @override
  void onClose() {
    customerNameController.dispose();
    costCenterNameController.dispose();
    descriptionController.dispose();
    collectorController.dispose();
    Get.delete<ReceiptHeaderController>();
    Get.delete<ReceiptInputController>();
    Get.delete<ReceiptItemsController>();
    Get.delete<ReceiptCalculationsController>();
    super.onClose();
  }

  bool handleBackPress() {
    if (_didJustUpdate) {
      resetForm();
      return true;
    }
    return false;
  }

  Future<void> loadAllAvailableCustomers() async {
    try {
      final customers = await _lookupsRepository.fetchAllCustomers();
      if (customers.isNotEmpty) {
        allAvailableCustomers.assignAll(customers);
      }
    } catch (e) {
      showMessage('خطأ في تحميل قائمة العملاء: ${e.toString()}', isError: true);
    }
  }

  List<SunCustomer> filterCustomers(String query) {
    if (query.isEmpty) return allAvailableCustomers.toList();
    return allAvailableCustomers
        .where((customer) =>
    customer.customerName.toLowerCase().contains(query.toLowerCase()) ||
        customer.customerNo.toString().contains(query.toLowerCase()))
        .toList();
  }

  void selectCustomer(SunCustomer customer) {
    selectedCustomer.value = customer;
    customerNameController.text = customer.customerName;
    descriptionController.text = 'لكم مقابل سداد من الحساب';
    itemsController.populateFirstRowWithCustomerAccount(customer);
  }

  Future<void> _loadAllAvailableCostCenters() async {
    try {
      final response = await _lookupsRepository.fetchAllCostCenters();
      if (response.isNotEmpty) {
        allAvailableCostCenters
            .assignAll(response.map((json) => CostCenter.fromJson(json)).toList());
      }
    } catch (e) {
      showMessage('خطأ في تحميل مراكز التكلفة: ${e.toString()}', isError: true);
    }
  }

  List<CostCenter> filterCostCenters(String query) {
    if (query.isEmpty) return allAvailableCostCenters.toList();
    return allAvailableCostCenters
        .where((center) =>
    center.centerName.toLowerCase().contains(query.toLowerCase()) ||
        center.centerNo.toString().contains(query.toLowerCase()))
        .toList();
  }

  void selectCostCenter(CostCenter center) {
    selectedCostCenter.value = center;
    costCenterNameController.text = center.centerName;
    Get.back();
  }

  void clearSelectedCostCenter() {
    selectedCostCenter.value = null;
    costCenterNameController.clear();
  }

  Future<void> loadReceiptForEditing(int receiptId) async {
    _didJustUpdate = false;
    isLoading.value = true;
    try {
      final FullReceipt fullReceipt = await _receiptRepository.loadReceipt(receiptId);
      final receiptData = fullReceipt.receipt;

      currentReceiptId.value = receiptData.id;
      headerController.transactionNumber.value = receiptData.transactionNumber;
      headerController.selectedDate.value = receiptData.date;
      customerNameController.text = receiptData.accountName;

      await inputController.updateSelectedBox(receiptData.cashBox);
      inputController.updateSelectedCurrency(receiptData.currency);

      collectorController.text = receiptData.collectorName ?? '';
      descriptionController.text = receiptData.description ?? '';
      calculationsController.updateTotal(receiptData.totalAmount);

      final int? costCenterNo = receiptData.costCenterNo;
      if (costCenterNo != null) {
        final foundCenter = allAvailableCostCenters
            .firstWhereOrNull((c) => c.centerNo == costCenterNo);
        if (foundCenter != null) {
          selectedCostCenter.value = foundCenter;
          costCenterNameController.text = foundCenter.centerName;
        } else {
          costCenterNameController.text = 'مركز محذوف ($costCenterNo)';
        }
      } else {
        clearSelectedCostCenter();
      }

      final List<ReceiptPaymentItem> receiptItems = fullReceipt.items;
      if (receiptItems.isNotEmpty) {
        final loadedItems = receiptItems.map((item) {
          final currencyNameFromDb = item.itemCurrency.trim();
          final foundCurrency = itemsController.allAvailableCurrenciesList
              .firstWhereOrNull((c) =>
          c.currencyName == currencyNameFromDb ||
              c.currencySymbol == currencyNameFromDb);
          final account = itemsController.allAvailableAccountsList
              .firstWhereOrNull((acc) => acc.accountNumber == item.accountNo);
          return {
            'id': item.id,
            'account_id_link': account?.id,
            'account_no': item.accountNo,
            'account_name': item.accountName,
            'amount': item.amount,
            'item_currency': foundCurrency?.currencyNo,
            'exchange_rate': item.exchangeRate,
            'equivalent_amount': item.equivalentAmount,
            'isEmpty': false,
            'allowed_currencies': <SunCurrency>[],
          };
        }).toList();
        itemsController.loadReceiptItems(loadedItems);
        for (var i = 0; i < itemsController.items.length; i++) {
          final accountId = itemsController.items[i]['account_id_link'];
          if (accountId != null) {
            await itemsController.fetchAllowedCurrenciesOnly(i, accountId);
          }
        }
      }
    } catch (e) {
      showMessage('خطأ أثناء تحميل السند: ${e.toString()}', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveReceipt({bool showSuccessMessage = true}) async {
    if (isReadOnly.value) {
      showMessage('هذا السند للعرض فقط ولا يمكن تعديله.', isError: true);
      return;
    }

    isLoading.value = true;

    if (inputController.isLoadingCurrencies.value) {
      showMessage('يرجى الانتظار حتى يتم تحميل عملات الصندوق.', isError: true);
      isLoading.value = false;
      return;
    }

    final itemsToSave = itemsController.items.where((item) => item['isEmpty'] != true).toList();

    if (customerNameController.text.trim().isEmpty ||
        inputController.selectedBox.value.isEmpty ||
        inputController.selectedCurrency.value.isEmpty ||
        itemsToSave.isEmpty) {
      showMessage('يرجى ملء جميع الحقول الإجبارية وإضافة بند واحد على الأقل.', isError: true);
      isLoading.value = false;
      return;
    }

    for (int i = 0; i < itemsToSave.length; i++) {
      final item = itemsToSave[i];
      final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
      if (amount <= 0) {
        showMessage('عذراً، لا يمكن حفظ السند لأن المبلغ في أحد البنود يساوي صفر.', isError: true);
        isLoading.value = false;
        return;
      }
      if (item['account_no'] == null || item['account_no'].toString().trim().isEmpty) {
        showMessage('عذراً، يرجى تحديد حساب صالح في جميع البنود المدخلة.', isError: true);
        isLoading.value = false;
        return;
      }
    }

    if (calculationsController.total.value <= 0) {
      showMessage('لا يمكن حفظ السند. إجمالي المبلغ يجب أن يكون أكبر من صفر.', isError: true);
      isLoading.value = false;
      return;
    }


    final isUpdate = currentReceiptId.value != null;
    if (!isUpdate) {
      final checkResult = await TrialPeriodManager.checkOnSave(invoiceTypeChar: 'ق');
      if (checkResult != TrialSaveCheckResult.allow) {
        isLoading.value = false;
        return;
      }
    }

    String fullAmountInWords = calculationsController.amountInWords.value;
    final String currencyName = inputController.selectedCurrency.value;
    if (fullAmountInWords.isNotEmpty && !fullAmountInWords.contains(currencyName)) {
      fullAmountInWords = '$fullAmountInWords $currencyName';
    }

    final Map<String, dynamic> receiptHeaderData = {
      'date': headerController.selectedDate.value,
      'cash_box': inputController.selectedBox.value,
      'currency': inputController.selectedCurrency.value,
      'account_name': customerNameController.text.trim(),
      'cost_center_no': selectedCostCenter.value?.centerNo,
      'description': descriptionController.text.trim(),
      'total_amount': calculationsController.total.value,
      'amount_in_words': fullAmountInWords,
      'invoice_type_char': 'ق',
      'collector_name': collectorController.text.trim(),
      'sun_year': userState.safeFinancialYearName,
      'branch_id': userState.userBranch,
      'department_id': userState.userDepartment,
      'source_last_updated_at': DateTime.now().toString(),
    };

    if (isUpdate) {
      receiptHeaderData['id'] = currentReceiptId.value;
      receiptHeaderData['transaction_number'] = headerController.transactionNumber.value;
    }

    try {
      final preparedItems = _prepareReceiptItems(itemsToSave);
      final preparedLedger = await _prepareLedgerPostings();

      if (isUpdate) {
        if (!userState.canEdit(_kCurrentScreenName)) {
          showMessage('ليس لديك صلاحية لتعديل سندات القبض.', isError: true);
          isLoading.value = false;
          return;
        }

        await _receiptRepository.updateCompleteReceipt(
          receiptId: currentReceiptId.value!,
          receiptHeader: receiptHeaderData,
          receiptItems: preparedItems,
          ledgerPostings: preparedLedger,
        );

        _didJustUpdate = true;

      } else {
        if (!userState.canAdd(_kCurrentScreenName)) {
          showMessage('ليس لديك صلاحية لإضافة سندات قبض جديدة.', isError: true);
          isLoading.value = false;
          return;
        }
        receiptHeaderData['user_id'] = userState.userNo;

        final result = await _receiptRepository.saveCompleteReceipt(
          receiptHeader: receiptHeaderData,
          receiptItems: preparedItems,
          ledgerPostings: preparedLedger,
        );

        currentReceiptId.value = result['id'];
        headerController.transactionNumber.value = result['transaction_number'];

        await TrialPeriodManager.handlePostSave(
          invoiceTypeChar: 'ق',
          screenTitle: 'سند القبض',
        );
      }

      if (showSuccessMessage) {
        showMessage(
            isUpdate
                ? 'تم التحديث بنجاح!'
                : 'تم الحفظ بنجاح. رقم الحركة: ${headerController.transactionNumber.value}',
            isError: false);
      }

      _triggerBackgroundSync();

      if (!isUpdate && isAutoWhatsAppEnabled.value) {
        _autoSendWhatsApp(headerController.transactionNumber.value);
      }

    } catch (e) {
      showMessage('خطأ أثناء الحفظ: ${e.toString()}', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> _prepareReceiptItems(List<Map<String, dynamic>> itemsToSave) {
    return itemsToSave.map((item) {
      final currency = itemsController.allAvailableCurrenciesList
          .firstWhereOrNull((c) => c.currencyNo == item['item_currency']);
      return {
        'account_no': item['account_no'],
        'account_name': item['account_name'],
        'amount': item['amount'],
        'item_currency': currency?.currencyName ?? '',
        'exchange_rate': item['exchange_rate'],
        'equivalent_amount': item['equivalent_amount'],
        'created_at': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _prepareLedgerPostings() async {
    dynamic boxAccountIdRaw = inputController.selectedBoxAccountId.value;
    if (boxAccountIdRaw == null) throw Exception('لم يتم تحديد حساب الصندوق.');

    int? resolvedBoxAccountId;
    final int? parsedId = int.tryParse(boxAccountIdRaw.toString());

    if (parsedId != null) {
      final idCheck = await _lookupsRepository.fetchAccountById(parsedId);
      if (idCheck != null) {
        resolvedBoxAccountId = parsedId;
      } else {
        final accNumCheck = await _lookupsRepository.fetchAccountByNumber(boxAccountIdRaw.toString());
        if (accNumCheck != null) {
          resolvedBoxAccountId = int.parse(accNumCheck.id);
        }
      }
    } else {
      final accNumCheck = await _lookupsRepository.fetchAccountByNumber(boxAccountIdRaw.toString());
      if (accNumCheck != null) {
        resolvedBoxAccountId = int.parse(accNumCheck.id);
      }
    }

    if (resolvedBoxAccountId == null) {
      throw Exception('حساب الصندوق ($boxAccountIdRaw) غير موجود في جدول الحسابات (لا كمعرف ولا كرقم حساب). تأكد من صحة البيانات.');
    }

    final totalInBaseCurrency = itemsController.items
        .where((p) => p['isEmpty'] == false)
        .fold<double>(0.0, (sum, item) => sum + (item['equivalent_amount'] as double));

    if (inputController.currencies.isEmpty) {
      throw Exception("لم يتم العثور على العملة المختارة.");
    }

    final SunCurrency? mainCurrency = inputController.currencies.firstWhereOrNull(
            (c) => c.currencyName == inputController.selectedCurrency.value);

    if (mainCurrency == null) {
      throw Exception("لم يتم العثور على العملة المختارة.");
    }

    final int? costCenterNo = selectedCostCenter.value?.centerNo;
    final String transactionNumber = headerController.transactionNumber.value;
    final String transactionDate = headerController.selectedDate.value.toIso8601String();

    final debitEntry = {
      'account_id': resolvedBoxAccountId,
      'debit': totalInBaseCurrency,
      'credit': 0,
      'description': 'مقابل قيد سند قبض من ${customerNameController.text}',
      'transaction_date': transactionDate,
      'transaction_type': 'سند قبض',
      'transaction_ref': transactionNumber,
      'beneficiary_name': customerNameController.text.trim(),
      'original_amount': calculationsController.total.value,
      'currency_id': mainCurrency.currencyNo,
      'exchange_rate': inputController.selectedExchangeRate.value,
      'cost_center_no': costCenterNo,
      'transaction_id': currentReceiptId.value,
    };

    final creditEntries = itemsController.items
        .where((item) => item['isEmpty'] == false)
        .map((item) {
      if (item['account_id_link'] == null) {
        throw Exception('لم يتم العثور على معرّف الحساب للبند: ${item['account_name']}');
      }
      return {
        'account_id': item['account_id_link'],
        'debit': 0,
        'credit': item['equivalent_amount'],
        'description': 'مقابل سند قبض رقم $transactionNumber',
        'transaction_date': transactionDate,
        'transaction_type': 'سند قبض',
        'transaction_ref': transactionNumber,
        'beneficiary_name': customerNameController.text.trim(),
        'original_amount': item['amount'],
        'currency_id': item['item_currency'],
        'exchange_rate': item['exchange_rate'],
        'cost_center_no': null,
        'transaction_id': currentReceiptId.value,
      };
    }).toList();

    return [debitEntry, ...creditEntries];
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

  Future<void> printReceipt() async {
    if (!userState.canPrint(_kCurrentScreenName)) {
      showMessage('ليس لديك صلاحية للطباعة.', isError: true);
      return;
    }

    if (inputController.selectedCurrency.value.isEmpty) {
      showMessage('يرجى اختيار الصندوق والعملة قبل الطباعة.', isError: true);
      return;
    }

    if (!isReadOnly.value) {
      await saveReceipt(showSuccessMessage: false);
      if (currentReceiptId.value == null) {
        showMessage('فشل في حفظ السند، لا يمكن الطباعة.', isError: true);
        return;
      }
    }

    isLoading.value = true;
    try {
      _invoiceTemplatesController.selectTemplate(_kCurrentScreenName);

      final double customerCurrentBalance = await _fetchCustomerBalance();

      final List<SunCurrency> currencyList = itemsController.allAvailableCurrenciesList;

      final List<Map<String, dynamic>> rawItems = itemsController.items
          .where((item) => item['isEmpty'] != true)
          .toList();

      final List<Map<String, dynamic>> printableItems = rawItems.map((item) {
        final int? currencyId = item['item_currency'] as int?;
        final String currencyName = currencyList
            .firstWhereOrNull((c) => c.currencyNo == currencyId)
            ?.currencyName ?? 'N/A';
        final Map<String, dynamic> pdfItem = Map.from(item);
        pdfItem['item_currency'] = currencyName;
        return pdfItem;
      }).toList();

      final bool? shouldResetForm = await Get.to<bool?>(() => ReceiptPdfViewerScreen(
        transactionNumber: headerController.transactionNumber.value,
        date: headerController.selectedDate.value,
        items: printableItems,
        totalAmount: calculationsController.total.value,
        accountName: customerNameController.text,
        cashBox: inputController.selectedBox.value,
        currency: inputController.selectedCurrency.value,
        costCenter: costCenterNameController.text,
        description: descriptionController.text,
        amountInWords: calculationsController.amountInWords.value,
        invoiceTypeChar: 'ق',
        userName: userState.userName,
        receiptId: currentReceiptId.value.toString(),
        collectorName: collectorController.text,
        userBranchName: userState.safeUserBranchName,
        userDepartmentName: userState.safeUserDepartmentName,
        companyName: _invoiceTemplatesController.companyNameController.text,
        companyAddress: _invoiceTemplatesController.addressDetailsController.text,
        contactInfo: _invoiceTemplatesController.contactInfoController.text,
        thanksMessage: _invoiceTemplatesController.thanksMessageController.text,
        logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
        showLogo: _invoiceTemplatesController.showLogo.value,
        customerBalance: customerCurrentBalance,
        customerPhone: selectedCustomer.value?.phoneNumber,
      ));
      if (shouldResetForm == true) {
        resetForm();
      }
    } catch (e) {
      showMessage('خطأ في إعداد الطباعة: ${e.toString()}', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> navigateToPreviousReceipts() async {
    if (isReadOnly.value) {
      showMessage('لا يمكن البحث في السندات السابقة أثناء عرض سند من السيرفر.', isError: true);
      return;
    }

    if (!userState.canSearch(_kCurrentScreenName)) {
      showMessage('ليس لديك صلاحية للبحث.', isError: true);
      return;
    }
    final dynamic result = await Get.to(() => const PreviousReceiptsScreen(),
        arguments: {'invoiceType': 'ق'});

    if (result != null) {
      if (result is int) {
        await loadReceiptForEditing(result);
      } else if (result is String) {
        final int? parsedId = int.tryParse(result);
        if (parsedId != null) {
          await loadReceiptForEditing(parsedId);
        }
      } else if (result == true) {
        resetForm();
      }
    }
  }

  void resetForm() async {
    _didJustUpdate = false;
    currentReceiptId.value = null;
    isReadOnly.value = false;
    headerController.resetHeader();
    await inputController.resetDropdowns();
    itemsController.resetItems();
    calculationsController.reset();
    customerNameController.clear();
    selectedCustomer.value = null;
    clearSelectedCostCenter();
    descriptionController.clear();
    collectorController.clear();
    headerController.generateAndSetNextTransactionNumber();
  }

  void showMessage(String message, {bool isError = true}) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
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

  String _buildReceiptSyncUrl(String savedAddress) {
    String base = savedAddress.trim();
    if (!base.startsWith('http://') && !base.startsWith('https://')) {
      base = 'http://$base';
    }
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/api/Receipt/sync-receipt';
  }

  Future<void> performManualSync() async {
    if (isManualSyncing.value) return;

    isManualSyncing.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedAddress = prefs.getString('server_address');

      if (savedAddress != null && savedAddress.isNotEmpty) {
        final String fullApiUrl = _buildReceiptSyncUrl(savedAddress);

        final int syncedCount = await _receiptRepository.syncReceiptsToRemote(
            fullApiUrl,
            "",
            invoiceTypeChar: 'ق'
        );

        if (syncedCount > 0) {
          showMessage('تمت مزامنة $syncedCount سند بنجاح', isError: false);
        } else {
          showMessage('لا توجد سندات غير متزامنة حالياً', isError: false);
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
          final String fullApiUrl = _buildReceiptSyncUrl(savedAddress);

          await _receiptRepository.syncReceiptsToRemote(
              fullApiUrl,
              "",
              invoiceTypeChar: 'ق'
          );
          await _receiptRepository.deleteOldSyncedReceipts();
        }
      } catch (e) {
        log("Background sync error: $e");
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    isAutoWhatsAppEnabled.value = prefs.getBool('isAutoWhatsAppEnabled') ?? false;
    whatsappPackage.value = prefs.getString('whatsappPackagePreference') ?? 'com.whatsapp';
  }

  Future<void> toggleAutoWhatsApp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    isAutoWhatsAppEnabled.value = value;
    await prefs.setBool('isAutoWhatsAppEnabled', value);
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
      final List<SunCurrency> currencyList = itemsController.allAvailableCurrenciesList;

      final List<Map<String, dynamic>> rawItems = itemsController.items
          .where((item) => item['isEmpty'] != true)
          .toList();

      final List<Map<String, dynamic>> printableItems = rawItems.map((item) {
        final int? currencyId = item['item_currency'] as int?;
        final String currencyName = currencyList
            .firstWhereOrNull((c) => c.currencyNo == currencyId)
            ?.currencyName ?? 'N/A';
        final Map<String, dynamic> pdfItem = Map.from(item);
        pdfItem['item_currency'] = currencyName;
        return pdfItem;
      }).toList();

      final Uint8List pdfBytes = await PdfInvoiceData.generate(
        pageType: PdfPageType.a4,
        transactionNumber: transactionNumber,
        date: headerController.selectedDate.value,
        items: printableItems,
        totalAmount: calculationsController.total.value,
        accountName: customerNameController.text,
        cashBox: inputController.selectedBox.value,
        currency: inputController.selectedCurrency.value,
        costCenter: costCenterNameController.text,
        description: descriptionController.text,
        amountInWords: calculationsController.amountInWords.value,
        invoiceTypeChar: 'ق',
        userName: userState.userName,
        receiptId: currentReceiptId.value?.toString() ?? '',
        paymentId: null,
        collectorName: collectorController.text,
        recipientName: null,
        companyName: _invoiceTemplatesController.companyNameController.text,
        companyAddress: _invoiceTemplatesController.addressDetailsController.text,
        contactInfo: _invoiceTemplatesController.contactInfoController.text,
        thanksMessage: _invoiceTemplatesController.thanksMessageController.text,
        logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
        showLogo: _invoiceTemplatesController.showLogo.value,
        userBranchName: userState.safeUserBranchName,
        userDepartmentName: userState.safeUserDepartmentName,
        customerBalance: customerCurrentBalance,
      );

      final String invoiceType = "سند قبض";
      final String safeInvoiceType = invoiceType.replaceAll(' ', '_');

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${safeInvoiceType}_$transactionNumber.pdf');
      await file.writeAsBytes(pdfBytes);

      final String companyName = _invoiceTemplatesController.companyNameController.text;
      final String date = headerController.selectedDate.value.toIso8601String().split('T').first;
      final String total = calculationsController.total.value.toStringAsFixed(2);
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