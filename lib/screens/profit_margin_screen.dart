// lib/screens/profit_margin_screen.dart
// شاشة تقرير هامش الربح — مستقلة تماماً

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'controllers/profit_margin_controller.dart';

class ProfitMarginScreen extends StatefulWidget {
  const ProfitMarginScreen({super.key});

  @override
  State<ProfitMarginScreen> createState() => _ProfitMarginScreenState();
}

class _ProfitMarginScreenState extends State<ProfitMarginScreen> {
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();
  final ScrollController _footerScrollController = ScrollController();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _headerScrollController.addListener(() => _syncScroll(_headerScrollController));
    _bodyScrollController.addListener(() => _syncScroll(_bodyScrollController));
    _footerScrollController.addListener(() => _syncScroll(_footerScrollController));
  }

  void _syncScroll(ScrollController source) {
    if (_isSyncing) return;
    _isSyncing = true;
    final offset = source.offset;
    if (source != _headerScrollController && _headerScrollController.hasClients && _headerScrollController.offset != offset) {
      _headerScrollController.jumpTo(offset);
    }
    if (source != _bodyScrollController && _bodyScrollController.hasClients && _bodyScrollController.offset != offset) {
      _bodyScrollController.jumpTo(offset);
    }
    if (source != _footerScrollController && _footerScrollController.hasClients && _footerScrollController.offset != offset) {
      _footerScrollController.jumpTo(offset);
    }
    _isSyncing = false;
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    _footerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProfitMarginController controller =
        Get.put(ProfitMarginController());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'هامش الربح',
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
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up_rounded,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
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
  // Filter Section — Date pickers only (Branch/Department read from session)
  // ---------------------------------------------------------------------------
  Widget _buildFilterSection(
      BuildContext context, ProfitMarginController controller) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // صف التواريخ
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
  Widget _buildSummaryBar(ProfitMarginController controller) {
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
                _summaryItem('عدد الصفوف',
                    controller.rowCount.value.toString(), Icons.list_alt),
                _divider(),
                _summaryItem(
                    'قيمة المبيعات',
                    controller.grandSalesValueStr.value,
                    Icons.receipt_long_outlined),
                _divider(),
                _summaryItem(
                    'تكلفة المبيعات',
                    controller.grandSalesCostStr.value,
                    Icons.money_off_outlined),
                _divider(),
                _summaryItem(
                    'هامش الربح',
                    controller.grandMarginStr.value,
                    Icons.trending_up_rounded,
                    valueColor: controller.grandMargin.value >= 0
                        ? Colors.green.shade700
                        : Colors.red),
                _divider(),
                _summaryItem(
                    'كمية الرصيد',
                    controller.grandBalanceQtyStr.value,
                    Icons.inventory_2_outlined),
                _divider(),
                _summaryItem(
                    'تكلفة الرصيد',
                    controller.grandBalanceCostStr.value,
                    Icons.account_balance_wallet_outlined),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _divider() =>
      Container(width: 1, height: 40, color: Colors.blue.shade200,
          margin: const EdgeInsets.symmetric(horizontal: 10));

  Widget _summaryItem(String label, String value, IconData icon,
      {Color? valueColor}) {
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
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.blue.shade900)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Continuous Virtualized Table — Dynamic columns
  // ---------------------------------------------------------------------------
  Widget _buildDataTable(
      BuildContext context, ProfitMarginController controller) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Obx(() {
        final String currentGroupBy  = controller.groupBy;
        final bool showUnit          = currentGroupBy == 'item';
        final bool showBranch        = controller.showBranch.value;
        final bool showDepartment    = controller.showDepartment.value;
        final bool showBatch         = controller.showBatch.value;
        final bool showCostCenter    = controller.showCostCenter.value;

        const double colIndex      = 50.0;
        const double colKey        = 120.0;
        const double colName       = 220.0;
        const double colUnit       = 80.0;
        const double colBranch     = 80.0;
        const double colDept       = 80.0;
        const double colBatch      = 100.0;
        const double colCostCenter = 140.0;
        const double colSalesQty   = 110.0;
        const double colSalesVal   = 120.0;
        const double colSalesCost  = 120.0;
        const double colMargin     = 120.0;
        const double colProfitPct  = 100.0;
        const double colBalQty     = 110.0;
        const double colBalCost    = 120.0;
        const double colBalSalesPct= 120.0;

        double totalTableWidth = colIndex + colKey + colName +
            colSalesQty + colSalesVal + colSalesCost + colMargin +
            colProfitPct + colBalQty + colBalCost + colBalSalesPct;

        if (showUnit)       totalTableWidth += colUnit;
        if (showBranch)     totalTableWidth += colBranch;
        if (showDepartment) totalTableWidth += colDept;
        if (showBatch)      totalTableWidth += colBatch;
        if (showCostCenter) totalTableWidth += colCostCenter;

        final rows = controller.reportData;

        return Column(
          children: [
            // PINNED HEADER
            Container(
              color: Colors.blue.shade100,
              child: SingleChildScrollView(
                controller: _headerScrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Container(
                  width: totalTableWidth,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.blue.shade200, width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      _vHeaderCell('م', colIndex),
                      _vHeaderCell(controller.primaryKeyLabel, colKey),
                      _vHeaderCell(controller.primaryNameLabel, colName),
                      if (showUnit)       _vHeaderCell('الوحدة', colUnit),
                      if (showBranch)     _vHeaderCell('الفرع', colBranch),
                      if (showDepartment) _vHeaderCell('القسم', colDept),
                      if (showBatch)      _vHeaderCell('التشغيلة', colBatch),
                      if (showCostCenter) _vHeaderCell('مركز التكلفة', colCostCenter),
                      _vHeaderCell('كمية المبيعات', colSalesQty),
                      _vHeaderCell('قيمة المبيعات', colSalesVal),
                      _vHeaderCell('تكلفة المبيعات', colSalesCost),
                      _vHeaderCell('هامش الربح', colMargin),
                      _vHeaderCell('نسبة الربح %', colProfitPct),
                      _vHeaderCell('كمية الرصيد', colBalQty),
                      _vHeaderCell('تكلفة الرصيد', colBalCost),
                      _vHeaderCell('نسبة مبيعات الرصيد %', colBalSalesPct),
                    ],
                  ),
                ),
              ),
            ),

            // VIRTUALIZED BODY
            Expanded(
              child: SingleChildScrollView(
                controller: _bodyScrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: totalTableWidth,
                  child: ListView.builder(
                    itemCount: rows.length,
                    itemExtent: 44.0,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final isEven = index % 2 == 0;
                      final rowColor = isEven ? Colors.white : Colors.grey.shade50;
                      final marginColor =
                          row.margin >= 0 ? Colors.green.shade700 : Colors.red;

                      return Container(
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: rowColor,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200, width: 0.8),
                          ),
                        ),
                        child: Row(
                          children: [
                            _vCell('${index + 1}', colIndex, bold: true, align: TextAlign.center),
                            _vCell(row.primaryKey, colKey, bold: true, align: TextAlign.center),
                            _vCell(row.primaryName, colName, align: TextAlign.center),
                            if (showUnit)       _vCell(row.itemUnit, colUnit, align: TextAlign.center),
                            if (showBranch)     _vCell(row.branchId, colBranch, align: TextAlign.center),
                            if (showDepartment) _vCell(row.departmentId, colDept, align: TextAlign.center),
                            if (showBatch)      _vCell(row.batchNumber, colBatch, align: TextAlign.center),
                            if (showCostCenter) _vCell(row.costCenterName, colCostCenter, align: TextAlign.center),
                            _vCell(row.salesQtyStr, colSalesQty, align: TextAlign.center),
                            _vCell(row.salesValueStr, colSalesVal, color: Colors.blueAccent, align: TextAlign.center),
                            _vCell(row.salesCostStr, colSalesCost, align: TextAlign.center),
                            _vCell(row.marginStr, colMargin, color: marginColor, bold: true, align: TextAlign.center),
                            _vCell(row.profitPctStr, colProfitPct, color: marginColor, align: TextAlign.center),
                            _vCell(row.balanceQtyStr, colBalQty, align: TextAlign.center),
                            _vCell(row.balanceCostStr, colBalCost, align: TextAlign.center),
                            _vCell(row.balanceSalesPctStr, colBalSalesPct, align: TextAlign.center),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // PINNED FOOTER (TOTALS)
            Container(
              color: Colors.blue.shade50,
              child: SingleChildScrollView(
                controller: _footerScrollController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Container(
                  width: totalTableWidth,
                  height: 46,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.blue.shade200, width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      _vCell('المجموع', colIndex, bold: true, align: TextAlign.center, color: Colors.blue.shade900),
                      _vCell('', colKey),
                      _vCell('', colName),
                      if (showUnit)       _vCell('', colUnit),
                      if (showBranch)     _vCell('', colBranch),
                      if (showDepartment) _vCell('', colDept),
                      if (showBatch)      _vCell('', colBatch),
                      if (showCostCenter) _vCell('', colCostCenter),
                      _vCell(controller.grandSalesQtyStr.value, colSalesQty, bold: true, align: TextAlign.center, color: Colors.blue.shade900),
                      _vCell(controller.grandSalesValueStr.value, colSalesVal, bold: true, align: TextAlign.center, color: Colors.blueAccent),
                      _vCell(controller.grandSalesCostStr.value, colSalesCost, bold: true, align: TextAlign.center, color: Colors.blue.shade900),
                      _vCell(controller.grandMarginStr.value, colMargin, bold: true, align: TextAlign.center,
                          color: controller.grandMargin.value >= 0 ? Colors.green.shade700 : Colors.red),
                      _vCell('', colProfitPct),
                      _vCell(controller.grandBalanceQtyStr.value, colBalQty, bold: true, align: TextAlign.center, color: Colors.blue.shade900),
                      _vCell(controller.grandBalanceCostStr.value, colBalCost, bold: true, align: TextAlign.center, color: Colors.blue.shade900),
                      _vCell('', colBalSalesPct),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings Bottom Sheet — 7 Switches
  // ---------------------------------------------------------------------------
  void _showSettingsSheet(
      BuildContext context, ProfitMarginController controller) {
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
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.tune,
                          color: Colors.blue.shade800, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'إعدادات عرض التقرير',
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

                // --- القسم 1: أعمدة اختيارية ---
                _sectionLabel('عرض الأعمدة الإضافية', Colors.blue.shade800),
                Obx(() => _buildSwitch('الفرع',        Icons.store,
                    controller.showBranch.value,
                    (v) => controller.toggleSetting('showBranch', v))),
                Obx(() => _buildSwitch('القسم',        Icons.business,
                    controller.showDepartment.value,
                    (v) => controller.toggleSetting('showDepartment', v))),
                Obx(() => _buildSwitch('التشغيلة',     Icons.batch_prediction_outlined,
                    controller.showBatch.value,
                    (v) => controller.toggleSetting('showBatch', v))),
                Obx(() => _buildSwitch('مركز التكلفة', Icons.account_tree_outlined,
                    controller.showCostCenter.value,
                    (v) => controller.toggleSetting('showCostCenter', v))),

                const Divider(height: 24),

                // --- القسم 2: التجميع الحصري ---
                _sectionLabel('تجميع البيانات حسب', Colors.purple.shade700),
                Obx(() => _buildSwitch(
                    'مجموعة الأصناف', Icons.category_outlined,
                    controller.groupByItemGroup.value,
                    (v) => controller.toggleSetting('groupByItemGroup', v),
                    highlight: true, highlightColor: Colors.purple.shade700)),
                Obx(() => _buildSwitch(
                    'المستخدم', Icons.person_outline,
                    controller.groupByUser.value,
                    (v) => controller.toggleSetting('groupByUser', v),
                    highlight: true, highlightColor: Colors.purple.shade700)),

                const Divider(height: 24),

                // --- القسم 3: فلترة متقدمة ---
                _sectionLabel('فلترة متقدمة', Colors.orange.shade800),
                Obx(() => _buildSwitch(
                    'الهامش السالب فقط', Icons.trending_down_rounded,
                    controller.negativeMarginOnly.value,
                    (v) => controller.toggleSetting('negativeMarginOnly', v),
                    highlight: true, highlightColor: Colors.orange.shade800)),
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
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.5)),
    );
  }

  Widget _buildSwitch(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    bool highlight = false,
    Color highlightColor = Colors.blue,
  }) {
    final Color activeColor = highlight ? highlightColor : Colors.blue.shade800;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: value ? FontWeight.bold : FontWeight.normal,
          color: highlight
              ? highlightColor
              : (value ? Colors.black87 : Colors.grey.shade600),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor:  activeColor,
      activeTrackColor:  activeColor.withValues(alpha: 0.4),
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.grey.shade200,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: value
              ? activeColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            color: value ? activeColor : Colors.grey, size: 20),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Widgets
  // ---------------------------------------------------------------------------
  Widget _vHeaderCell(String label, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _vCell(
    String text,
    double width, {
    bool bold = false,
    Color? color,
    TextAlign align = TextAlign.center,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : align == TextAlign.left
              ? Alignment.centerLeft
              : Alignment.center,
      child: Text(
        text,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black87,
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
