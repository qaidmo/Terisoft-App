// lib/screens/item_movement_screen.dart
// شاشة تقرير حركة الأصناف - مستقلة تماماً

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'controllers/item_movement_controller.dart';
import '../models/item_movement_models.dart';

class ItemMovementScreen extends StatelessWidget {
  const ItemMovementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ItemMovementController controller =
        Get.put(ItemMovementController());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'حركة الأصناف',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 45,
        actions: [
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
          return Padding(
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'الرجاء تحديد الفلاتر والضغط على "عرض التقرير"',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                if (controller.reportData.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد بيانات لعرضها حسب الفلاتر المحددة',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                return _buildDataTable(context, controller);
              }),
            ),
          ],
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
      BuildContext context, ItemMovementController controller) {
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

            // الصف الثاني: نوع الحركة
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
            const SizedBox(height: 10),

            // الصف الثالث: مجموعة الأصناف
            Obx(() {
              final groups = controller.itemGroupsList;
              return DropdownButtonFormField<String?>(
                value: controller.selectedItemGroupId.value,
                decoration: const InputDecoration(
                  labelText: 'اسم المجموعة',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('الكل', overflow: TextOverflow.ellipsis),
                  ),
                  ...groups.map((g) => DropdownMenuItem<String?>(
                        value: g['group_no'],
                        child: Text(
                          '${g['group_name']} (${g['group_no']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (value) {
                  controller.selectedItemGroupId.value = value;
                },
              );
            }),
            const SizedBox(height: 12),

            // أزرار التحكم
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('مسح الفلاتر'),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: controller.clearFilters,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: const Text('عرض التقرير'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
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
  // شريط الملخص
  // ---------------------------------------------------------------------------
  Widget _buildSummaryBar(ItemMovementController controller) {
    return Obx(() {
      if (!controller.hasSearched.value || controller.reportData.isEmpty) {
        return const SizedBox.shrink();
      }
      return Card(
        color: Colors.blue.shade50,
        elevation: 2,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _summaryItem('عدد الأسطر',
                    controller.rowCount.value.toString(), Icons.list_alt),
                _divider(),
                _summaryItem(
                    'إجمالي القيمة',
                    controller.formatNumber(controller.grandTotalAmount.value),
                    Icons.attach_money),
                _divider(),
                _summaryItem(
                    'صافي القيمة',
                    controller.formatNumber(controller.grandNetAmount.value),
                    Icons.account_balance_wallet),
                _divider(),
                _summaryItem(
                    'إجمالي التكلفة',
                    controller.formatNumber(controller.grandTotalCost.value),
                    Icons.price_check),
                _divider(),
                _summaryItem(
                    'الهامش الإجمالي',
                    controller.formatNumber(controller.grandMargin.value),
                    Icons.trending_up),
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
          Icon(icon, size: 18, color: Colors.blue.shade700),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: Colors.blue.shade200);

  // ---------------------------------------------------------------------------
  // جدول البيانات — 34 عمود مع تمرير أفقي وعمودي
  // ---------------------------------------------------------------------------
  Widget _buildDataTable(
      BuildContext context, ItemMovementController controller) {
    const double totalWidth = 3755.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Obx(() {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.reportData.length,
                    itemExtent: 44.0,
                    itemBuilder: (context, index) {
                      final ItemMovementRow row = controller.reportData[index];
                      return _buildRow(row, index);
                    },
                  ),
                ),
                _buildFooter(controller),
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
        color: Colors.blue.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      ),
      child: Row(
        children: [
          _vHeaderCell('م', width: 45.0),
          _vHeaderCell('رقم الصنف', width: 110.0),
          _vHeaderCell('اسم الصنف', width: 180.0),
          _vHeaderCell('الوحدة', width: 80.0),
          _vHeaderCell('العبوة', width: 70.0),
          _vHeaderCell('الكمية', width: 90.0),
          _vHeaderCell('كمية مجاني', width: 90.0),
          _vHeaderCell('القيمة', width: 90.0),
          _vHeaderCell('الإجمالي', width: 110.0),
          _vHeaderCell('القيمة بعد الخصم', width: 110.0),
          _vHeaderCell('قيمة المجاني', width: 100.0),
          _vHeaderCell('التاريخ', width: 100.0),
          _vHeaderCell('الوصف', width: 180.0),
          _vHeaderCell('رقم الحركة', width: 110.0),
          _vHeaderCell('المرجع', width: 100.0),
          _vHeaderCell('الاسم', width: 180.0),
          _vHeaderCell('ت الانتهاء', width: 100.0),
          _vHeaderCell('رقم الدفعة', width: 100.0),
          _vHeaderCell('الصافي', width: 110.0),
          _vHeaderCell('العملة', width: 70.0),
          _vHeaderCell('التكلفة', width: 90.0),
          _vHeaderCell('إجمالي التكلفة', width: 110.0),
          _vHeaderCell('الهامش', width: 110.0),
          _vHeaderCell('سعر الصرف', width: 90.0),
          _vHeaderCell('الصافي محلي', width: 110.0),
          _vHeaderCell('رقم الحساب', width: 110.0),
          _vHeaderCell('اسم الحساب', width: 180.0),
          _vHeaderCell('مركز التكلفة', width: 120.0),
          _vHeaderCell('المندوب', width: 120.0),
          _vHeaderCell('المحصل', width: 120.0),
          _vHeaderCell('الفرع', width: 80.0),
          _vHeaderCell('القسم', width: 80.0),
          _vHeaderCell('رقم المخزن', width: 80.0),
          _vHeaderCell('اسم المخزن', width: 130.0),
          _vHeaderCell('المستخدم', width: 100.0),
        ],
      ),
    );
  }

  Widget _buildRow(ItemMovementRow row, int rawIndex) {
    final int index = rawIndex + 1;
    final Color rowColor = index % 2 == 0 ? Colors.white : Colors.grey.shade50;

    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: Row(
        children: [
          _vCell(index.toString(), width: 45.0, align: TextAlign.center),
          _vCell(row.itemNo, width: 110.0, bold: true, align: TextAlign.center),
          _vCell(row.itemName, width: 180.0, align: TextAlign.right),
          _vCell(row.itemUnit, width: 80.0, align: TextAlign.center),
          _vCell(row.packFactor, width: 70.0, align: TextAlign.center),
          _vCell(row.quantityStr.isNotEmpty ? row.quantityStr : row.quantity.toString(), width: 90.0, align: TextAlign.right),
          _vCell(row.freeQuantityStr.isNotEmpty ? row.freeQuantityStr : row.freeQuantity.toString(), width: 90.0, align: TextAlign.right),
          _vCell(row.unitPriceStr.isNotEmpty ? row.unitPriceStr : row.unitPrice.toString(), width: 90.0, align: TextAlign.right),
          _vCell(row.totalAmountStr.isNotEmpty ? row.totalAmountStr : row.totalAmount.toString(), width: 110.0, align: TextAlign.right, color: Colors.blueAccent),
          _vCell(row.netUnitPriceStr.isNotEmpty ? row.netUnitPriceStr : row.netUnitPrice.toString(), width: 110.0, align: TextAlign.right),
          _vCell(row.freeValueStr.isNotEmpty ? row.freeValueStr : row.freeValue.toString(), width: 100.0, align: TextAlign.right),
          _vCell(row.formattedDate.isNotEmpty ? row.formattedDate : row.date, width: 100.0, align: TextAlign.center),
          _vCell(row.description, width: 180.0, align: TextAlign.right),
          _vCell(row.transactionNumber, width: 110.0, bold: true, align: TextAlign.center),
          _vCell(row.referenceNumber, width: 100.0, align: TextAlign.center, color: Colors.grey.shade600),
          _vCell(row.customerName, width: 180.0, align: TextAlign.right),
          _vCell(row.expiryDate, width: 100.0, align: TextAlign.center),
          _vCell(row.batchNumber, width: 100.0, align: TextAlign.center),
          _vCell(row.netAmountStr.isNotEmpty ? row.netAmountStr : row.netAmount.toString(), width: 110.0, align: TextAlign.right, color: Colors.green.shade700),
          _vCell(row.currency, width: 70.0, align: TextAlign.center),
          _vCell(row.costPriceStr.isNotEmpty ? row.costPriceStr : row.costPrice.toString(), width: 90.0, align: TextAlign.right),
          _vCell(row.totalCostStr.isNotEmpty ? row.totalCostStr : row.totalCost.toString(), width: 110.0, align: TextAlign.right),
          _vCell(row.marginStr.isNotEmpty ? row.marginStr : row.margin.toString(), width: 110.0, align: TextAlign.right, color: row.margin >= 0 ? Colors.green.shade700 : Colors.red),
          _vCell(row.exchangeRateStr.isNotEmpty ? row.exchangeRateStr : row.exchangeRate.toString(), width: 90.0, align: TextAlign.right),
          _vCell(row.localNetAmountStr.isNotEmpty ? row.localNetAmountStr : row.localNetAmount.toString(), width: 110.0, align: TextAlign.right),
          _vCell(row.accountNumber, width: 110.0, align: TextAlign.center),
          _vCell(row.accountName, width: 180.0, align: TextAlign.right),
          _vCell(row.costCenterName, width: 120.0, align: TextAlign.right),
          _vCell(row.salespersonName, width: 120.0, align: TextAlign.right),
          _vCell(row.collectorName, width: 120.0, align: TextAlign.right),
          _vCell(row.branchId, width: 80.0, align: TextAlign.center),
          _vCell(row.departmentId, width: 80.0, align: TextAlign.center),
          _vCell(row.storeNo, width: 80.0, align: TextAlign.center),
          _vCell(row.storeName, width: 130.0, align: TextAlign.right),
          _vCell(row.userName, width: 100.0, align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFooter(ItemMovementController controller) {
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        border: Border(top: BorderSide(color: Colors.blue.shade300, width: 1.2)),
      ),
      child: Row(
        children: [
          _vCell('المجموع', width: 45.0, bold: true, align: TextAlign.center),
          _vCell('', width: 110.0),
          _vCell('', width: 180.0),
          _vCell('', width: 80.0),
          _vCell('', width: 70.0),
          _vCell('', width: 90.0),
          _vCell('', width: 90.0),
          _vCell('', width: 90.0),
          _vCell(controller.grandTotalAmountStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.blue.shade900),
          _vCell('', width: 110.0),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell('', width: 180.0),
          _vCell('', width: 110.0),
          _vCell('', width: 100.0),
          _vCell('', width: 180.0),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell(controller.grandNetAmountStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.green.shade800),
          _vCell('', width: 70.0),
          _vCell('', width: 90.0),
          _vCell(controller.grandTotalCostStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.blue.shade900),
          _vCell(controller.grandMarginStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.blue.shade900),
          _vCell('', width: 90.0),
          _vCell('', width: 110.0),
          _vCell('', width: 110.0),
          _vCell('', width: 180.0),
          _vCell('', width: 120.0),
          _vCell('', width: 120.0),
          _vCell('', width: 120.0),
          _vCell('', width: 80.0),
          _vCell('', width: 80.0),
          _vCell('', width: 80.0),
          _vCell('', width: 130.0),
          _vCell('', width: 100.0),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date Picker
  // ---------------------------------------------------------------------------
  Widget _buildDatePicker(
      BuildContext context, String label, Rx<DateTime> date) {
    final DateFormat displayFormat = DateFormat('yyyy-MM-dd');
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: date.value,
          firstDate: DateTime(2018),
          lastDate: DateTime(2100),
        );
        if (picked != null) date.value = picked;
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          suffixIcon: const Icon(Icons.calendar_month, size: 18),
        ),
        child: Obx(() => Text(displayFormat.format(date.value),
            style: const TextStyle(fontSize: 14))),
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
          color: Colors.blue.shade900,
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
          color: color,
        ),
      ),
    );
  }
}
