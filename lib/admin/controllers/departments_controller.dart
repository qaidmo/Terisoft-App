import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/repositories/lookups_repository.dart'; // <-- تم الإضافة
import '../../utils/snackbar_helper.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/admin/printing/pdf_departments_report.dart';
import 'package:untitled4/admin/printing/departments_pdf_view.dart';

// تم حذف: supabase_flutter.dart, supabase_manager.dart

class DepartmentsController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository(); // <-- تم الإضافة

  final RxList<Map<String, dynamic>> allDepartments = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredDepartments = <Map<String, dynamic>>[].obs;

  final RxBool isLoading = false.obs;

  final departmentIdController = TextEditingController();
  final departmentNameController = TextEditingController();
  final mainSearchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
    mainSearchController.addListener(() => filterDepartments(mainSearchController.text));
  }

  @override
  void onClose() {
    departmentIdController.dispose();
    departmentNameController.dispose();
    mainSearchController.dispose();
    super.onClose();
  }

  Future<void> fetchInitialData() async {
    isLoading.value = true;
    try {
      final response = await _lookupsRepository.fetchAllDepartments(); // <-- تم التعديل
      allDepartments.assignAll(response);
      filterDepartments('');
      clearDisplay();

    } catch (e) {
      showMessage('حدث خطأ أثناء جلب البيانات: ${e.toString()}', isError: true); // <-- عرض الخطأ
    } finally {
      isLoading.value = false;
    }
  }

  void filterDepartments(String query) {
    if (query.isEmpty) {
      filteredDepartments.assignAll(allDepartments);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredDepartments.assignAll(allDepartments.where((dep) {
        final nameMatch = (dep['department_name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final idMatch = (dep['department_id'] as int? ?? 0).toString().contains(lowerCaseQuery);
        return nameMatch || idMatch;
      }).toList());
    }
  }

  void clearDisplay() {
    departmentIdController.clear();
    departmentNameController.clear();
  }

  void displayDepartment(Map<String, dynamic> departmentData) {
    departmentIdController.text = departmentData['department_id']?.toString() ?? '';
    departmentNameController.text = departmentData['department_name'] ?? '';
    Get.back();
  }

  Future<void> printData() async {
    List<Map<String, dynamic>> dataToPrint = [];
    String reportTitle = '';

    if (mainSearchController.text.isNotEmpty) {
      dataToPrint = filteredDepartments.toList();
      reportTitle = 'طباعة نتائج البحث عن: "${mainSearchController.text}"';
    } else {
      dataToPrint = allDepartments.toList();
      reportTitle = 'تقرير بجميع الأقسام';
    }

    if (dataToPrint.isEmpty) {
      showMessage('لا توجد بيانات للطباعة.', isError: true);
      return;
    }

    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final userState = Get.find<UserState>();
      final currentUserName = userState.safeUserName;

      final pdfData = await PdfDepartmentsReport.generate(
        departments: dataToPrint,
        reportTitle: reportTitle,
        userName: currentUserName,
      );

      Get.back();

      Get.to(() => DepartmentsPdfView(
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