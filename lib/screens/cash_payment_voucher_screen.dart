import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/models/cost_center.dart';
import 'package:untitled4/models/sun_account_model.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/screens/controllers/cash_payment_controller.dart';
import 'package:untitled4/screens/controllers/payment_calculations_controller.dart';
import 'package:untitled4/screens/controllers/payment_header_controller.dart';
import 'package:untitled4/screens/controllers/payment_input_controller.dart';
import 'package:untitled4/screens/controllers/payment_items_controller.dart';
import 'package:untitled4/utils/dialog_helper.dart';

class CashPaymentVoucherScreen extends StatefulWidget {
  final int? paymentId;
  const CashPaymentVoucherScreen({super.key, this.paymentId});

  @override
  State<CashPaymentVoucherScreen> createState() => _CashPaymentVoucherScreenState();
}

class _CashPaymentVoucherScreenState extends State<CashPaymentVoucherScreen> {
  late final CashPaymentController controller;
  late final String _controllerTag;

  @override
  void initState() {
    super.initState();
    _controllerTag = widget.paymentId?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    controller = Get.put(
      CashPaymentController(initialPaymentId: widget.paymentId),
      tag: _controllerTag,
    );
  }

  @override
  void dispose() {
    Get.delete<CashPaymentController>(tag: _controllerTag);
    super.dispose();
  }

  String _formatNumberForDisplay(num? number) {
    if (number == null) return '';
    double val = number.toDouble();
    if (val == 0) return '0';
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toString().replaceAll(RegExp(r"([.]*0)(?!.*\d)"), "");
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.userState.canAccessScreen('CashPaymentVoucherScreen')) {
        return Scaffold(appBar: AppBar(title: const Text('خطأ في الصلاحيات')), body: const Center(child: Text('لا تملك الصلاحيات اللازمة.')));
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final bool shouldExit = await DialogHelper.showExitConfirmationDialog();
          if (shouldExit) {
            Get.back();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
                controller.isReadOnly.value
                    ? 'عرض سند (أرشيف)'
                    : (controller.currentReceiptId.value == null ? 'سند صرف نقداً' : 'تعديل سند صرف'),
                style: const TextStyle(fontSize: 16, color: Colors.white)
            ),
            centerTitle: true,
            backgroundColor: Colors.blue.shade800,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                final bool shouldExit = await DialogHelper.showExitConfirmationDialog();
                if (shouldExit) {
                  Get.back();
                }
              },
            ),
            actions: [
              controller.isManualSyncing.value
                  ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
                  : IconButton(
                icon: const Icon(Icons.sync, size: 24, color: Colors.white),
                onPressed: controller.isReadOnly.value ? null : () => controller.performManualSync(),
              )
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTransactionHeader(controller.headerController), const SizedBox(height: 8),
                    _buildMainInputSection(context, controller.inputController, controller), const SizedBox(height: 8),
                    _buildPaymentItemsSection(context, controller.itemsController), const SizedBox(height: 8),
                    _buildTotalAmountSection(controller.calculationsController), const SizedBox(height: 12),
                    _buildActionButtons(controller),
                  ],
                ),
              ),
              if (controller.isLoading.value) Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTransactionHeader(PaymentHeaderController headerController) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildTransactionNumberDisplay(headerController), _buildDateRow(headerController)]),
            Obx(() => headerController.showPaymentId.value ? Padding(padding: const EdgeInsets.only(top: 8.0), child: _buildPaymentIdDisplay(headerController)) : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionNumberDisplay(PaymentHeaderController headerController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [const Icon(Icons.numbers, size: 18, color: Colors.blue), const SizedBox(width: 6), Obx(() => Text('رقم الحركة: ${headerController.transactionNumber.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)))]),
    );
  }

  Widget _buildPaymentIdDisplay(PaymentHeaderController headerController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200, width: 0.8)),
      child: Row(children: [const Icon(Icons.info_outline, size: 18, color: Colors.red), const SizedBox(width: 6), Obx(() => Text('معرف السند: ${headerController.paymentId.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)))]),
    );
  }

  Widget _buildDateRow(PaymentHeaderController headerController) {
    return InkWell(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: Row(children: [const Icon(Icons.calendar_today, size: 16, color: Colors.blue), const SizedBox(width: 6), Obx(() => Text(DateFormat('yyyy-MM-dd').format(headerController.selectedDate.value), style: const TextStyle(fontSize: 13)))]),
      ),
    );
  }

  Widget _buildMainInputSection(BuildContext context, PaymentInputController inputController, CashPaymentController cashPaymentController) {
    return Column(
      children: [
        _buildBoxSelector(context, inputController),
        _buildCurrencyDropdown(inputController),
        _buildRecipientSearchField(context, cashPaymentController),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: buildCostCenterSelector(cashPaymentController, context),
        ),
        _buildTextFieldRow(label: 'البيان*', icon: Icons.description, controller: cashPaymentController.descriptionController, readOnly: cashPaymentController.isReadOnly.value),
      ],
    );
  }

  Widget _buildBoxSelector(BuildContext context, PaymentInputController inputController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Icon(Icons.account_balance, size: 16, color: Colors.blue.shade800),
              const SizedBox(width: 4),
              Flexible(child: Text('الصندوق*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis))
            ]),
          ),
          Expanded(
            child: SizedBox(
              height: 35,
              child: Obx(() {
                final selectedBoxName = inputController.selectedBox.value;
                final bool isEnabled = inputController.isBoxEnabled.value && !controller.isReadOnly.value;

                return InkWell(
                  onTap: isEnabled ? () async {
                    final String? selectedName = await Get.dialog(
                      BoxSearchDialog(inputController: inputController),
                    );
                    if (selectedName != null) {
                      inputController.updateSelectedBox(selectedName);
                    }
                  } : null,
                  child: AbsorbPointer(
                    child: TextFormField(
                      key: ValueKey(selectedBoxName),
                      initialValue: selectedBoxName.isEmpty ? null : selectedBoxName,
                      readOnly: true,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'اضغط لاختيار الصندوق',
                        hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                        filled: true,
                        fillColor: isEnabled ? Colors.grey.shade50 : Colors.grey.shade200,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                        isDense: true,
                        suffixIcon: isEnabled ? const Icon(Icons.search, size: 20, color: Colors.blue) : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCostCenterSelector(CashPaymentController controller, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 90,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [Icon(Icons.account_tree_outlined, size: 18, color: Colors.blue.shade800), const SizedBox(width: 6), Flexible(child: Text("مركز التكلفة", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis))]),
        ),
        Expanded(
          child: SizedBox(
            height: 35,
            child: Obx(() => InkWell(
              onTap: controller.isReadOnly.value ? null : () => _showCostCenterSearchDialog(context, controller),
              borderRadius: BorderRadius.circular(8),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: controller.costCenterNameController,
                  readOnly: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'انقر للاختيار',
                    hintStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: controller.isReadOnly.value ? Colors.grey.shade200 : Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    isDense: true,
                    suffixIcon: (controller.selectedCostCenter.value != null && !controller.isReadOnly.value)
                        ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: controller.clearSelectedCostCenter)
                        : null,
                  ),
                ),
              ),
            )),
          ),
        ),
      ],
    );
  }

  void _showCostCenterSearchDialog(BuildContext context, CashPaymentController controller) {
    final searchController = TextEditingController();
    final RxList<CostCenter> filteredList = controller.allAvailableCostCenters.toList().obs;

    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن مركز تكلفة'),
        contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'ابحث بالرقم أو الاسم...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                onChanged: (query) {
                  filteredList.value = controller.filterCostCenters(query);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (filteredList.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج مطابقة'));
                  }
                  return SingleChildScrollView(
                    child: DataTable(
                      border: TableBorder.all(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('اسم المركز', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredList.map((center) {
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
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientSearchField(BuildContext context, CashPaymentController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [Icon(Icons.person_pin_circle, size: 16, color: Colors.blue.shade800), const SizedBox(width: 4), Flexible(child: Text('المستلم*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800)))]),
          ),
          Expanded(
            child: InkWell(
              onTap: controller.isReadOnly.value ? null : () async {
                final SunAccount? selectedAccount = await Get.dialog(PaymentAccountSearchDialog(itemsController: controller.itemsController));
                if (selectedAccount != null) {
                  controller.onAccountSelected(selectedAccount);
                }
              },
              child: AbsorbPointer(
                child: SizedBox(
                  height: 35,
                  child: TextFormField(
                    controller: controller.recipientController,
                    readOnly: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'اختر حساب المستلم...', hintStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: controller.isReadOnly.value ? Colors.grey.shade200 : Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), isDense: true,
                      suffixIcon: controller.isReadOnly.value ? null : const Icon(Icons.search, size: 20, color: Colors.blue),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown(PaymentInputController inputController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 90, padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [Icon(Icons.currency_exchange, size: 16, color: Colors.blue.shade800), const SizedBox(width: 4), Flexible(child: Text('العملة*', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis))])),
        Expanded(child: Row(children: [
          Expanded(flex: 3, child: Obx(() {
            return Container(height: 35, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: controller.isReadOnly.value ? Colors.grey.shade200 : Colors.grey.shade50), padding: const EdgeInsets.symmetric(horizontal: 8.0), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: inputController.selectedCurrency.value.isEmpty ? null : inputController.selectedCurrency.value, hint: const Text('اختر', style: TextStyle(fontSize: 12)), isExpanded: true, items: inputController.currencies.map((currency) => DropdownMenuItem<String>(value: currency.currencyName, child: Text(currency.currencyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))).toList(), onChanged: controller.isReadOnly.value ? null : inputController.updateSelectedCurrency, isDense: true, icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600, size: 20))));
          })),
          const SizedBox(width: 8), Text('س.ص:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800)), const SizedBox(width: 4),
          Expanded(flex: 2, child: SizedBox(height: 35, child: TextField(controller: inputController.exchangeRateController, readOnly: true, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.black87), decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade200, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6), isDense: true))))
        ]))
      ]),
    );
  }

  Widget _buildTextFieldRow({required String label, required IconData icon, required TextEditingController controller, TextInputType keyboardType = TextInputType.text, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 90, padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [Icon(icon, size: 18, color: Colors.blue.shade800), const SizedBox(width: 6), Flexible(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis))])),
        Expanded(child: SizedBox(height: 35, child: TextField(controller: controller, readOnly: readOnly, style: const TextStyle(fontSize: 14), keyboardType: keyboardType, decoration: InputDecoration(filled: true, fillColor: readOnly ? Colors.grey.shade200 : Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), isDense: true))))
      ]),
    );
  }

  Widget _buildPaymentItemsSection(BuildContext context, PaymentItemsController itemsController) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 6.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('تفاصيل الصرف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Obx(() => controller.isReadOnly.value
            ? const SizedBox.shrink()
            : ElevatedButton.icon(onPressed: () => itemsController.addNewItem(), icon: const Icon(Icons.add, size: 16), label: const Text('إضافة بند', style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.blue.shade600, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 2)))
      ])),
      const SizedBox(height: 8),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildPaymentItemsTable(context, itemsController))
    ]);
  }

  Widget _buildPaymentItemsTable(BuildContext context, PaymentItemsController itemsController) {
    return Obx(() => DataTable(
      headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
      columnSpacing: 5, headingRowHeight: 40, dataRowHeight: 48, horizontalMargin: 4,
      columns: ['م', 'المبلغ', 'رقم الحساب', 'اسم الحساب', 'العملة', 'س.ص', 'م.المقابل', if (!controller.isReadOnly.value) 'حذف'].map((text) => _buildAdjustedDataColumn(text)).toList(),
      rows: itemsController.items.asMap().entries.map((entry) {
        final int index = entry.key;
        final Map<String, dynamic> item = entry.value;

        final double equivalentAmount = (item['equivalent_amount'] as num?)?.toDouble() ?? 0.0;
        final double displayAmount = equivalentAmount;
        final bool isReadOnly = controller.isReadOnly.value;

        return DataRow(cells: [
          _buildFixedDataCell((index + 1).toString()),
          _buildAdjustedEditableCell(controller: itemsController.getAmountController(index), onChanged: (value) => itemsController.updateItemAmount(index, double.tryParse(value) ?? 0.0), keyboardType: const TextInputType.numberWithOptions(decimal: true), readOnly: isReadOnly),
          _buildAdjustedEditableCell(controller: itemsController.getAccountNoController(index), readOnly: true),
          _buildSearchableAccountCell(context, itemsController, index, isReadOnly),
          _buildCurrencyDropdownCell(itemsController, item, index, isReadOnly),
          _buildAdjustedEditableCell(controller: itemsController.getExchangeRateController(index), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (value) => itemsController.updateItemExchangeRate(index, double.tryParse(value) ?? 1.0), readOnly: isReadOnly),
          _buildFixedDataCell(_formatNumberForDisplay(displayAmount)),
          if (!isReadOnly) DataCell(Container(alignment: Alignment.center, child: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => itemsController.removeItem(index)))),
        ]);
      }).toList(),
    ));
  }

  DataColumn _buildAdjustedDataColumn(String text) {
    return DataColumn(label: Container(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Center(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800), textAlign: TextAlign.center))));
  }

  DataCell _buildFixedDataCell(String value) {
    return DataCell(Container(constraints: const BoxConstraints(minWidth: 60), alignment: Alignment.centerRight, padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(value, style: const TextStyle(fontSize: 13), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)));
  }

  DataCell _buildAdjustedEditableCell({required TextEditingController controller, ValueChanged<String>? onChanged, TextInputType keyboardType = TextInputType.text, bool readOnly = false}) {
    return DataCell(Container(constraints: const BoxConstraints(minWidth: 100), padding: const EdgeInsets.symmetric(horizontal: 4), child: TextFormField(controller: controller, readOnly: readOnly, keyboardType: keyboardType, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center, onChanged: onChanged, decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), border: InputBorder.none, filled: true, fillColor: readOnly ? Colors.grey.shade100 : Colors.white))));
  }

  DataCell _buildSearchableAccountCell(BuildContext context, PaymentItemsController itemsController, int index, bool readOnly) {
    return DataCell(
      InkWell(
        onTap: readOnly ? null : () async {
          final SunAccount? selectedAccount = await Get.dialog(PaymentAccountSearchDialog(itemsController: itemsController));
          if (selectedAccount != null) {
            await itemsController.onAccountSelectedInTable(index, selectedAccount);
          }
        },
        child: AbsorbPointer(
          child: TextFormField(
            controller: itemsController.getAccountNameController(index),
            readOnly: true,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            textAlign: TextAlign.right,
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.fromLTRB(4, 0, 4, 12)),
          ),
        ),
      ),
    );
  }

  DataCell _buildCurrencyDropdownCell(PaymentItemsController itemsController, Map<String, dynamic> item, int index, bool readOnly) {
    final List<SunCurrency> allowedCurrencies = (item['allowed_currencies'] as List<dynamic>?)?.cast<SunCurrency>() ?? [];
    final int? selectedCurrencyNo = item['item_currency'] as int?;

    if (readOnly) {
      final currencyName = allowedCurrencies.firstWhereOrNull((c) => c.currencyNo == selectedCurrencyNo)?.currencySymbol ?? (selectedCurrencyNo?.toString() ?? '-');
      return DataCell(Center(child: Text(currencyName, style: const TextStyle(fontSize: 13))));
    }

    return DataCell(
      (allowedCurrencies.isEmpty && item['isEmpty'] == false)
          ? const Center(child: Text('لا عملات', style: TextStyle(fontSize: 11, color: Colors.red)))
          : Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        alignment: Alignment.center,
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: selectedCurrencyNo,
            isExpanded: true, isDense: true,
            style: const TextStyle(fontSize: 13, color: Colors.black),
            items: allowedCurrencies.map((currency) => DropdownMenuItem<int>(value: currency.currencyNo, child: Text(currency.currencySymbol, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (newValue) => itemsController.updateItemCurrency(index, newValue),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAmountSection(PaymentCalculationsController calculationsController) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Obx(() => _CalculationDisplayRow(label: 'الإجمالي', value: _formatNumberForDisplay(calculationsController.total.value), isTotal: true)),
        const SizedBox(height: 4),
        Obx(() => _CalculationDisplayRow(label: 'المبلغ كتابة', value: calculationsController.amountInWords.value))
      ]),
    );
  }

  Widget _buildActionButtons(CashPaymentController controller) {
    return Obx(() {
      final isNew = controller.currentReceiptId.value == null;
      final isReadOnly = controller.isReadOnly.value;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _buildActionButton('جديد', Icons.create, Colors.blue, controller.canPerformAction('add') ? () => controller.resetForm() : null), const SizedBox(width: 6),
          _buildActionButton(isNew ? 'حفظ' : 'تعديل', isNew ? Icons.save : Icons.edit, isNew ? Colors.green : Colors.orange, controller.isLoading.value || isReadOnly || (isNew ? !controller.canPerformAction('add') : !controller.canPerformAction('edit')) ? null : () => controller.savePayment()), const SizedBox(width: 6),
          _buildActionButton('طباعة', Icons.print, Colors.purple, controller.canPerformAction('print') ? () => controller.printPayment() : null), const SizedBox(width: 6),
          _buildActionButton('بحث', Icons.search, Colors.orange, isReadOnly ? null : (controller.canPerformAction('search') ? () => controller.navigateToPreviousPayments() : null))
        ]),
      );
    });
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback? onPressed) {
    return Expanded(child: ElevatedButton.icon(icon: Icon(icon, size: 20, color: Colors.white), label: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)), onPressed: onPressed, style: ElevatedButton.styleFrom(backgroundColor: onPressed != null ? color : color.withOpacity(0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 8), elevation: onPressed != null ? 2 : 0)));
  }
}

class _CalculationDisplayRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  final Color? color;
  const _CalculationDisplayRow({required this.label, required this.value, this.isTotal = false, this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Expanded(
            child: Text('$label:', style: TextStyle(fontSize: 12, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600, color: Colors.blue.shade800)),
          ),
          Container(
            width: 200,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(
              color: isTotal ? Colors.blue.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade400, width: 0.8),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: color ?? (isTotal ? Colors.blue.shade800 : Colors.grey.shade800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentAccountSearchDialog extends StatelessWidget {
  final PaymentItemsController itemsController;
  const PaymentAccountSearchDialog({super.key, required this.itemsController});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    final searchQuery = ''.obs;

    return AlertDialog(
      title: const Text('بحث عن حساب'),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (value) => searchQuery.value = value,
              decoration: InputDecoration(labelText: 'ابحث بالرقم أو الاسم', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Obx(() {
                if (itemsController.isLoadingAccounts.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filteredList = itemsController.searchAccountsByName(searchQuery.value).toList();
                if (filteredList.isEmpty) {
                  return const Center(child: Text('لا توجد حسابات حركية مطابقة'));
                }
                return SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.85),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('رقم الحساب', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('اسم الحساب', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('الاسم الأجنبي', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('حساب الأب', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredList.map((account) {
                          return DataRow(
                            onSelectChanged: (isSelected) {
                              if (isSelected ?? false) Get.back(result: account);
                            },
                            cells: [
                              DataCell(Text(account.accountNumber)),
                              DataCell(Text(account.name)),
                              DataCell(Text(account.nameEn ?? '')),
                              DataCell(Text(itemsController.getParentAccountName(account.parentId))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Get.back(result: null), child: const Text('إغلاق'))],
    );
  }
}

class BoxSearchDialog extends StatelessWidget {
  final PaymentInputController inputController;
  const BoxSearchDialog({super.key, required this.inputController});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    final searchQuery = ''.obs;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.blue.shade800),
          const SizedBox(width: 8),
          const Text('بحث عن صندوق', style: TextStyle(fontSize: 18)),
        ],
      ),
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (value) => searchQuery.value = value,
              decoration: InputDecoration(
                labelText: 'ابحث باسم الصندوق أو الرقم...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                final filteredList = inputController.boxes.where((box) {
                  final query = searchQuery.value.toLowerCase();
                  return box.boxName.toLowerCase().contains(query) ||
                      (box.boxNo?.toString().contains(query) ?? false);
                }).toList();

                if (filteredList.isEmpty) {
                  return const Center(child: Text('لا توجد صناديق مطابقة'));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width * 0.75),
                      child: DataTable(
                        border: TableBorder.all(
                            color: Colors.grey.shade400,
                            width: 1,
                            borderRadius: BorderRadius.circular(4)
                        ),
                        headingRowColor: WidgetStateProperty.all(Colors.blue.shade100),
                        dataRowColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) return Colors.blue.shade50;
                          return Colors.white;
                        }),
                        columnSpacing: 20,
                        headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        showCheckboxColumn: false,
                        columns: const [
                          DataColumn(label: Text('رقم الصندوق')),
                          DataColumn(label: Text('اسم الصندوق')),
                        ],
                        rows: filteredList.map((box) {
                          return DataRow(
                            onSelectChanged: (isSelected) {
                              if (isSelected ?? false) {
                                Get.back(result: box.boxName);
                              }
                            },
                            cells: [
                              DataCell(Text(box.boxNo?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(box.boxName)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: null),
          child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
        )
      ],
    );
  }
}