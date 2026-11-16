import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/collectors_controller.dart';

class CollectorsScreen extends StatelessWidget {
  const CollectorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CollectorsController controller = Get.put(CollectorsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('استعراض المحصلين'),
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: controller.isLoading.value ? null : controller.fetchCollectors,
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
            // --- قسم عرض البيانات (للقراءة فقط) ---
            const Text('بيانات المحصل المحدد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            _buildReadOnlyField(controller: controller.noController, label: 'رقم المحصل'),
            const SizedBox(height: 16),
            _buildReadOnlyField(controller: controller.nameController, label: 'اسم المحصل'),
            const SizedBox(height: 16),
            _buildReadOnlyField(controller: controller.phoneController, label: 'رقم الهاتف'),
            const SizedBox(height: 16),
            _buildReadOnlyField(controller: controller.accountNameController, label: 'اسم الحساب'),
            const SizedBox(height: 16),
            _buildReadOnlyField(controller: controller.branchNameController, label: 'محصور بالفرع'),
            const SizedBox(height: 24),

            // --- أزرار الإجراءات (بحث وطباعة فقط) ---
            Obx(() => Row( // استخدام Row بدلاً من Wrap
              children: [
                // زر البحث يمتد ليأخذ المساحة المتاحة
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('بحث عن محصل'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: controller.isLoading.value ? null : () => _showMainSearchDialog(context, controller),
                  ),
                ),

                const SizedBox(width: 10), // مسافة فاصلة بين الزرين

                // زر الطباعة يمتد ليأخذ المساحة المتاحة
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة التقرير'),
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

  /// ويدجت مساعد لبناء حقول القراءة فقط
  Widget _buildReadOnlyField({required TextEditingController controller, required String label}) {
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

  /// دالة فتح نافذة البحث
  void _showMainSearchDialog(BuildContext context, CollectorsController controller) {
    controller.mainSearchController.clear();
    Get.dialog(AlertDialog(
      title: const Text('بحث عن محصل'),
      content: _MainSearchDialogContent(controller: controller),
      actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
    ));
  }
}

/// محتوى نافذة البحث (مع التمرير الأفقي ومنع التفاف النص)
class _MainSearchDialogContent extends StatelessWidget {
  final CollectorsController controller;
  const _MainSearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          TextField(
            controller: controller.mainSearchController,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'ابحث بالرقم أو الاسم...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              if (controller.filteredCollectors.isEmpty) {
                return const Center(child: Text('لا توجد نتائج'));
              }
              // --- [تم التعديل] إضافة التمرير الأفقي ---
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(
                        width: 1.0,
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8)),
                    headingRowColor:
                    MaterialStateProperty.all(Colors.blue.shade50),
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(
                          label: Text('الرقم',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('الاسم',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('الحساب',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: controller.filteredCollectors
                        .map((collector) => DataRow(
                      onSelectChanged: (_) {
                        controller.displayCollector(collector);
                        Get.back();
                      },
                      cells: [
                        DataCell(Text(
                            collector['collector_no']?.toString() ??
                                '')),
                        // --- [تم التعديل] منع التفاف النص ---
                        DataCell(Text(
                          collector['collector_name'] ?? '',
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        )),
                        DataCell(Text(
                          collector['account']?['name'] ?? '',
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        )),
                      ],
                    ))
                        .toList(),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
