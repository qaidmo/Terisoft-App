import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:untitled4/screens/controllers/credit_sale_controller.dart';
import 'package:untitled4/screens/controllers/credit_transaction_header_controller.dart';
import 'package:untitled4/screens/controllers/credit_input_section_controller.dart';
import 'package:untitled4/screens/controllers/credit_products_controller.dart';
import 'package:untitled4/screens/controllers/credit_calculations_controller.dart';

import 'package:untitled4/models/sun_customer.dart';
import 'package:untitled4/models/sun_store.dart';
import '../i_price_change_permission.dart';
import 'package:untitled4/utils/dialog_helper.dart';

const String _kCurrentScreenName = 'CreditSaleScreen';

class CreditSaleScreen extends StatefulWidget {
  final String? invoiceId;
  const CreditSaleScreen({super.key, this.invoiceId});

  @override
  State<CreditSaleScreen> createState() => _CreditSaleScreenState();
}

class _CreditSaleScreenState extends State<CreditSaleScreen> {
  late final CreditSaleController controller;
  late final String _controllerTag;
  final TextEditingController _productSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controllerTag = widget.invoiceId ?? DateTime.now().millisecondsSinceEpoch.toString();

    controller = Get.put(
      CreditSaleController(
        initialInvoiceId: widget.invoiceId,
        controllerTag: _controllerTag,
      ),
      tag: _controllerTag,
    );
    Get.put<IPriceChangePermission>(controller, tag: _controllerTag);
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    Get.delete<IPriceChangePermission>(tag: _controllerTag, force: true);
    Get.delete<CreditSaleController>(tag: _controllerTag, force: true);
    super.dispose();
  }

  String _formatSmart(double? value) {
    if (value == null) return '0';
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r"0*$"), "").replaceAll(RegExp(r"\.$"), "");
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.userState.canAccessScreen(_kCurrentScreenName)) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ في الصلاحيات')),
        body: const Center(
          child: Text('لا تملك الصلاحيات اللازمة لعرض هذه الشاشة.'),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool shouldExit = await DialogHelper.showExitConfirmationDialog();
        if (shouldExit) {
          if (controller.currentInvoiceId.value != null) {
            Get.back(result: true);
          } else {
            Get.offAllNamed('/home');
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() => Text(
            controller.currentInvoiceId.value == null ? 'بيع آجل' : 'تعديل فاتورة بيع آجل',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          )),
          centerTitle: true,
          backgroundColor: Colors.blue.shade800,
          elevation: 3,
          shadowColor: Colors.blue.shade200,
          toolbarHeight: 45.0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              final bool shouldExit = await DialogHelper.showExitConfirmationDialog();
              if (shouldExit) {
                if (controller.currentInvoiceId.value != null) {
                  Get.back(result: true);
                } else {
                  Get.offAllNamed('/home');
                }
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, size: 24, color: Colors.white),
              tooltip: 'إعدادات الجدول',
              onPressed: () => _showTableSettingsSheet(context, controller),
            ),
            Obx(() => controller.isManualSyncing.value
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
              onPressed: () => controller.performManualSync(),
            )),
          ],
        ),
        body: Obx(() => Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTransactionHeader(controller.headerController),
                        const SizedBox(height: 8),
                        _buildInputSection(context, controller.inputController, controller),
                        const SizedBox(height: 8),
                        _buildProductsSection(context, controller.productsController),
                        const SizedBox(height: 8),
                        _buildCalculationsSection(controller.calculationsController),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: SafeArea(
                    top: false,
                    child: _buildActionButtons(controller),
                  ),
                ),
              ],
            ),
            if (controller.isLoading.value)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        )),
      ),
    );
  }

  Widget _buildTransactionHeader(CreditTransactionHeaderController headerController) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.numbers, size: 18, color: Colors.blue),
                  const SizedBox(width: 6),
                  Obx(() => Text(
                    'رقم الحركة: ${headerController.transactionNumber.value}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
                  )),
                ],
              ),
            ),
            InkWell(
              onTap: controller.isReadOnly.value ? null : () {},
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Obx(() => Text(
                      DateFormat('yyyy-MM-dd').format(headerController.selectedDate.value),
                      style: const TextStyle(fontSize: 13),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(BuildContext context, CreditInputSectionController inputController, CreditSaleController creditSaleController) {
    return AbsorbPointer(
      absorbing: creditSaleController.isReadOnly.value,
      child: Column(
        children: [
          Obx(() => _buildSearchableInputRow(
            label: 'العميل*',
            icon: Icons.person,
            controller: creditSaleController.customerNameController,
            onTap: () => _showCustomerSearchDialog(context, creditSaleController),
            onClear: creditSaleController.selectedCustomer.value != null
                ? () {
              creditSaleController.customerNameController.clear();
              creditSaleController.selectedCustomer.value = null;
              inputController.clearCurrencies();
            }
                : null,
          )),

          _buildCurrencyDropdown(inputController),
          _buildStoreDropdown(inputController),

          Obx(() => _buildSearchableInputRow(
            label: 'المحصل',
            icon: Icons.payment,
            controller: inputController.collectorNameController,
            onTap: () => _showCollectorSearchDialog(context, inputController),
            onClear: inputController.selectedCollectorId.value != null
                ? () {
              inputController.collectorNameController.clear();
              inputController.selectedCollectorId.value = null;
            }
                : null,
          )),

          Obx(() => _buildSearchableInputRow(
            label: 'المندوب',
            icon: Icons.person_outline,
            controller: inputController.agentNameController,
            onTap: () => _showAgentSearchDialog(context, inputController),
            onClear: inputController.selectedAgentId.value != null
                ? () {
              inputController.agentNameController.clear();
              inputController.selectedAgentId.value = null;
            }
                : null,
          )),
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown(CreditInputSectionController inputController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildLabelWithIcon(Icons.currency_exchange, 'العملة*'),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Obx(() => _buildDropdownContainer(
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: inputController.selectedCurrency.value.isEmpty ? null : inputController.selectedCurrency.value,
                        hint: const Text('اختر', style: TextStyle(fontSize: 12)),
                        isExpanded: true,
                        items: inputController.availableCurrencies.map((currency) {
                          return DropdownMenuItem<String>(value: currency, child: Text(currency, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
                        }).toList(),
                        onChanged: controller.isReadOnly.value ? null : inputController.updateSelectedCurrency,
                        isDense: true,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600, size: 20),
                      ),
                    ),
                  )),
                ),
                const SizedBox(width: 8),
                Text('س.ص:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                const SizedBox(width: 4),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 35,
                    child: TextField(
                      controller: inputController.exchangeRateController,
                      readOnly: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      decoration: _buildInputDecoration(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreDropdown(CreditInputSectionController inputController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildLabelWithIcon(Icons.store, 'المخزن*'),
          Expanded(
            child: Obx(() => _buildDropdownContainer(
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: inputController.selectedStore.value.isEmpty ? null : inputController.selectedStore.value,
                  hint: const Text('اختر المخزن', style: TextStyle(fontSize: 12)),
                  isExpanded: true,
                  items: inputController.availableStores.map((store) {
                    return DropdownMenuItem<String>(value: store, child: Text(store, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
                  }).toList(),
                  onChanged: controller.isReadOnly.value ? null : (val) { if (val != null) inputController.selectedStore.value = val; },
                  isDense: true,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600, size: 20),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelWithIcon(IconData icon, String label) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade800),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Container _buildDropdownContainer(Widget child) {
    return Container(
      height: 35,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.grey.shade50),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: child,
    );
  }

  InputDecoration _buildInputDecoration({String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade50,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      isDense: true,
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildSearchableInputRow({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildLabelWithIcon(icon, label),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: AbsorbPointer(
                child: SizedBox(
                  height: 35,
                  child: TextField(
                    controller: controller,
                    readOnly: true,
                    style: const TextStyle(fontSize: 14),
                    decoration: _buildInputDecoration(
                      hint: 'اضغط للاختيار...',
                      suffixIcon: onClear != null && !this.controller.isReadOnly.value ? IconButton(icon: const Icon(Icons.clear, size: 18, color: Colors.red), onPressed: onClear) : null,
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

  void _showCustomerSearchDialog(BuildContext context, CreditSaleController controller) {
    Get.dialog(AlertDialog(
      title: const Text('بحث عن عميل'),
      content: _CustomerSearchDialogContent(controller: controller),
      actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
    ));
  }

  void _showCollectorSearchDialog(BuildContext context, CreditInputSectionController controller) {
    controller.collectorSearchController.clear();
    controller.filteredCollectors.assignAll(controller.allCollectors);
    Get.dialog(AlertDialog(title: const Text('بحث عن محصل'), content: _CollectorSearchDialogContent(controller: controller), actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))]));
  }

  void _showAgentSearchDialog(BuildContext context, CreditInputSectionController controller) {
    controller.agentSearchController.clear();
    controller.filteredAgents.assignAll(controller.allAgents);
    Get.dialog(AlertDialog(title: const Text('بحث عن مندوب'), content: _AgentSearchDialogContent(controller: controller), actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))]));
  }

  Widget _buildProductsSection(BuildContext context, CreditProductsController productsController) {
    const double rowHeight = 45.0;
    const double headerHeight = 40.0;
    const int maxVisibleRows = 6;
    const double maxTableHeight = headerHeight + (rowHeight * maxVisibleRows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!controller.isReadOnly.value)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                const Text(' الأصناف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 10),
                _buildProductSearch(context, productsController),
              ],
            ),
          ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: maxTableHeight),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: _buildProductsTable(context, productsController),
          ),
        ),
      ],
    );
  }

  Widget _buildProductSearch(BuildContext context, CreditProductsController productsController) {
    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TypeAheadField<Map<String, dynamic>>(
                  controller: productsController.productSearchController,
                  direction: VerticalDirection.up,
                  decorationBuilder: (context, child) {
                    return Material(
                      elevation: 8.0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: child,
                      ),
                    );
                  },
                  builder: (context, controller, focusNode) {
                    return SizedBox(
                      height: 35,
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'ابحث برقم، اسم، أو باركود...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: Icon(Icons.search, size: 18, color: Colors.blue.shade800),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            final results = productsController.filterProducts(value);
                            final exactMatch = results.firstWhereOrNull((p) =>
                            p['item_no'].toString() == value ||
                                p['item_barcode'].toString() == value);

                            if (exactMatch != null) {
                              productsController.addProduct(exactMatch);
                            } else if (results.isNotEmpty) {
                              productsController.addProduct(results.first);
                            } else {
                              Get.snackbar('تنبيه', 'لم يتم العثور على الصنف "$value"',
                                  backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
                            }
                          }
                        },
                      ),
                    );
                  },
                  suggestionsCallback: (query) => productsController.filterProducts(query),
                  itemBuilder: (context, product) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
                    leading: CircleAvatar(radius: 14, backgroundColor: Colors.blue.shade50, child: Text(product['item_no']?.toString() ?? '', style: TextStyle(color: Colors.blue.shade800, fontSize: 10))),
                    title: Text(product['item_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text('السعر: ${_formatSmart(double.tryParse(product['item_price']?.toString() ?? '0'))}', style: const TextStyle(fontSize: 11)),
                  ),
                  onSelected: (product) {
                    productsController.addProduct(product);
                  },
                  emptyBuilder: (context) => const Padding(padding: EdgeInsets.all(8.0), child: Text('لا توجد نتائج', textAlign: TextAlign.center)),
                  loadingBuilder: (context) => const Padding(padding: EdgeInsets.all(8.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => productsController.toggleCamera(),
                child: Obx(() => Container(
                  height: 35,
                  width: 45,
                  decoration: BoxDecoration(
                    color: productsController.isCameraVisible.value ? Colors.red : Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    productsController.isCameraVisible.value ? Icons.close : Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 20,
                  ),
                )),
              ),
            ],
          ),
          Obx(() {
            if (productsController.isCameraVisible.value) {
              return Container(
                height: 100,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: productsController.cameraController,
                        onDetect: productsController.onBarcodeDetect,
                      ),
                      Container(width: 250, height: 2, color: Colors.red.withOpacity(0.7)),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                          onPressed: () => productsController.toggleCamera(),
                        ),
                      )
                    ],
                  ),
                ),
              );
            } else {
              return const SizedBox.shrink();
            }
          }),
        ],
      ),
    );
  }

  Widget _buildProductsTable(BuildContext context, CreditProductsController productsController) {
    final double totalWidth = MediaQuery.of(context).size.width + 350;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(2, 3))],
      ),
      child: Obx(() {
        final List<Map<String, dynamic>> displayedProducts = productsController.products;
        final bool showBatch = controller.showBatchNumber.value;
        final bool showExpiry = controller.showExpiryDate.value;
        final bool showBonus = controller.showBonusQuantity.value;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
            columnSpacing: 10,
            headingRowHeight: 40,
            dataRowMinHeight: 45,
            dataRowMaxHeight: 45,
            horizontalMargin: 8,
            dividerThickness: 0.5,
            columns: [
              _buildDataColumn('رقم الصنف', 80, totalWidth),
              _buildDataColumn('اسم الصنف', 130, totalWidth),
              _buildDataColumn('الوحدة', 75, totalWidth),
              _buildDataColumn('العبوة', 50, totalWidth),
              if (showBatch) _buildDataColumn('رقم الدفعة', 90, totalWidth),
              if (showExpiry) _buildDataColumn('تاريخ الانتهاء', 160, totalWidth),
              _buildDataColumn('الكمية', 70, totalWidth),
              if (showBonus) _buildDataColumn('ك.ص', 60, totalWidth),
              _buildDataColumn('السعر', 80, totalWidth),
              _buildDataColumn('الرصيد', 70, totalWidth),
              _buildDataColumn('الخصم', 70, totalWidth),
              _buildDataColumn('الإجمالي', 100, totalWidth),
            ],
            rows: displayedProducts.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> product = entry.value;
              bool isEmptyRow = product['isEmpty'] == true;
              bool isEditable = !isEmptyRow && !controller.isReadOnly.value;

              return DataRow(
                cells: [
                  _buildDataCell(isEmptyRow ? '' : product['item_no']?.toString() ?? '', textAlign: TextAlign.center),
                  _buildDataCell(isEmptyRow ? '________________' : product['item_name']?.toString() ?? ''),
                  DataCell(isEmptyRow ? const Text('') : _buildUnitDropdown(product, index, productsController)),
                  _buildDataCell(isEmptyRow ? '' : _formatSmart(product['pack_factor']), textAlign: TextAlign.center),
                  if (showBatch) _buildDataCell(isEmptyRow ? '' : product['batch_no']?.toString() ?? ''),
                  if (showExpiry) DataCell(isEmptyRow ? const Text('') : _buildExpiryDropdown(product, index, productsController)),
                  isEditable
                      ? _buildEditableCell(productsController.getQuantityController(index), (val) => productsController.updateQuantity(index, val), TextInputType.number)
                      : _buildDataCell(isEmptyRow ? '' : product['quantity'].toString(), textAlign: TextAlign.center),
                  if (showBonus)
                    isEditable
                        ? _buildEditableCell(productsController.getBonusQuantityController(index), (val) => productsController.updateBonusQuantity(index, val), TextInputType.number)
                        : _buildDataCell(isEmptyRow ? '' : product['bonus_quantity'].toString(), textAlign: TextAlign.center),
                  isEditable
                      ? _buildEditableCell(productsController.getPriceController(index), (val) => productsController.updatePrice(index, val), const TextInputType.numberWithOptions(decimal: true), !productsController.isPriceChangeAllowed)
                      : _buildDataCell(isEmptyRow ? '' : _formatSmart(product['item_price'] as double?)),
                  isEmptyRow
                      ? _buildDataCell('')
                      : _buildStockDisplayCell(index, productsController),
                  _buildDataCell(isEmptyRow ? '' : _formatSmart(product['item_discount'] as double?), textAlign: TextAlign.center),
                  DataCell(
                    Row(
                      children: [
                        Expanded(child: Align(alignment: Alignment.centerRight, child: Text(isEmptyRow ? '' : _formatSmart(product['total_item'] as double?), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right))),
                        if (isEditable) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () => productsController.removeProduct(index), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      }),
    );
  }

  Widget _buildUnitDropdown(Map<String, dynamic> product, int index, CreditProductsController controller) {
    final List<dynamic> units = product['units_list'] ?? [];
    if (units.isEmpty) return Text(product['item_unit']?.toString() ?? '', style: const TextStyle(fontSize: 12));

    final String? currentUnit = product['item_unit'];
    final bool valueExists = units.any((u) => u['unit_name'] == currentUnit);
    final String validValue = valueExists ? currentUnit! : units.first['unit_name'];

    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          items: units.map<DropdownMenuItem<String>>((u) {
            return DropdownMenuItem<String>(value: u['unit_name'], child: Text(u['unit_name'], overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: this.controller.isReadOnly.value ? null : (newVal) { if (newVal != null) controller.changeItemUnit(index, newVal); },
        ),
      ),
    );
  }

  Widget _buildExpiryDropdown(Map<String, dynamic> product, int index, CreditProductsController controller) {
    final List<dynamic> stockList = product['stock_list'] ?? [];
    final double currentPackFactor = (product['pack_factor'] as num?)?.toDouble() ?? 1.0;

    if (stockList.isEmpty) {
      return const Center(
        child: Text(
          'لا يوجد رصيد',
          style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }

    int? selectedStockIndex;
    final String? currentExpiry = product['expiry_date'];
    final String? currentBatch = product['batch_no']?.toString();

    if (currentExpiry != null) {
      for (int i = 0; i < stockList.length; i++) {
        final s = stockList[i];
        final bool dateMatch = s['expiry_date'] == currentExpiry;
        final bool batchMatch = (s['batch_no']?.toString() ?? '') == (currentBatch ?? '');

        if (dateMatch && batchMatch) {
          selectedStockIndex = i;
          break;
        }
      }
    }

    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedStockIndex,
          hint: const Text('التاريخ', style: TextStyle(fontSize: 11, color: Colors.grey)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.blue),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          items: stockList.asMap().entries.map((entry) {
            final int itemIndex = entry.key;
            final Map<String, dynamic> s = entry.value;

            final double baseQty = (s['quantity'] as num?)?.toDouble() ?? 0.0;
            final double displayQty = currentPackFactor > 0 ? (baseQty / currentPackFactor) : baseQty;

            Color qtyColor = displayQty < 0 ? Colors.red.shade50 : Colors.green.shade50;
            Color qtyTextColor = displayQty < 0 ? Colors.red.shade800 : Colors.green.shade800;

            return DropdownMenuItem<int>(
              value: itemIndex,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s['expiry_date'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: qtyColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: qtyTextColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      displayQty % 1 == 0 ? displayQty.toInt().toString() : displayQty.toStringAsFixed(2),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: qtyTextColor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: this.controller.isReadOnly.value
              ? null
              : (newIndex) {
            if (newIndex != null) {
              final selectedStock = stockList[newIndex];
              controller.changeExpiryDate(
                  index,
                  selectedStock['expiry_date'],
                  specificBatchNo: selectedStock['batch_no']?.toString() ?? ''
              );
            }
          },
        ),
      ),
    );
  }

  DataCell _buildStockDisplayCell(int index, CreditProductsController controller) {
    double calculatedStock = controller.getCalculatedStockForDisplay(index);
    bool isAlert = controller.shouldShowStockAlert(index);

    return DataCell(
      Container(
        height: 45,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5))
        ),
        child: Text(
          _formatSmart(calculatedStock),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isAlert ? Colors.red : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  DataColumn _buildDataColumn(String text, double fixedWidth, double _) {
    return DataColumn(
      label: Container(
        width: fixedWidth,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5))),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800), textAlign: TextAlign.center),
      ),
    );
  }

  DataCell _buildDataCell(String value, {TextAlign textAlign = TextAlign.right}) {
    return DataCell(Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Align(alignment: textAlign == TextAlign.center ? Alignment.center : Alignment.centerRight, child: Text(value, style: const TextStyle(fontSize: 13), textAlign: textAlign)),
    ));
  }

  DataCell _buildEditableCell(TextEditingController controller, Function(String) onChanged, [TextInputType keyboardType = TextInputType.text, bool readOnly = false]) {
    return DataCell(Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Center(
        child: TextFormField(
          controller: controller,
          readOnly: readOnly || this.controller.isReadOnly.value,
          textAlign: TextAlign.center,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onTap: () {
            if (controller.text.isNotEmpty && !readOnly && !this.controller.isReadOnly.value) {
              controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
            }
          },
          decoration: InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true, fillColor: (readOnly || this.controller.isReadOnly.value) ? Colors.grey.shade200 : Colors.transparent, filled: true),
          style: TextStyle(fontSize: 13, color: (readOnly || this.controller.isReadOnly.value) ? Colors.grey.shade700 : Colors.black),
        ),
      ),
    ));
  }

  Widget _buildCalculationsSection(CreditCalculationsController calculationsController) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            _buildCalculationRow('الإجمالي', _formatSmart(calculationsController.total.value)),
            const SizedBox(height: 4),
            _buildDiscountDisplay(calculationsController),
            const SizedBox(height: 4),
            _buildTaxInput(calculationsController),
            const SizedBox(height: 4),
            _buildCalculationRow('الصافي', _formatSmart(calculationsController.netTotal.value), isTotal: true),
          ],
        ),
      );
    });
  }

  Widget _buildCalculationRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Expanded(child: Text('$label:', style: TextStyle(fontSize: 12, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600, color: Colors.blue.shade800))),
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(color: isTotal ? Colors.blue.shade100 : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade400, width: 0.8)),
            child: Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? Colors.blue.shade800 : Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountDisplay(CreditCalculationsController calculationsController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Expanded(child: Text('مجموع الخصم:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade800))),
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade400, width: 0.8)),
            child: Obx(() => Text(_formatSmart(calculationsController.discount.value), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Colors.grey.shade800))),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxInput(CreditCalculationsController calculationsController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        children: [
          Expanded(child: Text('الضريبة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade800))),
          SizedBox(
            width: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
              child: Text(_formatSmart(calculationsController.tax.value), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(CreditSaleController controller) {
    return Obx(() {
      bool isSaveDisabled = controller.isLoading.value ||
          controller.isReadOnly.value ||
          (controller.currentInvoiceId.value == null ? !controller.canPerformAction('add') : !controller.canPerformAction('edit'));

      bool isSearchEnabled = controller.canPerformAction('search');

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton('جديد', Icons.create, Colors.blue, controller.resetForm),
          const SizedBox(width: 6),
          _buildActionButton(
            controller.currentInvoiceId.value == null ? 'حفظ' : 'تعديل',
            controller.currentInvoiceId.value == null ? Icons.save : Icons.edit,
            controller.currentInvoiceId.value == null ? Colors.green : Colors.orange,
            isSaveDisabled ? null : controller.saveSale,
          ),
          const SizedBox(width: 6),
          _buildActionButton('طباعة', Icons.print, Colors.purple, controller.canPerformAction('print') ? controller.printSale : null),
          const SizedBox(width: 6),
          _buildActionButton(
            'بحث',
            Icons.search,
            Colors.orange,
            isSearchEnabled ? () async {
              final bool? shouldReset = await controller.navigateToPreviousInvoices();
              if (shouldReset == true) controller.resetForm();
            } : null,
          ),
        ],
      );
    });
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback? onPressed) {
    return Expanded(
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 8),
          elevation: 2,
        ),
      ),
    );
  }
}

// لاحظ التعديل هنا: أضفنا (CreditSaleController controller)
void _showTableSettingsSheet(BuildContext context, CreditSaleController controller) {
  Get.bottomSheet(
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.tune, color: Colors.blue.shade800, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'إعدادات عرض الجدول',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // خيار التاريخ
            Obx(() {
              final bool isActive = controller.showExpiryDate.value;
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'إظهار عمود تاريخ الانتهاء',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                value: isActive,
                onChanged: (val) => controller.toggleTableSetting('expiry', val),
                activeColor: Colors.blue.shade800,
                activeTrackColor: Colors.blue.shade200,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade200,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.orange.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    color: isActive ? Colors.orange : Colors.grey,
                    size: 22,
                  ),
                ),
              );
            }),

            // خيار الدفعة
            Obx(() {
              final bool isActive = controller.showBatchNumber.value;
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'إظهار عمود رقم الدفعة',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                value: isActive,
                onChanged: (val) => controller.toggleTableSetting('batch', val),
                activeColor: Colors.blue.shade800,
                activeTrackColor: Colors.blue.shade200,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade200,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.purple.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.qr_code,
                    color: isActive ? Colors.purple : Colors.grey,
                    size: 22,
                  ),
                ),
              );
            }),

            // خيار البونص (ك.ص)
            Obx(() {
              final bool isActive = controller.showBonusQuantity.value;
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'إظهار عمود البونص (ك.ص)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                value: isActive,
                onChanged: (val) => controller.toggleTableSetting('bonus', val),
                activeColor: Colors.blue.shade800,
                activeTrackColor: Colors.blue.shade200,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade200,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: isActive ? Colors.green : Colors.grey,
                    size: 22,
                  ),
                ),
              );
            }),
            
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.send, color: Colors.green.shade800, size: 24),
              ),
              const SizedBox(width: 12),
              Text('إعدادات الإرسال التلقائي',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Colors.green.shade900)),
            ]),
            const SizedBox(height: 8),

            Obx(() {
              final bool isActive = controller.isAutoWhatsAppEnabled.value;
              return Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('إرسال تلقائي عبر واتساب',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.black87 : Colors.grey.shade600,
                      )),
                    subtitle: Text('إرسال الفاتورة تلقائياً للعميل عند الحفظ',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    value: isActive,
                    onChanged: (val) => controller.toggleTableSetting('autoWhatsApp', val),
                    activeColor: Colors.green.shade800,
                    activeTrackColor: Colors.green.shade200,
                    inactiveThumbColor: Colors.grey.shade400,
                    inactiveTrackColor: Colors.grey.shade200,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.call,  // or a custom WhatsApp icon
                        color: isActive ? Colors.green : Colors.grey, size: 22),
                    ),
                  ),
                  if (isActive)
                    Padding(
                      padding: const EdgeInsets.only(right: 48.0, top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('التطبيق المفضل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Radio<String>(
                                value: 'com.whatsapp',
                                groupValue: controller.whatsappPackage.value,
                                onChanged: (val) {
                                  if (val != null) controller.setWhatsAppPackage(val);
                                },
                              ),
                              const Text('واتساب العادي', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 16),
                              Radio<String>(
                                value: 'com.whatsapp.w4b',
                                groupValue: controller.whatsappPackage.value,
                                onChanged: (val) {
                                  if (val != null) controller.setWhatsAppPackage(val);
                                },
                              ),
                              const Text('واتساب للأعمال', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
  );
}

class _CustomerSearchDialogContent extends StatefulWidget {
  final CreditSaleController controller;
  const _CustomerSearchDialogContent({required this.controller});

  @override
  State<_CustomerSearchDialogContent> createState() => _CustomerSearchDialogContentState();
}

class _CustomerSearchDialogContentState extends State<_CustomerSearchDialogContent> {
  late TextEditingController searchController;
  late RxList<SunCustomer> filteredList;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    filteredList = RxList<SunCustomer>(widget.controller.allAvailableCustomers);

    searchController.addListener(() {
      final query = searchController.text.toLowerCase();
      if (query.isEmpty) {
        filteredList.assignAll(widget.controller.allAvailableCustomers);
      } else {
        filteredList.assignAll(widget.controller.allAvailableCustomers.where((c) =>
        c.customerName.toLowerCase().contains(query) ||
            c.customerNo.toString().contains(query)
        ).toList());
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ابحث باسم العميل أو الرقم...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              if (filteredList.isEmpty) return const Center(child: Text('لا توجد نتائج'));

              final displayedCustomers = filteredList.take(10).toList();

              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(width: 1.0, color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                    headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                    columns: const [DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))), DataColumn(label: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold)))],
                    rows: displayedCustomers.map<DataRow>((customer) {
                      return DataRow(
                        onSelectChanged: (_) {
                          widget.controller.selectCustomer(customer);
                          Get.back();
                        },
                        cells: [DataCell(Text(customer.customerNo.toString())), DataCell(Text(customer.customerName))],
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _CollectorSearchDialogContent extends StatelessWidget {
  final CreditInputSectionController controller;
  const _CollectorSearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          TextField(
            controller: controller.collectorSearchController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ابحث بالرقم أو الاسم...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              if (controller.filteredCollectors.isEmpty) return const Center(child: Text('لا توجد نتائج'));
              final displayedCollectors = controller.filteredCollectors.take(10).toList();
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(width: 1.0, color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                    headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                    columns: const [DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))), DataColumn(label: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold)))],
                    rows: displayedCollectors.map<DataRow>((collector) {
                      return DataRow(
                        onSelectChanged: (_) => controller.selectCollector(collector['id'], collector['collector_name']),
                        cells: [DataCell(Text(collector['collector_no']?.toString() ?? '')), DataCell(Text(collector['collector_name'] ?? ''))],
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AgentSearchDialogContent extends StatelessWidget {
  final CreditInputSectionController controller;
  const _AgentSearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          TextField(
            controller: controller.agentSearchController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ابحث بالرقم أو الاسم...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() {
              if (controller.filteredAgents.isEmpty) return const Center(child: Text('لا توجد نتائج'));
              final displayedAgents = controller.filteredAgents.take(10).toList();
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    border: TableBorder.all(width: 1.0, color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                    headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                    columns: const [DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))), DataColumn(label: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold)))],
                    rows: displayedAgents.map<DataRow>((agent) {
                      return DataRow(
                        onSelectChanged: (_) => controller.selectAgent(agent['id'], agent['salesperson_name']),
                        cells: [DataCell(Text(agent['salesperson_no']?.toString() ?? '')), DataCell(Text(agent['salesperson_name'] ?? ''))],
                      );
                    }).toList(),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}