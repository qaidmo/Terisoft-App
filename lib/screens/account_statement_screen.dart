import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/models/sun_account_model.dart';
import 'package:untitled4/models/sun_currency.dart';
import '../models/account_statement_models.dart';
import 'controllers/account_statement_controller.dart';

class AccountStatementScreen extends StatelessWidget {
  const AccountStatementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AccountStatementController controller = Get.put(AccountStatementController());
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('كشف حساب'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'طباعة كشف الحساب',
            onPressed: controller.printStatement,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(
          left: 12.0,
          right: 12.0,
          top: 8.0,
          bottom: MediaQuery.of(context).padding.bottom + 8.0,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // ضمان وجود مساحة موجبة كافية دائماً لقسم النتائج Expanded ومنع أي تجاوز لـ RenderFlex
            // مهما كانت الشاشة صغيرة أو تم تصغير الـ Viewport
            final double minTableHeight = constraints.maxHeight > 240 ? 120.0 : constraints.maxHeight * 0.35;
            final double maxFilterHeight = (constraints.maxHeight - minTableHeight).clamp(0.0, double.infinity);

            return Column(
              children: [
                // 1+2: قسم الفلاتر والملخص مقيد بأقصى ارتفاع مسموح به حتى يتمرر بسلاسة عند الحاجة
                // دون التسبب بأي خطأ RenderFlex overflow
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxFilterHeight),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. قسم الفلاتر الثابت (دائم الظهور 100% ولا يطوى إطلاقاً)
                        _buildFilterSection(context, controller),
                        const SizedBox(height: 8),

                        // 2. شريط الملخص المالي المصغر
                        _buildSummarySection(controller),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // 3. الجدول الكامل المستمر المدوّر افتراضياً
                Expanded(
                  child: _buildResultsSection(controller),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, AccountStatementController controller) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildAccountSelector(context, controller),
            const SizedBox(height: 12),
            _buildDateAndCurrencySelector(context, controller),
            const SizedBox(height: 12),
            _buildBranchAndDepartmentRow(context, controller),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.display_settings_outlined),
                    label: const Text('عرض التقرير'),
                    onPressed: controller.getStatement,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('طباعة'),
                    onPressed: controller.printStatement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchAndDepartmentRow(
      BuildContext context, AccountStatementController controller) {
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
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
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
                  final match = controller.allBranches.firstWhereOrNull((b) => b['branch_id']?.toString() == newId);
                  controller.onBranchSelected(match);
                }
              : null,
          ),
        ),
        const SizedBox(width: 10),
        // --- Department Dropdown ---
        Expanded(
          child: DropdownButtonFormField<String?>(
            value: controller.selectedDepartment.value?['department_id']?.toString(),
            hint: const Text('كل الأقسام'),
            decoration: InputDecoration(
              labelText: 'القسم',
              prefixIcon: const Icon(Icons.business_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
            ),
            isExpanded: true,
            items: [
              // "All Departments" option (null value)
              if (controller.userState.isAdmin)
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('كل الأقسام'),
                ),
              ...controller.allDepartments.map((dept) {
                return DropdownMenuItem<String?>(
                  value: dept['department_id']?.toString(),
                  child: Text(
                    dept['department_name']?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: controller.userState.isAdmin
              ? (String? newId) {
                  final match = newId == null ? null : controller.allDepartments.firstWhereOrNull((d) => d['department_id']?.toString() == newId);
                  controller.onDepartmentSelected(match);
                }
              : null,
          ),
        ),
      ],
    ));
  }

  Widget _buildAccountSelector(BuildContext context, AccountStatementController controller) {
    return InkWell(
      onTap: () async {
        final SunAccount? result = await Get.dialog(StatementAccountSearchDialog(controller: controller));
        if (result != null) controller.onAccountSelected(result);
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller.accountNameController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'اختر الحساب',
            prefixIcon: const Icon(Icons.account_balance_wallet),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildDateAndCurrencySelector(BuildContext context, AccountStatementController controller) {
    return Obx(() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildDateField(context, 'من تاريخ', controller.fromDate.value, (date) => controller.fromDate.value = date)),
        const SizedBox(width: 10),
        Expanded(flex: 3, child: _buildDateField(context, 'إلى تاريخ', controller.toDate.value, (date) => controller.toDate.value = date)),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<SunCurrency>(
            initialValue: controller.selectedCurrency.value,
            hint: const Text('العملة'),
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            isExpanded: true,
            items: controller.allowedCurrencies.map((currency) {
              return DropdownMenuItem<SunCurrency>(value: currency, child: Text(currency.currencySymbol, overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: controller.onCurrencySelected,
            validator: (value) => value == null ? 'مطلوب' : null,
          ),
        ),
      ],
    ));
  }

  Widget _buildDateField(BuildContext context, String label, DateTime initialDate, Function(DateTime) onDateChanged) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(context: context, initialDate: initialDate, firstDate: DateTime(2000), lastDate: DateTime(2101));
        if (picked != null && picked != initialDate) onDateChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
        child: Text(DateFormat('yyyy-MM-dd').format(initialDate)),
      ),
    );
  }

  Widget _buildSummarySection(AccountStatementController controller) {
    return Obx(() => Column(
      children: [
        Row(children: [
          _buildSummaryCard('الرصيد الافتتاحي', controller.openingBalance.value),
          _buildSummaryCard(
            'الرصيد الختامي',
            controller.closingBalance.value,
            isClosing: true,
            currencySymbol: controller.selectedCurrency.value?.currencySymbol,
          ),
        ]),
        Row(children: [
          _buildSummaryCard('إجمالي مدين', controller.totalDebit.value),
          _buildSummaryCard('إجمالي دائن', controller.totalCredit.value),
        ]),
      ],
    ));
  }

  Widget _buildSummaryCard(String title, double value, {bool isClosing = false, String? currencySymbol}) {
    return Expanded(
      child: Card(
        color: isClosing ? Colors.blue.shade50 : Colors.grey.shade200,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    NumberFormat("#,##0.##").format(value),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: value < 0 ? Colors.red : (isClosing ? Colors.blue.shade800 : Colors.black87),
                    ),
                  ),
                  if (currencySymbol != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(
                        currencySymbol,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isClosing ? Colors.blue.shade800 : Colors.black87,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection(AccountStatementController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.statementRows.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('الرجاء اختيار حساب وعملة وفترة لعرض الكشف.'),
          ),
        );
      }

      const double tableWidth = 1000.0;
      const double rowHeight = 44.0;

      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
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
                    itemCount: controller.statementRows.length,
                    itemExtent: rowHeight,
                    padding: EdgeInsets.zero,
                    itemBuilder: (context, index) {
                      final row = controller.statementRows[index];
                      return _buildTableRow(index, row, rowHeight, controller);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTableHeader() {
    return Container(
      height: 42.0,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade400, width: 1.2),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('م', 45.0, alignment: Alignment.center),
          _buildHeaderCell('مدين', 100.0, alignment: Alignment.centerRight),
          _buildHeaderCell('دائن', 100.0, alignment: Alignment.centerRight),
          _buildHeaderCell('الرصيد', 115.0, alignment: Alignment.centerRight),
          _buildHeaderCell('التاريخ', 95.0, alignment: Alignment.center),
          _buildHeaderCell('رقم الحركة', 85.0, alignment: Alignment.center),
          _buildHeaderCell('النوع', 95.0, alignment: Alignment.center),
          _buildHeaderCell('المستفيد', 140.0, alignment: Alignment.centerRight),
          _buildHeaderCell('البيان', 225.0, alignment: Alignment.centerRight),
        ],
      ),
    );
  }

  Widget _buildTableRow(
      int index, StatementRowDisplayModel row, double height, AccountStatementController controller) {
    final isEven = index % 2 == 0;
    final isCarriedForward = row.type == 'رصيد مرحل';
    final isNegativeBalance = row.balance < 0;

    return InkWell(
      onTap: isCarriedForward ? null : () => controller.onStatementRowTap(row),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isCarriedForward
              ? Colors.amber.shade50
              : (isEven ? Colors.white : Colors.grey.shade50),
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 0.8),
          ),
        ),
        child: Row(
          children: [
            _buildDataCell(row.index.toString(), 45.0, alignment: Alignment.center),
            _buildDataCell(
              row.debitStr,
              100.0,
              alignment: Alignment.centerRight,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            _buildDataCell(
              row.creditStr,
              100.0,
              alignment: Alignment.centerRight,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            _buildDataCell(
              row.balanceStr,
              115.0,
              alignment: Alignment.centerRight,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isNegativeBalance ? Colors.red.shade700 : Colors.green.shade800,
              ),
            ),
            _buildDataCell(row.dateStr, 95.0, alignment: Alignment.center),
            _buildDataCell(row.traNoStr, 85.0, alignment: Alignment.center),
            _buildDataCell(
              row.typeStr,
              95.0,
              alignment: Alignment.center,
              style: TextStyle(
                color: isCarriedForward ? Colors.amber.shade900 : Colors.black87,
                fontWeight: isCarriedForward ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            _buildDataCell(row.beneficiaryStr, 140.0, alignment: Alignment.centerRight),
            _buildDataCell(row.descriptionStr, 225.0, alignment: Alignment.centerRight),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String title, double width, {Alignment alignment = Alignment.center}) {
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontSize: 13,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataCell(
    String text,
    double width, {
    Alignment alignment = Alignment.center,
    TextStyle? style,
  }) {
    return Container(
      width: width,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade200, width: 0.8),
        ),
      ),
      child: Text(
        text,
        style: style ?? const TextStyle(fontSize: 12.5, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

class StatementAccountSearchDialog extends StatelessWidget {
  final AccountStatementController controller;
  const StatementAccountSearchDialog({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    final searchQuery = ''.obs;

    return AlertDialog(
      title: const Text('بحث عن حساب'),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      content: SizedBox(
        width: Get.width * 0.9,
        height: Get.height * 0.7,
        child: Column(
          children: [
            TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (value) => searchQuery.value = value,
              decoration: InputDecoration(labelText: 'ابحث بالرقم أو الاسم', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 10),
            _buildHeaderRow(),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: Obx(() {
                if (controller.allAccounts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filteredList = controller.allAccounts.where((account) {
                  final query = searchQuery.value.toLowerCase();
                  return account.isTransactional && (account.name.toLowerCase().contains(query) || account.accountNumber.toLowerCase().contains(query));
                }).toList();
                if (filteredList.isEmpty) {
                  return const Center(child: Text('لا توجد حسابات حركية مطابقة'));
                }
                return ListView.builder(
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final account = filteredList[index];
                    return InkWell(
                      onTap: () => Get.back(result: account),
                      child: _buildDataRow(account, controller),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Get.back(result: null), child: const Text('إغلاق'))],
    );
  }

  Widget _buildHeaderRow() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey.shade200, border: Border(bottom: BorderSide(color: Colors.grey.shade400))),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('رقم الحساب', style: headerStyle)),
          Expanded(flex: 5, child: Text('اسم الحساب', style: headerStyle)),
          Expanded(flex: 4, child: Text('حساب الأب', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildDataRow(SunAccount account, AccountStatementController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(account.accountNumber, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 5, child: Text(account.name, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 4, child: Text(controller.getParentAccountName(account.parentId), style: const TextStyle(fontSize: 12, color: Colors.grey))),
        ],
      ),
    );
  }
}