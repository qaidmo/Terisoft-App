import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/models/sun_store.dart';
import 'package:untitled4/repositories/account_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/repositories/lookups_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/repositories/store_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/utils/snackbar_helper.dart';
import '../printing/funds_pdf_view.dart';
import '../printing/pdf_stores_report.dart';


class StoreController extends GetxController {
  final StoreRepository _storeRepository = StoreRepository(); // <-- تم الإضافة
  final AccountRepository _accountRepository = AccountRepository(); // <-- تم الإضافة
  final LookupsRepository _lookupsRepository = LookupsRepository(); // <-- تم الإضافة

  final RxList<SunStore> allStores = <SunStore>[].obs;
  final RxList<SunStore> filteredStores = <SunStore>[].obs;
  final RxList<Map<String, dynamic>> transactionalAccounts = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> allBranches = <Map<String, dynamic>>[].obs;

  final RxBool isLoading = true.obs;

  final noController = TextEditingController();
  final nameController = TextEditingController();
  final searchController = TextEditingController();
  final RxnString selectedAccountId = RxnString();
  final RxnInt selectedBranchId = RxnInt();

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
    searchController.addListener(() {
      filterStores(searchController.text);
    });
  }

  @override
  void onClose() {
    noController.dispose();
    nameController.dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> fetchInitialData() async {
    isLoading.value = true;
    try {
      const String parentAccountNumber = '1241';

      final parentAccountResponse =
      await _accountRepository.getAccountByTrimmedNumber(parentAccountNumber); // <-- تم التعديل

      if (parentAccountResponse == null || parentAccountResponse['id'] == null) {
        showMessage('خطأ: الحساب الرئيسي للمخازن رقم "$parentAccountNumber" غير موجود.', isError: true);
        isLoading.value = false;
        return;
      }

      final parentAccountId = parentAccountResponse['id'];

      final responses = await Future.wait([
        _storeRepository.fetchAllStoresWithDetails(), // <-- تم التعديل
        _accountRepository.getTransactionalChildrenOfParent(parentAccountId), // <-- تم التعديل
        _lookupsRepository.fetchAllBranches(), // <-- تم التعديل
      ]);

      allStores.assignAll(responses[0] as List<SunStore>);
      filteredStores.assignAll(allStores);
      transactionalAccounts.assignAll(responses[1] as List<Map<String, dynamic>>);
      allBranches.assignAll(responses[2] as List<Map<String, dynamic>>);

    } catch (e) {
      showMessage('حدث خطأ أثناء جلب البيانات: ${e.toString()}', isError: true); // <-- عرض الخطأ
    } finally {
      isLoading.value = false;
    }
  }

  void filterStores(String query) {
    if (query.isEmpty) {
      filteredStores.assignAll(allStores);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredStores.assignAll(allStores.where((store) {
        final nameMatch = store.nameStore.toLowerCase().contains(lowerCaseQuery);
        final noMatch = store.noStore.toString().contains(lowerCaseQuery);
        final accountNameMatch = store.linkedAccount?.name.toLowerCase().contains(lowerCaseQuery) ?? false;
        final branchNameMatch = allBranches
            .firstWhereOrNull((branch) => branch['branch_id'] == store.branchId)?['branch_name']
            .toString()
            .toLowerCase()
            .contains(lowerCaseQuery) ?? false;
        return nameMatch || noMatch || accountNameMatch || branchNameMatch;
      }).toList());
    }
  }

  Future<void> clearForm() async {
    noController.clear();
    nameController.clear();
    selectedAccountId.value = null;
    selectedBranchId.value = null;
  }

  void displayStore(SunStore store) {
    noController.text = store.noStore.toString();
    nameController.text = store.nameStore;
    selectedAccountId.value = store.inventoryAccountId;
    selectedBranchId.value = store.branchId;
  }

  void printData() async {
    List<SunStore> dataToPrint;
    String reportTitle;

    if (searchController.text.isNotEmpty) {
      dataToPrint = filteredStores.toList();
      reportTitle = 'طباعة نتائج البحث عن: "${searchController.text}"';
    } else {
      dataToPrint = allStores.toList();
      reportTitle = 'تقرير بجميع المخازن';
    }

    if (dataToPrint.isEmpty) {
      showMessage('لا توجد بيانات للطباعة.', isError: true);
      return;
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final pdfData = await PdfStoresReport.generate(
        stores: dataToPrint,
        reportTitle: reportTitle,
      );

      Get.back();
      Get.to(() => FundsPdfView(
        pdfData: pdfData,
        reportTitle: reportTitle,
      ));

    } catch (e) {
      Get.back();
      showMessage('حدث خطأ أثناء إنشاء الـ PDF: $e', isError: true);
    }
  }

  String getBranchName(int? branchId) {
    if (branchId == null) return 'غير محدد';
    final branch = allBranches.firstWhereOrNull((b) => b['branch_id'] == branchId);
    return branch?['branch_name'] ?? 'غير معروف';
  }

  void showMessage(String message, {bool isError = false}) {
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }
}