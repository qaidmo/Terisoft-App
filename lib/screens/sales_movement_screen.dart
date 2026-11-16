// lib/screens/sales_movement_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/controllers/sales_movement_controller.dart';
class SalesMovementScreen extends StatelessWidget {
  const SalesMovementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SalesMovementController controller = Get.put(SalesMovementController());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('تقرير سجل الحركات'),
        centerTitle: true,
        elevation: 2,
        actions: [
          if (controller.canPrint())
            IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: controller.printReport,
              tooltip: 'طباعة التقرير',
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
                        const SizedBox(height: 12),
                        _buildSummarySection(controller),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (controller.reportData.isEmpty && controller.hasSearched.value) {
                      return const Center(child: Text('لا توجد بيانات لعرضها.'));
                    }
                    if (!controller.hasSearched.value) {
                      return const Center(child: Text('الرجاء تحديد الفلاتر والضغط على عرض.'));
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

  Widget _buildFilterSection(BuildContext context, SalesMovementController controller) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildDatePicker(context, 'من تاريخ:', controller.fromDate)),
                const SizedBox(width: 10),
                Expanded(child: _buildDatePicker(context, 'إلى تاريخ:', controller.toDate)),
              ],
            ),
            const SizedBox(height: 12),
            Obx(() => DropdownButtonFormField<String>(
              initialValue: controller.selectedReportType.value,
              decoration: const InputDecoration(
                labelText: 'نوع الحركة',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              ),
              isExpanded: true,
              items: controller.reportTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['value'],
                  child: Text(type['display']!, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) controller.selectedReportType.value = value;
              },
            )),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Obx(() => DropdownButtonFormField<int?>(
                    initialValue: controller.selectedBranchId.value,
                    decoration: const InputDecoration(
                      labelText: 'الفرع',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    isExpanded: true,
                    items: controller.branchesList.map((branch) {
                      return DropdownMenuItem<int?>(
                        value: branch['branch_id'] as int?,
                        child: Text(branch['branch_name'] as String, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      controller.selectedBranchId.value = value;
                    },
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(() => DropdownButtonFormField<int?>(
                    initialValue: controller.selectedDepartmentId.value,
                    decoration: const InputDecoration(
                      labelText: 'القسم',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    ),
                    isExpanded: true,
                    items: controller.departmentsList.map((dept) {
                      return DropdownMenuItem<int?>(
                        value: dept['department_id'] as int?,
                        child: Text(dept['department_name'] as String, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      controller.selectedDepartmentId.value = value;
                    },
                  )),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: controller.clearFilters,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('مسح الفلاتر'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('عرض التقرير'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: controller.fetchReportData,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(SalesMovementController controller) {
    return Card(
      color: Colors.blue.shade50,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Obx(() {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('عدد الحركات', controller.itemsCount.value.toString()),
              Container(width: 1, height: 40, color: Colors.blue.shade200),
              _summaryItem('الإجمالي الصافي', controller.grandTotal.value.toStringAsFixed(2)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDataTable(BuildContext context, SalesMovementController controller) {
    const double tableWidth = 950.0;
    const double rowHeight = 48.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: controller.reportData.length,
                  itemExtent: rowHeight,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final item = controller.reportData[index];
                    return _buildTableRow(index, item, rowHeight, controller);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
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
          _buildHeaderCell('التاريخ', 105.0),
          _buildHeaderCell('اسم الحركة', 130.0),
          _buildHeaderCell('رقم الحركة', 110.0),
          _buildHeaderCell('المرجع', 100.0),
          _buildHeaderCell('الاسم', 180.0),
          _buildHeaderCell('المبلغ', 125.0),
          _buildHeaderCell('المستخدم', 150.0),
        ],
      ),
    );
  }

  Widget _buildTableRow(int index, Map<String, dynamic> item, double height, SalesMovementController controller) {
    final int displayIndex = index + 1;
    final Color rowColor = (displayIndex % 2 == 0) ? Colors.white : Colors.grey.shade50;
    final bool isClickable = item['source'] == 'sales' || item['source'] == 'receipt';
    final formattedDate = item['formatted_date'] ?? item['date'] ?? 'N/A';
    final netTotalStr = item['net_total_str'] ?? ((item['net_total'] as num?)?.toStringAsFixed(2) ?? '0.00');

    return InkWell(
      onTap: isClickable ? () => controller.navigateToTransactionDetails(item) : null,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 0.8),
          ),
        ),
        child: Row(
          children: [
            _buildDataCell(displayIndex.toString(), 50.0, style: const TextStyle(fontWeight: FontWeight.bold)),
            _buildDataCell(formattedDate, 105.0),
            _buildDataCell(item['display_name'] ?? '', 130.0, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            _buildDataCell(item['transaction_number'] ?? '', 110.0, style: const TextStyle(fontWeight: FontWeight.bold)),
            _buildDataCell(item['reference_number'] ?? '', 100.0, style: const TextStyle(color: Colors.grey)),
            _buildDataCell(item['customer_name'] ?? '', 180.0),
            _buildDataCell(netTotalStr, 125.0, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            _buildDataCell(item['user_name'] ?? 'غير معروف', 150.0),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String title, double width) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade300, width: 0.8)),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, double width, {TextStyle? style}) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade200, width: 0.8)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style ?? const TextStyle(fontSize: 13),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, String label, Rx<DateTime> date) {
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        child: Obx(() => Text(displayFormat.format(date.value), style: const TextStyle(fontSize: 15))),
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: Get.textTheme.titleSmall?.copyWith(color: Colors.blue.shade800, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: Get.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 18)),
      ],
    );
  }
}