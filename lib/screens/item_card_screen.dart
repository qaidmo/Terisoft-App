// lib/screens/item_card_screen.dart
// شاشة تقرير بطاقة الصنف - مستقلة تماماً

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';
import 'controllers/item_card_controller.dart';
import '../models/item_card_models.dart';

class ItemCardScreen extends StatelessWidget {
  const ItemCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ItemCardController controller = Get.put(ItemCardController());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'بطاقة صنف',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 45,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'إعدادات التقرير',
            onPressed: () => _showSettingsSheet(context, controller),
          ),
          Obx(() => controller.canPrint()
              ? IconButton(
                  icon: const Icon(Icons.print_outlined, color: Colors.white),
                  tooltip: 'طباعة التقرير',
                  onPressed: controller.printReport,
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.only(
                left: 8.0,
                right: 8.0,
                top: 10.0,
                bottom: MediaQuery.of(context).padding.bottom + 8.0,
              ),
              child: Column(
                children: [
            _buildFilterSection(context, controller),
            const SizedBox(height: 8),
            _buildSummaryBar(controller),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!controller.hasSearched.value) {
                  return const Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.credit_card_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'أدخل اسم الصنف واضغط على "عرض التقرير"',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (controller.reportData.isEmpty) {
                  return const Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'لا توجد بيانات لعرضها حسب الفلاتر المحددة',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return _buildDataTable(context, controller);
              }),
            ),
          ],
        ),
      ),
    );
  },
),
);
}

  // ---------------------------------------------------------------------------
  // قسم الفلاتر
  // ---------------------------------------------------------------------------
  Widget _buildFilterSection(
      BuildContext context, ItemCardController controller) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // الصف الأول: التاريخ
            Row(
              children: [
                Expanded(
                    child: _buildDatePicker(
                        context, 'من تاريخ:', controller.fromDate)),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildDatePicker(
                        context, 'إلى تاريخ:', controller.toDate)),
              ],
            ),
            const SizedBox(height: 10),

            // الصف الثاني: اسم الصنف (إجباري) مع زر بحث
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final String? result = await Get.dialog(
                          _ItemCardSearchDialog(controller: controller));
                      if (result != null && result.isNotEmpty) {
                        controller.itemNameTextController.text = result;
                        controller.onItemNameSubmitted();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: controller.itemNameTextController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'اسم الصنف ★',
                          hintText: 'اضغط للبحث عن صنف...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // الصف الثالث: الوحدة + رقم الدفعة (Dropdowns تابعة)
            Row(
              children: [
                Expanded(
                  child: Obx(() {
                    final units = controller.unitsList;
                    return DropdownButtonFormField<UnitInfo?>(
                      value: controller.selectedUnit.value,
                      decoration: const InputDecoration(
                        labelText: 'الوحدة (تحويل)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      isExpanded: true,
                      // معطّل حتى يتم إدخال اسم الصنف
                      onChanged: units.isEmpty
                          ? null
                          : (value) {
                              controller.onUnitChanged(value);
                            },
                      items: units.map(
                        (u) => DropdownMenuItem<UnitInfo?>(
                          value: u,
                          child: Text(
                            u.packFactor == 1.0
                                ? u.name
                                : '${u.name} (×${u.packFactor.toStringAsFixed(u.packFactor == u.packFactor.roundToDouble() ? 0 : 2)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ).toList(),
                    );
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(() {
                    final batches = controller.batchesList;
                    return DropdownButtonFormField<String?>(
                      value: controller.selectedBatch.value,
                      decoration: const InputDecoration(
                        labelText: 'رقم الدفعة',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      isExpanded: true,
                      // معطّل حتى يتم إدخال اسم الصنف
                      onChanged: batches.isEmpty
                          ? null
                          : (value) {
                              controller.selectedBatch.value = value;
                            },
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('الكل',
                              overflow: TextOverflow.ellipsis),
                        ),
                        ...batches.map(
                          (b) => DropdownMenuItem<String?>(
                            value: b,
                            child: Text(b,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // الصف الرابع: نوع الحركة
            Obx(() => DropdownButtonFormField<String>(
                  value: controller.selectedReportType.value,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحركة',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  ),
                  isExpanded: true,
                  items: controller.reportTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type['value'],
                      child: Text(type['display']!,
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      controller.selectedReportType.value = value;
                    }
                  },
                )),
            const SizedBox(height: 12),

            // الصف الخامس: الأزرار
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('مسح الفلاتر'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red),
                  onPressed: controller.clearFilters,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: const Text('عرض التقرير'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed: controller.fetchReportData,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // نافذة الإعدادات (Bottom Sheet)
  // ---------------------------------------------------------------------------
  void _showSettingsSheet(
      BuildContext context, ItemCardController controller) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('إعدادات التقرير',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const Divider(),
            Obx(() => CheckboxListTile(
                  title: const Text('استبعاد الرصيد الافتتاحي'),
                  value: controller.excludeOpeningBalance.value,
                  activeColor: Colors.teal.shade800,
                  onChanged: (v) =>
                      controller.excludeOpeningBalance.value = v ?? false,
                )),
            Obx(() => CheckboxListTile(
                  title: const Text('استبعاد الرصيد السابق'),
                  value: controller.excludePreviousBalance.value,
                  activeColor: Colors.teal.shade800,
                  onChanged: (v) =>
                      controller.excludePreviousBalance.value = v ?? false,
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // شريط الملخص
  // ---------------------------------------------------------------------------
  Widget _buildSummaryBar(ItemCardController controller) {
    return Obx(() {
      if (!controller.hasSearched.value || controller.reportData.isEmpty) {
        return const SizedBox.shrink();
      }
      return Card(
        color: Colors.teal.shade50,
        elevation: 2,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _summaryItem(
                    'عدد الأسطر',
                    controller.rowCount.value.toString(),
                    Icons.list_alt),
                _divider(),
                _summaryItem(
                    'إجمالي وارد',
                    controller.totalQuantityInStr.value,
                    Icons.arrow_downward),
                _divider(),
                _summaryItem(
                    'إجمالي صادر',
                    controller.totalQuantityOutStr.value,
                    Icons.arrow_upward),
                _divider(),
                _summaryItem(
                    'الرصيد النهائي',
                    controller.finalBalanceStr.value,
                    Icons.account_balance_wallet_outlined),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.teal.shade700),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.teal.shade800,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.teal.shade900,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: Colors.teal.shade200,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  // ---------------------------------------------------------------------------
  // جدول البيانات (Continuous Virtualized Table)
  // ---------------------------------------------------------------------------
  Widget _buildDataTable(
      BuildContext context, ItemCardController controller) {
    const double tableWidth = 2555.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Obx(() {
                    final data = controller.reportData;
                    return ListView.builder(
                      itemCount: data.length,
                      itemExtent: 44.0,
                      itemBuilder: (context, index) {
                        return _buildRow(data[index], index);
                      },
                    );
                  }),
                ),
                Obx(() => _buildFooter(controller)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: Colors.teal.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      ),
      child: Row(
        children: [
          _vHeaderCell('م', width: 45.0),
          _vHeaderCell('وارد', width: 100.0),
          _vHeaderCell('منصرف', width: 100.0),
          _vHeaderCell('الرصيد', width: 110.0),
          _vHeaderCell('رقم القطعة', width: 100.0),
          _vHeaderCell('التكلفة', width: 100.0),
          _vHeaderCell('الوحدة', width: 80.0),
          _vHeaderCell('التاريخ', width: 100.0),
          _vHeaderCell('البيان', width: 180.0),
          _vHeaderCell('رقم الحركة', width: 100.0),
          _vHeaderCell('الاسم', width: 180.0),
          _vHeaderCell('تاريخ انتهاء', width: 100.0),
          _vHeaderCell('الوحدة', width: 80.0),
          _vHeaderCell('التكاليف', width: 110.0),
          _vHeaderCell('المبلغ', width: 110.0),
          _vHeaderCell('السعر', width: 100.0),
          _vHeaderCell('رقم_التاريخ', width: 100.0),
          _vHeaderCell('مرجع', width: 100.0),
          _vHeaderCell('المخزن', width: 130.0),
          _vHeaderCell('رقم الصنف', width: 110.0),
          _vHeaderCell('الفرع', width: 100.0),
          _vHeaderCell('اسم الحساب', width: 180.0),
          _vHeaderCell('مركز التكلفة', width: 140.0),
        ],
      ),
    );
  }

  Widget _buildRow(ItemCardRow row, int rawIndex) {
    final int index = rawIndex + 1;
    final Color rowBg = index.isEven ? Colors.white : Colors.grey.shade50;

    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: Row(
        children: [
          _vCell(index.toString(), width: 45.0, align: TextAlign.center),
          _vCell(
            row.quantityInStr,
            width: 100.0,
            align: TextAlign.right,
            color: row.quantityIn > 0 ? Colors.green.shade700 : null,
          ),
          _vCell(
            row.quantityOutStr,
            width: 100.0,
            align: TextAlign.right,
            color: row.quantityOut > 0 ? Colors.red.shade700 : null,
          ),
          _vCell(
            row.balanceStr,
            width: 110.0,
            align: TextAlign.right,
            bold: true,
            color: row.balance >= 0 ? Colors.teal.shade800 : Colors.red.shade700,
          ),
          _vCell(row.batchNumber, width: 100.0, align: TextAlign.center),
          _vCell(row.costPriceStr, width: 100.0, align: TextAlign.right),
          _vCell(row.itemUnit, width: 80.0, align: TextAlign.center),
          _vCell(row.formattedDate.isNotEmpty ? row.formattedDate : row.date, width: 100.0, align: TextAlign.center),
          _vCell(row.description, width: 180.0, align: TextAlign.right),
          _vCell(row.transactionNumber, width: 100.0, bold: true, color: Colors.blueAccent, align: TextAlign.center),
          _vCell(row.customerName, width: 180.0, align: TextAlign.right),
          _vCell(row.expiryDate, width: 100.0, align: TextAlign.center),
          _vCell(row.packFactor, width: 80.0, align: TextAlign.center),
          _vCell(row.totalCostStr, width: 110.0, align: TextAlign.right),
          _vCell(row.totalAmountStr, width: 110.0, align: TextAlign.right),
          _vCell(row.unitPriceStr, width: 100.0, align: TextAlign.right),
          _vCell(row.dateNo, width: 100.0, align: TextAlign.center),
          _vCell(row.referenceNumber, width: 100.0, align: TextAlign.center),
          _vCell(row.storeName, width: 130.0, align: TextAlign.right),
          _vCell(row.itemNo, width: 110.0, bold: true, align: TextAlign.center),
          _vCell(row.branchName, width: 100.0, align: TextAlign.center),
          _vCell(row.accountName, width: 180.0, align: TextAlign.right),
          _vCell(row.costCenterName, width: 140.0, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _buildFooter(ItemCardController controller) {
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: Colors.teal.shade100,
        border: Border(top: BorderSide(color: Colors.teal.shade300, width: 1.2)),
      ),
      child: Row(
        children: [
          _vCell('المجموع', width: 45.0, bold: true, align: TextAlign.center),
          _vCell(controller.totalQuantityInStr.value, width: 100.0, bold: true, align: TextAlign.right, color: Colors.green.shade800),
          _vCell(controller.totalQuantityOutStr.value, width: 100.0, bold: true, align: TextAlign.right, color: Colors.red.shade800),
          _vCell(controller.finalBalanceStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.teal.shade900),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell('', width: 80.0),
          _vCell('', width: 100.0),
          _vCell('', width: 180.0),
          _vCell('', width: 100.0),
          _vCell('', width: 180.0),
          _vCell('', width: 100.0),
          _vCell('', width: 80.0),
          _vCell('', width: 110.0),
          _vCell('', width: 110.0),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell('', width: 130.0),
          _vCell('', width: 110.0),
          _vCell('', width: 100.0),
          _vCell('', width: 180.0),
          _vCell('', width: 140.0),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // منتقي التاريخ
  // ---------------------------------------------------------------------------
  Widget _buildDatePicker(
      BuildContext context, String label, Rx<DateTime> date) {
    final DateFormat displayFormat = DateFormat('yyyy-MM-dd');
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: date.value,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) date.value = picked;
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        child: Obx(() => Text(displayFormat.format(date.value),
            style: const TextStyle(fontSize: 15))),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // خلايا الجدول المساعدة (Continuous Virtualized Table)
  // ---------------------------------------------------------------------------

  Widget _vHeaderCell(String text, {required double width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade900,
        ),
      ),
    );
  }

  Widget _vCell(
    String text, {
    required double width,
    bool bold = false,
    Color? color,
    TextAlign align = TextAlign.center,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : (align == TextAlign.left ? Alignment.centerLeft : Alignment.center),
      child: Text(
        text,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// نافذة البحث عن صنف
// ---------------------------------------------------------------------------
class _ItemCardSearchDialog extends StatelessWidget {
  final ItemCardController controller;
  const _ItemCardSearchDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    final RxString searchQuery = ''.obs;

    return AlertDialog(
      title: const Text('بحث عن صنف'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (val) => searchQuery.value = val,
              decoration: InputDecoration(
                labelText: 'ابحث بالاسم أو الرقم',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Obx(() {
                final query = searchQuery.value.trim();
                final items = controller.filterItems(query);

                if (items.isEmpty) {
                  return const Center(
                    child: Text('لا توجد أصناف مطابقة',
                        style: TextStyle(color: Colors.red, fontSize: 14)),
                  );
                }
                
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final itemName = item['item_name']?.toString() ?? '';
                    final itemNo = item['item_no']?.toString() ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.teal.shade50,
                        child: const Icon(Icons.inventory_2_outlined, size: 18, color: Colors.teal),
                      ),
                      title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(itemNo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      onTap: () => Get.back(result: itemName),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: null),
          child: const Text('إغلاق', style: TextStyle(color: Colors.grey)),
        )
      ],
    );
  }
}
