import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/departments_controller.dart';

class DepartmentsPage extends StatelessWidget {
  const DepartmentsPage({super.key});

  // دالة إظهار نافذة البحث عن الأقسام
  void _showSearchDialog(BuildContext context, DepartmentsController controller) {
    controller.mainSearchController.clear();
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن قسم'),
        contentPadding: const EdgeInsets.all(16.0),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.6,
          child: _SearchDialogContent(controller: controller),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DepartmentsController controller = Get.put(DepartmentsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('استعراض الأقسام'),
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: controller.isLoading.value ? null : controller.fetchInitialData,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('بيانات القسم المحدد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // حقول عرض البيانات
            _buildReadOnlyField(
              controller: controller.departmentIdController,
              label: 'رقم القسم',
            ),
            const SizedBox(height: 16),
            _buildReadOnlyField(
              controller: controller.departmentNameController,
              label: 'اسم القسم',
            ),
            const SizedBox(height: 24),

            // الأزرار النهائية بعرض الشاشة الكاملة
            Obx(() => Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('بحث'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: controller.isLoading.value ? null : () => _showSearchDialog(context, controller),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: controller.isLoading.value ? null : controller.printData,
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  // ويدجت مساعدة لبناء حقول العرض فقط
  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade200,
      ),
    );
  }
}

// ويدجت محتوى نافذة البحث عن الأقسام (المعدل)
class _SearchDialogContent extends StatelessWidget {
  final DepartmentsController controller;
  const _SearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller.mainSearchController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ابحث بالرقم أو الاسم...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.filteredDepartments.isEmpty) {
              return const Center(child: Text('لا توجد نتائج مطابقة'));
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(width: 1.0, color: Colors.grey.shade400, borderRadius: BorderRadius.circular(8)),
                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('رقم القسم', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('اسم القسم', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: controller.filteredDepartments.map((department) {
                      return DataRow(
                        onSelectChanged: (isSelected) {
                          if (isSelected ?? false) {
                            // استدعاء دالة العرض بدلاً من التعديل
                            controller.displayDepartment(department);
                          }
                        },
                        cells: [
                          DataCell(Text(department['department_id']?.toString() ?? '')),
                          DataCell(Text(department['department_name'] ?? '', softWrap: false)),
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