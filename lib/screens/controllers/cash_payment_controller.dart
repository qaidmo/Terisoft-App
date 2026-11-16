import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/models/cost_center.dart';
import 'package:untitled4/models/full_receipt.dart';
import 'package:untitled4/models/receipt_payment_item.dart';
import 'package:untitled4/models/sun_account_model.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/receipt_repository.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/screens/controllers/payment_calculations_controller.dart';
import 'package:untitled4/screens/controllers/payment_header_controller.dart';
import 'package:untitled4/screens/controllers/payment_input_controller.dart';
import 'package:untitled4/screens/controllers/payment_items_controller.dart';
import 'package:untitled4/screens/pdf_design/receipt_pdf_viewer_screen.dart';
import 'package:untitled4/screens/previous_receipts_screen.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../utils/trial_period_manager.dart';

const String _kCurrentScreenName = 'CashPaymentVoucherScreen';

class CashPaymentController extends GetxController {
  final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController = Get.find<InvoiceTemplatesController>();
  final ReceiptRepository _receiptRepository = ReceiptRepository();
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final ReportRepository _reportRepository = ReportRepository();

  late final PaymentHeaderController headerController;
  late final PaymentInputController inputController;
  late final PaymentItemsController itemsController;
  late final PaymentCalculationsController calculationsController;

  late final TextEditingController recipientController;
  late final TextEditingController descriptionController;
  late final TextEditingController costCenterNameController;
  final Rxn<CostCenter> selectedCostCenter = Rxn<CostCenter>();
  final RxList<CostCenter> allAvailableCostCenters = <CostCenter>[].obs;

  final Rxn<SunAccount> selectedAccount = Rxn<SunAccount>();

  final RxBool isLoading = false.obs;
  final RxBool isManualSyncing = false.obs;
  final RxnInt currentReceiptId = RxnInt();
  final RxBool isReadOnly = false.obs;
  static const String _kInvoiceTypeChar = 'ص';

  bool _didJustUpdate = false;

  CashPaymentController({int? initialPaymentId}) {
    if (initialPaymentId != null) {
      currentReceiptId.value = initialPaymentId;
    }
    calculationsController = Get.put(PaymentCalculationsController());
    headerController = Get.put(PaymentHeaderController());
    inputController = Get.put(PaymentInputController());
    itemsController = Get.put(PaymentItemsController(calculationsController: calculationsController));
    recipientController = TextEditingController();
    costCenterNameController = TextEditingController();
    descriptionController = TextEditingController();
  }

  @override
  void onInit() {
    super.onInit();
    if (!userState.canAccessScreen(_kCurrentScreenName)) {
      showMessage('ليس لديك صلاحية الوصول.', isError: true);
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
        _loadAllAvailableCostCenters(),
      ]);

      final args = Get.arguments;
      if (args != null && args is Map && args['isRemote'] == true) {
        isReadOnly.value = true;
        await _loadRemoteReceipt(args);
      } else {
        isReadOnly.value = false;
        if (currentReceiptId.value != null) {
          await loadPaymentForEditing(currentReceiptId.value!);
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
      recipientController.text = receiptData.accountName;

      await inputController.updateSelectedBox(receiptData.cashBox);
      inputController.updateSelectedCurrency(receiptData.currency);

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

      final List<ReceiptPaymentItem> paymentItems = fullReceipt.items;

      if (paymentItems.isNotEmpty) {
        for (var item in paymentItems) {
          final foundAccount = itemsController.allAvailableAccountsList.firstWhereOrNull(
                  (acc) => acc.id == item.accountNo || acc.accountNumber == item.accountNo
          );

          if (foundAccount != null) {
            selectedAccount.value = foundAccount;
            break;
          }
        }
      }

      if (paymentItems.isNotEmpty) {
        final loadedItems = paymentItems.map((item) {
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
            'item_currency': foundCurrency?.currencyNo ?? 1,
            'exchange_rate': item.exchangeRate,
            'equivalent_amount': item.equivalentAmount,
            'isEmpty': false,
            'allowed_currencies': <SunCurrency>[],
          };
        }).toList();
        itemsController.loadPaymentItems(loadedItems);
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
    recipientController.dispose();
    costCenterNameController.dispose();
    descriptionController.dispose();
    Get.delete<PaymentHeaderController>();
    Get.delete<PaymentInputController>();
    Get.delete<PaymentItemsController>();
    Get.delete<PaymentCalculationsController>();
    super.onClose();
  }

  Future<void> _loadAllAvailableCostCenters() async {
    try {
      final response = await _lookupsRepository.fetchAllCostCenters();
      allAvailableCostCenters
          .assignAll(response.map((json) => CostCenter.fromJson(json)).toList());
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

  List<SunAccount> searchAccounts(String query) {
    if (query.isEmpty) return itemsController.allAvailableAccountsList.toList();
    return itemsController.allAvailableAccountsList
        .where((acc) =>
    acc.name.toLowerCase().contains(query.toLowerCase()) ||
        acc.accountNumber.contains(query))
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

  bool handleBackPress() {
    if (_didJustUpdate) {
      resetForm();
      return true;
    }
    return false;
  }

  void onAccountSelected(SunAccount account) {
    selectedAccount.value = account;
    recipientController.text = account.name;
    descriptionController.text = 'عليكم مقابل سداد من الحساب';
    itemsController.populateFirstRowWithAccount(account);
  }

  Future<void> loadPaymentForEditing(int paymentId) async {
    _didJustUpdate = false;
    isLoading.value = true;
    try {
      final FullReceipt fullReceipt = await _receiptRepository.loadReceipt(paymentId);
      final paymentData = fullReceipt.receipt;

      currentReceiptId.value = paymentData.id;
      headerController.transactionNumber.value = paymentData.transactionNumber;
      headerController.selectedDate.value = paymentData.date;
      recipientController.text = paymentData.accountName;

      await inputController.updateSelectedBox(paymentData.cashBox);
      inputController.updateSelectedCurrency(paymentData.currency);

      descriptionController.text = paymentData.description ?? '';
      calculationsController.updateTotal(paymentData.totalAmount);

      final int? costCenterNo = paymentData.costCenterNo;
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

      final List<ReceiptPaymentItem> paymentItems = fullReceipt.items;
      if (paymentItems.isNotEmpty) {
        final loadedItems = paymentItems.map((item) {
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
        itemsController.loadPaymentItems(loadedItems);
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

  Future<void> savePayment({bool showSuccessMessage = true}) async {
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

    if (recipientController.text.trim().isEmpty ||
        inputController.selectedBox.value.isEmpty ||
        inputController.selectedCurrency.value.isEmpty ||
        descriptionController.text.trim().isEmpty ||
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
      final checkResult = await TrialPeriodManager.checkOnSave(invoiceTypeChar: 'ص');
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

    final Map<String, dynamic> paymentHeaderData = {
      'date': headerController.selectedDate.value.toIso8601String(),
      'cash_box': inputController.selectedBox.value,
      'currency': inputController.selectedCurrency.value,
      'account_name': recipientController.text.trim(),
      'cost_center_no': selectedCostCenter.value?.centerNo,
      'description': descriptionController.text.trim(),
      'total_amount': calculationsController.total.value,
      'amount_in_words': fullAmountInWords,
      'invoice_type_char': _kInvoiceTypeChar,
      'sun_year': userState.safeFinancialYearName,
      'branch_id': userState.userBranch,
      'department_id': userState.userDepartment,
      'source_last_updated_at': DateTime.now().toString(),
    };

    if (isUpdate) {
      paymentHeaderData['id'] = currentReceiptId.value;
      paymentHeaderData['transaction_number'] = headerController.transactionNumber.value;
    }

    try {
      final preparedItems = _preparePaymentItems(itemsToSave);
      final preparedLedger = await _prepareLedgerPostings();

      if (isUpdate) {
        if (!userState.canEdit(_kCurrentScreenName)) {
          showMessage('ليس لديك صلاحية للتعديل.', isError: true);
          isLoading.value = false;
          return;
        }

        await _receiptRepository.updateCompleteReceipt(
          receiptId: currentReceiptId.value!,
          receiptHeader: paymentHeaderData,
          receiptItems: preparedItems,
          ledgerPostings: preparedLedger,
        );

        _didJustUpdate = true;

      } else {
        if (!userState.canAdd(_kCurrentScreenName)) {
          showMessage('ليس لديك صلاحية للإضافة.', isError: true);
          isLoading.value = false;
          return;
        }
        paymentHeaderData['user_id'] = userState.userNo;

        final result = await _receiptRepository.saveCompleteReceipt(
          receiptHeader: paymentHeaderData,
          receiptItems: preparedItems,
          ledgerPostings: preparedLedger,
        );

        currentReceiptId.value = result['id'];
        headerController.transactionNumber.value = result['transaction_number'];

        await TrialPeriodManager.handlePostSave(
          invoiceTypeChar: 'ص',
          screenTitle: 'سند الصرف',
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

    } catch (e) {
      showMessage('خطأ أثناء الحفظ: ${e.toString()}', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> _preparePaymentItems(List<Map<String, dynamic>> itemsToSave) {
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
      throw Exception('حساب الصندوق غير موجود في جدول الحسابات. يرجى التأكد من البيانات.');
    }

    final totalInBaseCurrency = itemsController.items
        .where((p) => p['isEmpty'] == false)
        .fold<double>(0.0, (sum, item) => sum + (item['equivalent_amount'] as double? ?? 0.0));

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

    final creditEntry = {
      'account_id': resolvedBoxAccountId,
      'debit': 0,
      'credit': totalInBaseCurrency,
      'description': 'قيد سند صرف إلى ${recipientController.text}',
      'transaction_date': transactionDate,
      'transaction_type': 'سند صرف',
      'transaction_ref': transactionNumber,
      'beneficiary_name': recipientController.text.trim(),
      'original_amount': calculationsController.total.value,
      'currency_id': mainCurrency.currencyNo,
      'exchange_rate': inputController.selectedExchangeRate.value,
      'cost_center_no': costCenterNo,
      'transaction_id': currentReceiptId.value,
    };

    final debitEntries = itemsController.items
        .where((item) => item['isEmpty'] == false)
        .map((item) {
      if (item['account_id_link'] == null) {
        throw Exception('لم يتم العثور على معرّف الحساب للبند: ${item['account_name']}');
      }
      return {
        'account_id': item['account_id_link'],
        'debit': item['equivalent_amount'],
        'credit': 0,
        'description': 'عن سند صرف رقم $transactionNumber',
        'transaction_date': transactionDate,
        'transaction_type': 'سند صرف',
        'transaction_ref': transactionNumber,
        'beneficiary_name': recipientController.text.trim(),
        'original_amount': item['amount'],
        'currency_id': item['item_currency'],
        'exchange_rate': item['exchange_rate'],
        'cost_center_no': null,
        'transaction_id': currentReceiptId.value,
      };
    }).toList();

    return [creditEntry, ...debitEntries];
  }

  Future<double> _fetchCustomerBalance() async {
    try {
      if (selectedAccount.value == null || selectedAccount.value!.id.isEmpty) return 0.0;

      final String accountId = selectedAccount.value!.id;

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

  Future<void> printPayment() async {
    if (!userState.canPrint(_kCurrentScreenName)) {
      showMessage('ليس لديك صلاحية للطباعة.', isError: true);
      return;
    }

    if (inputController.selectedCurrency.value.isEmpty) {
      showMessage('يرجى اختيار الصندوق والعملة قبل الطباعة.', isError: true);
      return;
    }

    if (!isReadOnly.value) {
      await savePayment(showSuccessMessage: false);
      if (currentReceiptId.value == null) {
        showMessage('فشل حفظ السند، لا يمكن الطباعة.', isError: true);
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
        accountName: recipientController.text,
        cashBox: inputController.selectedBox.value,
        currency: inputController.selectedCurrency.value,
        costCenter: costCenterNameController.text,
        description: descriptionController.text,
        amountInWords: calculationsController.amountInWords.value,
        invoiceTypeChar: _kInvoiceTypeChar,
        userName: userState.userName,
        paymentId: currentReceiptId.value.toString(),
        recipientName: recipientController.text,
        userBranchName: userState.safeUserBranchName,
        userDepartmentName: userState.safeUserDepartmentName,
        companyName: _invoiceTemplatesController.companyNameController.text,
        companyAddress: _invoiceTemplatesController.addressDetailsController.text,
        contactInfo: _invoiceTemplatesController.contactInfoController.text,
        thanksMessage: _invoiceTemplatesController.thanksMessageController.text,
        logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
        showLogo: _invoiceTemplatesController.showLogo.value,
        customerBalance: customerCurrentBalance,
        customerPhone: null,
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

  void navigateToPreviousPayments() async {
    if (isReadOnly.value) {
      showMessage('لا يمكن البحث أثناء عرض سند من السيرفر.', isError: true);
      return;
    }
    if (!userState.canSearch(_kCurrentScreenName)) {
      showMessage('ليس لديك صلاحية للبحث.', isError: true);
      return;
    }
    final dynamic result = await Get.to(() => const PreviousReceiptsScreen(),
        arguments: {'invoiceType': _kInvoiceTypeChar});

    if (result != null) {
      if (result is int) {
        await loadPaymentForEditing(result);
      } else if (result is String) {
        final int? parsedId = int.tryParse(result);
        if (parsedId != null) {
          await loadPaymentForEditing(parsedId);
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
    recipientController.clear();
    selectedAccount.value = null;
    clearSelectedCostCenter();
    descriptionController.clear();
    headerController.generateAndSetNextTransactionNumber();
  }

  void showMessage(String message, {bool isError = false}) {
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

  Future<void> performManualSync() async {
    if (isManualSyncing.value) return;

    isManualSyncing.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedAddress = prefs.getString('server_address');

      if (savedAddress != null && savedAddress.isNotEmpty) {
        final String fullApiUrl = 'http://$savedAddress/api/Receipt/sync-receipt';

        final int syncedCount = await _receiptRepository.syncReceiptsToRemote(
            fullApiUrl,
            "",
            invoiceTypeChar: _kInvoiceTypeChar
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
          final String fullApiUrl = 'http://$savedAddress/api/Receipt/sync-receipt';

          await _receiptRepository.syncReceiptsToRemote(
              fullApiUrl,
              "",
              invoiceTypeChar: _kInvoiceTypeChar
          );
          await _receiptRepository.deleteOldSyncedReceipts();
        }
      } catch (e) {
        log("Background sync error: $e");
      }
    });
  }
}