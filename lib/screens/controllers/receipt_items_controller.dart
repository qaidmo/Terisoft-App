import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/models/sun_customer.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/screens/controllers/receipt_input_controller.dart';
import 'package:untitled4/screens/controllers/receipt_calculations_controller.dart';
import 'package:untitled4/models/sun_account_model.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'dart:async';
import '../../utils/snackbar_helper.dart';

class ReceiptItemsController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final ReceiptCalculationsController calculationsController;

  final RxList<Map<String, dynamic>> items = <Map<String, dynamic>>[].obs;
  final RxList<SunAccount> allAvailableAccountsList = <SunAccount>[].obs;
  final RxBool isLoadingAccounts = false.obs;
  final RxList<SunCurrency> allAvailableCurrenciesList = <SunCurrency>[].obs;
  final RxBool isLoadingCurrencies = false.obs;

  final Map<int, TextEditingController> _amountControllers = {};
  final Map<int, TextEditingController> _accountNoControllers = {};
  final Map<int, TextEditingController> _accountNameControllers = {};
  final Map<int, TextEditingController> _exchangeRateControllers = {};
  final Map<int, TextEditingController> _equivalentAmountControllers = {};

  Timer? _debounce;
  static const int initialEmptyRows = 2;

  ReceiptItemsController({required this.calculationsController});

  @override
  void onInit() {
    super.onInit();
    ever(items, (_) => _updateTotalAmount());
    if (items.isEmpty) _initializeEmptyItems();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _disposeAllControllers();
    super.onClose();
  }

  void _disposeAllControllers() {
    for (var c in _amountControllers.values) {
      c.dispose();
    }
    for (var c in _accountNoControllers.values) {
      c.dispose();
    }
    for (var c in _accountNameControllers.values) {
      c.dispose();
    }
    for (var c in _exchangeRateControllers.values) {
      c.dispose();
    }
    for (var c in _equivalentAmountControllers.values) {
      c.dispose();
    }

    _amountControllers.clear();
    _accountNoControllers.clear();
    _accountNameControllers.clear();
    _exchangeRateControllers.clear();
    _equivalentAmountControllers.clear();
  }

  String _formatStrictNoDecimals(dynamic amount) {
    if (amount == null) return '';
    double val = double.tryParse(amount.toString()) ?? 0.0;
    if (val == 0) return '';
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toString();
  }

  TextEditingController getAmountController(int index) {
    String initialText = _formatStrictNoDecimals(items[index]['amount']);
    _amountControllers.putIfAbsent(index, () => TextEditingController(text: initialText));
    return _amountControllers[index]!;
  }

  TextEditingController getAccountNoController(int index) {
    _accountNoControllers.putIfAbsent(index, () => TextEditingController(text: items[index]['account_no']?.toString() ?? ''));
    return _accountNoControllers[index]!;
  }

  TextEditingController getAccountNameController(int index) {
    _accountNameControllers.putIfAbsent(index, () => TextEditingController(text: items[index]['account_name']?.toString() ?? ''));
    return _accountNameControllers[index]!;
  }

  TextEditingController getExchangeRateController(int index) {
    String initialText = _formatStrictNoDecimals(items[index]['exchange_rate'] ?? 1.0);
    _exchangeRateControllers.putIfAbsent(index, () => TextEditingController(text: initialText.isEmpty ? '1' : initialText));
    return _exchangeRateControllers[index]!;
  }

  TextEditingController getEquivalentAmountController(int index) {
    String initialText = _formatStrictNoDecimals(items[index]['equivalent_amount']);
    _equivalentAmountControllers.putIfAbsent(index, () => TextEditingController(text: initialText));
    return _equivalentAmountControllers[index]!;
  }

  Future<void> loadAllAvailableAccounts() async {
    isLoadingAccounts.value = true;
    try {
      final List<SunAccount> response = await _lookupsRepository.fetchAllAccounts();
      allAvailableAccountsList.assignAll(response);
    } catch (e) {
      print('Error fetching accounts: ${e.toString()}');
    } finally {
      isLoadingAccounts.value = false;
    }
  }

  Future<void> loadAllAvailableCurrencies() async {
    isLoadingCurrencies.value = true;
    try {
      final List<SunCurrency> response = await _lookupsRepository.fetchAllCurrencies();
      allAvailableCurrenciesList.assignAll(response);
    } catch (e) {
      print('Error fetching currencies: ${e.toString()}');
    } finally {
      isLoadingCurrencies.value = false;
    }
  }

  Map<String, dynamic> createEmptyItemPlaceholder() {
    return {
      'id': null,
      'account_id_link': null,
      'account_no': '',
      'account_name': '',
      'amount': 0.0,
      'item_currency': null,
      'exchange_rate': 1.0,
      'equivalent_amount': 0.0,
      'isEmpty': true,
      'allowed_currencies': <SunCurrency>[],
    };
  }

  void _initializeEmptyItems() {
    _disposeAllControllers();
    items.clear();
    for (int i = 0; i < initialEmptyRows; i++) {
      items.add(createEmptyItemPlaceholder());
    }
  }

  void addNewItem() {
    items.add(createEmptyItemPlaceholder());
  }

  void removeItem(int index) {
    if (index < 0 || index >= items.length) return;
    _amountControllers.remove(index)?.dispose();
    _accountNoControllers.remove(index)?.dispose();
    _accountNameControllers.remove(index)?.dispose();
    _exchangeRateControllers.remove(index)?.dispose();
    _equivalentAmountControllers.remove(index)?.dispose();
    items.removeAt(index);
    if (items.isEmpty) addNewItem();
  }

  void loadReceiptItems(List<Map<String, dynamic>> loadedData) {
    _disposeAllControllers();
    items.assignAll(loadedData.map((item) => { ...item, 'isEmpty': false }).toList());
    if (items.every((item) => item['isEmpty'] == false)) addNewItem();
    for (var i = 0; i < items.length; i++) {
      getAmountController(i).text = _formatStrictNoDecimals(items[i]['amount']);
      getAccountNoController(i).text = items[i]['account_no']?.toString() ?? '';
      getAccountNameController(i).text = items[i]['account_name']?.toString() ?? '';

      String rate = _formatStrictNoDecimals(items[i]['exchange_rate'] ?? 1.0);
      getExchangeRateController(i).text = rate.isEmpty ? '1' : rate;

      getEquivalentAmountController(i).text = _formatStrictNoDecimals(items[i]['equivalent_amount']);
    }
  }

  void resetItems() {
    _initializeEmptyItems();
  }

  Future<void> populateFirstRowWithCustomerAccount(SunCustomer customer) async {
    if (customer.accountId == null || customer.accountNumber == null) {
      AppSnackbar.showCustomSnackbar('تنبيه', 'بيانات الحساب المرتبطة بهذا العميل غير مكتملة.', isError: true);
      return;
    }

    int firstEmptyIndex = items.indexWhere((item) => item['isEmpty'] == true);
    if (firstEmptyIndex == -1) {
      addNewItem();
      firstEmptyIndex = items.length - 1;
    }
    final item = items[firstEmptyIndex];

    item['account_id_link'] = customer.accountId;
    item['account_no'] = customer.accountNumber;
    item['account_name'] = customer.accountName ?? customer.customerName;
    item['amount'] = 0.0;
    item['equivalent_amount'] = 0.0;

    try {
      final List<SunCurrency> customerCurrencies = await _lookupsRepository.fetchCurrenciesForCustomer(customer.customerNo);
      _setCurrenciesForItem(firstEmptyIndex, customerCurrencies);
    } catch (e) {
      _setCurrenciesForItem(firstEmptyIndex, []);
    }

    item['isEmpty'] = false;
    getAccountNoController(firstEmptyIndex).text = customer.accountNumber!;
    getAccountNameController(firstEmptyIndex).text = customer.accountName ?? customer.customerName;
    getAmountController(firstEmptyIndex).text = '';
    getEquivalentAmountController(firstEmptyIndex).text = '';

    items[firstEmptyIndex] = Map<String, dynamic>.from(item);
    if (items.every((i) => i['isEmpty'] == false)) addNewItem();
  }

  Future<void> onAccountSelectedInTable(int index, SunAccount selectedAccount) async {
    if (index >= 0 && index < items.length) {
      final item = items[index];

      item['account_id_link'] = selectedAccount.id;
      item['account_no'] = selectedAccount.accountNumber;
      item['account_name'] = selectedAccount.name;

      await fetchAndSetCurrenciesForRow(index, selectedAccount.id);

      getAccountNoController(index).text = selectedAccount.accountNumber;
      getAccountNameController(index).text = selectedAccount.name;
      item['isEmpty'] = false;
      items[index] = Map<String, dynamic>.from(item);
      if (items.every((i) => i['isEmpty'] == false)) addNewItem();
    }
  }

  Future<void> fetchAndSetCurrenciesForRow(int index, dynamic accountId) async {
    if (accountId == null) return;

    try {
      final List<SunCurrency> fetchedCurrencies = await _lookupsRepository.fetchCurrenciesForAccount(accountId.toString());
      _setCurrenciesForItem(index, fetchedCurrencies);
    } catch (e) {
      _setCurrenciesForItem(index, []);
    }
  }

  void _setCurrenciesForItem(int index, List<SunCurrency> currencies) {
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    item['allowed_currencies'] = currencies;
    if (currencies.isNotEmpty) {
      final defaultCurrency = currencies.first;
      item['item_currency'] = defaultCurrency.currencyNo;
      _updateExchangeRateBasedOnCurrency(item, defaultCurrency.currencyName);
    } else {
      item['item_currency'] = null;
      item['exchange_rate'] = 1.0;
      getExchangeRateController(index).text = "1";
    }
    items[index] = Map<String, dynamic>.from(item);
  }

  Iterable<SunAccount> searchAccountsByName(String query) {
    final results = allAvailableAccountsList.where((account) {
      final bool isMatch = query.isEmpty || account.name.toLowerCase().contains(query.toLowerCase()) || account.accountNumber.toLowerCase().contains(query.toLowerCase());
      return account.isTransactional && isMatch;
    });
    return results;
  }

  String getParentAccountName(dynamic parentId) {
    if (parentId == null) return 'N/A';
    final parentAccount = allAvailableAccountsList.firstWhereOrNull((acc) => acc.id.toString() == parentId.toString());
    return parentAccount?.name ?? 'غير معروف';
  }

  void updateItemAmount(int index, double newAmount) {
    if (index >= 0 && index < items.length) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        final item = items[index];
        item['amount'] = newAmount;
        if (item['isEmpty'] == true && newAmount > 0) {
          item['isEmpty'] = false;
          if (items.every((i) => i['isEmpty'] == false)) addNewItem();
        }
        _calculateEquivalentAmount(index);
        items[index] = Map<String, dynamic>.from(item);
      });
    }
  }

  void updateItemCurrency(int index, int? newCurrencyNo) {
    if (index >= 0 && index < items.length && newCurrencyNo != null) {
      final item = items[index];
      item['item_currency'] = newCurrencyNo;
      final selectedCurrency = allAvailableCurrenciesList.firstWhereOrNull((c) => c.currencyNo == newCurrencyNo);
      if (selectedCurrency != null) {
        _updateExchangeRateBasedOnCurrency(item, selectedCurrency.currencyName);
      }
      items[index] = Map<String, dynamic>.from(item);
    }
  }

  void updateItemExchangeRate(int index, double newRate) {
    if (index >= 0 && index < items.length) {
      final item = items[index];
      item['exchange_rate'] = newRate > 0 ? newRate : 1.0;
      _calculateEquivalentAmount(index);
      items[index] = Map<String, dynamic>.from(item);
    }
  }

  void _updateExchangeRateBasedOnCurrency(Map<String, dynamic> item, String currencyName) {
    final SunCurrency? foundCurrency = allAvailableCurrenciesList.firstWhereOrNull((c) => c.currencyName == currencyName || c.currencySymbol == currencyName);
    item['exchange_rate'] = foundCurrency?.currencyRate ?? 1.0;

    final index = items.indexOf(item);
    if(index != -1){
      String rateText = _formatStrictNoDecimals(item['exchange_rate']);
      getExchangeRateController(index).text = rateText.isEmpty ? '1' : rateText;
      _calculateEquivalentAmount(index);
    }
  }

  void _calculateEquivalentAmount(int index) {
    final double amount = (items[index]['amount'] as double?) ?? 0.0;
    final double itemExchangeRate = (items[index]['exchange_rate'] as double?) ?? 1.0;

    final inputController = Get.find<ReceiptInputController>();
    final mainCurrencyName = inputController.selectedCurrency.value;
    final mainCurrencyObject = allAvailableCurrenciesList.firstWhereOrNull(
          (c) => c.currencyName == mainCurrencyName,
    );
    final double mainExchangeRate = mainCurrencyObject?.currencyRate ?? 1.0;

    double equivalent = 0.0;

    if (itemExchangeRate != 0) {
      equivalent = amount * (mainExchangeRate / itemExchangeRate);
    }

    items[index]['equivalent_amount'] = equivalent;

    if (_equivalentAmountControllers.containsKey(index)) {
      _equivalentAmountControllers[index]!.text = _formatStrictNoDecimals(equivalent);
    }
  }

  void recalculateAllEquivalentAmounts() {
    for (int i = 0; i < items.length; i++) {
      if (items[i]['isEmpty'] == false) {
        _calculateEquivalentAmount(i);
      }
    }
    items.refresh();
  }

  void _updateTotalAmount() {
    if (!Get.isRegistered<ReceiptInputController>()) return;

    double totalInBoxCurrency = 0.0;
    for (var item in items) {
      if (item['isEmpty'] == false) {
        totalInBoxCurrency += (item['amount'] as double?) ?? 0.0;
      }
    }

    calculationsController.updateTotal(totalInBoxCurrency);
  }

  Future<void> fetchAllowedCurrenciesOnly(int index, dynamic accountId) async {
    if (index < 0 || index >= items.length) return;
    if (accountId == null) return;

    final item = items[index];
    try {
      final List<SunCurrency> fetchedCurrencies =
      await _lookupsRepository.fetchCurrenciesForAccount(accountId.toString());

      item['allowed_currencies'] = fetchedCurrencies;

    } catch (e) {
      item['allowed_currencies'] = <SunCurrency>[];
    } finally {
      items[index] = Map<String, dynamic>.from(item);
    }
  }
}