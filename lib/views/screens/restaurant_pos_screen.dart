import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/controllers/restaurant_pos_controller.dart';
import 'package:untitled4/utils/dialog_helper.dart';


class RestaurantPosScreen extends StatelessWidget {
  const RestaurantPosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final RestaurantPosController controller = Get.put(RestaurantPosController());

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
        title: Obx(() {
          if (controller.isEditMode.value) return const Text('عرض فاتورة');
          if (controller.isCreditSale.value) return const Text('طلبية آجل');
          if (controller.isNetworkSale.value) return const Text('طلبية شبكة');
          return const Text('طلبية نقداً');
        }),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final bool shouldExit = await DialogHelper.showExitConfirmationDialog();
            if (shouldExit) {
              Get.back();
            }
          },
        ),
        actions: [
          Obx(() => TextButton.icon(
            icon: const Icon(Icons.group_add_outlined, color: Colors.white),
            label: const Text('آجل', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: (controller.isSaving.value || controller.isInvoiceFinalized.value || controller.isEditMode.value || !controller.canMakeCreditSale)
                ? null
                : () => controller.handleCreditSale(),
          )),
          Obx(() => TextButton.icon(
            icon: const Icon(Icons.wifi_tethering, color: Colors.white),
            label: const Text('شبكة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: (controller.isSaving.value || controller.isInvoiceFinalized.value || controller.isEditMode.value || !controller.canMakeCashSale)
                ? null
                : () => controller.handleNetworkSale(),
          )),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'إعدادات الطباعة',
            onPressed: controller.showPrintSettingsDialog,
          ),
          // IconButton(
          //   icon: const Icon(Icons.sync),
          //   tooltip: 'مزامنة الفواتير غير المرفوعة',
          //   onPressed: controller.syncOfflineInvoices,
          // ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.all(12.0),
                children: [
                  _buildTransactionHeader(context, controller),
                  const SizedBox(height: 12),
                  _buildInputSection(controller),
                  const Divider(height: 20, thickness: 1),
                  _buildCategoriesSection(controller),
                  const SizedBox(height: 12),
                  _buildItemsSection(controller),
                  const Divider(height: 20, thickness: 1),
                  _buildProductsTable(controller),
                  const SizedBox(height: 12),
                  _buildBottomPanel(controller),
                ],
              );
            }),
          ),
          SafeArea(
            top: false,
            child: _buildActionButtonsBar(context, controller),
          ),
        ],
      ),
    ));
  }

  Widget _buildTransactionHeader(BuildContext context, RestaurantPosController controller) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.numbers, size: 18, color: Colors.blue),
                const SizedBox(width: 6),
                Text('رقم الحركة: ${controller.currentInvoiceNumber.value}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue))
              ]),
            )),
            InkWell(
              onTap: () => controller.selectTransactionDate(context),
              borderRadius: BorderRadius.circular(8),
              child: Obx(() => Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration:
                BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(DateFormat('yyyy-MM-dd').format(controller.transactionDate.value),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
                ]),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputSection(RestaurantPosController controller) {
    return Column(
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _buildCompactInput(controller.orderNumberController,
                  label: 'رقم الطلب', icon: Icons.confirmation_number_outlined, readOnly: true)),
          const SizedBox(width: 8),
          Expanded(
              child: _buildCompactInput(controller.tableNumberController,
                  label: 'رقم الطاولة', icon: Icons.table_restaurant_outlined, isNumber: true)),
        ]),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Obx(() {
              if (controller.isCreditSale.value) {
                return _buildCompactInput(
                  controller.customerAccountController,
                  label: 'الحساب',
                  icon: Icons.person_pin_circle_outlined,
                  readOnly: true,
                );
              } else {
                return _buildCompactInput(controller.boxController,
                    label: 'الصندوق', icon: Icons.account_balance_wallet_outlined, readOnly: true);
              }
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: _buildCompactInput(controller.storeController,
                  label: 'المخزن', icon: Icons.store_mall_directory_outlined, readOnly: true)),
        ]),
        const SizedBox(height: 6),
        _buildCurrencyDropdown(controller),
        const SizedBox(height: 6),
        _buildCompactInput(controller.customerNameController, label: 'الزبون', icon: Icons.person_outline),
      ],
    );
  }

  Widget _buildCategoriesSection(RestaurantPosController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('الأقسام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Spacer(),
              SizedBox(
                width: Get.width * 0.5,
                height: 40,
                child: TextField(
                  controller: controller.categorySearchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن قسم...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 65, // Finger-friendly touch target height
          child: Obx(() {
            if (controller.filteredCategories.isEmpty) {
              return const Center(child: Text('لا توجد أقسام مطابقة'));
            }
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.filteredCategories.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final category = controller.filteredCategories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _categoryButton(controller, category),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildItemsSection(RestaurantPosController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Obx(() => Text(
                'الوجبات: ${controller.selectedCategory['name'] ?? 'اختر قسمًا'}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 35,
                child: TextField(
                  controller: controller.itemSearchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن وجبة...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 120,
              maxHeight: 370,
            ),
            child: Obx(() {
              if (controller.isLoadingItems.value) return const Center(child: CircularProgressIndicator());
              if (controller.filteredItems.isEmpty) return const Center(child: Text('لا توجد وجبات'));

              return LayoutBuilder(
                builder: (context, constraints) {
                  final double maxWidth = constraints.maxWidth;
                  const double spacing = 12.0;

                  final int columnCount = (maxWidth / (140 + spacing)).floor().clamp(1, 10);
                  final double cardWidth = (maxWidth - (spacing * (columnCount - 1)) - 24) / columnCount;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: 16.0,
                      children: controller.filteredItems.map((item) {
                        return _buildItemCard(controller, item, width: cardWidth);
                      }).toList(),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTable(RestaurantPosController controller) {
    const double rowHeight = 48.0;
    const double headerHeight = 40.0;
    const int visibleRows = 4;
    const double tableHeight = headerHeight + (rowHeight * visibleRows);
    return SizedBox(
      height: tableHeight,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Obx(() {
            controller.netTotal.value; // Force reactivity when quantities re-calculate total
            return DataTable(
              headingRowHeight: headerHeight,
              dataRowMinHeight: rowHeight,
              dataRowMaxHeight: rowHeight,
              columnSpacing: 10,
              horizontalMargin: 8,
              headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
              border: TableBorder.all(width: 1.0, color: Colors.grey.shade300),
              columns: const [
                DataColumn(label: SizedBox(width: 30, child: Center(child: Text('م')))),
                DataColumn(label: SizedBox(width: 60, child: Center(child: Text('الرقم')))),
                DataColumn(label: SizedBox(width: 150, child: Text('اسم الوجبة'))),
                DataColumn(label: SizedBox(width: 50, child: Center(child: Text('الوحدة')))),
                DataColumn(label: SizedBox(width: 50, child: Center(child: Text('الكمية')))),
                DataColumn(label: SizedBox(width: 80, child: Center(child: Text('القيمة')))),
                DataColumn(label: SizedBox(width: 90, child: Center(child: Text('الإجمالي')))),
                DataColumn(label: SizedBox(width: 120, child: Text('ملاحظات'))),
              ],
              rows: List.generate(controller.addedProducts.length, (index) {
                Map<String, dynamic> product = controller.addedProducts[index];
                
                if (product['isEmpty'] == true) {
                  return DataRow(
                      color: WidgetStateProperty.resolveWith(
                              (states) => controller.selectedRowIndex.value == index ? Colors.blue.shade200 : null),
                      selected: controller.selectedRowIndex.value == index,
                      onSelectChanged: (isSelected) => controller.selectedRowIndex.value = index,
                      cells: [
                        DataCell(Center(child: Text((index + 1).toString()))),
                        const DataCell(Center(child: Text(''))),
                        const DataCell(Text('')),
                        const DataCell(Center(child: Text(''))),
                        DataCell(_buildEditableQuantityCell(controller, controller.quantityControllers[index])),
                        const DataCell(Center(child: Text(''))),
                        const DataCell(Center(child: Text(''))),
                        DataCell(_buildEditableNotesCell(controller, controller.notesControllers[index])),
                      ]);
                }

                double price = product['price'];
                double discountPercent = product['discount'];
                double taxPercent = product['tax'];
                double quantity = double.tryParse(controller.quantityControllers[index].text) ?? 0.0;
                double finalPricePerUnit = price - (price * discountPercent / 100) + (price * taxPercent / 100);
                double totalItem = finalPricePerUnit * quantity;
                return DataRow(
                    color: WidgetStateProperty.resolveWith( 
                            (states) => controller.selectedRowIndex.value == index ? Colors.blue.shade200 : null),
                    selected: controller.selectedRowIndex.value == index,
                    onSelectChanged: (isSelected) => controller.selectedRowIndex.value = index,
                    cells: [
                      DataCell(Center(child: Text((index + 1).toString()))),
                      DataCell(Center(child: Text(product['number'].toString()))),
                      DataCell(Text(product['name'])),
                      DataCell(
                        Center(
                          child: (product['units_list'] == null || (product['units_list'] as List).isEmpty)
                              ? Text(product['unit']?.toString() ?? '')
                              : DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: (product['units_list'] as List<dynamic>).any((u) => u['unit_name'].toString() == product['unit'])
                                        ? product['unit']
                                        : (product['units_list'] as List<dynamic>).first['unit_name'].toString(),
                                    isDense: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    items: (product['units_list'] as List<dynamic>).map((u) {
                                      return DropdownMenuItem<String>(
                                        value: u['unit_name'].toString(),
                                        child: Text(u['unit_name'].toString()),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        controller.changeItemUnit(index, val);
                                      }
                                    },
                                  ),
                                ),
                        ),
                      ),
                      DataCell(_buildEditableQuantityCell(controller, controller.quantityControllers[index])),
                      DataCell(Center(child: Text(product['price'].toStringAsFixed(0)))),
                      DataCell(Center(child: Text(totalItem.round().toString()))),
                      DataCell(_buildEditableNotesCell(controller, controller.notesControllers[index])),
                    ]);
              }),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(RestaurantPosController controller) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        children: [
          _buildNumericKeypad(controller),
          const SizedBox(height: 12),
          _buildCalculationsSection(controller),
        ],
      ),
    );
  }

  Widget _buildActionButtonsBar(BuildContext context, RestaurantPosController controller) {
    final userState = Get.find<UserState>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), spreadRadius: 0, blurRadius: 10)],
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1.0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(() => _buildActionButton(
              'جديد', Icons.create, Colors.blue, 
              (controller.isSaving.value) ? null : controller.resetForm
            )),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Obx(() => _buildActionButton(
                controller.isSaving.value ? 'جاري...' : 'دفع',
                Icons.payment,
                Colors.green,
                (controller.isCreditSale.value ||
                    controller.isEditMode.value ||
                    controller.isSaving.value ||
                    controller.isInvoiceFinalized.value ||
                    !controller.canMakeCashSale)
                    ? null
                    : () => controller.handleCashSale(),
              ))),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() => _buildActionButton(
              'طباعة', Icons.print, Colors.purple, 
              (controller.isSaving.value) ? null : controller.handlePrint
            )),
          ),
          // Obx(() {
          //   if (userState.safeId == '0') {
          //     return Expanded(
          //       child: Row(children: [
          //         const SizedBox(width: 8),
          //         Expanded(
          //             child: _buildActionButton(
          //                 'بحث', Icons.search, Colors.orange, () => _showInvoiceSearchDialog(context, controller))),
          //       ]),
          //     );
          //   } else {
          //     return const SizedBox.shrink();
          //   }
          // }),
        ],
      ),
    );
  }

  Widget _buildCalculationsSection(RestaurantPosController controller) {
    return Obx(() => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 12.0,
        children: [
          _buildCalculationItem(
            'المجموع',
            _displayValueContainer(controller.total.value.toString()),
          ),
          _buildCalculationItem(
            'التخفيض',
            _inputValueContainer(controller.discountController, isReadOnly: true),
          ),
          _buildCalculationItem(
            'الضريبة',
            _inputValueContainer(controller.taxController, isReadOnly: true),
          ),
          _buildCalculationItem(
            'المبلغ المطلوب',
            _displayValueContainer(controller.netTotal.value.toString(), isTotal: true),
          ),
          _buildCalculationItem(
            'مجموع الكميات',
            _displayValueContainer(controller.totalQuantities.value.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')),
          ),
        ],
      ),
    ));
  }

  Widget _buildCalculationItem(String label, Widget valueWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            valueWidget,
          ],
        ),
      ),
    );
  }

  Widget _displayValueContainer(String value, {bool isTotal = false}) {
    return Container(
      height: 35,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: isTotal ? Colors.yellow.shade200 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade400)),
      child: Text(value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isTotal ? Colors.red.shade900 : Colors.black)),
    );
  }

  Widget _inputValueContainer(TextEditingController textController, {bool isReadOnly = false}) {
    return SizedBox(
      height: 35,
      width: double.infinity,
      child: TextFormField(
        controller: textController,
        readOnly: isReadOnly,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
          filled: true,
          fillColor: isReadOnly ? Colors.grey.shade200 : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  Widget _buildNumericKeypad(RestaurantPosController controller) {
    Widget numButton(String label, {String? value}) {
      final String processValue = value ?? label;

      return Padding(
        padding: const EdgeInsets.all(3.0),
        child: ElevatedButton(
          onPressed: () => controller.onNumpadPress(processValue),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 45),
            padding: EdgeInsets.zero,
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          child: Text(label),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: numButton('نص', value: '1/2')),
              Expanded(child: numButton('9')),
              Expanded(child: numButton('8')),
              Expanded(child: numButton('7')),
            ],
          ),
          Row(
            children: [
              Expanded(child: numButton('ربع', value: '1/4')),
              Expanded(child: numButton('6')),
              Expanded(child: numButton('5')),
              Expanded(child: numButton('4')),
            ],
          ),
          Row(
            children: [
              Expanded(child: numButton('ثُمن', value: '1/8')),
              Expanded(child: numButton('3')),
              Expanded(child: numButton('2')),
              Expanded(child: numButton('1')),
            ],
          ),
          Row(
            children: [
              Expanded(flex: 1, child: numButton('C')),
              Expanded(flex: 1, child: numButton('.')),
              Expanded(flex: 2, child: numButton('0')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback? onPressed) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }

  void _showInvoiceSearchDialog(BuildContext context, RestaurantPosController controller) {
    // controller.isSearchingCreditInvoices.value = false;
    // controller.searchInvoices();

    Get.dialog(
      AlertDialog(
        title: Obx(() => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('بحث عن فاتورة', style: TextStyle(fontSize: 18)),
            ToggleButtons(
              isSelected: [
                !controller.isSearchingCreditInvoices.value,
                controller.isSearchingCreditInvoices.value,
              ],
              onPressed: (index) {
                // controller.isSearchingCreditInvoices.value = (index == 1);
                // controller.searchInvoices();
              },
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: Theme.of(context).primaryColor,
              constraints: const BoxConstraints(minHeight: 32.0),
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('نقداً')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('آجل')),
              ],
            )
          ],
        )),
        contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        content: SizedBox(
          width: Get.width * 0.9,
          height: Get.height * 0.7,
          child: Column(
            children: [
              TextField(
                controller: controller.invoiceSearchController,
                decoration: _inputDecoration('يمكنك البحث هنا لفلترة النتائج...'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  if (controller.isSearching.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (controller.searchResults.isEmpty) {
                    return const Center(child: Text('لا توجد فواتير.'));
                  }
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                        columns: const [
                          DataColumn(label: Text('رقم الفاتورة')),
                          DataColumn(label: Text('اسم المستفيد')),
                          DataColumn(label: Text('المبلغ')),
                          DataColumn(label: Text('التاريخ')),
                          DataColumn(label: Text('الطاولة')),
                          DataColumn(label: Text('المرجع')),
                          DataColumn(label: Text('المستخدم')),
                        ],
                        rows: controller.searchResults.map((invoice) {
                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                              if (invoice.traLstId == '803') {
                                return Colors.orange.shade50;
                              }
                              return null;
                            }),
                            cells: [
                              DataCell(Text(invoice.invoiceNumber)),
                              DataCell(Text(invoice.customerName)),
                              DataCell(Text(invoice.amount.toStringAsFixed(0))),
                              DataCell(Text(invoice.date)),
                              DataCell(Text(invoice.table)),
                              DataCell(Text(invoice.reference)),
                              DataCell(Text(invoice.userName)),
                            ],
                            onSelectChanged: (_) {
                              // controller.loadInvoiceForEdit(invoice.invoiceNumber);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
      ),
      barrierDismissible: false,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _buildCompactInput(TextEditingController controller,
      {required String label, required IconData icon, bool isNumber = false, bool readOnly = false}) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
          fillColor: readOnly ? Colors.grey.shade200 : null,
          filled: readOnly,
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown(RestaurantPosController controller) {
    return SizedBox(
      height: 48,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          flex: 3,
          child: Obx(() => DropdownButtonFormField<String>(
            initialValue: controller.selectedCurrencyId.value.isEmpty ? null : controller.selectedCurrencyId.value,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: 'العملة*',
                prefixIcon: const Icon(Icons.currency_exchange_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                isDense: true),
            hint: const Text('اختر', style: TextStyle(fontSize: 12)),
            onChanged: controller.onCurrencyChanged,
            items: controller.currencies.map((currency) {
              return DropdownMenuItem<String>(
                  value: currency['id'],
                  child: Text(currency['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));
            }).toList(),
          )),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
              controller: controller.exchangeRateController,
              readOnly: true,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                  labelText: 'س.الصرف',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade200)),
        ),
      ]),
    );
  }


  Widget _categoryButton(RestaurantPosController controller, Map<String, dynamic> category) {
    return Obx(() {
      final bool isSelected = controller.selectedCategory['id'] == category['id'];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120),
          child: InkWell(
            onTap: () => controller.selectCategory(category),
            borderRadius: BorderRadius.circular(25),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF3374EA) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.blue.shade200,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: Colors.indigo.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
                    : [],
              ),
              child: Center(
                child: Text(
                  category['name'],
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.indigo.shade800,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAddedQuantityBadge(RestaurantPosController controller, Map<String, dynamic> item) {
    return Obx(() {
      final productIndex = controller.addedProducts.indexWhere((p) => p['id'] == item['id']);
      if (productIndex == -1) return const SizedBox.shrink();
      final quantity = double.tryParse(controller.quantityControllers[productIndex].text) ?? 0.0;
      if (quantity <= 0) return const SizedBox.shrink();

      return Positioned(
        top: -8,
        right: -8,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 3)],
          ),
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                quantity.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildItemCard(RestaurantPosController controller, Map<String, dynamic> item, {required double width}) {
    final imageBytes = item['imageBase'];

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => controller.addItemToTable(item),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Card(
                    elevation: 3,
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: (imageBytes != null && imageBytes.isNotEmpty)
                        ? Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                        : Image.asset(
                      'assets/images/placeholder.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  _buildAddedQuantityBadge(controller, item),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item['name'],
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${(item['price'] as num).toStringAsFixed(0)} ريال',
              style: TextStyle(fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableQuantityCell(RestaurantPosController controller, TextEditingController qtyController) {
    return SizedBox(
      width: 50,
      child: TextFormField(
        controller: qtyController,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) => controller.calculateTotals(),
        decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder(), contentPadding: EdgeInsets.zero),
      ),
    );
  }

  Widget _buildEditableNotesCell(RestaurantPosController controller, TextEditingController notesController) {
    return SizedBox(
      width: 120,
      child: TextFormField(
        controller: notesController,
        decoration: const InputDecoration(
            hintText: 'ملاحظة...', isDense: true, border: UnderlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 4)),
      ),
    );
  }
}

