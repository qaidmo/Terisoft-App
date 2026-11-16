// lib/screens/supplier_movement_screen.dart
// شاشة تقرير حركة الموردين — البنية المعيارية مطابقة لـ ItemBalancesScreen

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'controllers/supplier_movement_controller.dart';

class SupplierMovementScreen extends StatelessWidget {
  const SupplierMovementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SupplierMovementController controller =
        Get.put(SupplierMovementController());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'حركة الموردين',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal.shade800,
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
          // ترس الإعدادات — موجود دائماً في كل تقارير المنظومة
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'إعدادات عرض التقرير',
            onPressed: () => _showSettingsSheet(context, controller),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: EdgeInsets.only(
              left: 12.0,
              right: 12.0,
              top: 12.0,
              bottom: MediaQuery.of(context).padding.bottom + 12.0,
            ),
            child: Column(
              children: [
                _buildFilterSection(context, controller),
                const SizedBox(height: 10),
                _buildSummaryBar(controller),
                const SizedBox(height: 10),
                Expanded(
                  child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!controller.hasSearched.value) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.handshake_outlined,
                            size: 64, color: Colors.teal.shade200),
                        const SizedBox(height: 12),
                        const Text(
                          'الرجاء تحديد الفلاتر والضغط على "عرض التقرير"',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
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
                          style: TextStyle(color: Colors.grey, fontSize: 14),
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
  // Filter Section — تاريخان + عملة + أزرار الإجراءات فقط
  // ---------------------------------------------------------------------------
  Widget _buildFilterSection(
      BuildContext context, SupplierMovementController controller) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // التواريخ
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
            const SizedBox(height: 12),

            // عملة الحساب — مباشرة تحت التواريخ
            Obx(() {
              if (controller.isCurrencyListLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return DropdownButtonFormField<int>(
                value: controller.selectedCurrency.value?.currencyNo,
                decoration: const InputDecoration(
                  labelText: 'عملة الحساب',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
                isExpanded: true,
                items: controller.allCurrencies.map((c) {
                  return DropdownMenuItem<int>(
                    value: c.currencyNo,
                    child:
                        Text(c.currencyName, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    controller.selectedCurrency.value = controller.allCurrencies
                        .firstWhere((c) => c.currencyNo == val);
                  }
                },
              );
            }),
            const SizedBox(height: 12),

            // أزرار الإجراءات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('مسح الفلاتر'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
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
  // Summary Bar
  // ---------------------------------------------------------------------------
  Widget _buildSummaryBar(SupplierMovementController controller) {
    return Obx(() {
      if (!controller.hasSearched.value || controller.reportData.isEmpty) {
        return const SizedBox.shrink();
      }
      return Card(
        color: Colors.teal.shade50,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _summaryItem(
                    'عدد الموردين',
                    controller.reportData.length.toString(),
                    Icons.handshake_outlined),
                _divider(),
                _summaryItem(
                    'مشتريات',
                    controller
                        .formatCurrency(controller.grandTotalPurchases.value),
                    Icons.shopping_cart_outlined,
                    valueColor: Colors.teal.shade900),
                _divider(),
                _summaryItem(
                    'مردودات',
                    controller
                        .formatCurrency(controller.grandTotalReturns.value),
                    Icons.assignment_return_outlined,
                    valueColor: Colors.orange.shade800),
                _divider(),
                _summaryItem(
                    'السداد',
                    controller
                        .formatCurrency(controller.grandTotalPayments.value),
                    Icons.payments_outlined,
                    valueColor: Colors.blue.shade800),
                _divider(),
                _summaryItem(
                    'الرصيد',
                    controller.formatCurrency(controller.grandBalance.value),
                    Icons.account_balance_wallet_outlined,
                    valueColor: controller.grandBalance.value < 0
                        ? Colors.red
                        : Colors.teal.shade900),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _divider() => Container(
      width: 1,
      height: 40,
      color: Colors.teal.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 10));

  Widget _summaryItem(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.teal.shade700),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.teal.shade800,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.teal.shade900)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // DataTable2 — هيكل الأعمدة النهائي
  //
  // أعمدة ثابتة دائماً (بدون شرط if):
  //   م | رقم الحساب | افتتاحي | مشتريات | مردودات | صافي المشتريات |
  //   السداد | تسويات | رصيد نهائي | العملة
  // ---------------------------------------------------------------------------
  Widget _buildDataTable(
      BuildContext context, SupplierMovementController controller) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Obx(() {
        final bool inclAccName   = controller.showAccountName.value;
        final bool inclSuppName  = controller.showSupplierName.value;
        final bool inclDept      = controller.showDepartment.value;
        final bool inclBranch    = controller.showBranch.value;
        final bool showInv       = controller.showInventoryValue.value;
        final bool detailedMode  = controller.isDetailedMode;

        double totalWidth = 50.0 + 100.0 + 110.0 + 110.0 + 110.0 + 110.0 + 110.0 + 110.0 + 120.0 + 110.0;
        if (inclAccName) totalWidth += 150.0;
        if (inclSuppName) totalWidth += 160.0;
        if (inclDept) totalWidth += 80.0;
        if (inclBranch) totalWidth += 80.0;
        if (showInv) totalWidth += 220.0;
        if (detailedMode) totalWidth += 220.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                _buildHeader(inclAccName, inclSuppName, inclDept, inclBranch, showInv, detailedMode),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.reportData.length,
                    itemExtent: 44.0,
                    itemBuilder: (context, index) {
                      final row = controller.reportData[index];
                      return _buildRow(
                        row,
                        index,
                        inclAccName,
                        inclSuppName,
                        inclDept,
                        inclBranch,
                        showInv,
                        detailedMode,
                        controller,
                      );
                    },
                  ),
                ),
                _buildFooter(inclAccName, inclSuppName, inclDept, inclBranch, showInv, detailedMode, controller),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHeader(bool inclAccName, bool inclSuppName, bool inclDept, bool inclBranch, bool showInv, bool detailedMode) {
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: Colors.teal.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      ),
      child: Row(
        children: [
          _vHeaderCell('م', width: 50.0),
          _vHeaderCell('رقم الحساب', width: 100.0),
          if (inclAccName) _vHeaderCell('اسم الحساب', width: 150.0),
          if (inclSuppName) _vHeaderCell('اسم المورد', width: 160.0),
          if (inclDept) _vHeaderCell('القسم', width: 80.0),
          if (inclBranch) _vHeaderCell('الفرع', width: 80.0),
          _vHeaderCell('افتتاحي', width: 110.0),
          _vHeaderCell('مشتريات', width: 110.0),
          _vHeaderCell('مردودات', width: 110.0),
          _vHeaderCell('صافي المشتريات', width: 110.0),
          _vHeaderCell('السداد', width: 110.0),
          _vHeaderCell('تسويات', width: 110.0),
          _vHeaderCell('الرصيد', width: 120.0),
          if (showInv) _vHeaderCell('المخزون', width: 110.0),
          if (showInv) _vHeaderCell('الفارق', width: 110.0),
          _vHeaderCell('تاريخ آخر سداد', width: 110.0),
          if (detailedMode) _vHeaderCell('تاريخ الفاتورة', width: 110.0),
          if (detailedMode) _vHeaderCell('رقم الفاتورة', width: 110.0),
        ],
      ),
    );
  }

  Widget _buildRow(
    Map<String, dynamic> row,
    int index,
    bool inclAccName,
    bool inclSuppName,
    bool inclDept,
    bool inclBranch,
    bool showInv,
    bool detailedMode,
    SupplierMovementController controller,
  ) {
    final int displayIndex = index + 1;
    final Color rowBg = displayIndex % 2 == 0 ? Colors.white : Colors.grey.shade50;

    final double balance = (row['balance'] as num?)?.toDouble() ?? 0.0;
    final Color balanceColor = balance < 0
        ? Colors.red.shade700
        : balance > 0
            ? Colors.teal.shade800
            : Colors.black54;

    final bool isFirstRow = row['is_first_row'] as bool? ?? true;
    final double openingVal = (row['opening_balance'] as num?)?.toDouble() ?? 0.0;
    final String displayedSupplierName = (row['displayed_supplier_name'] ?? row['supplier_name'] ?? '').toString();

    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: Row(
        children: [
          _vCell(displayIndex.toString(), width: 50.0, bold: true, align: TextAlign.center),
          _vCell(row['account_number']?.toString() ?? '', width: 100.0, bold: true, align: TextAlign.center),
          if (inclAccName) _vCell(row['account_name']?.toString() ?? '', width: 150.0, align: TextAlign.right),
          if (inclSuppName) _vCell(displayedSupplierName, width: 160.0, bold: true, align: TextAlign.right),
          if (inclDept) _vCell(row['department_id']?.toString() ?? '', width: 80.0, align: TextAlign.center),
          if (inclBranch) _vCell(row['branch_id']?.toString() ?? '', width: 80.0, align: TextAlign.center),
          _vCell(
            isFirstRow && openingVal != 0
                ? (row['opening_balance_str'] ?? controller.formatCurrency(openingVal))
                : (isFirstRow ? (row['opening_balance_str'] ?? controller.formatCurrency(openingVal)) : ''),
            width: 110.0,
            align: TextAlign.right,
          ),
          _vCell(row['total_purchases_str'] ?? controller.formatCurrency(row['total_purchases']), width: 110.0, align: TextAlign.right, color: Colors.teal.shade700),
          _vCell(row['total_returns_str'] ?? controller.formatCurrency(row['total_returns']), width: 110.0, align: TextAlign.right, color: Colors.orange.shade700),
          _vCell(row['net_purchases_str'] ?? controller.formatCurrency(row['net_purchases']), width: 110.0, align: TextAlign.right, bold: true),
          _vCell(row['total_payments_str'] ?? controller.formatCurrency(row['total_payments']), width: 110.0, align: TextAlign.right, color: Colors.blue.shade700),
          _vCell(row['total_adjustments_str'] ?? controller.formatCurrency(row['total_adjustments']), width: 110.0, align: TextAlign.right),
          _vCell(
            isFirstRow ? (row['balance_str'] ?? controller.formatCurrency(row['balance'])) : '',
            width: 120.0,
            align: TextAlign.right,
            bold: isFirstRow,
            color: isFirstRow ? balanceColor : null,
          ),
          if (showInv) _vCell(row['inventory_value_str'] ?? controller.formatCurrency(row['inventory_value']), width: 110.0, align: TextAlign.right, color: Colors.purple.shade700),
          if (showInv) _vCell(row['difference_str'] ?? controller.formatCurrency(row['difference']), width: 110.0, align: TextAlign.right),
          _vCell(row['last_payment_date']?.toString() ?? '', width: 110.0, align: TextAlign.center),
          if (detailedMode) _vCell(row['invoice_date']?.toString() ?? '', width: 110.0, align: TextAlign.center),
          if (detailedMode) _vCell(row['invoice_number']?.toString() ?? '', width: 110.0, align: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildFooter(
    bool inclAccName,
    bool inclSuppName,
    bool inclDept,
    bool inclBranch,
    bool showInv,
    bool detailedMode,
    SupplierMovementController controller,
  ) {
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: Colors.teal.shade100,
        border: Border(top: BorderSide(color: Colors.teal.shade300, width: 1.2)),
      ),
      child: Row(
        children: [
          _vCell('المجموع', width: 50.0, bold: true, align: TextAlign.center),
          _vCell('', width: 100.0, align: TextAlign.center),
          if (inclAccName) _vCell('', width: 150.0),
          if (inclSuppName) _vCell('', width: 160.0),
          if (inclDept) _vCell('', width: 80.0, align: TextAlign.center),
          if (inclBranch) _vCell('', width: 80.0, align: TextAlign.center),
          _vCell(controller.grandOpeningBalanceStr.value, width: 110.0, bold: true, align: TextAlign.right),
          _vCell(controller.grandTotalPurchasesStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.teal.shade800),
          _vCell(controller.grandTotalReturnsStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.orange.shade800),
          _vCell(controller.grandNetPurchasesStr.value, width: 110.0, bold: true, align: TextAlign.right),
          _vCell(controller.grandTotalPaymentsStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.blue.shade800),
          _vCell(controller.grandTotalAdjustmentsStr.value, width: 110.0, bold: true, align: TextAlign.right),
          _vCell(controller.grandBalanceStr.value, width: 120.0, bold: true, align: TextAlign.right, color: Colors.teal.shade900),
          if (showInv) _vCell('0', width: 110.0, bold: true, align: TextAlign.right),
          if (showInv)
            _vCell(controller.grandBalanceStr.value, width: 110.0, bold: true, align: TextAlign.right),
          _vCell('', width: 110.0),
          if (detailedMode) _vCell('', width: 110.0),
          if (detailedMode) _vCell('', width: 110.0),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings Bottom Sheet — قسمان + 6 مفاتيح SwitchListTile
  // ---------------------------------------------------------------------------
  void _showSettingsSheet(
      BuildContext context, SupplierMovementController controller) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس النافذة
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.tune,
                          color: Colors.teal.shade800, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'إعدادات عرض التقرير',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // --- القسم 1: تجميع وإضافة أعمدة ---
                _sectionLabel('تجميع وإضافة أعمدة', Colors.teal.shade800),
                Obx(() => _buildSwitch(
                    'اسم الحساب', Icons.account_balance,
                    controller.showAccountName.value,
                    (v) => controller.toggleSetting('showAccountName', v))),
                Obx(() => _buildSwitch(
                    'اسم المورد', Icons.badge_outlined,
                    controller.showSupplierName.value,
                    (v) => controller.toggleSetting('showSupplierName', v))),
                Obx(() => _buildSwitch(
                    'حسب القسم', Icons.business_outlined,
                    controller.showDepartment.value,
                    (v) => controller.toggleSetting('showDepartment', v))),
                Obx(() => _buildSwitch(
                    'حسب الفرع', Icons.store_outlined,
                    controller.showBranch.value,
                    (v) => controller.toggleSetting('showBranch', v))),

                const Divider(height: 24),

                // --- القسم 2: فلترة وعرض البيانات ---
                _sectionLabel('فلترة وعرض البيانات', Colors.orange.shade800),
                Obx(() => _buildSwitch(
                    'استبعاد الصفرية', Icons.filter_alt_outlined,
                    controller.excludeZero.value,
                    (v) => controller.toggleSetting('excludeZero', v),
                    highlight: true,
                    highlightColor: Colors.orange.shade800)),
                Obx(() => _buildSwitch(
                    'إظهار قيمة المخزون', Icons.inventory_2_outlined,
                    controller.showInventoryValue.value,
                    (v) => controller.toggleSetting('showInventoryValue', v),
                    highlight: true,
                    highlightColor: Colors.purple.shade700)),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool highlight = false,
    Color? highlightColor,
  }) {
    final Color activeColor = highlight
        ? (highlightColor ?? Colors.orange.shade800)
        : Colors.teal.shade800;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight:
              (value || highlight) ? FontWeight.bold : FontWeight.normal,
          color: highlight
              ? (highlightColor ?? Colors.orange.shade800)
              : (value ? Colors.black87 : Colors.grey.shade600),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeColor,
      activeTrackColor: activeColor.withValues(alpha: 0.3),
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.grey.shade200,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlight
              ? activeColor.withValues(alpha: 0.1)
              : (value
                  ? Colors.teal.withValues(alpha: 0.1)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            color: highlight
                ? activeColor
                : (value ? Colors.teal.shade700 : Colors.grey),
            size: 20),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
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
          color: color,
        ),
      ),
    );
  }

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
}
