import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/boxes_controller.dart';
import 'package:untitled4/models/sun_currency.dart';

class BoxesScreen extends StatelessWidget {
  const BoxesScreen({super.key});

  // --- دوال عرض نوافذ البحث ---
  void _showBoxSearchDialog(BuildContext context, BoxesController controller) {
    controller.searchController.clear();
    controller.filterBoxes('');
    Get.dialog(
      AlertDialog(
        title: const Text('بحث وعرض صندوق'),
        contentPadding: const EdgeInsets.all(16.0),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.6,
          child: _BoxSearchDialogContent(controller: controller),
        ),
        actions: [
          TextButton(onPressed: controller.clearForm, child: const Text('مسح البيانات')),
          TextButton(onPressed: () => Get.back(), child: const Text('إغلاق')),
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showAccountSearchDialog(BuildContext context, BoxesController controller) {
    controller.accountSearchController.clear();
    controller.filterAccounts('');
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن حساب (للعرض فقط)'),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: _AccountSearchDialog(controller: controller),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إغلاق')),
        ],
      ),
    );
  }
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final BoxesController controller = Get.put(BoxesController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل الصناديق (للعرض فقط)'),
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: controller.isLoading.value
                ? null
                : controller.fetchInitialData,
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
            const Text('بيانات الصندوق المحدد',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- تجميع حقول القراءة فقط في Obx واحد لتصحيح خطأ GetX وضمان التحديث ---
            Obx(() {
              // قراءة المتغير القابل للمراقبة selectedAccountId تضمن إعادة البناء
              final String? _ = controller.selectedAccountId.value;
              return Column(
                children: [
                  _buildReadOnlyInputField(
                    controller: controller.noController,
                    label: 'رقم الصندوق',
                    icon: Icons.numbers,
                  ),
                  const SizedBox(height: 16),
                  _buildReadOnlyInputField(
                    controller: controller.nameController,
                    label: 'اسم الصندوق',
                    icon: Icons.label_important_outline,
                  ),
                  const SizedBox(height: 16),
                  TextFormField( // حقل الحساب المرتبط
                    controller: controller.accountNameController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'الحساب المرتبط',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                      suffixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[100],
                      hintText: 'انقر للبحث وعرض الحساب',
                    ),
                    onTap: () => _showAccountSearchDialog(context, controller),
                  ),
                ],
              );
            }),
            const SizedBox(height: 16),
            // -----------------------------------------------------------------------

            // --- ويدجت إدارة العملات (للعرض فقط) ---
            const _BoxCurrenciesReadOnlyWidget(),
            const SizedBox(height: 24),

            // --- شريط الأزرار (بحث وطباعة فقط) - باستخدام Row و Expanded للتجاوب ---
            Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('بحث وعرض'),
                    onPressed: () => _showBoxSearchDialog(context, controller),
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
                    onPressed: controller.isLoading.value
                        ? null
                        : controller.printData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            )),
            const SizedBox(height: 20),
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


// --- ويدجت العملات (للعرض فقط) ---
class _BoxCurrenciesReadOnlyWidget extends StatelessWidget {
  const _BoxCurrenciesReadOnlyWidget();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BoxesController>();
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('عملات الصندوق (للعرض فقط)',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(),
            Obx(() {
              if (controller.selectedBoxCurrencyNos.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('لا توجد عملات مرتبطة بهذا الصندوق.'));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controller.selectedBoxCurrencyNos.length,
                itemBuilder: (context, index) {
                  final currencyNo = controller.selectedBoxCurrencyNos[index];
                  final currency = controller.allCurrencies.firstWhere(
                        (c) => c.currencyNo == currencyNo,
                    orElse: () => SunCurrency.empty(),
                  );
                  return ListTile(
                    dense: true,
                    title: Text(currency.currencyName),
                    subtitle: Text('رقم العملة: $currencyNo'),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- محتوى نافذة بحث الصناديق ---
class _BoxSearchDialogContent extends StatelessWidget {
  final BoxesController controller;
  const _BoxSearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller.searchController,
          onChanged: controller.filterBoxes, // تفعيل البحث التلقائي
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ابحث بالرقم أو الاسم أو اسم الحساب...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.filteredBoxes.isEmpty) {
              return const Center(child: Text('لا توجد نتائج مطابقة'));
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        showCheckboxColumn: false,
                        border: TableBorder.all(
                          width: 1.0,
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        headingRowColor:
                        MaterialStateProperty.all(Colors.grey.shade200),
                        columns: const [
                          DataColumn(
                              label: Text('الرقم',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('اسم الصندوق',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('الحساب المرتبط',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: controller.filteredBoxes.map((box) {
                          return DataRow(
                            onSelectChanged: (isSelected) {
                              if (isSelected ?? false) {
                                controller.displayBox(box);
                                Get.back();
                              }
                            },
                            cells: [
                              DataCell(Text(box.boxNo.toString())),
                              DataCell(Text(box.boxName)),
                              DataCell(
                                  Text(box.linkedAccount?.name ?? 'غير مربوط')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

// --- ويدجت نافذة بحث الحسابات (للعرض فقط) ---
class _AccountSearchDialog extends StatelessWidget {
  final BoxesController controller;
  const _AccountSearchDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextField(
            controller: controller.accountSearchController,
            onChanged: controller.filterAccounts, // تفعيل البحث التلقائي
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'ابحث بالاسم أو الرقم...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Expanded(
          child: Obx(() {
            if (controller.filteredAccounts.isEmpty) {
              return const Center(child: Text('لا توجد نتائج مطابقة'));
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        showCheckboxColumn: false,
                        border: TableBorder.all(width: 1.0, color: Colors.grey.shade300),
                        headingRowColor: MaterialStateProperty.all(Colors.blue.shade100),
                        columns: const [
                          DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الاسم الأجنبي', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('حساب الأب', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: controller.filteredAccounts.map((account) {
                          return DataRow(
                            onSelectChanged: (isSelected) {
                              if (isSelected ?? false) {
                                controller.selectAccount(account['id'], account['name']);
                                Get.back();
                              }
                            },
                            cells: [
                              DataCell(Text(account['account_number']?.toString() ?? 'N/A')),
                              DataCell(Text(account['name']?.toString() ?? '')),
                              DataCell(Text(account['name_en']?.toString() ?? '')),
                              DataCell(Text(controller.getParentAccountName(account['parent_id']))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}