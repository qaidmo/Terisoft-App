import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/models/sun_currency.dart'; // <-- تم الإضافة
import 'controllers/customer_movement_controller.dart';

class ClientsMovementScreen extends StatelessWidget {
  const ClientsMovementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CustomerMovementController controller =
    Get.put(CustomerMovementController());

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('تقرير حركة العملاء'),
        actions: [
          Obx(() => controller.canPrint()
              ? IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: controller.printReport,
            tooltip: 'طباعة التقرير',
          )
              : const SizedBox.shrink()),
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
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (controller.reportData.isEmpty &&
                        controller.hasSearched.value) {
                      return const Center(
                          child: Text('لا توجد بيانات لعرضها حسب الفلاتر المحددة.'));
                    }
                    if (!controller.hasSearched.value) {
                      return const Center(
                          child: Text('الرجاء تحديد الفلاتر والضغط على عرض.'));
                    }
                    return _buildDataTable(controller);
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterSection(
      BuildContext context, CustomerMovementController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildCustomerSearchField(context, controller),
            const SizedBox(height: 12),
            _buildCurrencyDropdown(controller),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child:
                    _buildDatePicker(context, 'من تاريخ:', controller.fromDate)),
                const SizedBox(width: 10),
                Expanded(
                    child:
                    _buildDatePicker(context, 'إلى تاريخ:', controller.toDate)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: controller.clearFilters,
                  child: const Text('مسح الفلاتر'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('عرض التقرير'),
                  onPressed: controller.fetchReportData,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown(CustomerMovementController controller) {
    return Obx(() {
      if (controller.isCurrencyListLoading.value) {
        return const InputDecorator(
          decoration: InputDecoration(
            labelText: 'العملة',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            suffixIcon: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      }
      return DropdownButtonFormField<SunCurrency>(
        decoration: const InputDecoration(
          labelText: 'العملة',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
        initialValue: controller.selectedCurrency.value,
        items: controller.allCurrencies.map((currency) {
          return DropdownMenuItem<SunCurrency>(
            value: currency,
            child: Text(currency.currencyName),
          );
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            controller.setCurrency(newValue);
          }
        },
      );
    });
  }

  Widget _buildCustomerSearchField(
      BuildContext context, CustomerMovementController controller) {
    return Obx(() => InkWell(
      onTap: () => _showCustomerSearchDialog(context, controller),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'اسم العميل',
          border: const OutlineInputBorder(),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          suffixIcon: controller.selectedCustomer.value != null
              ? IconButton(
            icon: const Icon(Icons.close),
            onPressed: controller.removeSelectedCustomer,
            tooltip: 'إزالة التحديد',
          )
              : const Icon(Icons.search),
        ),
        child: Text(
          controller.selectedCustomer.value?.customerName ??
              'عرض جميع العملاء',
          style: TextStyle(
            color: controller.selectedCustomer.value != null
                ? Colors.black
                : Colors.grey.shade600,
          ),
        ),
      ),
    ));
  }

  void _showCustomerSearchDialog(
      BuildContext context, CustomerMovementController controller) {
    final RxString searchQuery = ''.obs;

    Get.dialog(
      AlertDialog(
        title: const Text('ابحث عن عميل'),
        contentPadding: const EdgeInsets.all(10.0),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  onChanged: (value) => searchQuery.value = value,
                  decoration: const InputDecoration(
                    labelText: 'اكتب اسم العميل أو رقمه...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (controller.isCustomerListLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final filteredList =
                  controller.allCustomers.where((customer) {
                    final customerName = customer.customerName.toLowerCase();
                    final customerNo =
                    customer.customerNo.toString().toLowerCase();
                    final query = searchQuery.value.toLowerCase();
                    return customerName.contains(query) ||
                        customerNo.contains(query);
                  }).toList();

                  return SingleChildScrollView(
                    child: DataTable(
                      border: TableBorder.all(
                        width: 1.0,
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      headingRowColor:
                      WidgetStateProperty.all(Colors.blue.shade50),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(
                            label: Text('الرقم',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('اسم الحساب',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredList.map((customer) {
                        return DataRow(
                          cells: [
                            DataCell(Text(customer.customerNo.toString())),
                            DataCell(Text(customer.customerName)),
                          ],
                          onSelectChanged: (isSelected) {
                            if (isSelected ?? false) {
                              controller.setCustomer(customer);
                              Get.back();
                            }
                          },
                        );
                      }).toList(),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _buildDataTable(CustomerMovementController controller) {
    const double totalWidth = 1290.0;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade400, width: 1.0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              // Pinned Header
              Container(
                height: 44.0,
                color: Colors.blue.shade100,
                child: Row(
                  children: [
                    _buildCell('اسم الحساب', 180.0, isHeader: true, isNumeric: false),
                    _buildCell('الرصيد الافتتاحي', 110.0, isHeader: true),
                    _buildCell('المبيعات', 105.0, isHeader: true),
                    _buildCell('المردودات', 105.0, isHeader: true),
                    _buildCell('صافي المبيعات', 105.0, isHeader: true),
                    _buildCell('التحصيل', 105.0, isHeader: true),
                    _buildCell('نسبة التحصيل', 95.0, isHeader: true),
                    _buildCell('الرصيد', 110.0, isHeader: true),
                    _buildCell('نسبة الرصيد', 95.0, isHeader: true),
                    _buildCell('آخر فاتورة', 100.0, isHeader: true, isNumeric: false),
                    _buildCell('آخر سداد', 100.0, isHeader: true, isNumeric: false),
                    _buildCell('عمر الدين', 80.0, isHeader: true, isNumeric: false),
                  ],
                ),
              ),
              // Virtualized Rows
              Expanded(
                child: ListView.builder(
                  itemCount: controller.reportData.length,
                  itemExtent: 44.0,
                  itemBuilder: (context, index) {
                    final item = controller.reportData[index];
                    final balance = (item['balance'] as num?) ?? 0;
                    final isEven = index % 2 == 0;

                    return Container(
                      height: 44.0,
                      color: isEven ? Colors.white : Colors.grey.shade50,
                      child: Row(
                        children: [
                          _buildCell(item['customer_name']?.toString() ?? '', 180.0, isNumeric: false),
                          _buildCell(item['openingBalanceStr']?.toString() ?? '', 110.0),
                          _buildCell(item['salesStr']?.toString() ?? '', 105.0),
                          _buildCell(item['returnsStr']?.toString() ?? '', 105.0),
                          _buildCell(item['net_salesStr']?.toString() ?? '', 105.0),
                          _buildCell(item['collectionsStr']?.toString() ?? '', 105.0),
                          _buildCell(item['collection_percentageStr']?.toString() ?? '', 95.0),
                          _buildCell(
                            item['balanceStr']?.toString() ?? '',
                            110.0,
                            textColor: balance > 0 ? Colors.red.shade700 : Colors.green.shade700,
                            isBold: true,
                          ),
                          _buildCell(item['balance_percentageStr']?.toString() ?? '', 95.0),
                          _buildCell(item['last_invoice_date']?.toString() ?? '-', 100.0, isNumeric: false),
                          _buildCell(item['last_payment_date']?.toString() ?? '-', 100.0, isNumeric: false),
                          _buildCell(item['debt_age']?.toString() ?? '0', 80.0, isNumeric: false),
                        ],
                      ),
                    );
                  },
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
        fontSize: 12,
        color: Colors.black87,
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
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Obx(() => Text(displayFormat.format(date.value))),
      ),
    );
  }
}