import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/item_groups_controller.dart';

class ItemGroupsScreen extends StatelessWidget {
  const ItemGroupsScreen({super.key});

  void _showSearchDialog(BuildContext context, ItemGroupsController controller) {
    controller.searchController.clear();
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن مجموعة'),
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

  @override
  Widget build(BuildContext context) {
    final ItemGroupsController controller = Get.put(ItemGroupsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('استعراض مجموعات الأصناف'),
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: controller.isLoading.value ? null : controller.fetchGroups,
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
            const Text('بيانات المجموعة المحددة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildReadOnlyField(
              controller: controller.noController,
              label: 'رقم المجموعة',
            ),
            const SizedBox(height: 16),
            _buildReadOnlyField(
              controller: controller.nameController,
              label: 'اسم المجموعة',
            ),
            const SizedBox(height: 24),
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

  Widget _buildReadOnlyField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.category_outlined),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade200,
      ),
    );
  }
}

class _SearchDialogContent extends StatelessWidget {
  final ItemGroupsController controller;
  const _SearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller.searchController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'ابحث بالرقم أو الاسم...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.filteredGroups.isEmpty) {
              return const Center(child: Text('لا توجد نتائج مطابقة'));
            }
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  border: TableBorder.all(width: 1.0, color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                  columns: const [
                    DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: controller.filteredGroups.map((group) {
                    return DataRow(
                      onSelectChanged: (isSelected) {
                        if (isSelected ?? false) {
                          controller.displayGroup(group);
                        }
                      },
                      cells: [
                        DataCell(Text(group.groupNo.toString())),
                        DataCell(Text(group.groupName, softWrap: false)),
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