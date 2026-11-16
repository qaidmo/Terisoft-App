import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_fancy_tree_view/flutter_fancy_tree_view.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/printing/pdf_accounts_report.dart';
import 'package:untitled4/repositories/account_repository.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../models/sun_account_model.dart';
import '../../user_state.dart';
import '../account_screen.dart';
import '../printing/funds_pdf_view.dart';

class AccountController extends GetxController {
  final AccountRepository _accountRepository = AccountRepository();
  final LookupsRepository _lookupsRepository = LookupsRepository();

  var isLoading = true.obs;
  var allAccounts = <SunAccount>[].obs;
  var mainTypes = <Map<String, dynamic>>[].obs;
  var majorTypes = <Map<String, dynamic>>[].obs;
  var allClassifications = <Map<String, dynamic>>[].obs;
  var filteredClassifications = <Map<String, dynamic>>[].obs;
  var currencies = <Map<String, dynamic>>[].obs; // Keep this for now

  late final TreeController<SunAccount> treeController;
  var selectedAccount = Rxn<SunAccount>();
  var parentAccountDisplay = ''.obs;

  var searchResults = <SunAccount>[].obs;
  late TextEditingController searchController;
  var accountMap = <String, SunAccount>{}.obs;

  @override
  void onInit() {
    super.onInit();
    treeController = TreeController<SunAccount>(
        roots: [], childrenProvider: (node) => node.children);
    searchController = TextEditingController();
    fetchInitialData();
  }

  @override
  void onClose() {
    treeController.dispose();
    searchController.dispose();
    super.onClose();
  }

  void _showSnackbar(String title, String message, {bool isError = false}) {
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }

  Future<void> fetchInitialData() async {
    try {
      isLoading.value = true;
      final responses = await Future.wait([
        _accountRepository.fetchAllAccounts(),
        _lookupsRepository.fetchAllAccountTypes(),
        _lookupsRepository.fetchAllMajorAccountTypes(),
        _lookupsRepository.fetchAllAccountClassifications(),
        // Assuming fetchAllCurrencies returns List<SunCurrency>
        _lookupsRepository.fetchAllCurrencies(),
      ]);

      allAccounts.value = responses[0] as List<SunAccount>;
      mainTypes.value = responses[1] as List<Map<String, dynamic>>;
      majorTypes.value = responses[2] as List<Map<String, dynamic>>;
      allClassifications.value = responses[3] as List<Map<String, dynamic>>;

      // Convert SunCurrency list back to Map list if needed by UI
      currencies.value = (responses[4] as List<dynamic>)
          .map((currency) => {
        'currency_no': currency.currencyNo,
        'currency_name': currency.currencyName
      })
          .toList();

      _buildTree();
    } catch (e) {
      _showSnackbar(
          'خطأ فادح', 'فشل في جلب بيانات دليل الحسابات: ${e.toString()}',
          isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  void _buildTree() {
    accountMap.value = {for (var acc in allAccounts) acc.id: acc};
    List<SunAccount> rootNodes = [];

    for (var acc in allAccounts) {
      acc.children.clear();
    }

    for (var account in allAccounts) {
      if (account.parentId != null &&
          accountMap.containsKey(account.parentId)) {
        accountMap[account.parentId]!.children.add(account);
      } else {
        rootNodes.add(account);
      }
    }
    treeController.roots = rootNodes;
    treeController.rebuild();
    searchResults.value = allAccounts.toList();
  }

  void expandTreeToNode(SunAccount node) {
    SunAccount? currentNode = node;
    final List<SunAccount> ancestors = [];
    while (currentNode?.parentId != null &&
        accountMap.containsKey(currentNode!.parentId)) {
      final parent = accountMap[currentNode.parentId!]!;
      ancestors.add(parent);
      currentNode = parent;
    }
    for (final ancestor in ancestors.reversed) {
      treeController.expand(ancestor);
    }
  }

  void selectAccount(SunAccount account) {
    expandTreeToNode(account);
    selectedAccount.value = account;

    final parentAccount =
    allAccounts.firstWhereOrNull((a) => a.id == account.parentId);
    parentAccountDisplay.value = parentAccount != null
        ? "${parentAccount.name} (${parentAccount.accountNumber})"
        : "لا يوجد أب (حساب رئيسي)";

    searchController.clear();
    searchResults.value = allAccounts.toList();
  }

  void showSearchDialog() {
    searchController.clear();
    searchAccounts('');
    Get.dialog(
      const AccountSearchDialog(),
      barrierDismissible: false,
    );
  }

  void searchAccounts(String query) {
    if (query.isEmpty) {
      searchResults.value = allAccounts.toList();
    } else {
      final queryLower = query.toLowerCase();
      searchResults.value = allAccounts.where((account) {
        final nameMatch = account.name.toLowerCase().contains(queryLower);
        final nameEnMatch =
        (account.nameEn ?? '').toLowerCase().contains(queryLower);
        final numberMatch = account.accountNumber.contains(query);
        return nameMatch || nameEnMatch || numberMatch;
      }).toList();
    }
  }

  String getParentAccountNumber(SunAccount account) {
    if (account.parentId == null) {
      return 'لا يوجد';
    }
    final parent = accountMap[account.parentId];
    return parent?.accountNumber ?? 'غير معروف';
  }

  void printAccounts() async {
    List<SunAccount> initialAccounts = [];
    String reportTitle = '';

    if (selectedAccount.value != null) {
      initialAccounts.add(selectedAccount.value!);
      reportTitle = 'طباعة بيانات حساب: ${selectedAccount.value!.name}';
    } else if (searchController.text.isNotEmpty) {
      initialAccounts = searchResults.toList();
      reportTitle = 'طباعة نتائج البحث عن: "${searchController.text}"';
    } else {
      initialAccounts = allAccounts.toList();
      reportTitle = 'تقرير شامل بدليل الحسابات';
    }

    if (initialAccounts.isEmpty) {
      _showSnackbar('خطأ', 'لا توجد بيانات للطباعة.', isError: true);
      return;
    }

    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);

    try {
      final List<Map<String, String>> finalReportData = [];
      final transactionalAccountIds = initialAccounts
          .where((acc) => acc.isTransactional)
          .map((acc) => acc.id)
          .toList();

      Map<String, List<String>> currencyMap = {};

      if (transactionalAccountIds.isNotEmpty) {
        final currencyRelations = await _lookupsRepository
            .fetchCurrenciesForAccounts(transactionalAccountIds);

        for (var relation in currencyRelations) {
          final accountId = relation['account_id'];
          final currencyName =
              relation['sun_currencies']?['currency_name'] ?? 'غير معروفة';
          if (accountId != null) {
            currencyMap.putIfAbsent(accountId, () => []).add(currencyName);
          }
        }
      }

      for (final account in initialAccounts) {
        final parentAccountNumber = account.parentId != null
            ? (accountMap[account.parentId]?.accountNumber ?? '-')
            : 'حساب رئيسي';

        if (account.isTransactional &&
            currencyMap.containsKey(account.id) &&
            currencyMap[account.id]!.isNotEmpty) {
          for (final currencyName in currencyMap[account.id]!) {
            finalReportData.add({
              'number': account.accountNumber,
              'name': account.name,
              'nameEn': account.nameEn ?? '-',
              'nature': account.nature,
              'parent': parentAccountNumber,
              'currency': currencyName,
            });
          }
        } else {
          finalReportData.add({
            'number': account.accountNumber,
            'name': account.name,
            'nameEn': account.nameEn ?? '-',
            'nature': account.nature,
            'parent': parentAccountNumber,
            'currency': account.isTransactional ? 'ريال يمني (افتراضي)' : '-',
          });
        }
      }

      final userState = Get.find<UserState>();
      final currentUserName = userState.safeUserName;

      final pdfData = await PdfAccountsReport.generate(
        reportData: finalReportData,
        reportTitle: reportTitle,
        userName: currentUserName,
      );

      Get.back();

      Get.to(() => FundsPdfView(pdfData: pdfData, reportTitle: reportTitle));
    } catch (e) {
      Get.back();
      _showSnackbar('خطأ فادح', 'حدث خطأ أثناء إنشاء الـ PDF: ${e.toString()}',
          isError: true);
    }
  }
}