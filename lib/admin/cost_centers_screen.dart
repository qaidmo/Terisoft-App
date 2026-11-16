import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/cost_center_controller.dart';


class CostCentersScreen extends StatelessWidget {
  const CostCentersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CostCenterController controller = Get.put(CostCenterController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('استعراض مراكز التكلفة'),
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: controller.isLoading.value ? null : controller.fetchCostCenters,
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
            // --- قسم عرض البيانات ---
            const Text('بيانات مركز التكلفة المحدد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildReadOnlyField(
              controller: controller.noController,
              label: 'رقم المركز',
              icon: Icons.numbers,
            ),
            const SizedBox(height: 16),
            _buildReadOnlyField(
              controller: controller.nameController,
              label: 'اسم المركز',
              icon: Icons.label_important_outline,
            ),
            const SizedBox(height: 24),

            // --- قسم الأزرار النهائي ---
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

  /// ويدجت مساعد لبناء حقول العرض فقط
  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade200,
      ),
    );
  }

  /// دالة فتح نافذة البحث
  void _showSearchDialog(BuildContext context, CostCenterController controller) {
    controller.filterCenters('');
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن مركز تكلفة'),
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
      barrierDismissible: false,
    );
  }
}

/// محتوى نافذة البحث المعدل
class _SearchDialogContent extends StatelessWidget {
  final CostCenterController controller;
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
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.filteredCostCenters.isEmpty) {
              return const Center(child: Text('لا توجد نتائج مطابقة للبحث'));
            }
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('الرقم')),
                    DataColumn(label: Text('اسم المركز')),
                  ],
                  rows: controller.filteredCostCenters.map((center) {
                    return DataRow(
                      // [تم التعديل] استدعاء دالة العرض
                      onSelectChanged: (isSelected) {
                        if (isSelected ?? false) {
                          controller.displayCenter(center);
                        }
                      },
                      cells: [
                        DataCell(Text(center.centerNo.toString())),
                        DataCell(Text(center.centerName, softWrap: false)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}