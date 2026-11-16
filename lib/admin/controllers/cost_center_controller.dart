import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/models/cost_center.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/admin/printing/pdf_cost_centers_report.dart';
import 'package:untitled4/admin/printing/cost_centers_pdf_view.dart';

class CostCenterController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository();

  final noController = TextEditingController();
  final nameController = TextEditingController();
  final searchController = TextEditingController();

  final RxList<CostCenter> costCentersList = <CostCenter>[].obs;
  final RxList<CostCenter> filteredCostCenters = <CostCenter>[].obs;

  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() => filterCenters(searchController.text));
    fetchCostCenters();
  }

  @override
  void onClose() {
    noController.dispose();
    nameController.dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> fetchCostCenters() async {
    isLoading.value = true;
    try {
      final List<Map<String, dynamic>> response =
      await _lookupsRepository.fetchAllCostCenters();
      costCentersList.assignAll(
          response.map((data) => CostCenter.fromJson(data)).toList());
      filterCenters('');
      clearDisplay();
    } catch (e) {
      AppSnackbar.showCustomSnackbar(
          'خطأ في الاتصال', 'فشل في جلب البيانات: ${e.toString()}',
          isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  void clearDisplay() {
    nameController.clear();
    noController.clear();
  }

  void displayCenter(CostCenter center) {
    noController.text = center.centerNo.toString();
    nameController.text = center.centerName;
    Get.back();
  }

  void filterCenters(String query) {
    if (query.isEmpty) {
      filteredCostCenters.value = costCentersList;
    } else {
      filteredCostCenters.value = costCentersList.where((center) {
        return center.centerName
            .toLowerCase()
            .contains(query.toLowerCase()) ||
            center.centerNo.toString().contains(query);
      }).toList();
    }
  }

  Future<void> printData() async {
    List<CostCenter> dataToPrint = [];
    String reportTitle = '';

    if (searchController.text.isNotEmpty) {
      dataToPrint = filteredCostCenters.toList();
      reportTitle = 'طباعة نتائج البحث عن: "${searchController.text}"';
    } else {
      dataToPrint = costCentersList.toList();
      reportTitle = 'تقرير بجميع مراكز التكلفة';
    }

    if (dataToPrint.isEmpty) {
      AppSnackbar.showCustomSnackbar('خطأ', 'لا توجد بيانات للطباعة.',
          isError: true);
      return;
    }

    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);

    try {
      final userState = Get.find<UserState>();
      final currentUserName = userState.safeUserName;

      final pdfData = await PdfCostCentersReport.generate(
        costCenters: dataToPrint,
        reportTitle: reportTitle,
        userName: currentUserName,
      );

      Get.back();

      Get.to(() => CostCentersPdfView(
        pdfData: pdfData,
        reportTitle: reportTitle,
      ));

    } catch (e) {
      Get.back();
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ أثناء إنشاء الـ PDF: $e',
          isError: true);
    }
  }
}