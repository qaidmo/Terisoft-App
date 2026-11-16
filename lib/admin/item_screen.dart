import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/item_controller.dart';
import 'package:untitled4/models/sun_item.dart';
import 'package:untitled4/models/sun_item_group.dart';
import 'package:untitled4/models/cost_center.dart';


class ItemsScreen extends StatelessWidget {
  ItemsScreen({super.key});

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _showItemSearchDialog(BuildContext context, ItemController controller) {
    Get.dialog(
      _ItemSearchDialog(controller: controller),
      barrierDismissible: false,
    );
  }

  void _showGroupSearchDialog(BuildContext context, ItemController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن مجموعة'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: _GroupSearchDialogContent(controller: controller),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))
        ],
      ),
      barrierDismissible: false,
    );
  }

  void _showCostCenterSearchDialog(BuildContext context, ItemController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('بحث عن مركز تكلفة'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: _CostCenterSearchDialogContent(controller: controller),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ItemController controller = Get.put(ItemController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الأصناف'),
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.refresh),
            onPressed:
            controller.isLoading.value ? null : controller.fetchData,
          )),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: 16.0,
              ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('بيانات الصنف',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // ── Main Group Dropdown ──
              _buildMainGroupDropdown(controller),
              const SizedBox(height: 15),
              // ── Group selector + item number ──
              // Plain Row: _buildGroupSelectorField has its own Obx internally
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 3,
                      child: _buildGroupSelectorField(context, controller)),
                  const SizedBox(width: 10),
                  Expanded(
                      flex: 2,
                      child: _buildInputField(
                          controller.noController,
                          'رقم الصنف',
                          Icons.confirmation_number_outlined,
                          readOnly: true)), // Always read-only — auto-generated
                ],
              ),
              const SizedBox(height: 15),
              // ── Item name ──
              Obx(() => _buildInputField(
                  controller.nameController, 'اسم الصنف', Icons.label_outline,
                  readOnly: !controller.isSaveEnabled.value)),
              const SizedBox(height: 15),
              // ── Barcode + Unit ──
              Obx(() => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _buildInputField(controller.barcodeController,
                          'الباركود', Icons.qr_code_scanner,
                          isRequired: false,
                          readOnly: !controller.isSaveEnabled.value)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: controller.units.isEmpty
                          ? _buildInputField(controller.unitController,
                              'الوحدة', Icons.architecture_outlined,
                              readOnly: !controller.isSaveEnabled.value)
                          : _buildUnitDropdown(controller)),
                ],
              )),
              const SizedBox(height: 15),
              // ── Price + Currency ──
              Obx(() => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _buildInputField(controller.priceController, 'السعر',
                          Icons.attach_money,
                          keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                          readOnly: !controller.isSaveEnabled.value)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildCurrencyDropdown(controller)),
                ],
              )),
              const SizedBox(height: 15),
              const Text('إعدادات الخصم والضريبة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              // ── Discount checkbox + rate ──
              Obx(() => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    child: CheckboxListTile(
                      title: const Text('مسموح بالخصم',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14)),
                      value: controller.isDiscountable.value,
                      onChanged: controller.isSaveEnabled.value
                          ? (bool? value) {
                              controller.isDiscountable.value = value ?? false;
                              if (!controller.isDiscountable.value) {
                                controller.discountRateController.clear();
                              }
                            }
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.blue,
                    ),
                  ),
                  if (controller.isDiscountable.value)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8.0),
                        child: _buildInputField(
                          controller.discountRateController,
                          'معدل (%)',
                          Icons.local_offer_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          isRequired: false,
                          readOnly: !controller.isSaveEnabled.value,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                ],
              )),
              const SizedBox(height: 10),
              // ── Tax checkbox + rate ──
              Obx(() => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    child: CheckboxListTile(
                      title: const Text('خاضع للضريبة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14)),
                      value: controller.isTaxable.value,
                      onChanged: controller.isSaveEnabled.value
                          ? (bool? value) {
                              controller.isTaxable.value = value ?? false;
                            }
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.blue,
                    ),
                  ),
                  if (controller.isTaxable.value)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 8.0),
                        child: _buildInputField(
                          controller.taxRateController,
                          'نسبة (%)',
                          Icons.percent,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          isRequired: false,
                          readOnly: !controller.isSaveEnabled.value,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                ],
              )),
              const SizedBox(height: 20),
              // ── Cash-reserved checkbox ──
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: Obx(() => CheckboxListTile(
                      title: const Text('محجوز نقداً',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      value: controller.isCashReserved.value,
                      onChanged: controller.isSaveEnabled.value
                          ? (bool? value) {
                              controller.isCashReserved.value = value ?? false;
                            }
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.blue,
                    )),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 20),
              const Text('الحسابات المالية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildAccountDropdown(
                controller: controller,
                label: 'حساب المخزون',
                icon: Icons.inventory_2_outlined,
                itemsList: controller.inventoryAccounts,
                selectedValue: controller.selectedInventoryAccountId,
                onChanged: (value) =>
                    controller.selectedInventoryAccountId.value = value,
                isRequired: true,
              ),
              const SizedBox(height: 15),
              _buildAccountDropdown(
                controller: controller,
                label: 'حساب التكلفة',
                icon: Icons.calculate_outlined,
                itemsList: controller.cogsAccounts,
                selectedValue: controller.selectedCogsAccountId,
                onChanged: (value) =>
                    controller.selectedCogsAccountId.value = value,
                isRequired: true,
              ),
              const SizedBox(height: 15),
              _buildAccountDropdown(
                controller: controller,
                label: 'حساب الإيراد',
                icon: Icons.paid_outlined,
                itemsList: controller.salesRevenueAccounts,
                selectedValue: controller.selectedSalesRevenueAccountId,
                onChanged: (value) =>
                    controller.selectedSalesRevenueAccountId.value = value,
                isRequired: true,
              ),
              const SizedBox(height: 15),
              _buildAccountDropdown(
                controller: controller,
                label: 'حساب الخصم',
                icon: Icons.discount_outlined,
                itemsList: controller.salesDiscountAccounts,
                selectedValue: controller.selectedSalesDiscountAccountId,
                onChanged: (value) =>
                    controller.selectedSalesDiscountAccountId.value = value,
                isRequired: false,
              ),
              const SizedBox(height: 15),
              _buildCostCenterSelectorField(context, controller),
              const SizedBox(height: 30),
            ],
          ),
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
        child: _buildActionButtons(context, controller),
      ),
    ),
  ],
)
);
}

Widget _buildActionButtons(BuildContext context, ItemController controller) {
  return Obx(() {
    final bool loading = controller.isLoading.value;
    final bool saveEnabled = controller.isSaveEnabled.value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          'جديد',
          Icons.create,
          Colors.blue,
          loading ? null : controller.startNew,
        ),
        const SizedBox(width: 6),
        _buildActionButton(
          'حفظ',
          Icons.save,
          saveEnabled ? Colors.green : Colors.grey,
          (loading || !saveEnabled) ? null : () => controller.submitForm(_formKey),
          isLoading: loading,
        ),
        const SizedBox(width: 6),
        _buildActionButton(
          'طباعة',
          Icons.print,
          Colors.purple,
          loading ? null : controller.printData,
        ),
        const SizedBox(width: 6),
        _buildActionButton(
          'بحث',
          Icons.search,
          Colors.orange,
          loading ? null : () => _showItemSearchDialog(context, controller),
        ),
      ],
    );
  });
}

Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback? onPressed, {bool isLoading = false}) {
  return Expanded(
    child: ElevatedButton.icon(
      icon: isLoading 
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Icon(icon, size: 20, color: Colors.white),
      label: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: Colors.grey.shade300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 8),
        elevation: 2,
      ),
    ),
  );
}


  Widget _buildInputField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text,
        bool readOnly = false,
        bool isRequired = true}) {
    return SizedBox(
      height: 50,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          prefixIcon: Icon(icon, color: Colors.blue, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        ),
        style: const TextStyle(fontSize: 14),
        validator: (value) =>
        isRequired && (value == null || value.isEmpty)
            ? 'هذا الحقل مطلوب'
            : null,
      ),
    );
  }

  Widget _buildUnitDropdown(ItemController controller) {
    return SizedBox(
      height: 50,
      child: Obx(() {
        final bool enabled = controller.isSaveEnabled.value;
        final String? currentUnit = controller.unitController.text;
        
        final List<String> availableUnits = controller.units;
        final bool valueExists = currentUnit != null && currentUnit.isNotEmpty && availableUnits.contains(currentUnit);
        final String? dropdownValue = valueExists ? currentUnit : null;

        return DropdownButtonFormField<String>(
          value: dropdownValue,
          isExpanded: true,
          items: availableUnits
              .map((unit) => DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: enabled
              ? (value) {
                  if (value != null) controller.unitController.text = value;
                }
              : null,
          decoration: InputDecoration(
            labelText: 'الوحدة *',
            prefixIcon: const Icon(Icons.architecture_outlined, color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade200,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          validator: (value) => value == null ? 'هذا الحقل مطلوب' : null,
        );
      }),
    );
  }

  Widget _buildCurrencyDropdown(ItemController controller) {
    return SizedBox(
      height: 50,
      child: Obx(() {
        final bool enabled = controller.isSaveEnabled.value;
        return DropdownButtonFormField<int>(
          initialValue: controller.selectedCurrency.value,
          isExpanded: true,
          items: controller.currencies
              .map((currency) => DropdownMenuItem<int>(
            value: currency.currencyNo,
            child: Text(
                '${currency.currencyName} (${currency.currencySymbol})',
                overflow: TextOverflow.ellipsis),
          ))
              .toList(),
          onChanged: enabled
              ? (value) => controller.selectedCurrency.value = value
              : null,
          decoration: InputDecoration(
            labelText: 'العملة *',
            prefixIcon: const Icon(Icons.currency_exchange_outlined,
                color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade200,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          validator: (value) => value == null ? 'هذا الحقل مطلوب' : null,
        );
      }),
    );
  }

  Widget _buildMainGroupDropdown(ItemController controller) {
    return SizedBox(
      height: 50,
      child: Obx(() {
        final bool enabled = controller.isSaveEnabled.value && !controller.isEditing.value;
        return DropdownButtonFormField<String>(
          value: controller.selectedMainGroupNo.value,
          isExpanded: true,
          items: controller.allMainGroups
              .map((group) => DropdownMenuItem<String>(
            value: group.mainGroupNo,
            child: Text(
                '${group.mainGroupName} (${group.mainGroupNo})',
                overflow: TextOverflow.ellipsis),
          ))
              .toList(),
          onChanged: enabled
              ? (value) {
                  controller.selectedMainGroupNo.value = value;
                  controller.selectedGroupNo.value = null; // Clear child group
                  controller.groupNameController.clear();
                }
              : null,
          decoration: InputDecoration(
            labelText: 'المجموعة الرئيسية *',
            prefixIcon: const Icon(Icons.category,
                color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade200,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          validator: (value) => value == null ? 'يرجى اختيار المجموعة الرئيسية' : null,
        );
      }),
    );
  }

  Widget _buildAccountDropdown({
    required ItemController controller,
    required String label,
    required IconData icon,
    required RxList<Map<String, dynamic>> itemsList,
    required RxnString selectedValue,
    required Function(String?) onChanged,
    bool isRequired = true,
  }) {
    return SizedBox(
      height: 50,
      child: Obx(() {
        final bool enabled = controller.isSaveEnabled.value;
        final String? currentValue = selectedValue.value;
        final List<String?> availableIds =
        itemsList.map((acc) => acc['id'] as String?).toList();
        final bool valueExists =
            currentValue != null && availableIds.contains(currentValue);
        final String? dropdownValue = valueExists ? currentValue : null;

        return DropdownButtonFormField<String>(
          initialValue: dropdownValue,
          hint: Text('اختر $label'),
          isExpanded: true,
          items: itemsList.map((account) {
            return DropdownMenuItem<String>(
              value: account['id'] as String,
              child: Text('${account['account_number']} - ${account['name']}',
                  overflow: TextOverflow.ellipsis),
            );
          }).toSet().toList(),
          onChanged: enabled ? onChanged : null,
          validator: (value) =>
          isRequired && value == null ? 'هذا الحقل مطلوب' : null,
          decoration: InputDecoration(
            labelText: isRequired ? '$label *' : label,
            prefixIcon: Icon(icon, color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade200,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            suffixIcon: (controller.isLoading.value && itemsList.isEmpty)
                ? const Padding(
              padding: EdgeInsets.all(10.0),
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.0)),
            )
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildGroupSelectorField(
      BuildContext context, ItemController controller) {
    return SizedBox(
      height: 50,
      child: Obx(() {
        final bool enabled = controller.isSaveEnabled.value && !controller.isEditing.value;
        return TextFormField(
          controller: controller.groupNameController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'مجموعة الصنف *',
            prefixIcon: const Icon(Icons.category_outlined, color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            // Grey out when locked or in edit mode (group cannot change on edit)
            fillColor: enabled ? Colors.white : Colors.grey.shade200,
            hintText: 'اختر مجموعة',
            contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          ),
          onTap: enabled
              ? () => _showGroupSearchDialog(context, controller)
              : null,
          validator: (value) =>
          value == null || value.isEmpty ? 'يرجى اختيار مجموعة' : null,
        );
      }),
    );
  }

  Widget _buildCostCenterSelectorField(
      BuildContext context, ItemController controller) {
    return SizedBox(
      height: 50,
      child: Obx(() {
        final bool enabled = controller.isSaveEnabled.value;
        return TextFormField(
          controller: controller.costCenterNameController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'مركز التكلفة',
            prefixIcon: const Icon(Icons.business_center_outlined, color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade200,
            hintText: 'اختر مركز تكلفة',
            contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          ),
          onTap: enabled
              ? () => _showCostCenterSearchDialog(context, controller)
              : null,
        );
      }),
    );
  }
}

class _GroupSearchDialogContent extends StatelessWidget {
  final ItemController controller;
  const _GroupSearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    final searchQuery = ''.obs;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            autofocus: true,
            onChanged: (val) => searchQuery.value = val,
            decoration: const InputDecoration(
                labelText: 'ابحث بالرقم أو الاسم...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _buildHeaderRow(),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: Obx(() {
              List<SunItemGroup> baseList = controller.allGroups;
              if (controller.selectedMainGroupNo.value != null) {
                baseList = baseList.where((g) => g.mainGroupNo == controller.selectedMainGroupNo.value).toList();
              }

              final query = searchQuery.value.toLowerCase();
              final filtered = baseList.where((g) {
                return g.groupName.toLowerCase().contains(query) || g.groupNo.toLowerCase().contains(query);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('لا توجد نتائج'));
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final group = filtered[index];
                  return InkWell(
                    onTap: () => controller.selectGroup(group),
                    child: _buildDataRow(group),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey.shade200, border: Border(bottom: BorderSide(color: Colors.grey.shade400))),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('الرقم', style: headerStyle)),
          Expanded(flex: 7, child: Text('الاسم', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildDataRow(SunItemGroup group) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(group.groupNo.padLeft(3, '0'), style: const TextStyle(fontSize: 12))),
          Expanded(flex: 7, child: Text(group.groupName, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _CostCenterSearchDialogContent extends StatelessWidget {
  final ItemController controller;
  const _CostCenterSearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    final searchQuery = ''.obs;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            autofocus: true,
            onChanged: (val) => searchQuery.value = val,
            decoration: const InputDecoration(
                labelText: 'ابحث بالرقم أو الاسم...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          _buildHeaderRow(),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: Obx(() {
              final query = searchQuery.value.toLowerCase();
              final filtered = controller.costCenters.where((center) {
                return center.centerName.toLowerCase().contains(query) || center.centerNo.toString().contains(query);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('لا توجد نتائج'));
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final center = filtered[index];
                  return InkWell(
                    onTap: () => controller.selectCostCenter(center),
                    child: _buildDataRow(center),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey.shade200, border: Border(bottom: BorderSide(color: Colors.grey.shade400))),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('الرقم', style: headerStyle)),
          Expanded(flex: 7, child: Text('الاسم', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildDataRow(CostCenter center) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(center.centerNo.toString(), style: const TextStyle(fontSize: 12))),
          Expanded(flex: 7, child: Text(center.centerName, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _ItemSearchDialog extends StatelessWidget {
  final ItemController controller;
  const _ItemSearchDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    final searchQuery = ''.obs;

    return AlertDialog(
      title: const Text('بحث عن صنف'),
      contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextField(
                controller: searchController,
                autofocus: true,
                onChanged: (val) => searchQuery.value = val,
                decoration: InputDecoration(
                  labelText: 'ابحث بالاسم, الرقم, أو الباركود',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double targetWidth = constraints.maxWidth > 800 ? constraints.maxWidth : 800;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: targetWidth,
                      child: Column(
                        children: [
                          _buildHeaderRow(),
                      const Divider(height: 1, thickness: 1),
                      Expanded(
                        child: Obx(() {
                          final query = searchQuery.value.toLowerCase();
                          final filtered = controller.allItems.where((item) {
                            final nameMatch = item.itemName.toLowerCase().contains(query);
                            final barcodeMatch = item.itemBarcode?.toLowerCase().contains(query) ?? false;
                            final itemNoMatch = item.itemNo.contains(query);
                            return nameMatch || barcodeMatch || itemNoMatch;
                          }).toList();

                          if (filtered.isEmpty) {
                            return const Center(child: Text('لا توجد نتائج مطابقة'));
                          }
                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return InkWell(
                                onTap: () {
                                  controller.editItem(item);
                                  Get.back();
                                },
                                child: _buildDataRow(item),
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('إغلاق')),
      ],
    );
  }

  Widget _buildHeaderRow() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey.shade200, border: Border(bottom: BorderSide(color: Colors.grey.shade400))),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('رقم الصنف', style: headerStyle, softWrap: false, overflow: TextOverflow.clip)),
          Expanded(flex: 4, child: Text('اسم الصنف', style: headerStyle, softWrap: false, overflow: TextOverflow.clip)),
          Expanded(flex: 2, child: Text('الباركود', style: headerStyle, softWrap: false, overflow: TextOverflow.clip)),
          Expanded(flex: 3, child: Text('المجموعة', style: headerStyle, softWrap: false, overflow: TextOverflow.clip)),
          Expanded(flex: 2, child: Text('السعر', style: headerStyle, softWrap: false, overflow: TextOverflow.clip)),
        ],
      ),
    );
  }

  Widget _buildDataRow(SunItem item) {
    const dataStyle = TextStyle(fontSize: 14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.itemNo, style: dataStyle, softWrap: false, overflow: TextOverflow.clip)),
          Expanded(flex: 4, child: Text(item.itemName, style: dataStyle, softWrap: false, overflow: TextOverflow.clip)),
          Expanded(flex: 2, child: Text(item.itemBarcode ?? 'لا يوجد', style: dataStyle, softWrap: false, overflow: TextOverflow.clip)),
          Expanded(flex: 3, child: Text(item.groupName ?? 'N/A', style: dataStyle, softWrap: false, overflow: TextOverflow.clip)),
          Expanded(flex: 2, child: Text(item.itemPrice.toStringAsFixed(2), style: dataStyle, softWrap: false, overflow: TextOverflow.clip)),
        ],
      ),
    );
  }
}