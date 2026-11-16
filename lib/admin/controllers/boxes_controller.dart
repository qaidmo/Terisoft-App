import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/models/sun_box.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/repositories/account_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/repositories/box_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/repositories/lookups_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../user_state.dart';
import '../printing/funds_pdf_view.dart';
import '../printing/pdf_funds_report.dart';

// تم حذف: supabase_flutter.dart, supabase_manager.dart

class BoxesController extends GetxController {
  // --- المستودعات ---
  final BoxRepository _boxRepository = BoxRepository();
  final AccountRepository _accountRepository = AccountRepository();
  final LookupsRepository _lookupsRepository = LookupsRepository();

  // --- قوائم لإدارة البيانات ---
  final Map<String, String> _accountNamesById = {};
  final RxList<SunBox> allBoxes = <SunBox>[].obs;
  final RxList<SunBox> filteredBoxes = <SunBox>[].obs;
  final RxList<Map<String, dynamic>> accountsList = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredAccounts = <Map<String, dynamic>>[].obs;

  final RxList<SunCurrency> allCurrencies = <SunCurrency>[].obs;
  final RxList<int> selectedBoxCurrencyNos = <int>[].obs;

  // --- متغيرات الحالة ---
  final RxBool isLoading = true.obs;

  // --- متحكمات الحقول والبحث (للعرض فقط) ---
  final noController = TextEditingController();
  final nameController = TextEditingController();
  final searchController = TextEditingController();
  final accountNameController = TextEditingController();
  final accountSearchController = TextEditingController();
  final RxnString selectedAccountId = RxnString();

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
    searchController.addListener(() => filterBoxes(searchController.text));
    accountSearchController.addListener(() => filterAccounts(accountSearchController.text));
  }

  @override
  void onClose() {
    noController.dispose();
    nameController.dispose();
    searchController.dispose();
    accountNameController.dispose();
    accountSearchController.dispose();
    super.onClose();
  }

  /// جلب اسم الحساب الأب بناءً على المعرف
  String getParentAccountName(String? parentId) {
    if (parentId == null) return 'N/A';
    return _accountNamesById[parentId] ?? 'غير معروف';
  }

  /// جلب كل البيانات الأولية اللازمة للشاشة
  Future<void> fetchInitialData() async {
    isLoading.value = true;
    try {
      final initialResponses = await Future.wait([
        _boxRepository.fetchAllBoxesWithDetails(),
        _lookupsRepository.fetchAllAccountNames(),
        _lookupsRepository.fetchAllCurrencies(),
      ]);

      allBoxes.assignAll(initialResponses[0] as List<SunBox>);
      filteredBoxes.assignAll(allBoxes);

      final allAccountsForMap = initialResponses[1] as List<Map<String, dynamic>>;
      _accountNamesById.clear();
      for (var acc in allAccountsForMap) {
        if (acc['id'] != null && acc['name'] != null) {
          _accountNamesById[acc['id']] = acc['name'];
        }
      }

      allCurrencies.assignAll(initialResponses[2] as List<SunCurrency>);

      const List<String> parentAccountNumbers = ['1211', '1212', '1213', '1221'];
      final List<String> parentIds = await _accountRepository.getParentIdsByNumbers(parentAccountNumbers);

      accountsList.clear();
      filteredAccounts.clear();
      if (parentIds.isNotEmpty) {
        final accountsResponse = await _accountRepository.getTransactionalChildrenOfParents(parentIds);
        accountsList.assignAll(accountsResponse);
        filteredAccounts.assignAll(accountsList);
      }

    } catch (e) {
      showMessage('حدث خطأ أثناء جلب البيانات: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  /// تصفية قائمة الصناديق المعروضة بناءً على استعلام البحث
  void filterBoxes(String query) {
    if (query.isEmpty) {
      filteredBoxes.assignAll(allBoxes);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredBoxes.assignAll(allBoxes.where((box) {
        final nameMatch = box.boxName.toLowerCase().contains(lowerCaseQuery);
        final noMatch = box.boxNo?.toString().contains(lowerCaseQuery) ?? false;
        final accountNameMatch = box.linkedAccount?.name.toLowerCase().contains(lowerCaseQuery) ?? false;
        return nameMatch || noMatch || accountNameMatch;
      }).toList());
    }
  }

  /// تصفية قائمة الحسابات المعروضة في نافذة البحث
  void filterAccounts(String query) {
    if (query.isEmpty) {
      filteredAccounts.assignAll(accountsList);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredAccounts.assignAll(accountsList.where((acc) {
        final nameMatch = acc['name'].toString().toLowerCase().contains(lowerCaseQuery);
        final numberMatch = acc['account_number'].toString().contains(lowerCaseQuery);
        return nameMatch || numberMatch;
      }).toList());
    }
  }

  /// مسح الحقول عند إلغاء التحديد أو الإضافة (للعرض فقط)
  Future<void> clearForm() async {
    nameController.clear();
    noController.clear();
    accountNameController.clear();
    selectedAccountId.value = null;
    selectedBoxCurrencyNos.clear();
  }

  /// عرض بيانات الصندوق المختار في الحقول
  void displayBox(SunBox box) {
    noController.text = box.boxNo?.toString() ?? '';
    nameController.text = box.boxName;
    selectAccount(box.accountId, box.linkedAccount?.name);
    selectedBoxCurrencyNos.assignAll(box.currencyNos);
  }

  /// تحديد الحساب المرتبط بالصندوق
  void selectAccount(String? id, String? name) {
    selectedAccountId.value = id;
    accountNameController.text = name ?? '';
  }

  /// إضافة عملة للصندوق (غير وظيفية للقراءة فقط)
  void addCurrencyToBox(int currencyNo) {
    // فارغة
  }

  /// إزالة عملة من الصندوق (غير وظيفية للقراءة فقط)
  void removeCurrencyFromBox(int currencyNo) {
    // فارغة
  }

  /// طباعة بيانات الصناديق
  void printData() async {
    List<SunBox> dataToPrint = [];
    String reportTitle = '';

    if (searchController.text.isNotEmpty) {
      dataToPrint = filteredBoxes.toList();
      reportTitle = 'طباعة نتائج البحث عن: "${searchController.text}"';
    } else {
      dataToPrint = allBoxes.toList();
      reportTitle = 'تقرير بجميع الصناديق';
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
      final userState = Get.find<UserState>();
      final currentUserName = userState.safeUserName;

      final pdfData = await PdfFundsReport.generate(
        boxes: dataToPrint,
        reportTitle: reportTitle,
        userName: currentUserName,
      );

      Get.back(); // Close loading dialog

      Get.to(() => FundsPdfView(
        pdfData: pdfData,
        reportTitle: reportTitle,
      ));

    } catch (e) {
      Get.back(); // Close loading dialog
      showMessage('حدث خطأ أثناء إنشاء الـ PDF: $e', isError: true);
    }
  }

  /// عرض رسالة Snackbar
  void showMessage(String message, {bool isError = false}) {
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }
}