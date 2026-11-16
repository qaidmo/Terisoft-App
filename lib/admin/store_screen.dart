import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/store_controller.dart';
import 'package:untitled4/models/sun_store.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  void _showSearchDialog(BuildContext context, StoreController controller) {
    controller.searchController.clear();
    controller.filterStores(''); // عرض جميع البيانات عند فتح نافذة البحث
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن مخزن'),
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
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final StoreController controller = Get.put(StoreController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل المخازن (للعرض فقط)'),
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
        // **تم حذف الـ Form**
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('بيانات المخزن المحدد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- حقل رقم المخزن (قراءة فقط) ---
            _buildReadOnlyInputField(
              controller: controller.noController,
              label: 'رقم المخزن',
              icon: Icons.confirmation_number_outlined,
            ),
            const SizedBox(height: 16),

            // --- حقل اسم المخزن (قراءة فقط) ---
            _buildReadOnlyInputField(
              controller: controller.nameController,
              label: 'اسم المخزن',
              icon: Icons.store_outlined,
            ),
            const SizedBox(height: 16),

            // --- حقل حساب المخزون (للعرض فقط) ---
            Obx(() {
              final selectedAccount = controller.transactionalAccounts.firstWhereOrNull(
                      (acc) => acc['id'] == controller.selectedAccountId.value);
              return _buildReadOnlyInputField(
                // استخدام النص لعرض الحساب بدلاً من Dropdown
                controller: TextEditingController(
                    text: selectedAccount != null
                        ? '${selectedAccount['account_number']} - ${selectedAccount['name']}'
                        : 'لم يتم تحديد حساب'
                ),
                label: 'حساب المخزون',
                icon: Icons.account_balance_wallet_outlined,
              );
            }),
            const SizedBox(height: 16),

            // --- حقل الفرع (للعرض فقط) ---
            Obx(() {
              final branchName = controller.getBranchName(controller.selectedBranchId.value);
              return _buildReadOnlyInputField(
                // استخدام النص لعرض الفرع بدلاً من Dropdown
                controller: TextEditingController(text: branchName),
                label: 'الفرع',
                icon: Icons.business_outlined,
              );
            }),
            const SizedBox(height: 24),

            // --- شريط الأزرار (بحث وطباعة فقط) ---
            Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search_outlined),
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
    // نستخدم TextFormField للقراءة فقط
    return TextFormField(
      controller: controller,
      readOnly: true,
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
  final StoreController controller;
  const _SearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller.searchController,
          onChanged: controller.filterStores, // تفعيل البحث التلقائي
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ابحث بالرقم، الاسم، الحساب، أو الفرع...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.filteredStores.isEmpty) {
              return const Center(child: Text('لا توجد نتائج مطابقة'));
            }
            return SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        showCheckboxColumn: false,
                        border: TableBorder.all(width: 1.0, color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                        headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                        columns: const [
                          DataColumn(label: Text('رقم المخزن', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('اسم المخزن', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('حساب المخزن', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الفرع', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: controller.filteredStores.map((store) {
                          final branchName = controller.getBranchName(store.branchId);
                          return DataRow(
                            onSelectChanged: (isSelected) {
                              if (isSelected ?? false) {
                                // استخدام displayStore بدلاً من editStore
                                controller.displayStore(store);
                                Get.back();
                              }
                            },
                            cells: [
                              DataCell(Text(store.noStore.toString())),
                              DataCell(Text(store.nameStore)),
                              DataCell(Text(store.linkedAccount?.name ?? 'غير مربوط')),
                              DataCell(Text(branchName)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}