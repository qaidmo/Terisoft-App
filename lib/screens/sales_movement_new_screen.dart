// lib/screens/sales_movement_new_screen.dart
// تقرير حركة المبيعات الجديد - شاشة مستقلة تماماً مع 9 أعمدة ديناميكية

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'controllers/sales_movement_new_controller.dart';

class SalesMovementNewScreen extends StatelessWidget {
  const SalesMovementNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SalesMovementNewController controller =
        Get.put(SalesMovementNewController());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          'حركة المبيعات',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'إعدادات عرض الجدول',
            onPressed: () => _showSettingsSheet(context, controller),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(
          left: 12.0,
          right: 12.0,
          top: 12.0,
          bottom: MediaQuery.of(context).padding.bottom + 12.0,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double minTableHeight = constraints.maxHeight > 240 ? 120.0 : constraints.maxHeight * 0.35;
            final double maxFilterHeight = (constraints.maxHeight - minTableHeight).clamp(0.0, double.infinity);

            return Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxFilterHeight),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterSection(context, controller),
                        const SizedBox(height: 10),
                        _buildSummaryBar(controller),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
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
                        Icon(Icons.bar_chart, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('الرجاء تحديد الفلاتر والضغط على "عرض التقرير"',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                        Text('لا توجد بيانات لعرضها حسب الفلاتر المحددة',
                            style: TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                  );
                }
                return _buildDataTable(context, controller);
              }),
            ),
          ],
        );
      },
    ),
  ),
);
}

  // ---------------------------------------------------------------------------
  // Filter Section
  // ---------------------------------------------------------------------------
  Widget _buildFilterSection(
      BuildContext context, SalesMovementNewController controller) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Date Row
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
            // Transaction Type Dropdown
            Obx(() => DropdownButtonFormField<String>(
                  initialValue: controller.selectedReportType.value,
                  decoration: const InputDecoration(
                    labelText: 'نوع الحركة',
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

            // Action Buttons
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
  // Summary Bar
  // ---------------------------------------------------------------------------
  Widget _buildSummaryBar(SalesMovementNewController controller) {
    return Obx(() {
      if (!controller.hasSearched.value || controller.reportData.isEmpty) {
        return const SizedBox.shrink();
      }
      return Card(
        color: Colors.blue.shade50,
        elevation: 2,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem(
                  'عدد الحركات',
                  controller.itemsCount.value.toString(),
                  Icons.list_alt),
              Container(width: 1, height: 40, color: Colors.blue.shade200),
              _summaryItem(
                  'صافي القيمة',
                  controller.formatCurrency(controller.grandNetValue.value),
                  Icons.account_balance_wallet),
              Container(width: 1, height: 40, color: Colors.blue.shade200),
              _summaryItem(
                  'القيمة النهائية',
                  controller.formatCurrency(controller.grandFinalValue.value),
                  Icons.monetization_on),
            ],
          ),
        ),
      );
    });
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.blue.shade700),
        const SizedBox(height: 4),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Dynamic DataTable — THE CORE FEATURE
  // Columns and cells MUST use identical `if (condition)` statements
  // ---------------------------------------------------------------------------
  Widget _buildDataTable(
      BuildContext context, SalesMovementNewController controller) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Obx(() {
        final bool showDate = controller.showDate.value;
        final bool showInvoiceNumber = controller.showInvoiceNumber.value;
        final bool showTransType = controller.showTransType.value;
        final bool showBeneficiary = controller.showBeneficiary.value;
        final bool showAccountName = controller.showAccountName.value;
        final bool showUserName = controller.showUserName.value;
        final bool showBranch = controller.showBranch.value;
        final bool showDepartment = controller.showDepartment.value;
        final bool showTaxDiscount = controller.showTaxDiscount.value;

        double tableWidth = 50.0;
        if (showDate) tableWidth += 110.0;
        if (showInvoiceNumber) tableWidth += 120.0;
        if (showTransType) tableWidth += 120.0;
        if (showBeneficiary) tableWidth += 150.0;
        if (showAccountName) tableWidth += 160.0;
        if (showUserName) tableWidth += 120.0;
        if (showBranch) tableWidth += 120.0;
        if (showDepartment) tableWidth += 120.0;
        if (!showTaxDiscount) {
          tableWidth += 130.0;
        } else {
          tableWidth += 630.0;
        }

        const double rowHeight = 48.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              children: [
                _buildTableHeader(
                  showDate: showDate,
                  showInvoiceNumber: showInvoiceNumber,
                  showTransType: showTransType,
                  showBeneficiary: showBeneficiary,
                  showAccountName: showAccountName,
                  showUserName: showUserName,
                  showBranch: showBranch,
                  showDepartment: showDepartment,
                  showTaxDiscount: showTaxDiscount,
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: controller.reportData.length,
                    itemExtent: rowHeight,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final row = controller.reportData[index];
                      return _buildTableRow(
                        index: index,
                        row: row,
                        height: rowHeight,
                        controller: controller,
                        showDate: showDate,
                        showInvoiceNumber: showInvoiceNumber,
                        showTransType: showTransType,
                        showBeneficiary: showBeneficiary,
                        showAccountName: showAccountName,
                        showUserName: showUserName,
                        showBranch: showBranch,
                        showDepartment: showDepartment,
                        showTaxDiscount: showTaxDiscount,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTableHeader({
    required bool showDate,
    required bool showInvoiceNumber,
    required bool showTransType,
    required bool showBeneficiary,
    required bool showAccountName,
    required bool showUserName,
    required bool showBranch,
    required bool showDepartment,
    required bool showTaxDiscount,
  }) {
    return Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade400, width: 1.2),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('م', 50.0),
          if (showDate) _buildHeaderCell('التاريخ', 110.0),
          if (showInvoiceNumber) _buildHeaderCell('رقم الفاتورة', 120.0),
          if (showTransType) _buildHeaderCell('نوع الحركة', 120.0),
          if (showBeneficiary) _buildHeaderCell('المستفيد', 150.0),
          if (showAccountName) _buildHeaderCell('اسم الحساب', 160.0),
          if (showUserName) _buildHeaderCell('المستخدم', 120.0),
          if (showBranch) _buildHeaderCell('الفرع', 120.0),
          if (showDepartment) _buildHeaderCell('القسم', 120.0),
          if (!showTaxDiscount) _buildHeaderCell('القيمة', 130.0),
          if (showTaxDiscount) ...[
            _buildHeaderCell('إجمالي الفاتورة', 130.0),
            _buildHeaderCell('الخصم', 110.0),
            _buildHeaderCell('الضريبة', 110.0),
            _buildHeaderCell('صافي القيمة', 130.0),
            _buildHeaderCell('القيمة النهائية', 150.0),
          ],
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required int index,
    required Map<String, dynamic> row,
    required double height,
    required SalesMovementNewController controller,
    required bool showDate,
    required bool showInvoiceNumber,
    required bool showTransType,
    required bool showBeneficiary,
    required bool showAccountName,
    required bool showUserName,
    required bool showBranch,
    required bool showDepartment,
    required bool showTaxDiscount,
  }) {
    final int displayIndex = index + 1;
    final Color rowColor = index % 2 == 0 ? Colors.white : Colors.grey.shade50;
    final String formattedDate = row['formatted_date'] ?? _formatDate(row['date']?.toString() ?? '');

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          _buildDataCell(displayIndex.toString(), 50.0, bold: true, align: TextAlign.center),
          if (showDate) _buildDataCell(formattedDate, 110.0, align: TextAlign.center),
          if (showInvoiceNumber)
            _buildDataCell(row['transaction_number']?.toString() ?? '', 120.0, align: TextAlign.center, bold: true),
          if (showTransType)
            _buildDataCell(row['transaction_type_name']?.toString() ?? '', 120.0, color: Colors.blueAccent, bold: true),
          if (showBeneficiary)
            _buildDataCell(row['beneficiary_name']?.toString() ?? '', 150.0),
          if (showAccountName)
            _buildDataCell(row['account_name']?.toString() ?? '', 160.0),
          if (showUserName)
            _buildDataCell(row['user_name']?.toString() ?? '', 120.0),
          if (showBranch)
            _buildDataCell(row['branch_name']?.toString() ?? '', 120.0),
          if (showDepartment)
            _buildDataCell(row['department_name']?.toString() ?? '', 120.0),
          if (!showTaxDiscount)
            _buildDataCell(row['net_value_str'] ?? controller.formatCurrency(row['net_value']), 130.0, color: Colors.green, bold: true, align: TextAlign.right),
          if (showTaxDiscount) ...[
            _buildDataCell(row['gross_total_str'] ?? controller.formatCurrency(row['gross_total']), 130.0, align: TextAlign.right),
            _buildDataCell(row['discount_amount_str'] ?? controller.formatCurrency(row['discount_amount']), 110.0, color: Colors.orange, align: TextAlign.right),
            _buildDataCell(row['tax_amount_str'] ?? controller.formatCurrency(row['tax_amount']), 110.0, color: Colors.purple, align: TextAlign.right),
            _buildDataCell(row['net_value_str'] ?? controller.formatCurrency(row['net_value']), 130.0, color: Colors.blue, align: TextAlign.right),
            _buildDataCell(row['final_value_str'] ?? controller.formatCurrency(row['final_value']), 150.0, color: Colors.green, bold: true, align: TextAlign.right),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label, double width) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade300, width: 0.8)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {bool bold = false, Color? color, TextAlign align = TextAlign.center}) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : (align == TextAlign.left ? Alignment.centerLeft : Alignment.center),
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings Bottom Sheet — 9 SwitchListTiles
  // ---------------------------------------------------------------------------
  void _showSettingsSheet(
      BuildContext context, SalesMovementNewController controller) {
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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.tune,
                          color: Colors.blue.shade800, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'إعدادات عرض الجدول',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Toggle 1
                Obx(() => _buildSwitch(
                    'حسب تاريخ الحركة',
                    Icons.calendar_today,
                    controller.showDate.value,
                    (v) => controller.toggleSetting('showDate', v))),
                // Toggle 2
                Obx(() => _buildSwitch(
                    'حسب رقم الفاتورة',
                    Icons.receipt_long,
                    controller.showInvoiceNumber.value,
                    (v) => controller.toggleSetting('showInvoiceNumber', v))),
                // Toggle 3
                Obx(() => _buildSwitch(
                    'حسب اسم الحركة',
                    Icons.swap_horiz,
                    controller.showTransType.value,
                    (v) => controller.toggleSetting('showTransType', v))),
                // Toggle 4
                Obx(() => _buildSwitch(
                    'حسب اسم المستفيد',
                    Icons.person_outline,
                    controller.showBeneficiary.value,
                    (v) => controller.toggleSetting('showBeneficiary', v))),
                // Toggle 5
                Obx(() => _buildSwitch(
                    'حسب اسم الحساب',
                    Icons.account_balance,
                    controller.showAccountName.value,
                    (v) => controller.toggleSetting('showAccountName', v))),
                // Toggle 6
                Obx(() => _buildSwitch(
                    'حسب المستخدم',
                    Icons.person,
                    controller.showUserName.value,
                    (v) => controller.toggleSetting('showUserName', v))),
                // Toggle 7
                Obx(() => _buildSwitch(
                    'حسب الفرع',
                    Icons.store,
                    controller.showBranch.value,
                    (v) => controller.toggleSetting('showBranch', v))),
                // Toggle 8
                Obx(() => _buildSwitch(
                    'حسب القسم',
                    Icons.business,
                    controller.showDepartment.value,
                    (v) => controller.toggleSetting('showDepartment', v))),
                const Divider(height: 16),
                // Toggle 9 — highlighted as special
                Obx(() => _buildSwitch(
                    'إظهار الضريبة والخصم',
                    Icons.percent,
                    controller.showTaxDiscount.value,
                    (v) => controller.toggleSetting('showTaxDiscount', v),
                    highlight: true)),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildSwitch(String title, IconData icon, bool value,
      ValueChanged<bool> onChanged,
      {bool highlight = false}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight:
              (value || highlight) ? FontWeight.bold : FontWeight.normal,
          color: highlight
              ? Colors.purple.shade700
              : (value ? Colors.black87 : Colors.grey.shade600),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: highlight ? Colors.purple.shade700 : Colors.blue.shade800,
      activeTrackColor: highlight ? Colors.purple.shade200 : Colors.blue.shade200,
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.grey.shade200,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.purple.withValues(alpha: 0.1)
              : (value
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            color: highlight
                ? Colors.purple.shade700
                : (value ? Colors.blue.shade700 : Colors.grey),
            size: 20),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
  // ---------------------------------------------------------------------------
  DataColumn _col(String label) {
    return DataColumn(
      label: Center(
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  DataCell _cell(String text,
      {bool bold = false,
      Color? color,
      TextAlign align = TextAlign.center}) {
    return DataCell(
      Center(
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
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

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
      }
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) return DateFormat('yyyy-MM-dd').format(parsed);
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }
}
