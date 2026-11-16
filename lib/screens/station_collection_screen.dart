import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:untitled4/screens/controllers/station_collection_controller.dart';
import 'package:untitled4/screens/controllers/station_transaction_header_controller.dart';
import 'package:untitled4/screens/controllers/station_input_section_controller.dart';
import 'package:untitled4/screens/controllers/station_products_controller.dart';
import 'package:untitled4/screens/controllers/station_calculations_controller.dart';
import 'package:untitled4/utils/dialog_helper.dart';
import 'package:untitled4/models/sun_box.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/models/sun_store.dart';
import 'package:untitled4/models/sun_customer.dart';
import '../i_price_change_permission.dart';

const String _kCurrentScreenName = 'StationsCollectionScreen';

class StationsCollectionScreen extends StatefulWidget {
  final String? invoiceId;
  const StationsCollectionScreen({super.key, this.invoiceId});

  @override
  State<StationsCollectionScreen> createState() => _StationsCollectionScreenState();
}

class _StationsCollectionScreenState extends State<StationsCollectionScreen> {
  late final StationsCollectionController controller;
  late final String _controllerTag;
  final TextEditingController _productSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controllerTag = widget.invoiceId ?? DateTime.now().millisecondsSinceEpoch.toString();
    controller = Get.put(
      StationsCollectionController(
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
    Get.delete<StationsCollectionController>(tag: _controllerTag, force: true);
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
        appBar: AppBar(title: const Text('تنبيه صلاحيات')),
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
          title: Obx(() {
            String title;
            if (controller.isUtilityModeActive.value) {
              title = controller.currentInvoiceId.value == null
                  ? 'فاتورة خدمات المحطة (كهرباء / ماء)'
                  : (controller.isReadOnly.value ? 'عرض فاتورة خدمات' : 'تعديل فاتورة خدمات');
            } else {
              title = controller.currentInvoiceId.value == null
                  ? 'فاتورة بيع المحطات'
                  : (controller.isReadOnly.value ? 'عرض فاتورة' : 'تعديل فاتورة');
            }
            return Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }),
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
              onPressed: () => _showTableSettingsSheet(context),
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
              onPressed: controller.isReadOnly.value ? null : () => controller.performManualSync(),
            )),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTransactionHeader(controller.headerController),
                    const SizedBox(height: 8),
                    _buildInputSection(controller.inputController),
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
                    color: Colors.grey.withValues(alpha: 0.3),
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
      ),
    );
  }

  Widget _buildTransactionHeader(StationsCollectionTransactionHeaderController headerController) {
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
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
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
            Container(
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
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(StationsCollectionInputSectionController inputController) {
    return Column(
      children: [
        _buildBoxDropdown(inputController),
        _buildCurrencyDropdown(inputController),
        Obx(() => controller.isUtilityModeActive.value
            ? _buildUtilityCustomerInputRow(inputController)
            : _buildCustomerInputRow(
                label: 'الزبون*',
                icon: Icons.person,
                controller: inputController.customerNameController,
                isReadOnly: controller.isReadOnly.value,
              )),
        _buildStoreDropdown(inputController),
        Obx(() => controller.isUtilityModeActive.value
            ? _buildUtilitySubscriptionFeeRow(inputController)
            : _buildPumpInputRow(inputController)),
      ],
    );
  }

  Widget _buildUtilityCustomerInputRow(StationsCollectionInputSectionController inputController) {
    final bool isReadOnly = controller.isReadOnly.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildLabelWithIcon(Icons.person_pin, 'العميل / المشترك*'),
          Expanded(
            child: SizedBox(
              height: 35,
              child: TypeAheadField<SunCustomer>(
                controller: inputController.customerNameController,
                builder: (context, textController, focusNode) {
                  return TextField(
                    controller: textController,
                    focusNode: focusNode,
                    readOnly: isReadOnly,
                    style: const TextStyle(fontSize: 14),
                    decoration: _buildInputDecoration(
                      disabled: isReadOnly,
                      hint: 'ابحث عن المشترك (بالاسم أو الرقم)...',
                      suffixIcon: textController.text.isNotEmpty && !isReadOnly
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => inputController.clearSelectedCustomer(),
                            )
                          : const Icon(Icons.search, size: 18, color: Colors.grey),
                    ),
                  );
                },
                suggestionsCallback: (query) => inputController.searchCustomers(query),
                itemBuilder: (context, SunCustomer customer) {
                  final readingStr = customer.costNext != null ? _formatSmart(customer.costNext) : '0';
                  final feeStr = customer.costRsom != null ? _formatSmart(customer.costRsom) : '0';
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        customer.customerNo.toString(),
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 10),
                      ),
                    ),
                    title: Text(customer.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                      'آخر قراءة: $readingStr | رسوم: $feeStr${customer.phoneNumber != null ? " | هاتف: ${customer.phoneNumber}" : ""}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                  );
                },
                onSelected: (SunCustomer customer) {
                  inputController.onCustomerSelected(customer);
                },
                emptyBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('لم يتم العثور على عملاء مطابقين', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilitySubscriptionFeeRow(StationsCollectionInputSectionController inputController) {
    final bool isReadOnly = controller.isReadOnly.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildLabelWithIcon(Icons.price_change, 'رسوم الاشتراك'),
          Expanded(
            child: SizedBox(
              height: 35,
              child: TextField(
                controller: inputController.subscriptionFeeController,
                readOnly: isReadOnly,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
                decoration: _buildInputDecoration(
                  disabled: isReadOnly,
                  hint: '0.00',
                  suffixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Text('الأعباء', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxDropdown(StationsCollectionInputSectionController inputController) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildLabelWithIcon(Icons.account_balance, 'الصندوق*'),
          Expanded(
            child: Obx(() => _buildDropdownContainer(
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: inputController.selectedBox.value.isEmpty ? null : inputController.selectedBox.value,
                  hint: const Text('اختر الصندوق', style: TextStyle(fontSize: 12)),
                  isExpanded: true,
                  items: inputController.boxes.map((SunBox box) {
                    return DropdownMenuItem<String>(
                      value: box.boxName,
                      child: Text(box.boxName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: controller.isReadOnly.value ? null : inputController.updateSelectedBox,
                  isDense: true,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600, size: 20),
                ),
              ),
              disabled: controller.isReadOnly.value,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown(StationsCollectionInputSectionController inputController) {
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
                        items: inputController.currencies.map((SunCurrency currency) {
                          return DropdownMenuItem<String>(
                            value: currency.currencyName,
                            child: Text(currency.currencyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: controller.isReadOnly.value ? null : inputController.updateSelectedCurrency,
                        isDense: true,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600, size: 20),
                      ),
                    ),
                    disabled: controller.isReadOnly.value,
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
                      style: const TextStyle(fontSize: 13),
                      decoration: _buildInputDecoration(disabled: true),
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

  Widget _buildStoreDropdown(StationsCollectionInputSectionController inputController) {
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
                  items: inputController.stores.map((SunStore store) {
                    return DropdownMenuItem<String>(
                      value: store.nameStore,
                      child: Text(store.nameStore, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: controller.isReadOnly.value ? null : inputController.updateSelectedStore,
                  isDense: true,
                  icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600, size: 20),
                ),
              ),
              disabled: controller.isReadOnly.value,
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

  Container _buildDropdownContainer(Widget child, {bool disabled = false}) {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: disabled ? Colors.grey.shade200 : Colors.grey.shade50,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: child,
    );
  }

  InputDecoration _buildInputDecoration({String? hint, Widget? suffixIcon, bool disabled = false}) {
    return InputDecoration(
      filled: true,
      fillColor: disabled ? Colors.grey.shade200 : Colors.grey.shade50,
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      isDense: true,
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildCustomerInputRow({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool isReadOnly,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildLabelWithIcon(icon, label),
          Expanded(
            child: SizedBox(
              height: 35,
              child: TextField(
                controller: controller,
                readOnly: isReadOnly,
                style: const TextStyle(fontSize: 14),
                decoration: _buildInputDecoration(
                  disabled: isReadOnly,
                  hint: 'أدخل اسم الزبون...',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPumpInputRow(StationsCollectionInputSectionController inputController) {
    final bool disabled = controller.isReadOnly.value || !controller.isPumpModeActive.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _buildLabelWithIcon(Icons.local_gas_station, 'العداد / الطرمبة'),
          Expanded(
            child: SizedBox(
              height: 35,
              child: TypeAheadField<Map<String, dynamic>>(
                controller: inputController.meterNameController,
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: !disabled,
                    style: const TextStyle(fontSize: 14),
                    decoration: _buildInputDecoration(
                      disabled: disabled,
                      hint: 'ابحث عن العداد/الطرمبة...',
                      suffixIcon: controller.text.isNotEmpty && !disabled
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                controller.clear();
                                // Let productsController reset reading if needed
                                final productsCtrl = Get.find<StationsCollectionProductsController>(tag: _controllerTag);
                                productsCtrl.updatePreviousReadingAndPumpName('', 0);
                              },
                            )
                          : const Icon(Icons.search, size: 18, color: Colors.grey),
                    ),
                  );
                },
                suggestionsCallback: (query) => inputController.filterPumps(query),
                itemBuilder: (context, Map<String, dynamic> suggestion) {
                  return ListTile(
                    dense: true,
                    title: Text(suggestion['name']?.toString() ?? ''),
                    subtitle: Text('رقم: ${suggestion['no']}'),
                  );
                },
                onSelected: (Map<String, dynamic> suggestion) {
                  final pumpName = suggestion['name']?.toString();
                  final reading = (suggestion['reading'] as num?)?.toDouble() ?? 0.0;
                  
                  final productsCtrl = Get.find<StationsCollectionProductsController>(tag: _controllerTag);
                  inputController.meterNameController.text = pumpName ?? '';
                  productsCtrl.updatePreviousReadingAndPumpName(pumpName, reading);
                },
                emptyBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('لا توجد طرمبات مطابقة', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),
        ],
      ),
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
                      disabled: this.controller.isReadOnly.value,
                      hint: 'اضغط للاختيار...',
                      suffixIcon: onClear != null
                          ? IconButton(icon: const Icon(Icons.clear, size: 18, color: Colors.red), onPressed: onClear)
                          : null,
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

  Widget _buildProductsSection(BuildContext context, StationsCollectionProductsController productsController) {
    const double rowHeight = 45.0;
    const double headerHeight = 40.0;
    const int maxVisibleRows = 6;
    const double maxTableHeight = headerHeight + (rowHeight * maxVisibleRows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              const Text(' الأصناف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 10),
              Obx(() => controller.isReadOnly.value ? const SizedBox() : _buildProductSearch(context, productsController)),
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

  Widget _buildProductSearch(BuildContext context, StationsCollectionProductsController productsController) {
    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TypeAheadField<Map<String, dynamic>>(
                  controller: productsController.productSearchController,
                  direction: VerticalDirection.up,
                  builder: (context, controller, focusNode) {
                    return SizedBox(
                      height: 35,
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن صنف (اسم/رقم/باركود)...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: Icon(Icons.search, size: 18, color: Colors.blue.shade800),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
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
                                  backgroundColor: Colors.red.withValues(alpha: 0.8), colorText: Colors.white);
                            }
                          }
                        },
                      ),
                    );
                  },
                  suggestionsCallback: (query) => productsController.filterProducts(query),
                  itemBuilder: (context, item) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        item['item_no']?.toString() ?? '',
                        style: TextStyle(color: Colors.blue.shade800, fontSize: 10),
                      ),
                    ),
                    title: Text(
                      item['item_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      'السعر: ${(double.tryParse(item['item_price']?.toString() ?? '') ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  onSelected: (item) => productsController.addProduct(item),
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
                      if (productsController.cameraController != null && productsController.cameraController!.value.isInitialized)
                        CameraPreview(productsController.cameraController!),
                      Container(width: 250, height: 2, color: Colors.red.withValues(alpha:0.7)),
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
  Widget _buildProductsTable(BuildContext context, StationsCollectionProductsController productsController) {
    final double totalWidth = MediaQuery.of(context).size.width + 350;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(2, 3))],
      ),
      child: Obx(() {
        final List<Map<String, dynamic>> displayedProducts = productsController.products;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
            columnSpacing: 10,
            headingRowHeight: 40,
            dataRowMinHeight: 45,
            dataRowMaxHeight: 45,
            horizontalMargin: 8,
            border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),

            columns: [
              _buildDataColumn('رقم الصنف', 80, totalWidth),
              _buildDataColumn('اسم الصنف', 130, totalWidth),
              _buildDataColumn('الوحدة', 75, totalWidth),
              _buildDataColumn('الكمية', 70, totalWidth),
              _buildDataColumn('السعر', 80, totalWidth),
              if (controller.isPumpModeActive.value || controller.isUtilityModeActive.value)
                _buildDataColumn('القراءة السابقة', 80, totalWidth),
              if (controller.isPumpModeActive.value || controller.isUtilityModeActive.value)
                _buildDataColumn('القراءة الحالية', 80, totalWidth),
              if (controller.isUtilityModeActive.value)
                _buildDataColumn('رسوم الاشتراك', 85, totalWidth),
              _buildDataColumn('الإجمالي', 100, totalWidth),
            ],

            rows: displayedProducts.asMap().entries.map((entry) {
              final int index = entry.key;
              final Map<String, dynamic> product = entry.value;
              bool isEmptyRow = product['isEmpty'] == true;
              bool isEditable = !isEmptyRow && !controller.isReadOnly.value;
              final bool isAutoQty = controller.isPumpModeActive.value || controller.isUtilityModeActive.value;

              return DataRow(
                cells: [
                  _buildDataCell(isEmptyRow ? '' : product['item_no']?.toString() ?? '', textAlign: TextAlign.center),
                  _buildDataCell(isEmptyRow ? '________________' : product['item_name']?.toString() ?? ''),

                  DataCell(isEmptyRow ? const Text('') : _buildUnitDropdown(product, index, productsController)),
                  
                  isEmptyRow
                      ? _buildDataCell('')
                      : _buildEditableCell(
                          productsController.getQuantityController(index),
                          (val) => productsController.updateQuantity(index, val),
                          TextInputType.number,
                          (!isEditable || isAutoQty),
                        ),
                  
                  isEmptyRow
                      ? _buildDataCell('')
                      : _buildEditableCell(
                          productsController.getPriceController(index),
                          (val) => productsController.updatePrice(index, val),
                          const TextInputType.numberWithOptions(decimal: true),
                          (!isEditable || !productsController.isPriceChangeAllowed),
                        ),
                  if (controller.isPumpModeActive.value || controller.isUtilityModeActive.value)
                    (isEmptyRow && !controller.isUtilityModeActive.value && (product['pump_name'] == null || product['pump_name'].toString().isEmpty))
                        ? _buildDataCell('')
                        : _buildEditableCell(
                            productsController.getPrevReadingController(index),
                            (val) => productsController.updatePrevReading(index, val),
                            TextInputType.number,
                            controller.isReadOnly.value,
                          ),
                  if (controller.isPumpModeActive.value || controller.isUtilityModeActive.value)
                    (isEmptyRow && !controller.isUtilityModeActive.value && (product['pump_name'] == null || product['pump_name'].toString().isEmpty))
                        ? _buildDataCell('')
                        : _buildEditableCell(
                            productsController.getCurrReadingController(index),
                            (val) => productsController.updateCurrentReading(index, val),
                            TextInputType.number,
                            controller.isReadOnly.value,
                          ),
                  if (controller.isUtilityModeActive.value)
                    isEmptyRow
                        ? _buildDataCell('')
                        : _buildDataCell(
                            _formatSmart((product['trad_tra_tax'] as num?)?.toDouble() ?? 0.0),
                            textAlign: TextAlign.center,
                          ),
                  DataCell(
                    Row(
                      children: [
                        Expanded(child: Text(isEmptyRow ? '' : _formatSmart(product['total_item'] as double?), style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
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

  Widget _buildExpiryDropdown(Map<String, dynamic> product, int index, StationsCollectionProductsController controller) {
    final List<dynamic> stockList = product['stock_list'] ?? [];
    final double currentPackFactor = (product['pack_factor'] as num?)?.toDouble() ?? 1.0;

    if (stockList.isEmpty && !this.controller.isReadOnly.value) {
      return const Center(
        child: Text(
          'لا يوجد رصيد',
          style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }

    final String? currentExpiry = product['expiry_date'];

    if (this.controller.isReadOnly.value) {
      return Center(child: Text(currentExpiry ?? '-', style: const TextStyle(fontSize: 12)));
    }

    int? selectedStockIndex;
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
                      border: Border.all(color: qtyTextColor.withValues(alpha:0.3)),
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
          onChanged: (newIndex) {
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

  DataCell _buildStockDisplayCell(int index, StationsCollectionProductsController controller) {
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

  Widget _buildUnitDropdown(Map<String, dynamic> product, int index, StationsCollectionProductsController controller) {
    final List<dynamic> units = product['units_list'] ?? [];

    if (units.isEmpty || this.controller.isReadOnly.value) {
      return Center(child: Text(product['item_unit']?.toString() ?? '', style: const TextStyle(fontSize: 12)));
    }

    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: product['item_unit'],
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 16),
          style: const TextStyle(fontSize: 12, color: Colors.black),
          items: units.map<DropdownMenuItem<String>>((u) {
            return DropdownMenuItem<String>(
              value: u['unit_name'],
              child: Text(u['unit_name'], overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (newVal) => controller.changeItemUnit(index, newVal),
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
        decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5))
        ),
        child: Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
            textAlign: TextAlign.center
        ),
      ),
    );
  }

  DataCell _buildDataCell(String value, {TextAlign textAlign = TextAlign.right}) {
    return DataCell(Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5))
      ),
      child: Align(
          alignment: textAlign == TextAlign.center ? Alignment.center : Alignment.centerRight,
          child: Text(value, style: const TextStyle(fontSize: 13), textAlign: textAlign)
      ),
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
          readOnly: readOnly,
          textAlign: TextAlign.center,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onTap: () {
            if (controller.text.isNotEmpty && !readOnly) {
              controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
            }
          },
          decoration: InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true, fillColor: readOnly ? Colors.grey.shade200 : Colors.transparent, filled: true),
          style: TextStyle(fontSize: 13, color: readOnly ? Colors.grey.shade700 : Colors.black),
        ),
      ),
    ));
  }

  Widget _buildCalculationsSection(StationsCollectionCalculationsController calculationsController) {
    return Obx(() {
      final bool isUtility = controller.isUtilityModeActive.value;
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            if (isUtility) ...[
              _buildCalculationRow('إجمالي الاستهلاك', _formatSmart(calculationsController.consumptionTotal.value)),
              const SizedBox(height: 4),
              _buildCalculationRow('رسوم الاشتراك / الأعباء', _formatSmart(calculationsController.totalCharges.value)),
              const SizedBox(height: 4),
            ],
            _buildCalculationRow('صافي الإجمالي', _formatSmart(calculationsController.total.value), isTotal: true),
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



  Widget _buildActionButtons(StationsCollectionController controller) {
    return Obx(() {
      bool isSaveDisabled = controller.isLoading.value ||
          controller.isReadOnly.value ||
          controller.currentInvoiceId.value != null ||
          (controller.currentInvoiceId.value == null && !controller.canPerformAction('add'));

      bool isSearchEnabled = controller.canPerformAction('search');

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton('جديد', Icons.create, Colors.blue, controller.resetForm),
          const SizedBox(width: 6),

          _buildActionButton(
            controller.currentInvoiceId.value == null ? 'حفظ' : 'محفوظ',
            controller.currentInvoiceId.value == null ? Icons.save : Icons.lock,
            controller.currentInvoiceId.value == null ? Colors.green : Colors.grey,
            isSaveDisabled ? null : controller.saveSale,
          ),

          const SizedBox(width: 6),

          _buildActionButton(
              'طباعة',
              Icons.print,
              Colors.purple,
              controller.canPerformAction('print') ? controller.printSale : null
          ),

          const SizedBox(width: 6),

          _buildActionButton(
              'بحث',
              Icons.search,
              Colors.orange,
              isSearchEnabled ? controller.navigateToPreviousInvoices : null
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

  void _showTableSettingsSheet(BuildContext context) {
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
              Obx(() {
                final bool isActive = controller.isPumpModeActive.value;
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'تفعيل نظام بيع البنزين',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  value: isActive,
                  onChanged: (val) {
                    controller.toggleTableSetting('pump_mode', val);
                    if (val) {
                      controller.toggleTableSetting('utility_mode', false);
                    }
                  },
                  activeThumbColor: Colors.blue.shade800,
                  activeTrackColor: Colors.blue.shade200,
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade200,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.orange.withValues(alpha:0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_gas_station,
                      color: isActive ? Colors.orange : Colors.grey,
                      size: 22,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Obx(() {
                final bool isUtility = controller.isUtilityModeActive.value;
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'تفعيل نظام فواتير الكهرباء والماء',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUtility ? FontWeight.bold : FontWeight.normal,
                      color: isUtility ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                  value: isUtility,
                  onChanged: (val) {
                    controller.toggleTableSetting('utility_mode', val);
                    if (val) {
                      controller.toggleTableSetting('pump_mode', false);
                    }
                  },
                  activeThumbColor: Colors.teal.shade800,
                  activeTrackColor: Colors.teal.shade200,
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade200,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUtility ? Colors.teal.withValues(alpha:0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.electric_bolt,
                      color: isUtility ? Colors.teal : Colors.grey,
                      size: 22,
                    ),
                  ),
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

}
