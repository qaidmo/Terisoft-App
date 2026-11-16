import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/utils/snackbar_helper.dart';


class AgentsController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository();

  final RxBool isLoading = true.obs;

  final noController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final accountNameController = TextEditingController();
  final mainSearchController = TextEditingController();

  final percentageController = TextEditingController();
  final RxBool commissionsDisabled = false.obs;
  final expenseAccountNameController = TextEditingController();

  final Rxn<String> selectedAccountId = Rxn<String>();
  final Rxn<String> selectedExpenseAccountId = Rxn<String>();

  final RxList<Map<String, dynamic>> allSalespeople =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredSalespeople =
      <Map<String, dynamic>>[].obs;

  final accountSearchController = TextEditingController();
  final RxList<Map<String, dynamic>> allAccounts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredAccounts =
      <Map<String, dynamic>>[].obs;

  final Map<String, String> _accountNamesById = {};

  @override
  void onInit() {
    super.onInit();
    fetchSalespeople();
    fetchAccountsForDialogs();

    mainSearchController
        .addListener(() => filterMainSalespeople(mainSearchController.text));
    accountSearchController
        .addListener(() => filterAccounts(accountSearchController.text));
  }

  @override
  void onClose() {
    noController.dispose();
    nameController.dispose();
    phoneController.dispose();
    accountNameController.dispose();
    mainSearchController.dispose();
    accountSearchController.dispose();
    percentageController.dispose();
    expenseAccountNameController.dispose();
    super.onClose();
  }

  Future<void> fetchSalespeople() async {
    isLoading.value = true;
    try {
      final response = await _lookupsRepository.fetchAllAgentsWithDetails();
      allSalespeople.assignAll(response);
      filteredSalespeople.assignAll(allSalespeople);
    } catch (e) {
      _showMessage('خطأ في جلب بيانات الوكلاء: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchAccountsForDialogs() async {
    try {
      final accountsData = await _lookupsRepository.getAllTransactionalAccounts();
      allAccounts.assignAll(accountsData);
      filteredAccounts.assignAll(allAccounts);

      // Use repository for all account names
      _accountNamesById.clear();
      final allSystemAccounts = await _lookupsRepository.fetchAllAccountNames(); // <-- Needs new method in repository
      for (var acc in allSystemAccounts) {
        if (acc['id'] != null && acc['name'] != null) {
          _accountNamesById[acc['id']] = acc['name'];
        }
      }

    } catch (e) {
      _showMessage('خطأ في جلب بيانات الحسابات: $e', isError: true);
    }
  }


  String getParentAccountName(String? parentId) {
    if (parentId == null) return '';
    return _accountNamesById[parentId] ?? 'غير معروف';
  }

  void filterMainSalespeople(String query) {
    if (query.isEmpty) {
      filteredSalespeople.assignAll(allSalespeople);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredSalespeople.assignAll(allSalespeople.where((sp) {
        final nameMatch =
        (sp['salesperson_name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final noMatch = (sp['salesperson_no']?.toString() ?? '').contains(lowerCaseQuery);
        return nameMatch || noMatch;
      }).toList());
    }
  }

  void filterAccounts(String query) {
    if (query.isEmpty) {
      filteredAccounts.assignAll(allAccounts);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredAccounts.assignAll(allAccounts.where((acc) {
        final nameMatch =
        (acc['name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final noMatch = (acc['account_number'] as String? ?? '')
            .toLowerCase()
            .contains(lowerCaseQuery);
        final enNameMatch =
        (acc['name_en'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        return nameMatch || noMatch || enNameMatch;
      }).toList());
    }
  }

  void displaySalesperson(Map<String, dynamic> salesperson) {
    noController.text = salesperson['salesperson_no']?.toString() ?? '';
    nameController.text = salesperson['salesperson_name'] ?? '';
    phoneController.text = salesperson['phone_number'] ?? '';

    selectedAccountId.value = salesperson['account_id'];
    accountNameController.text = salesperson['account_name'] ?? 'غير محدد';

    percentageController.text = salesperson['percentage']?.toString() ?? '';
    commissionsDisabled.value = salesperson['commissions_disabled'] ?? false;

    selectedExpenseAccountId.value = salesperson['expense_account_id'];
    expenseAccountNameController.text = salesperson['expense_account_name'] ?? 'غير محدد';
  }

  void clearForm() {
    noController.clear();
    nameController.clear();
    phoneController.clear();
    accountNameController.clear();
    percentageController.clear();
    expenseAccountNameController.clear();

    selectedAccountId.value = null;
    selectedExpenseAccountId.value = null;
    commissionsDisabled.value = false;
  }

  void selectAccount(String accountId, String accountName) {
    selectedAccountId.value = accountId;
    accountNameController.text = accountName;
    Get.back();
  }

  void selectExpenseAccount(String accountId, String accountName) {
    selectedExpenseAccountId.value = accountId;
    expenseAccountNameController.text = accountName;
    Get.back();
  }

  void _showMessage(String message, {bool isError = false}) {
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }

  void printSalespeople() async {
    _showMessage('منطق الطباعة غير متاح حالياً في هذا النموذج.');
  }
}