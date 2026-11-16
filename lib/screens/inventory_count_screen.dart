// lib/screens/inventory_count_screen.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // ✅ إضافة المكتبة
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

// استيراد الكنترولرات
import 'package:untitled4/screens/controllers/inventory_count_controller.dart';
import 'package:untitled4/screens/controllers/inventory_header_controller.dart';
import 'package:untitled4/screens/controllers/input_section_controller.dart';
import 'package:untitled4/screens/controllers/inventory_products_controller.dart';
import 'package:untitled4/screens/controllers/inventory_calculations_controller.dart';
import 'package:untitled4/utils/dialog_helper.dart';

// استيراد الموديلات
import 'package:untitled4/models/sun_store.dart';
import 'package:untitled4/models/sun_currency.dart';

class InventoryCountScreen extends StatefulWidget {
  final String? inventoryId;
  const InventoryCountScreen({super.key, this.inventoryId});

  @override
  State<InventoryCountScreen> createState() => _InventoryCountScreenState();
}

class _InventoryCountScreenState extends State<InventoryCountScreen> {
  late final InventoryCountController controller;
  late final String _controllerTag;

  @override
  void initState() {
    super.initState();
    _controllerTag = widget.inventoryId ?? DateTime.now().millisecondsSinceEpoch.toString();
    controller = Get.put(
      InventoryCountController(controllerTag: _controllerTag),
      tag: _controllerTag,
    );
  }

  @override
  void dispose() {
    Get.delete<InventoryCountController>(tag: _controllerTag, force: true);
    super.dispose();
  }

  String _formatSmart(double? value) {
    if (value == null) return '0';
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceAll(RegExp(r"0*$"), "").replaceAll(RegExp(r"\.$"), "");
  }

  // دالة لاختيار التاريخ
  Future<void> _pickDate(BuildContext context, Rx<DateTime> dateObs) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dateObs.value,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != dateObs.value) {
      dateObs.value = picked;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text('محضر جرد مخزني', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          centerTitle: true,
          backgroundColor: Colors.blue.shade800,
          toolbarHeight: 45.0,
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
            IconButton(
              icon: const Icon(Icons.settings, size: 24, color: Colors.white),
              tooltip: 'إعدادات الجدول',
              onPressed: () => _showTableSettingsSheet(context, controller),
            ),
          ],
        ),
        body: Stack(
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
                        _buildInputSection(context, controller.inputController, controller.headerController),
                        const SizedBox(height: 8),
                        _buildProductsSection(context, controller.productsController),
                        const SizedBox(height: 8),
                        _buildCalculationsSection(controller.calculationsController),
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
            Obx(() => controller.isLoading.value
                ? Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator()))
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. الرأس (تعديل كلمة الإغلاق إلى التاريخ)
  // ---------------------------------------------------------------------------
  Widget _buildTransactionHeader(InventoryHeaderController headerController) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12.0, // المسافة الأفقية بين العناصر
          runSpacing: 8.0, // المسافة العمودية عند النزول لسطر جديد
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min, // مهم جداً في Wrap
                children: [
                  const Icon(Icons.receipt_long, size: 18, color: Colors.blue),
                  const SizedBox(width: 6),
                  const Text('رقم المحضر: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.black87)),
                  Obx(() => Text(
                    headerController.transactionNumber.value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                  )),
                ],
              ),
            ),
            // ✅ تم التعديل: كلمة "التاريخ" بدلاً من الإغلاق
            InkWell(
              onTap: () => _pickDate(context, headerController.closingDate), // جعل هذا التاريخ أيضاً قابل للتعديل إن أردت
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // مهم جداً في Wrap
                  children: [
                    const Icon(Icons.event_note, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    const Text('التاريخ: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                    Obx(() => Text(
                      DateFormat('yyyy-MM-dd').format(headerController.closingDate.value),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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

  // ---------------------------------------------------------------------------
  // 2. المدخلات (تاريخ البدء قابل للتعديل + س.ص)
  // ---------------------------------------------------------------------------
  Widget _buildInputSection(BuildContext context, InputSectionController inputController, InventoryHeaderController headerController) {
    return Column(
      children: [
        // ✅ تاريخ البدء قابل للتعديل
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              _buildLabelWithIcon(Icons.timer_outlined, 'بدء الجرد'),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(context, headerController.startDate),
                  child: Container(
                    height: 35,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white, // لون أبيض ليدل على القابلية للتعديل
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Obx(() => Text(
                          DateFormat('yyyy-MM-dd').format(headerController.startDate.value),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        )),
                        const Icon(Icons.edit_calendar, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // المخزن
        Padding(
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
                        return DropdownMenuItem<String>(value: store.nameStore, child: Text(store.nameStore, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
                      }).toList(),
                      onChanged: inputController.updateSelectedStore,
                      isDense: true,
                      icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600, size: 20),
                    ),
                  ),
                )),
              ),
            ],
          ),
        ),
        // ✅ العملة + س.ص
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              _buildLabelWithIcon(Icons.currency_exchange, 'العملة'),
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
                              return DropdownMenuItem<String>(value: currency.currencyName, child: Text(currency.currencyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
                            }).toList(),
                            onChanged: inputController.updateSelectedCurrency,
                            isDense: true,
                            icon: Icon(Icons.arrow_drop_down, color: Colors.blue.shade600, size: 20),
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(width: 8),
                    // إضافة س.ص
                    const Text('س.ص:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 35,
                        child: TextField(
                          controller: inputController.exchangeRateController,
                          readOnly: true, // عادة يكون للقراءة فقط ويأتي من العملة
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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

  // ---------------------------------------------------------------------------
  // 3. الأصناف (تم توضيح الحدود)
  // ---------------------------------------------------------------------------
  Widget _buildProductsSection(BuildContext context, InventoryProductsController productsController) {
    // مجموع عروض الأعمدة تقريباً (70+150+75+50+120+70+70+70+80+70+80+80+40 = 1025)
    // نضع قيمة ثابتة لضمان ظهور كل الأعمدة بشكل جيد، مع السماح بالتمرير في الشاشات الصغيرة
    const double minContentWidth = 1140.0;
    
    // لضمان التناسق: إذا كانت الشاشة أكبر من المحتوى، اجعل الجدول يأخذ عرض الشاشة
    final double totalTableWidth = MediaQuery.of(context).size.width > minContentWidth 
        ? MediaQuery.of(context).size.width 
        : minContentWidth;

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
              _buildProductSearch(context, productsController),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            // ✅ حدود واضحة للإطار الخارجي
            border: Border.all(color: Colors.grey.shade600, width: 1.2),
            color: Colors.white,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: maxTableHeight),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: totalTableWidth),
                  child: Obx(() {
                    final bool showBatch = this.controller.showBatchNumber.value;
                    final bool showExpiry = this.controller.showExpiryDate.value;

                    return DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.blue.shade100),
                      columnSpacing: 10,
                      headingRowHeight: 40,
                      dataRowMinHeight: 45,
                      dataRowMaxHeight: 45,
                      horizontalMargin: 8,
                      dividerThickness: 1.0,
                      border: TableBorder.all(color: Colors.grey.shade400, width: 0.8),
                      columns: [
                        _buildDataColumn('رقم الصنف', 70),
                        _buildDataColumn('اسم الصنف', 150),
                        _buildDataColumn('الوحدة', 75),
                        _buildDataColumn('العبوة', 50),
                        if (showBatch) _buildDataColumn('رقم الدفعة', 90),
                        if (showExpiry) _buildDataColumn('تاريخ الانتهاء', 120),
                        _buildDataColumn('الرصيد ', 70),
                        _buildDataColumn('كمية الجرد', 70),
                        _buildDataColumn('التكلفة', 70),
                        _buildDataColumn('الإجمالي', 80),
                        _buildDataColumn('فارق ك الجرد', 70),
                        _buildDataColumn('قيمة الفائض', 80),
                        _buildDataColumn('قيمة العجز', 80),
                        _buildDataColumn('', 40),
                      ],
                      rows: productsController.products.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final Map<String, dynamic> product = entry.value;
                        bool isEmptyRow = product['isEmpty'] == true;
                        bool isEditable = !isEmptyRow;

                        return DataRow(
                          cells: [
                            _buildDataCell(isEmptyRow ? '' : product['item_no'].toString(), textAlign: TextAlign.center),
                            _buildDataCell(isEmptyRow ? '' : product['item_name'].toString()),
                            DataCell(isEmptyRow ? const SizedBox() : _buildUnitDropdown(product, index, productsController)),
                            _buildDataCell(isEmptyRow ? '' : _formatSmart(product['pack_factor']), textAlign: TextAlign.center),
                            if (showBatch) _buildDataCell(isEmptyRow ? '' : product['batch_no']?.toString() ?? ''),
                            if (showExpiry) DataCell(isEmptyRow ? const SizedBox() : _buildExpiryDropdown(product, index, productsController)),
                            _buildDataCell(isEmptyRow ? '' : _formatSmart(product['system_qty']), isBold: true),
                            isEditable
                                ? _buildEditableCell(productsController.getActualQtyController(index), (val) => productsController.updateActualQty(index, val))
                                : _buildDataCell(isEmptyRow ? '' : product['actual_qty'].toString(), textAlign: TextAlign.center),
                            isEditable
                                ? _buildEditableCell(productsController.getCostController(index), (val) => productsController.updateCost(index, val))
                                : _buildDataCell(isEmptyRow ? '' : _formatSmart(product['cost_price'])),
                            _buildDataCell(isEmptyRow ? '' : _formatSmart(product['total'])),
                            DataCell(isEmptyRow ? const SizedBox() : _buildDiffQtyCell(product['diff_qty'])),
                            _buildDataCell(isEmptyRow ? '' : _formatSmart(product['surplus_value']), color: Colors.green.shade700),
                            _buildDataCell(isEmptyRow ? '' : _formatSmart(product['deficit_value']), color: Colors.red.shade700),
                            DataCell(isEmptyRow ? const SizedBox() : IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () => productsController.removeProduct(index))),
                          ],
                        );
                      }).toList(),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper Methods for Table
  Widget _buildDiffQtyCell(double? value) {
    if (value == null) return const Text('');
    Color color = value == 0 ? Colors.black : (value > 0 ? Colors.green : Colors.red);
    return Container(
      alignment: Alignment.centerRight,
      child: Text(_formatSmart(value), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildUnitDropdown(Map<String, dynamic> product, int index, InventoryProductsController controller) {
    final List<dynamic> units = product['units_list'] ?? [];
    if (units.isEmpty) return Text(product['item_unit'] ?? '', style: const TextStyle(fontSize: 12));
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: product['item_unit'],
        isExpanded: true,
        style: const TextStyle(fontSize: 12, color: Colors.black),
        items: units.map<DropdownMenuItem<String>>((u) => DropdownMenuItem(value: u['unit_name'], child: Text(u['unit_name']))).toList(),
        onChanged: (val) => controller.changeItemUnit(index, val),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // القائمة المنسدلة لتاريخ الانتهاء (بتصميم شاشة البيع: تاريخ + كمية)
  // ---------------------------------------------------------------------------
  Widget _buildExpiryDropdown(Map<String, dynamic> product, int index, InventoryProductsController controller) {
    // جلب قائمة الدفعات (Stock List)
    final List<dynamic> stockList = product['stock_list'] ?? [];

    // إذا لم تكن هناك تواريخ
    if (stockList.isEmpty) {
      return const Center(child: Text('لا يوجد رصيد', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)));
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

    // جلب معامل العبوة لعرض الكمية بالوحدة الصحيحة داخل القائمة
    final double currentPackFactor = (product['pack_factor'] as num?)?.toDouble() ?? 1.0;

    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedStockIndex,
          hint: const Text('التاريخ', style: TextStyle(fontSize: 11, color: Colors.grey)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.blue),
          style: const TextStyle(fontSize: 12, color: Colors.black),

          // 🔥 هنا السحر: تحويل القائمة لعرض (التاريخ + الكمية) باستخدام الاندكس
          items: stockList.asMap().entries.map((entry) {
            final int itemIndex = entry.key;
            final Map<String, dynamic> s = entry.value;

            // حساب كمية هذه الدفعة تحديداً
            final double baseQty = (s['quantity'] as num?)?.toDouble() ?? 0.0;
            final double displayQty = currentPackFactor > 0 ? (baseQty / currentPackFactor) : baseQty;

            // تنسيق الألوان (أخضر للموجب، أحمر للسالب)
            Color qtyColor = displayQty < 0 ? Colors.red.shade50 : Colors.green.shade50;
            Color qtyTextColor = displayQty < 0 ? Colors.red.shade800 : Colors.green.shade800;

            return DropdownMenuItem<int>(
              value: itemIndex,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. التاريخ
                  Text(
                    s['expiry_date'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(width: 8),

                  // 2. شارة الكمية (Badge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: qtyColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: qtyTextColor.withOpacity(0.3))
                    ),
                    child: Text(
                      _formatSmart(displayQty), // استخدام نفس دالة التنسيق الموجودة في الصفحة
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: qtyTextColor
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          // عند الاختيار، يتم استدعاء دالة الكنترولر لتحديث السطر
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

  DataColumn _buildDataColumn(String text, double width) {
    return DataColumn(
      label: Container(width: width, alignment: Alignment.center, child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900), textAlign: TextAlign.center)),
    );
  }

  DataCell _buildDataCell(String value, {TextAlign textAlign = TextAlign.right, bool isBold = false, Color? color}) {
    return DataCell(Align(alignment: textAlign == TextAlign.center ? Alignment.center : Alignment.centerRight, child: Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black), textAlign: textAlign)));
  }

  DataCell _buildEditableCell(TextEditingController controller, Function(String) onChanged) {
    return DataCell(Center(child: TextFormField(
      controller: controller, textAlign: TextAlign.center, keyboardType: TextInputType.number, onChanged: onChanged,
      onTap: () { if (controller.text.isNotEmpty) controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length); },
      decoration: InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true, filled: true, fillColor: Colors.blue.shade50.withOpacity(0.5)),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    )));
  }



  Widget _buildProductSearch(BuildContext context, InventoryProductsController controller) {
    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TypeAheadField<Map<String, dynamic>>(
                  direction: VerticalDirection.up,
                  builder: (context, txtController, focusNode) {
                    return SizedBox(
                      height: 35,
                      child: TextField(
                        controller: txtController, focusNode: focusNode,
                        decoration: InputDecoration(hintText: 'ابحث عن صنف (اسم/رقم)...', hintStyle: const TextStyle(fontSize: 13), prefixIcon: Icon(Icons.search, size: 18, color: Colors.blue.shade800), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10), isDense: true, filled: true, fillColor: Colors.white),
                      ),
                    );
                  },
                  suggestionsCallback: (query) => controller.filterProducts(query),
                  itemBuilder: (context, item) => ListTile(dense: true, title: Text(item['item_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text('رقم: ${item['item_no']}', style: const TextStyle(fontSize: 11))),
                  onSelected: (item) => controller.addProduct(item),
                ),
              ),
              const SizedBox(width: 8),
              // ✅ زر الكاميرا (تبديل الوضع)
              InkWell(
                onTap: () => controller.toggleCamera(),
                child: Obx(() => Container(
                  height: 35,
                  width: 45,
                  decoration: BoxDecoration(
                    color: controller.isCameraVisible.value ? Colors.red : Colors.blue.shade700, // أحمر للإغلاق، أزرق للفتح
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    controller.isCameraVisible.value ? Icons.close : Icons.qr_code_scanner, 
                    color: Colors.white, size: 20
                  ),
                )),
              ),
            ],
          ),
          
          // ✅ منطقة الكاميرا (تظهر وتختفي)
          Obx(() {
            if (controller.isCameraVisible.value) {
              return Container(
                height: 250, // ارتفاع مناسب لرؤية الكاميرا والجدول معاً
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
                        controller: controller.cameraController,
                        onDetect: controller.onBarcodeDetect,
                      ),
                      // خط أحمر ليزر وهمي للتوجيه
                      Container(width: 250, height: 2, color: Colors.red.withOpacity(0.7)),
                      // زر إغلاق صريح إضافي
                      Positioned(
                        top: 5, right: 5,
                        child: IconButton(
                           icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
                           onPressed: () => controller.toggleCamera(),
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

  // ---------------------------------------------------------------------------
  // 4. الحسابات (✅ تم التعديل: مربعات واضحة مثل الـ TextFields)
  // ---------------------------------------------------------------------------
  Widget _buildCalculationsSection(InventoryCalculationsController calcs) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50, // خلفية القسم (مثل شاشة البيع)
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          children: [
            // --- السطر الأول ---
            Row(
              children: [
                // يمين: الاجمالي (النص ثم المربع)
                Expanded(child: _buildLabelAndBox(
                    label: 'الاجمالي',
                    value: _formatSmart(calcs.totalActualValue.value)
                )),
                const SizedBox(width: 15), // مسافة بين العمودين
                // يسار: عدد القطع
                Expanded(child: _buildLabelAndBox(
                    label: 'عدد القطع',
                    value: _formatSmart(calcs.totalItemsCount.value)
                )),
              ],
            ),
            const SizedBox(height: 10),

            // --- السطر الثاني ---
            Row(
              children: [
                // يمين: قيمة الرصيد
                Expanded(child: _buildLabelAndBox(
                    label: 'قيمة الرصيد',
                    value: _formatSmart(calcs.totalSystemValue.value)
                )),
                const SizedBox(width: 15),
                // يسار: عدد الرصيد
                Expanded(child: _buildLabelAndBox(
                    label: 'عدد الرصيد',
                    value: _formatSmart(calcs.totalSystemQty.value)
                )),
              ],
            ),
            const SizedBox(height: 10),

            // --- السطر الثالث ---
            Row(
              children: [
                // يمين: فارق القيمة
                Expanded(child: _buildLabelAndBox(
                    label: 'فارق القيمة',
                    value: _formatSmart(calcs.netDiffValue.value),
                    textColor: calcs.netDiffValue.value < 0 ? Colors.red : Colors.black
                )),
                const SizedBox(width: 15),
                // يسار: فارق الكمية
                Expanded(child: _buildLabelAndBox(
                    label: 'فارق الكمية',
                    value: _formatSmart(calcs.totalDiffQty.value),
                    textColor: calcs.totalDiffQty.value < 0 ? Colors.red : Colors.black
                )),
              ],
            ),
            const SizedBox(height: 10),

            // --- السطر الرابع ---
            Row(
              children: [
                // يمين: قيمة الفائض
                Expanded(child: _buildLabelAndBox(
                    label: 'قيمة الفائض',
                    value: _formatSmart(calcs.totalSurplusValue.value),
                    textColor: Colors.green.shade800
                )),
                const SizedBox(width: 15),
                // يسار: قيمة العجز
                Expanded(child: _buildLabelAndBox(
                    label: 'قيمة العجز',
                    value: _formatSmart(calcs.totalDeficitValue.value),
                    textColor: Colors.red.shade900
                )),
              ],
            ),
          ],
        ),
      );
    });
  }

  // ✅ التصميم الصحيح (النص أولاً -> ثم المربع)
  Widget _buildLabelAndBox({required String label, required String value, Color? textColor}) {
    return Row(
      children: [
        // 1. النص (العنوان) - يأتي في اليمين لأن الاتجاه RTL
        SizedBox(
          width: 70, // عرض ثابت للنص لضمان محاذاة المربعات تحت بعضها
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900, // لون النص أزرق غامق
            ),
          ),
        ),

        const SizedBox(width: 5),

        // 2. المربع (القيمة) - يأتي يسار النص
        Expanded(
          child: Container(
            height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white, // خلفية المربع بيضاء
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.black87
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. الأزرار
  // ---------------------------------------------------------------------------
  Widget _buildActionButtons(InventoryCountController controller) {
    return Obx(() {
      bool isDisabled = controller.isLoading.value;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton('جديد', Icons.create, Colors.blue, controller.productsController.clearAll),
            const SizedBox(width: 6),
            _buildActionButton('حفظ', Icons.save, Colors.green, isDisabled ? null : controller.saveInventory),
            const SizedBox(width: 6),
            _buildActionButton('طباعة', Icons.print, Colors.purple, () => Get.snackbar('تنبيه', 'قريباً')),
            const SizedBox(width: 6),
            _buildActionButton('بحث', Icons.search, Colors.orange, controller.navigateToSearch),
          ],
        ),
      );
    });
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback? onPressed) {
    return Expanded(
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
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

  void _showTableSettingsSheet(BuildContext context, InventoryCountController controller) {
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
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