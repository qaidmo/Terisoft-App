import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../models/account_balances_models.dart';
import 'controllers/account_balances_controller.dart';

class AccountBalancesScreen extends StatelessWidget {
  const AccountBalancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AccountBalancesController controller =
        Get.put(AccountBalancesController());
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('أرصدة الحسابات'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'إعدادات عرض التقرير',
            onPressed: () => _showSettingsSheet(context, controller),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxFiltersHeight =
              (constraints.maxHeight - 200).clamp(0.0, double.infinity);
          return Padding(
            padding: EdgeInsets.only(
              left: 12.0,
              right: 12.0,
              top: 12.0,
              bottom: MediaQuery.of(context).padding.bottom + 12.0,
            ),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxFiltersHeight),
                  child: SingleChildScrollView(
                    child: _buildFilterSection(context, controller),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildResultsSection(controller),
                ),
                Obx(() {
                  final hasData = controller.rows.isNotEmpty ||
                      controller.profitMarginRows.isNotEmpty;
                  if (!hasData) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildActionButtons(controller),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // قسم الفلاتر
  // =========================================================================
  Widget _buildFilterSection(
      BuildContext context, AccountBalancesController controller) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // صف التاريخ
            _buildDateRow(context, controller),
            const SizedBox(height: 12),
            // صف الفرع + العملة
            _buildBranchAndCurrencyRow(context, controller),
            const SizedBox(height: 12),
            // أزرار وضع التجميع
            _buildGroupingModeSelector(controller),
            // خانة اختيار: هامش أرباح مراكز التكلفة
            _buildProfitMarginCheckbox(controller),
            const SizedBox(height: 16),
            // زر عرض التقرير
            Obx(() => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: controller.isLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ))
                        : const Icon(Icons.display_settings_outlined),
                    label: Text(
                        controller.isLoading.value ? 'جاري التحميل...' : 'عرض التقرير'),
                    onPressed:
                        controller.isLoading.value ? null : controller.fetchReport,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow(
      BuildContext context, AccountBalancesController controller) {
    return Obx(() => Row(
          children: [
            Expanded(
                child: _buildDateField(context, 'من تاريخ',
                    controller.fromDate.value, (d) => controller.fromDate.value = d)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildDateField(context, 'إلى تاريخ',
                    controller.toDate.value, (d) => controller.toDate.value = d)),
          ],
        ));
  }

  Widget _buildDateField(BuildContext context, String label,
      DateTime initialDate, Function(DateTime) onDateChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onDateChanged(picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller:
              TextEditingController(text: DateFormat('yyyy-MM-dd').format(initialDate)),
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildBranchAndCurrencyRow(
      BuildContext context, AccountBalancesController controller) {
    return Obx(() => Row(
          children: [
            // --- Branch Dropdown ---
            Expanded(
              child: DropdownButtonFormField<String>(
                value: controller.selectedBranch.value?['branch_id']?.toString(),
                hint: const Text('الفرع'),
                decoration: InputDecoration(
                  labelText: 'الفرع',
                  prefixIcon: const Icon(Icons.account_tree_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                isExpanded: true,
                items: controller.allBranches.map((branch) {
                  return DropdownMenuItem<String>(
                    value: branch['branch_id']?.toString() ?? '',
                    child: Text(
                      branch['branch_name']?.toString() ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: controller.userState.isAdmin
                    ? (String? newId) {
                        final match = controller.allBranches.firstWhereOrNull(
                            (b) => b['branch_id']?.toString() == newId);
                        controller.onBranchSelected(match);
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // --- Currency: Static "بالعملة المحلية" label ---
            Expanded(
              child: TextFormField(
                initialValue: 'بالعملة المحلية',
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'العملة',
                  prefixIcon: const Icon(Icons.monetization_on_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ),
          ],
        ));
  }

  Widget _buildGroupingModeSelector(AccountBalancesController controller) {
    return Obx(() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6, right: 4),
              child: Text('وضع التجميع:',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: AccountBalancesController.groupingModes.map((mode) {
                final isSelected = controller.selectedMode.value == mode['key'];
                return ChoiceChip(
                  label: Text(
                    mode['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color.fromARGB(255, 1, 90, 163),
                  backgroundColor: Colors.grey.shade100,
                  onSelected: (_) => controller.onModeChanged(mode['key']),
                );
              }).toList(),
            ),
          ],
        ));
  }

  // =========================================================================
  // قسم النتائج - Continuous Virtualized Table (13 أعمدة)
  // =========================================================================
  Widget _buildResultsSection(AccountBalancesController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.rows.isEmpty && controller.profitMarginRows.isEmpty) {
        return const SizedBox.shrink();
      }

      // --- هامش الربح: جدول بديل 9 أعمدة ---
      if (controller.showProfitMargin.value &&
          controller.selectedMode.value == 'byCostCenter' &&
          controller.profitMarginRows.isNotEmpty) {
        return _buildProfitMarginTable(controller);
      }

      if (controller.rows.isEmpty) {
        return const SizedBox.shrink();
      }

      final nf = NumberFormat('#,##0.00', 'en_US');
      const double totalWidth = 1390.0;

      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              child: Column(
                children: [
                  // Pinned Header
                  _buildHeaderRow(),
                  // Virtualized List
                  Expanded(
                    child: ListView.builder(
                      itemCount: controller.rows.length,
                      itemExtent: 44.0,
                      itemBuilder: (context, index) {
                        final row = controller.rows[index];
                        final isEven = index % 2 == 0;
                        return Container(
                          height: 44.0,
                          color: isEven ? Colors.white : Colors.grey.shade50,
                          child: Row(
                            children: [
                              _buildCell('${index + 1}', 45.0, isNumeric: false),
                              _buildCell(row.col1, 110.0, isNumeric: false),
                              _buildCell(row.col2, 180.0, isNumeric: false),
                              _buildCell(row.openingDebitStr, 105.0),
                              _buildCell(row.openingCreditStr, 105.0),
                              _buildCell(row.periodDebitStr, 105.0),
                              _buildCell(row.periodCreditStr, 105.0),
                              _buildCell(row.totalDebitStr, 105.0),
                              _buildCell(row.totalCreditStr, 105.0),
                              _buildCell(row.balanceDebitStr, 105.0),
                              _buildCell(row.balanceCreditStr, 105.0),
                              _buildCell(
                                row.netBalanceStr,
                                110.0,
                                textColor: row.netBalance >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                isBold: true,
                              ),
                              _buildCell(row.valueStr, 105.0),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Pinned Totals Footer
                  _buildTotalsFooterRow(controller, nf),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildCell(
    String text,
    double width, {
    bool isHeader = false,
    bool isTotals = false,
    bool isNumeric = true,
    Color? textColor,
    bool isBold = false,
  }) {
    TextStyle style;
    if (isHeader) {
      style = const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Color.fromARGB(255, 1, 90, 163),
      );
    } else if (isTotals) {
      style = TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
        color: textColor ?? Colors.black87,
      );
    } else {
      style = TextStyle(
        fontSize: 11,
        color: textColor ?? Colors.black87,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      );
    }

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: isNumeric ? Alignment.centerLeft : Alignment.centerRight,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      height: 44.0,
      color: const Color.fromARGB(255, 1, 90, 163).withValues(alpha: 0.1),
      child: Row(
        children: [
          _buildCell('م', 45.0, isHeader: true, isNumeric: false),
          _buildCell('رقم الحساب', 110.0, isHeader: true, isNumeric: false),
          _buildCell('اسم الحساب', 180.0, isHeader: true, isNumeric: false),
          _buildCell('افتتاحي مدين', 105.0, isHeader: true),
          _buildCell('افتتاحي دائن', 105.0, isHeader: true),
          _buildCell('الفترة مدين', 105.0, isHeader: true),
          _buildCell('الفترة دائن', 105.0, isHeader: true),
          _buildCell('إجمالي مدين', 105.0, isHeader: true),
          _buildCell('إجمالي دائن', 105.0, isHeader: true),
          _buildCell('الرصيد مدين', 105.0, isHeader: true),
          _buildCell('الرصيد دائن', 105.0, isHeader: true),
          _buildCell('الرصيد', 110.0, isHeader: true),
          _buildCell('القيمة', 105.0, isHeader: true),
        ],
      ),
    );
  }

  Widget _buildTotalsFooterRow(AccountBalancesController c, NumberFormat nf) {
    return Container(
      height: 44.0,
      color: const Color.fromARGB(255, 1, 90, 163).withValues(alpha: 0.12),
      child: Row(
        children: [
          _buildCell('المجموع', 45.0,
              isTotals: true,
              isNumeric: false,
              textColor: const Color.fromARGB(255, 1, 90, 163)),
          _buildCell('', 110.0, isTotals: true, isNumeric: false),
          _buildCell('', 180.0, isTotals: true, isNumeric: false),
          _buildCell(nf.format(c.grandOpeningDebit.value), 105.0, isTotals: true),
          _buildCell(nf.format(c.grandOpeningCredit.value), 105.0, isTotals: true),
          _buildCell(nf.format(c.grandPeriodDebit.value), 105.0, isTotals: true),
          _buildCell(nf.format(c.grandPeriodCredit.value), 105.0, isTotals: true),
          _buildCell(nf.format(c.grandTotalDebit.value), 105.0, isTotals: true),
          _buildCell(nf.format(c.grandTotalCredit.value), 105.0, isTotals: true),
          _buildCell(nf.format(c.grandBalanceDebit.value), 105.0, isTotals: true),
          _buildCell(nf.format(c.grandBalanceCredit.value), 105.0, isTotals: true),
          _buildCell(
            nf.format(c.grandNetBalance.value),
            110.0,
            isTotals: true,
            textColor: c.grandNetBalance.value >= 0
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
          _buildCell(nf.format(c.grandValue.value), 105.0, isTotals: true),
        ],
      ),
    );
  }

  // =========================================================================
  // خانة الاختيار: هامش أرباح مراكز التكلفة
  // =========================================================================
  Widget _buildProfitMarginCheckbox(AccountBalancesController controller) {
    return Obx(() {
      final isCostCenter = controller.selectedMode.value == 'byCostCenter';
      return CheckboxListTile(
        value: controller.showProfitMargin.value,
        onChanged: isCostCenter ? controller.onProfitMarginToggled : null,
        title: Text(
          'هامش أرباح مراكز التكلفة',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isCostCenter ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
        subtitle: isCostCenter
            ? null
            : Text(
                'متاح فقط عند التجميع بمراكز التكلفة',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        activeColor: const Color.fromARGB(255, 1, 90, 163),
      );
    });
  }

  // =========================================================================
  // جدول هامش الأرباح (8 أعمدة بيانات + عمود التسلسل = 9 أعمدة)
  // =========================================================================
  Widget _buildProfitMarginTable(AccountBalancesController controller) {
    final nf = NumberFormat('#,##0.00', 'en_US');
    final pf = NumberFormat('#,##0.00', 'en_US');
    final c  = controller;
    final rows = c.profitMarginRows;
    const double totalWidth = 975.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Column(
              children: [
                // Pinned Header
                Container(
                  height: 44.0,
                  color: const Color.fromARGB(255, 1, 90, 163).withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      _buildCell('م', 45.0, isHeader: true, isNumeric: false),
                      _buildCell('رقم المركز', 100.0, isHeader: true, isNumeric: false),
                      _buildCell('اسم القسم', 160.0, isHeader: true, isNumeric: false),
                      _buildCell('صافي المنصرف مخزنياً', 120.0, isHeader: true),
                      _buildCell('المبيعات', 110.0, isHeader: true),
                      _buildCell('المردودات', 100.0, isHeader: true),
                      _buildCell('صافي المبيعات', 110.0, isHeader: true),
                      _buildCell('صافي الربح', 110.0, isHeader: true),
                      _buildCell('نسبة الربح %', 120.0, isHeader: true),
                    ],
                  ),
                ),
                // Virtualized List
                Expanded(
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemExtent: 44.0,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      final isEven = i % 2 == 0;
                      return Container(
                        height: 44.0,
                        color: isEven ? Colors.white : Colors.grey.shade50,
                        child: Row(
                          children: [
                            _buildCell('${i + 1}', 45.0, isNumeric: false),
                            _buildCell(row.costCenterId, 100.0, isNumeric: false),
                            _buildCell(row.costCenterName, 160.0, isNumeric: false),
                            _buildCell(nf.format(row.netCogs), 120.0),
                            _buildCell(nf.format(row.grossSales), 110.0),
                            _buildCell(nf.format(row.returns), 100.0),
                            _buildCell(nf.format(row.netSales), 110.0),
                            _buildCell(
                              nf.format(row.netProfit),
                              110.0,
                              textColor: row.netProfit >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              isBold: true,
                            ),
                            _buildCell(
                              '${pf.format(row.profitPct)}%',
                              120.0,
                              textColor: row.profitPct >= 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              isBold: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Pinned Totals Footer
                Container(
                  height: 44.0,
                  color: const Color.fromARGB(255, 1, 90, 163).withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      _buildCell('المجموع', 45.0,
                          isTotals: true,
                          isNumeric: false,
                          textColor: const Color.fromARGB(255, 1, 90, 163)),
                      _buildCell('', 100.0, isTotals: true, isNumeric: false),
                      _buildCell('', 160.0, isTotals: true, isNumeric: false),
                      _buildCell(nf.format(c.pmGrandNetCogs.value), 120.0, isTotals: true),
                      _buildCell(nf.format(c.pmGrandGrossSales.value), 110.0, isTotals: true),
                      _buildCell(nf.format(c.pmGrandReturns.value), 100.0, isTotals: true),
                      _buildCell(nf.format(c.pmGrandNetSales.value), 110.0, isTotals: true),
                      _buildCell(
                        nf.format(c.pmGrandNetProfit.value),
                        110.0,
                        isTotals: true,
                        textColor: c.pmGrandNetProfit.value >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                      _buildCell(
                        c.pmGrandNetCogs.value == 0
                            ? '0.00%'
                            : '${pf.format(c.pmGrandNetProfit.value / c.pmGrandNetCogs.value * 100)}%',
                        120.0,
                        isTotals: true,
                        textColor: c.pmGrandNetProfit.value >= 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // أزرار الإجراءات
  // =========================================================================
  Widget _buildActionButtons(AccountBalancesController controller) {

    return Obx(() {
      final hasData = controller.rows.isNotEmpty ||
          controller.profitMarginRows.isNotEmpty;
      if (!hasData) return const SizedBox.shrink();

      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('طباعة PDF'),
              onPressed: controller.printReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 1, 90, 163),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('مسح'),
              onPressed: controller.clearForm,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      );
    });
  }

  // =========================================================================
  // Settings Bottom Sheet
  // =========================================================================
  void _showSettingsSheet(
      BuildContext context, AccountBalancesController controller) {
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
                          color: const Color.fromARGB(255, 1, 90, 163).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.tune,
                          color: Color.fromARGB(255, 1, 90, 163), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'إعدادات عرض التقرير',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 1, 90, 163)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // --- القسم: فلترة وعرض البيانات ---
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Text(
                    'فلترة وعرض البيانات',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                Obx(() => _buildSwitch(
                    'استبعاد الأرصدة الصفرية', Icons.filter_alt_outlined,
                    controller.excludeZero.value,
                    (v) => controller.toggleSetting('excludeZero', v),
                    highlight: true,
                    highlightColor: Colors.orange)),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildSwitch(
      String title, IconData icon, bool value, Function(bool) onChanged,
      {bool highlight = false, Color? highlightColor}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: value
            ? (highlightColor?.withValues(alpha: 0.05) ?? Colors.blue.shade50)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value
              ? (highlightColor?.withValues(alpha: 0.3) ?? Colors.blue.shade200)
              : Colors.transparent,
        ),
      ),
      child: SwitchListTile(
        title: Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: value ? FontWeight.bold : FontWeight.normal,
                color: value
                    ? (highlightColor ?? const Color.fromARGB(255, 1, 90, 163))
                    : Colors.black87)),
        secondary: Icon(icon,
            size: 20,
            color: value
                ? (highlightColor ?? const Color.fromARGB(255, 1, 90, 163))
                : Colors.grey),
        value: value,
        onChanged: onChanged,
        activeColor: highlightColor ?? const Color.fromARGB(255, 1, 90, 163),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
    );
  }
}
