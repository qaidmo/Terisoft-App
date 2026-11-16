// lib/screens/item_balances_screen.dart
// شاشة تقرير أرصدة الأصناف — مستقلة تماماً

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'controllers/item_balances_controller.dart';
import '../models/item_balances_models.dart';

class ItemBalancesScreen extends StatelessWidget {
  const ItemBalancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ItemBalancesController controller =
        Get.put(ItemBalancesController());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'أرصدة الأصناف',
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
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'إعدادات عرض الجدول',
            onPressed: () => _showSettingsSheet(context, controller),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
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
                              Icon(Icons.inventory_outlined,
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
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter Section — Date pickers only
  // ---------------------------------------------------------------------------
  Widget _buildFilterSection(
      BuildContext context, ItemBalancesController controller) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
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
  Widget _buildSummaryBar(ItemBalancesController controller) {
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
                _summaryItem('عدد الصفوف',
                    controller.rowCount.value.toString(),
                    Icons.list_alt),
                _divider(),
                _summaryItem('الرصيد',
                    controller.grandBalanceStr.value,
                    Icons.inventory_2_outlined,
                    valueColor: controller.grandBalance.value < 0
                        ? Colors.red
                        : Colors.teal.shade900),
                _divider(),
                _summaryItem('تكلفة الرصيد',
                    controller.grandBalanceCostStr.value,
                    Icons.account_balance_wallet_outlined),
                _divider(),
                _summaryItem('ك مبيعات',
                    controller.grandSalesQtyStr.value,
                    Icons.shopping_cart_outlined),
                _divider(),
                _summaryItem('ك مشتريات',
                    controller.grandPurchaseQtyStr.value,
                    Icons.local_shipping_outlined),
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
  // Continuous Virtualized Table — 28 possible dynamic columns
  // ---------------------------------------------------------------------------
  Widget _buildDataTable(
      BuildContext context, ItemBalancesController controller) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Obx(() {
        final bool inclBranch  = controller.showBranch.value;
        final bool inclDept    = controller.showDepartment.value;
        final bool inclStore   = controller.showStore.value;
        final bool inclExpiry  = controller.showExpiry.value;
        final bool inclBatch   = controller.showBatch.value;

        final double tableWidth = _calculateTableWidth(inclBranch, inclDept, inclStore, inclExpiry, inclBatch);

        return LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  _buildHeader(inclBranch, inclDept, inclStore, inclExpiry, inclBatch),
                  Expanded(
                    child: Obx(() {
                      final data = controller.reportData;
                      return ListView.builder(
                        itemCount: data.length,
                        itemExtent: 44.0,
                        itemBuilder: (context, index) {
                          return _buildRow(data[index], index, inclBranch, inclDept, inclStore, inclExpiry, inclBatch);
                        },
                      );
                    }),
                  ),
                  _buildFooter(controller, inclBranch, inclDept, inclStore, inclExpiry, inclBatch),
                ],
              ),
            ),
          );
        });
      }),
    );
  }

  double _calculateTableWidth(bool inclBranch, bool inclDept, bool inclStore, bool inclExpiry, bool inclBatch) {
    double w = 45.0 + 110.0 + 180.0 + 80.0 + 100.0; // base 515.0
    if (inclBranch) w += 80.0;
    if (inclDept) w += 80.0;
    if (inclStore) w += 210.0; // storeNo 80 + storeName 130
    if (inclExpiry) w += 100.0;
    if (inclBatch) w += 100.0;
    w += 110.0 + 100.0 + 110.0 + 100.0 + 100.0 + 100.0 + 100.0 + 100.0 + 110.0 + 100.0 + 100.0 + 100.0 + 100.0 + 100.0 + 90.0 + 100.0; // 1620.0
    if (inclStore) w += 110.0;
    return w;
  }

  Widget _buildHeader(bool inclBranch, bool inclDept, bool inclStore, bool inclExpiry, bool inclBatch) {
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: Colors.teal.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      ),
      child: Row(
        children: [
          _vHeaderCell('م', width: 45.0),
          _vHeaderCell('رقم الصنف', width: 110.0),
          _vHeaderCell('اسم الصنف', width: 180.0),
          _vHeaderCell('الوحدة', width: 80.0),
          _vHeaderCell('سعر البيع', width: 100.0),
          if (inclBranch) _vHeaderCell('الفرع', width: 80.0),
          if (inclDept) _vHeaderCell('القسم', width: 80.0),
          if (inclStore) _vHeaderCell('رقم المخزن', width: 80.0),
          if (inclStore) _vHeaderCell('اسم المخزن', width: 130.0),
          if (inclExpiry) _vHeaderCell('تاريخ الانتهاء', width: 100.0),
          if (inclBatch) _vHeaderCell('رقم الدفعة', width: 100.0),
          _vHeaderCell('الرصيد', width: 110.0),
          _vHeaderCell('تكلفة الوحدة', width: 100.0),
          _vHeaderCell('تكلفة الرصيد', width: 110.0),
          _vHeaderCell('ك افتتاحي', width: 100.0),
          _vHeaderCell('ك مشتريات', width: 100.0),
          _vHeaderCell('ك مبيعات', width: 100.0),
          _vHeaderCell('ك اخرى', width: 100.0),
          _vHeaderCell('ك اخر المدة', width: 100.0),
          _vHeaderCell('الرصيد بسعر', width: 110.0),
          _vHeaderCell('ك_الوارد', width: 100.0),
          _vHeaderCell('ك_المنصرف', width: 100.0),
          _vHeaderCell('ك شراء', width: 100.0),
          _vHeaderCell('ك البيع', width: 100.0),
          _vHeaderCell('ك مرتجع بيع', width: 100.0),
          _vHeaderCell('بونص', width: 90.0),
          _vHeaderCell('بونص مبيعات', width: 100.0),
          if (inclStore) _vHeaderCell('رصيد الصنف', width: 110.0),
        ],
      ),
    );
  }

  Widget _buildRow(ItemBalancesRow r, int rawIndex, bool inclBranch, bool inclDept, bool inclStore, bool inclExpiry, bool inclBatch) {
    final int index = rawIndex + 1;
    final Color rowBg = index % 2 == 0 ? Colors.white : Colors.grey.shade50;
    final Color balColor = r.balanceQty < 0 ? Colors.red : Colors.teal.shade800;

    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: Row(
        children: [
          _vCell(index.toString(), width: 45.0, bold: true, align: TextAlign.center),
          _vCell(r.itemNo, width: 110.0, bold: true, align: TextAlign.center),
          _vCell(r.itemName, width: 180.0, align: TextAlign.right),
          _vCell(r.itemUnit, width: 80.0, align: TextAlign.center),
          _vCell(r.sellingPriceStr.isNotEmpty ? r.sellingPriceStr : r.sellingPrice.toString(), width: 100.0, align: TextAlign.right),
          if (inclBranch) _vCell(r.branchId, width: 80.0, align: TextAlign.center),
          if (inclDept) _vCell(r.departmentId, width: 80.0, align: TextAlign.center),
          if (inclStore) _vCell(r.storeNo, width: 80.0, align: TextAlign.center),
          if (inclStore) _vCell(r.storeName, width: 130.0, align: TextAlign.right),
          if (inclExpiry) _vCell(r.expiryDate, width: 100.0, align: TextAlign.center),
          if (inclBatch) _vCell(r.batchNumber, width: 100.0, align: TextAlign.center),
          _vCell(r.balanceQtyStr.isNotEmpty ? r.balanceQtyStr : r.balanceQty.toString(), width: 110.0, align: TextAlign.right, color: balColor, bold: true),
          _vCell(r.unitCostStr.isNotEmpty ? r.unitCostStr : r.unitCost.toString(), width: 100.0, align: TextAlign.right),
          _vCell(r.balanceCostStr.isNotEmpty ? r.balanceCostStr : r.balanceCost.toString(), width: 110.0, align: TextAlign.right),
          _vCell(r.openingQtyStr.isNotEmpty ? r.openingQtyStr : r.openingQty.toString(), width: 100.0, align: TextAlign.right),
          _vCell(r.purchaseQtyStr.isNotEmpty ? r.purchaseQtyStr : r.purchaseQty.toString(), width: 100.0, align: TextAlign.right, color: Colors.green.shade700),
          _vCell(r.salesQtyStr.isNotEmpty ? r.salesQtyStr : r.salesQty.toString(), width: 100.0, align: TextAlign.right, color: Colors.orange.shade700),
          _vCell(r.otherQtyStr.isNotEmpty ? r.otherQtyStr : r.otherQty.toString(), width: 100.0, align: TextAlign.right),
          _vCell(r.endingQtyStr.isNotEmpty ? r.endingQtyStr : r.endingQty.toString(), width: 100.0, align: TextAlign.right, bold: true),
          _vCell(r.balanceAtSellingStr.isNotEmpty ? r.balanceAtSellingStr : r.balanceAtSelling.toString(), width: 110.0, align: TextAlign.right),
          _vCell(r.incomingQtyStr.isNotEmpty ? r.incomingQtyStr : r.incomingQty.toString(), width: 100.0, align: TextAlign.right),
          _vCell(r.outgoingQtyStr.isNotEmpty ? r.outgoingQtyStr : r.outgoingQty.toString(), width: 100.0, align: TextAlign.right),
          _vCell(r.buyQtyStr.isNotEmpty ? r.buyQtyStr : r.buyQty.toString(), width: 100.0, align: TextAlign.right),
          _vCell(r.sellQtyStr.isNotEmpty ? r.sellQtyStr : r.sellQty.toString(), width: 100.0, align: TextAlign.right),
          _vCell(r.returnSellQtyStr.isNotEmpty ? r.returnSellQtyStr : r.returnSellQty.toString(), width: 100.0, align: TextAlign.right),
          _vCell(r.bonusQtyStr.isNotEmpty ? r.bonusQtyStr : r.bonusQty.toString(), width: 90.0, align: TextAlign.right),
          _vCell(r.salesBonusQtyStr.isNotEmpty ? r.salesBonusQtyStr : r.salesBonusQty.toString(), width: 100.0, align: TextAlign.right),
          if (inclStore) _vCell(r.itemBalanceStr.isNotEmpty ? r.itemBalanceStr : r.itemBalance.toString(), width: 110.0, align: TextAlign.right, color: balColor, bold: true),
        ],
      ),
    );
  }

  Widget _buildFooter(ItemBalancesController controller, bool inclBranch, bool inclDept, bool inclStore, bool inclExpiry, bool inclBatch) {
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: Colors.teal.shade100,
        border: Border(top: BorderSide(color: Colors.teal.shade300, width: 1.2)),
      ),
      child: Row(
        children: [
          _vCell('المجموع', width: 45.0, bold: true, align: TextAlign.center),
          _vCell('', width: 110.0),
          _vCell('', width: 180.0),
          _vCell('', width: 80.0),
          _vCell('', width: 100.0),
          if (inclBranch) _vCell('', width: 80.0),
          if (inclDept) _vCell('', width: 80.0),
          if (inclStore) _vCell('', width: 80.0),
          if (inclStore) _vCell('', width: 130.0),
          if (inclExpiry) _vCell('', width: 100.0),
          if (inclBatch) _vCell('', width: 100.0),
          _vCell(controller.grandBalanceStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.teal.shade900),
          _vCell('', width: 100.0),
          _vCell(controller.grandBalanceCostStr.value, width: 110.0, bold: true, align: TextAlign.right, color: Colors.teal.shade900),
          _vCell('', width: 100.0),
          _vCell(controller.grandPurchaseQtyStr.value, width: 100.0, bold: true, align: TextAlign.right, color: Colors.green.shade800),
          _vCell(controller.grandSalesQtyStr.value, width: 100.0, bold: true, align: TextAlign.right, color: Colors.orange.shade800),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell('', width: 110.0),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell('', width: 100.0),
          _vCell('', width: 90.0),
          _vCell('', width: 100.0),
          if (inclStore) _vCell('', width: 110.0),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings Bottom Sheet — 2 sections, 9 switches
  // ---------------------------------------------------------------------------
  void _showSettingsSheet(
      BuildContext context, ItemBalancesController controller) {
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
                    'حسب الفرع', Icons.store_outlined,
                    controller.showBranch.value,
                    (v) => controller.toggleSetting('showBranch', v))),
                Obx(() => _buildSwitch(
                    'حسب القسم', Icons.business_outlined,
                    controller.showDepartment.value,
                    (v) => controller.toggleSetting('showDepartment', v))),
                Obx(() => _buildSwitch(
                    'حسب المخزن', Icons.warehouse_outlined,
                    controller.showStore.value,
                    (v) => controller.toggleSetting('showStore', v))),
                Obx(() => _buildSwitch(
                    'حسب تاريخ الانتهاء', Icons.calendar_today_outlined,
                    controller.showExpiry.value,
                    (v) => controller.toggleSetting('showExpiry', v))),
                Obx(() => _buildSwitch(
                    'حسب الدفعة', Icons.batch_prediction_outlined,
                    controller.showBatch.value,
                    (v) => controller.toggleSetting('showBatch', v))),

                const Divider(height: 24),

                // --- القسم 2: فلترة البيانات ---
                _sectionLabel('فلترة البيانات', Colors.orange.shade800),
                Obx(() => _buildSwitch(
                    'استبعاد الصفرية', Icons.filter_alt_outlined,
                    controller.excludeZeros.value,
                    (v) => controller.toggleSetting('excludeZeros', v),
                    highlight: true,
                    highlightColor: Colors.orange.shade800)),
                Obx(() => _buildSwitch(
                    'كميات سالبة فقط', Icons.trending_down_rounded,
                    controller.negativeQtyOnly.value,
                    (v) => controller.toggleSetting('negativeQtyOnly', v),
                    highlight: true,
                    highlightColor: Colors.red.shade700)),
                Obx(() => _buildSwitch(
                    'استبعاد الرصيد السابق', Icons.history_toggle_off_outlined,
                    controller.excludePreviousBalance.value,
                    (v) => controller.toggleSetting('excludePreviousBalance', v),
                    highlight: true,
                    highlightColor: Colors.orange.shade800)),
                Obx(() => _buildSwitch(
                    'الأرصدة الصفرية', Icons.exposure_zero_outlined,
                    controller.zeroBalancesOnly.value,
                    (v) => controller.toggleSetting('zeroBalancesOnly', v),
                    highlight: true,
                    highlightColor: Colors.orange.shade800)),
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
    Color highlightColor = Colors.teal,
  }) {
    final Color activeColor =
        highlight ? highlightColor : Colors.teal.shade800;
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
      activeThumbColor:   activeColor,
      activeTrackColor:   activeColor.withValues(alpha: 0.4),
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
        child:
            Icon(icon, color: value ? activeColor : Colors.grey, size: 20),
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
