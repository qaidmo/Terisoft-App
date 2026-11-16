// lib/admin/currencies_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/currencies_controller.dart';

class CurrenciesScreen extends StatelessWidget {
  const CurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CurrenciesController controller = Get.put(CurrenciesController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('استعراض العملات'),
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed: controller.isLoading.value ? null : controller.fetchCurrencies,
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
            const Text('بيانات العملة المحددة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- [تم التعديل] --- استخدام حقول القراءة فقط
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField(controller: controller.noController, label: 'رقم العملة', icon: Icons.numbers),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildReadOnlyField(controller: controller.nameController, label: 'اسم العملة', icon: Icons.currency_exchange),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField(controller: controller.fkahController, label: 'فكة العملة', icon: Icons.money_off),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildReadOnlyField(controller: controller.symbolController, label: 'رمز العملة', icon: Icons.currency_lira),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildReadOnlyField(controller: controller.rateController, label: 'السعر الحالي', icon: Icons.attach_money),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField(controller: controller.highController, label: 'أعلى سعر', icon: Icons.trending_up),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildReadOnlyField(controller: controller.lowController, label: 'أدنى سعر', icon: Icons.trending_down),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- [تم التعديل] --- تبسيط الأزرار إلى البحث والطباعة فقط
            Obx(() => Row( // استخدام Row بدلاً من Wrap
              children: [
                // زر البحث يمتد ليأخذ المساحة المتاحة
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('بحث عن عملة'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: controller.isLoading.value ? null : () => _showSearchDialog(context, controller),
                  ),
                ),

                const SizedBox(width: 10), // مسافة فاصلة

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

  /// ويدجت مساعد جديد لبناء حقول القراءة فقط
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
  void _showSearchDialog(BuildContext context, CurrenciesController controller) {
    controller.searchController.clear();
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن عملة'),
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
}

/// محتوى نافذة البحث (مع تعديل بسيط)
class _SearchDialogContent extends StatelessWidget {
  final CurrenciesController controller;
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
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.filteredCurrencies.isEmpty) {
              return const Center(child: Text('لا توجد نتائج مطابقة'));
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              // [الإضافة 1] تمرير عمودي للصفوف
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                // [الإضافة 2] تمرير أفقي للأعمدة
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    border: TableBorder.all(width: 1.0, color: Colors.black38),
                    headingRowColor:
                    MaterialStateProperty.all(Colors.grey.shade200),
                    columns: const [
                      DataColumn(label: Text('الرقم')),
                      DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text('الرمز')),
                      DataColumn(label: Text('السعر')),
                    ],
                    rows: controller.filteredCurrencies.map((currency) {
                      return DataRow(
                        onSelectChanged: (isSelected) {
                          controller.displayCurrency(currency);
                          Get.back();
                        },
                        cells: [
                          DataCell(Text(currency.currencyNo.toString())),
                          // [تعديل] منع التفاف النص في خلية الاسم
                          DataCell(Text(
                            currency.currencyName,
                            softWrap: false, // يمنع نزول النص لسطر جديد
                            overflow: TextOverflow.ellipsis, // يضيف "..." إذا كان النص طويلاً جدًا
                          )),
                          DataCell(Text(currency.currencySymbol)),
                          DataCell(
                              Text(currency.currencyRate.toStringAsFixed(2))),
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