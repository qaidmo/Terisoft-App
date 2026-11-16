import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/models/sun_item_group.dart';
import 'package:untitled4/repositories/lookups_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/admin/printing/pdf_item_groups_report.dart';
import 'package:untitled4/admin/printing/item_groups_pdf_view.dart';

// تم حذف: supabase_flutter.dart, supabase_manager.dart

class ItemGroupsController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository(); // <-- تم الإضافة

  final RxList<SunItemGroup> allGroups = <SunItemGroup>[].obs;
  final RxList<SunItemGroup> filteredGroups = <SunItemGroup>[].obs;

  final RxBool isLoading = false.obs;

  final noController = TextEditingController();
  final nameController = TextEditingController();
  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchGroups();
    searchController.addListener(() => filterGroups(searchController.text));
  }

  @override
  void onClose() {
    noController.dispose();
    nameController.dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> fetchGroups() async {
    isLoading.value = true;
    try {
      final response = await _lookupsRepository.fetchAllItemGroups(); // <-- تم التعديل
      allGroups.assignAll(
          response.map((data) => SunItemGroup.fromJson(data)).toList());
      filterGroups('');
      clearDisplay();
    } catch (e) {
      showMessage('حدث خطأ أثناء جلب البيانات: ${e.toString()}', isError: true); // <-- عرض الخطأ
    } finally {
      isLoading.value = false;
    }
  }

  void filterGroups(String query) {
    if (query.isEmpty) {
      filteredGroups.assignAll(allGroups);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredGroups.assignAll(allGroups.where((group) {
        return group.groupName.toLowerCase().contains(lowerCaseQuery) ||
            group.groupNo.toString().contains(lowerCaseQuery);
      }).toList());
    }
  }

  void clearDisplay() {
    noController.clear();
    nameController.clear();
  }

  void displayGroup(SunItemGroup group) {
    noController.text = group.groupNo.toString();
    nameController.text = group.groupName;
    Get.back();
  }

  Future<void> printData() async {
    List<SunItemGroup> dataToPrint = [];
    String reportTitle = '';

    if (searchController.text.isNotEmpty) {
      dataToPrint = filteredGroups.toList();
      reportTitle = 'طباعة نتائج البحث عن: "${searchController.text}"';
    } else {
      dataToPrint = allGroups.toList();
      reportTitle = 'تقرير بجميع مجموعات الأصناف';
    }

    if (dataToPrint.isEmpty) {
      showMessage('لا توجد بيانات للطباعة.', isError: true);
      return;
    }

    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);

    try {
      final userState = Get.find<UserState>();
      final currentUserName = userState.safeUserName;

      final pdfData = await PdfItemGroupsReport.generate(
        groups: dataToPrint,
        reportTitle: reportTitle,
        userName: currentUserName,
      );

      Get.back();

      Get.to(() => ItemGroupsPdfView(
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