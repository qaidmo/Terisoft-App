import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/repositories/lookups_repository.dart'; // <-- تم الإضافة
import 'package:untitled4/utils/snackbar_helper.dart';

// تم حذف: supabase_flutter.dart, supabase_manager.dart

class BranchesController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository(); // <-- تم الإضافة

  // --- قوائم البيانات ---
  final RxList<Map<String, dynamic>> allBranches = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> filteredBranches = <Map<String, dynamic>>[].obs;

  // --- متغيرات الحالة ---
  final RxBool isLoading = false.obs;

  // --- متحكمات الحقول والبحث (للعرض فقط) ---
  final branchIdController = TextEditingController();
  final branchNameController = TextEditingController();
  final searchController = TextEditingController();

  final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void onInit() {
    super.onInit();
    fetchBranches();
    branchIdController.clear();
    searchController.addListener(() {
      filterBranches(searchController.text);
    });
  }

  @override
  void onClose() {
    branchIdController.dispose();
    branchNameController.dispose();
    searchController.dispose();
    super.onClose();
  }

  /// جلب قائمة الفروع من المستودع
  Future<void> fetchBranches() async {
    isLoading.value = true;
    try {
      final response = await _lookupsRepository.fetchAllBranches(); // <-- تم التعديل
      allBranches.assignAll(response);
      filterBranches(searchController.text); // Apply filter after fetching
    } catch (e) {
      showMessage('حدث خطأ أثناء جلب البيانات: ${e.toString()}', isError: true); // <-- عرض الخطأ
    } finally {
      isLoading.value = false;
    }
  }

  /// تصفية قائمة الفروع المعروضة بناءً على استعلام البحث
  void filterBranches(String query) {
    if (query.isEmpty) {
      filteredBranches.assignAll(allBranches);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredBranches.assignAll(allBranches.where((branch) {
        final nameMatch = (branch['branch_name'] as String? ?? '').toLowerCase().contains(lowerCaseQuery);
        final idMatch = (branch['branch_id'] as int? ?? 0).toString().contains(lowerCaseQuery);
        return nameMatch || idMatch;
      }).toList());
    }
  }

  /// مسح الحقول عند إلغاء التحديد (للعرض فقط)
  void clearForm() {
    branchIdController.clear();
    branchNameController.clear();
  }

  /// عرض بيانات الفرع المختار في الحقول
  void displayBranch(Map<String, dynamic> branchData) {
    branchIdController.text = branchData['branch_id']?.toString() ?? '';
    branchNameController.text = branchData['branch_name'] ?? '';
  }

  /// طباعة بيانات الفرع المحدد (غير مكتملة)
  void printData() {
    if (branchIdController.text.isEmpty) {
      showMessage('الرجاء تحديد فرع أولاً للعرض والطباعة', isError: true);
      return;
    }
    showMessage('جاري تجهيز بيانات الفرع #${branchIdController.text} للطباعة...');
    // Add actual printing logic here later
  }

  /// عرض رسالة Snackbar
  void showMessage(String message, {bool isError = false}) {
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }
}