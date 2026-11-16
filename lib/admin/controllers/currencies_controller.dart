import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/repositories/lookups_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../user_state.dart';
import '../printing/funds_pdf_view.dart';
import '../printing/pdf_currencies_report.dart';

// تم حذف: supabase_flutter.dart, supabase_manager.dart

class CurrenciesController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository(); // <-- تم الإضافة

  final RxList<SunCurrency> allCurrencies = <SunCurrency>[].obs;
  final RxList<SunCurrency> filteredCurrencies = <SunCurrency>[].obs;

  final RxBool isLoading = true.obs;

  final noController = TextEditingController();
  final nameController = TextEditingController();
  final fkahController = TextEditingController();
  final symbolController = TextEditingController();
  final rateController = TextEditingController();
  final highController = TextEditingController();
  final lowController = TextEditingController();
  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchCurrencies();
    searchController.addListener(() {
      filterCurrencies(searchController.text);
    });
  }

  @override
  void onClose() {
    noController.dispose();
    nameController.dispose();
    fkahController.dispose();
    symbolController.dispose();
    rateController.dispose();
    highController.dispose();
    lowController.dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> fetchCurrencies() async {
    isLoading.value = true;
    try {
      final response = await _lookupsRepository.fetchAllCurrencies(); // <-- تم التعديل
      allCurrencies.assignAll(response);
      filterCurrencies(searchController.text);
      clearDisplay();
    } catch (e) {
      showMessage('حدث خطأ أثناء جلب البيانات: ${e.toString()}', isError: true); // <-- عرض الخطأ
    } finally {
      isLoading.value = false;
    }
  }

  void filterCurrencies(String query) {
    if (query.isEmpty) {
      filteredCurrencies.assignAll(allCurrencies);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredCurrencies.assignAll(allCurrencies.where((currency) {
        final nameMatch = currency.currencyName.toLowerCase().contains(lowerCaseQuery);
        final noMatch = currency.currencyNo.toString().contains(lowerCaseQuery);
        return nameMatch || noMatch;
      }).toList());
    }
  }

  void clearDisplay() {
    noController.clear();
    nameController.clear();
    fkahController.clear();
    symbolController.clear();
    rateController.clear();
    highController.clear();
    lowController.clear();
  }

  void displayCurrency(SunCurrency currency) {
    noController.text = currency.currencyNo.toString();
    nameController.text = currency.currencyName;
    fkahController.text = currency.currencyFkah;
    symbolController.text = currency.currencySymbol;
    rateController.text = currency.currencyRate.toStringAsFixed(2);
    highController.text = currency.currencyHighest.toStringAsFixed(2);
    lowController.text = currency.currencyLowest.toStringAsFixed(2);
  }

  void printData() async {
    List<SunCurrency> dataToPrint = [];
    String reportTitle = '';

    if (searchController.text.isNotEmpty) {
      dataToPrint = filteredCurrencies.toList();
      reportTitle = 'طباعة نتائج البحث عن: "${searchController.text}"';
    } else {
      dataToPrint = allCurrencies.toList();
      reportTitle = 'تقرير بجميع العملات';
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

      final pdfData = await PdfCurrenciesReport.generate(
        currencies: dataToPrint,
        reportTitle: reportTitle,
        userName: currentUserName,
      );

      Get.back();

      Get.to(() => FundsPdfView( // قد تحتاج لتغيير FundsPdfView إذا أنشأت واجهة خاصة
        pdfData: pdfData,
        reportTitle: reportTitle,
      ));
    } catch (e) {
      Get.back();
      showMessage('حدث خطأ أثناء إنشاء الـ PDF: $e', isError: true);
    }
  }

  void showMessage(String message, {bool isError = false}) {
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }
}