import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/controllers/cost_center_report_controller.dart';
import 'package:untitled4/models/cost_center_transaction.dart';
import 'package:untitled4/utils/number_to_words_converter.dart';

class CostCenterReportScreen extends StatelessWidget {
  const CostCenterReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CostCenterReportController controller = Get.put(CostCenterReportController());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('تقرير مركز التكلفة'),
      ),
      bottomNavigationBar: Obx(() {
        if (controller.transactions.isEmpty) {
          return const SizedBox.shrink();
        }
        return BottomAppBar(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ElevatedButton.icon(
              onPressed: controller.printReport,
              icon: const Icon(Icons.print, size: 24),
              label: const Text('طباعة التقرير'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxFiltersHeight =
              (constraints.maxHeight - 200).clamp(0.0, double.infinity);
          return Padding(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: MediaQuery.of(context).padding.bottom + 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxFiltersHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCostCenterSelector(context, controller),
                        const SizedBox(height: 12),
                        _buildDateFilter(context, controller),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.bar_chart),
                          label: const Text('مشاهدة التفاصيل'),
                          onPressed: controller.fetchReportData,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (controller.transactions.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                              'الرجاء اختيار مركز تكلفة وتحديد الفترة ثم الضغط على "مشاهدة التفاصيل".'),
                        ),
                      );
                    }
                    return _buildDetailsTable(controller);
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // الويدجتات المساعدة تبقى كما هي
  Widget _buildCostCenterSelector(BuildContext context, CostCenterReportController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('مركز التكلفة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _showSearchDialog(context, controller),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.business_center_outlined, color: Colors.teal, size: 20),
                Obx(() => Text(
                  controller.selectedCostCenter.value?.centerName ?? 'اختر مركز تكلفة',
                  style: const TextStyle(fontSize: 15),
                )),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateFilter(BuildContext context, CostCenterReportController controller) {
    return Row(
      children: [
        Expanded(
          child: _buildDatePicker(
            context: context,
            label: 'من تاريخ:',
            date: controller.startDate,
            onTap: () => controller.selectStartDate(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildDatePicker(
            context: context,
            label: 'إلى تاريخ:',
            date: controller.endDate,
            onTap: () => controller.selectEndDate(context),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(
      {required BuildContext context, required String label, required Rxn<DateTime> date, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.calendar_month_outlined, color: Colors.teal, size: 20),
                Obx(() => Text(
                  date.value != null ? DateFormat('yyyy-MM-dd').format(date.value!) : 'اختر تاريخ',
                  style: const TextStyle(fontSize: 15),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsTable(CostCenterReportController controller) {
    const boldStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    final lastTransaction = controller.transactions.last;
    final finalBalance = lastTransaction.balance;
    final balanceType = finalBalance >= 0 ? "مدين" : "دائن";
    final amountInWords = convertNumberToWordsArabic(finalBalance.abs());
    const double totalWidth = 1075.0;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade400, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              // Pinned Header
              Container(
                height: 48.0,
                color: Colors.teal.shade700,
                child: Row(
                  children: [
                    _buildCell('مدين', 95.0, isHeader: true),
                    _buildCell('دائن', 95.0, isHeader: true),
                    _buildCell('الرصيد', 105.0, isHeader: true),
                    _buildCell('التاريخ', 100.0, isHeader: true, isNumeric: false),
                    _buildCell('نوع الحركة', 110.0, isHeader: true, isNumeric: false),
                    _buildCell('رقم الحركة', 100.0, isHeader: true, isNumeric: false),
                    _buildCell('البيان', 180.0, isHeader: true, isNumeric: false),
                    _buildCell('رقم الحساب', 110.0, isHeader: true, isNumeric: false),
                    _buildCell('اسم الحساب', 180.0, isHeader: true, isNumeric: false),
                  ],
                ),
              ),
              // Virtualized Rows
              Expanded(
                child: ListView.builder(
                  itemCount: controller.transactions.length,
                  itemExtent: 44.0,
                  itemBuilder: (context, index) {
                    final tx = controller.transactions[index];
                    final isEven = index % 2 == 0;
                    return Container(
                      height: 44.0,
                      color: isEven ? Colors.white : Colors.teal.shade50,
                      child: Row(
                        children: [
                          _buildCell(tx.debitStr, 95.0, textColor: Colors.green),
                          _buildCell(tx.creditStr, 95.0, textColor: Colors.red),
                          _buildCell(tx.balanceStr, 105.0, isBold: true),
                          _buildCell(tx.transactionDate, 100.0, isNumeric: false),
                          _buildCell(tx.transactionType, 110.0, isNumeric: false),
                          _buildCell(tx.transactionRef, 100.0, isNumeric: false),
                          _buildCell(tx.description, 180.0, isNumeric: false),
                          _buildCell(tx.accountNumber, 110.0, isNumeric: false),
                          _buildCell(tx.accountName, 180.0, isNumeric: false),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Pinned Footer
              Container(
                height: 44.0,
                color: Colors.amber.shade100,
                child: Row(
                  children: [
                    _buildCell('', 95.0),
                    _buildCell('', 95.0),
                    _buildCell(finalBalance.toStringAsFixed(2), 105.0, isBold: true),
                    _buildCell(balanceType, 100.0, isBold: true, isNumeric: false),
                    _buildCell(amountInWords, 680.0, isBold: true, isNumeric: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
    String text,
    double width, {
    bool isHeader = false,
    bool isNumeric = true,
    Color? textColor,
    bool isBold = false,
  }) {
    TextStyle style;
    if (isHeader) {
      style = const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontSize: 13,
      );
    } else {
      style = TextStyle(
        fontSize: 12,
        color: textColor ?? Colors.black87,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      );
    }

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: isNumeric ? Alignment.centerLeft : Alignment.centerRight,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _showSearchDialog(BuildContext context, CostCenterReportController controller) {
    controller.filterCenters('');
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن مركز تكلفة'),
        contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.6,
          child: _SearchDialogContent(controller: controller),
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
      ),
      barrierDismissible: false,
    );
  }
}

class _SearchDialogContent extends StatelessWidget {
  final CostCenterReportController controller;
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
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.filteredCostCenters.isEmpty) {
              return const Center(child: Text('لا توجد نتائج مطابقة للبحث'));
            }
            return SingleChildScrollView(
              child: DataTable(
                border: TableBorder.all(
                  color: Colors.grey.shade400,
                  width: 1,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(Colors.teal.shade50),
                columns: const [
                  DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('اسم المركز', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: controller.filteredCostCenters.map((center) {
                  return DataRow(
                    onSelectChanged: (isSelected) {
                      if (isSelected ?? false) {
                        controller.selectCostCenter(center);
                      }
                    },
                    cells: [
                      DataCell(Text(center.centerNo.toString())),
                      DataCell(Text(center.centerName)),
                    ],
                  );
                }).toList(),
              ),
            );
          }),
        ),
      ],
    );
  }
}