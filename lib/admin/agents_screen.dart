import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/agents_controller.dart';

class AgentsScreen extends StatelessWidget {
  const AgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // جلب الكنترولر وتعيينه
    final AgentsController controller = Get.put(AgentsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل المناديب '),
        actions: [
          // زر التحديث: يراقب isLoading لتغيير الأيقونة
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: controller.isLoading.value ? null : controller.fetchSalespeople,
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
            const Text('بيانات المندوب المحدد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- حقول القراءة فقط ---

            _buildReadOnlyInputField(
              controller: controller.noController,
              label: 'رقم المندوب',
            ),
            const SizedBox(height: 16),
            _buildReadOnlyInputField(
              controller: controller.nameController,
              label: 'اسم المندوب',
            ),
            const SizedBox(height: 16),
            _buildReadOnlyInputField(
              controller: controller.phoneController,
              label: 'رقم الهاتف',
            ),
            const SizedBox(height: 16),

            // --- قسم النسبة والعمولات (مع Obx حول Switch) ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildReadOnlyInputField(
                    controller: controller.percentageController,
                    label: 'نسبة المندوب %',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  // Obx هنا مطلوب لتحديث حالة Switch
                  child: Obx(() => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تعطيل العمولات', style: TextStyle(fontSize: 14)),
                    trailing: Switch(
                      value: controller.commissionsDisabled.value, // متغير مراقب
                      onChanged: null, // معطل
                    ),
                    dense: true,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- حقول الحسابات التفاعلية (للبحث والعرض فقط) ---
            _buildReadOnlyInteractiveField(
              controller: controller.accountNameController,
              label: 'اسم الحساب',
              onTap: () => _showAccountSearchDialog(context, controller),
            ),
            const SizedBox(height: 16),

            _buildReadOnlyInteractiveField(
              controller: controller.expenseAccountNameController,
              label: 'حساب النسبة (المصروف)',
              onTap: () => _showExpenseAccountSearchDialog(context, controller),
            ),
            const SizedBox(height: 24),

            // --- شريط الأزرار (بحث وطباعة فقط) ---

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search), label: const Text('بحث عن مندوب'),
                    onPressed: () => _showMainSearchDialog(context, controller),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print), label: const Text('طباعة التقرير'),
                    onPressed: controller.printSalespeople, // دالة الطباعة
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
// ----------------------------------------------------
// --- دوال مساعدة لإنشاء حقول القراءة فقط (Widgets) ---
// ----------------------------------------------------

  Widget _buildReadOnlyInputField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true, // مهم: للقراءة فقط
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey.shade200,
      ),
    );
  }

  Widget _buildReadOnlyInteractiveField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    // يسمح بالضغط لفتح نافذة البحث (للعرض)، ويمنع الكتابة المباشرة
    return InkWell(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey.shade100,
            suffixIcon: const Icon(Icons.search),
          ),
        ),
      ),
    );
  }

// ---------------------------------------
// --- دوال عرض نوافذ البحث (Dialogs) ---
// ---------------------------------------

  void _showMainSearchDialog(BuildContext context, AgentsController controller) {
    controller.mainSearchController.clear();
    controller.filterMainSalespeople('');
    Get.dialog(AlertDialog(
      title: const Text('بحث وعرض بيانات مندوب'),
      content: _MainSearchDialogContent(controller: controller),
      actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
    ));
  }

  void _showAccountSearchDialog(BuildContext context, AgentsController controller) {
    controller.accountSearchController.clear();
    controller.filterAccounts('');
    Get.dialog(AlertDialog(
      title: const Text('بحث عن حساب (للعرض فقط)'),
      content: _AccountSearchDialogContent(controller: controller, onSelect: controller.selectAccount),
      actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
    ));
  }

  void _showExpenseAccountSearchDialog(BuildContext context, AgentsController controller) {
    controller.accountSearchController.clear();
    controller.filterAccounts('');
    Get.dialog(AlertDialog(
      title: const Text('بحث عن حساب المصروف (للعرض فقط)'),
      content: _AccountSearchDialogContent(controller: controller, onSelect: controller.selectExpenseAccount),
      actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
    ));
  }
}


// -------------------------------------------------------------------
// --- محتوى نوافذ البحث (Search Dialogs) ---
// -------------------------------------------------------------------

class _MainSearchDialogContent extends StatelessWidget {
  final AgentsController controller;
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
            decoration: const InputDecoration(labelText: 'ابحث بالرقم أو الاسم...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              if (controller.filteredSalespeople.isEmpty && !controller.isLoading.value) return const Center(child: Text('لا توجد نتائج'));
              if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());

              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(width: 1.0, color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الحساب', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: controller.filteredSalespeople.map((sp) => DataRow(
                      onSelectChanged: (_) {
                        controller.displaySalesperson(sp);
                        Get.back();
                      },
                      cells: [
                        DataCell(Text(sp['salesperson_no']?.toString() ?? '')),
                        DataCell(Text(sp['salesperson_name'] ?? '')),
                        DataCell(Text(sp['account']?['name'] ?? '')),
                      ],
                    )).toList(),
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

class _AccountSearchDialogContent extends StatelessWidget {
  final AgentsController controller;
  final Function(String, String) onSelect;

  const _AccountSearchDialogContent({required this.controller, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          TextField(
            controller: controller.accountSearchController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ابحث بالرقم أو الاسم...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              if (controller.filteredAccounts.isEmpty) return const Center(child: Text('لا توجد نتائج'));
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(width: 1.0, color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                    headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('رقم الحساب', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('اسم الحساب', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('حساب الأب', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: controller.filteredAccounts.map((account) => DataRow(
                      onSelectChanged: (_) {
                        onSelect(account['id'], account['name']);
                      },
                      cells: [
                        DataCell(Text(account['account_number']?.toString() ?? '')),
                        DataCell(Text(account['name'] ?? '')),
                        DataCell(Text(controller.getParentAccountName(account['parent_id']))),
                      ],
                    )).toList(),
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