import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/printing/collectors_pdf_view.dart'; // تأكد من المسار
import 'package:untitled4/admin/printing/pdf_collectors_report.dart'; // تأكد من المسار
import 'package:untitled4/repositories/lookups_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/user_state.dart'; // تأكد من المسار
import 'package:untitled4/utils/snackbar_helper.dart'; // تأكد من المسار

class CollectorsController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository();

  final RxBool isLoading = true.obs;

  final noController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final accountNameController = TextEditingController();
  final branchNameController = TextEditingController();
  final mainSearchController = TextEditingController();

  final RxList<Map<String, dynamic>> allCollectors = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredCollectors = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchCollectors();
    mainSearchController.addListener(() => filterMainCollectors(mainSearchController.text));
  }

  @override
  void onClose() {
    noController.dispose();
    nameController.dispose();
    phoneController.dispose();
    accountNameController.dispose();
    branchNameController.dispose();
    mainSearchController.dispose();
    super.onClose();
  }

  /// جلب قائمة المحصلين مع التفاصيل من المستودع
  Future<void> fetchCollectors() async {
    isLoading.value = true;
    try {
      final response = await _lookupsRepository.fetchAllCollectorsWithDetails(); // <-- تم التعديل
      allCollectors.assignAll(response);
      filteredCollectors.assignAll(allCollectors);
      clearDisplay();
    } catch (e) {
      _showMessage('خطأ في جلب بيانات المحصلين: ${e.toString()}', isError: true); // <-- عرض الخطأ
    } finally {
      isLoading.value = false;
    }
  }

  /// تصفية قائمة المحصلين المعروضة بناءً على استعلام البحث
  void filterMainCollectors(String query) {
    if (query.isEmpty) {
      filteredCollectors.assignAll(allCollectors);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredCollectors.assignAll(allCollectors.where((collector) {
        final nameMatch = (collector['collector_name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final noMatch = (collector['collector_no'] as int? ?? 0).toString().contains(lowerCaseQuery);
        return nameMatch || noMatch;
      }).toList());
    }
  }

  /// تعرض بيانات المحصل المختار في حقول الواجهة.
  void displayCollector(Map<String, dynamic> collector) {
    noController.text = collector['collector_no']?.toString() ?? '';
    nameController.text = collector['collector_name'] ?? '';
    phoneController.text = collector['phone_number'] ?? '';
    // استخدام الأسماء المعاد هيكلتها من المستودع
    accountNameController.text = collector['account_name'] ?? 'غير محدد';
    branchNameController.text = collector['branch_name'] ?? 'غير محدد';
  }

  /// تمسح حقول العرض.
  void clearDisplay() {
    noController.clear();
    nameController.clear();
    phoneController.clear();
    accountNameController.clear();
    branchNameController.clear();
  }

  /// طباعة بيانات المحصلين
  Future<void> printData() async {
    List<Map<String, dynamic>> dataToPrint = [];
    String reportTitle = '';

    if (mainSearchController.text.isNotEmpty) {
      dataToPrint = filteredCollectors.toList();
      reportTitle = 'طباعة نتائج البحث عن: "${mainSearchController.text}"';
    } else {
      dataToPrint = allCollectors.toList();
      reportTitle = 'تقرير بجميع المحصلين';
    }

    if (dataToPrint.isEmpty) {
      _showMessage('لا توجد بيانات للطباعة.', isError: true);
      return;
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final userState = Get.find<UserState>();
      final currentUserName = userState.safeUserName;

      final pdfData = await PdfCollectorsReport.generate(
        collectors: dataToPrint,
        reportTitle: reportTitle,
        userName: currentUserName,
      );

      Get.back(); // لإغلاق مؤشر التحميل

      Get.to(() => CollectorsPdfView(
        pdfData: pdfData,
        reportTitle: reportTitle,
      ));
    } catch (e) {
      Get.back();
      _showMessage('حدث خطأ أثناء إنشاء الـ PDF: $e', isError: true);
    }
  }

  /// عرض رسالة Snackbar
  void _showMessage(String message, {bool isError = false}) {
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }
}