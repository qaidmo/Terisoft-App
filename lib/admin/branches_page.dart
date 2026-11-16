import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/branches_controller.dart';

class BranchesPage extends StatelessWidget {
  const BranchesPage({super.key});

  void _showSearchDialog(BuildContext context, BranchesController controller) {
    controller.searchController.clear();
    controller.filterBranches(''); // عرض جميع البيانات عند فتح نافذة البحث
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن فرع'),
        contentPadding: const EdgeInsets.all(16.0),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.6,
          child: _SearchDialogContent(controller: controller),
        ),
        actions: [
          TextButton(onPressed: controller.clearForm, child: const Text('مسح البيانات')),
          TextButton(onPressed: () => Get.back(), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BranchesController controller = Get.put(BranchesController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل الفروع (للعرض فقط)'),
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: controller.isLoading.value ? null : controller.fetchBranches,
          )),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 16.0,
          bottom: MediaQuery.of(context).padding.bottom + 16.0,
        ),
        // **تم حذف الـ Form**
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('بيانات الفرع المحدد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- حقل رقم الفرع (قراءة فقط) ---
            _buildReadOnlyInputField(
              controller: controller.branchIdController,
              label: 'رقم الفرع',
              icon: Icons.tag,
            ),
            const SizedBox(height: 16),

            // --- حقل اسم الفرع (قراءة فقط) ---
            _buildReadOnlyInputField(
              controller: controller.branchNameController,
              label: 'اسم الفرع',
              icon: Icons.business,
            ),
            const SizedBox(height: 24),

            // --- شريط الأزرار (بحث وطباعة فقط) ---
            Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('بحث وعرض'),
                    onPressed: () => _showSearchDialog(context, controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('طباعة'),
                    onPressed: controller.isLoading.value ? null : controller.printData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                // **تم حذف أزرار: جديد، حفظ، حذف**
              ],
            )),
          ],
        ),
      ),
    );
  }

  // --- دالة مساعدة لإنشاء حقول القراءة فقط ---
  Widget _buildReadOnlyInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true, // حقل قراءة فقط دائمًا
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade200, // لون يميز حقول القراءة فقط
      ),
    );
  }
}

// --- ويدجت محتوى نافذة البحث (تم تعديل منطق الاختيار) ---
class _SearchDialogContent extends StatelessWidget {
  final BranchesController controller;
  const _SearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller.searchController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ابحث بالرقم أو الاسم...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: controller.filterBranches, // تفعيل البحث التلقائي
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.filteredBranches.isEmpty) {
              return const Center(child: Text('لا توجد نتائج مطابقة'));
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    border: TableBorder.all(
                      width: 1.0,
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                    columns: const [
                      DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: controller.filteredBranches.map((branch) {
                      return DataRow(
                        onSelectChanged: (isSelected) {
                          if (isSelected ?? false) {
                            // استخدام displayBranch بدلاً من editBranch
                            controller.displayBranch(branch);
                            Get.back();
                          }
                        },
                        cells: [
                          DataCell(Text(branch['branch_id']?.toString() ?? '')),
                          DataCell(Text(branch['branch_name'] ?? '')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}