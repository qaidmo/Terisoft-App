import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/customer_controller.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CustomerController controller = Get.put(CustomerController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة العملاء'),
        centerTitle: true,
        actions: [
          Obx(() => IconButton(
            icon: controller.isLoading.value
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: controller.isLoading.value ? null : controller.fetchData,
          )),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Obx(() {
                final bool isReadOnly = !controller.isSaveEnabled.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('البيانات الأساسية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 15),
                    _buildField(controller.noController, 'رقم العميل', Icons.person_pin, true),
                    const SizedBox(height: 15),
                    _buildField(controller.nameController, 'اسم العميل', Icons.person, isReadOnly),
                    const SizedBox(height: 15),
                    _buildField(controller.foreignNameController, 'الاسم الأجنبي', Icons.language, isReadOnly),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: _buildField(controller.phoneController, 'رقم الهاتف', Icons.phone, isReadOnly)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildField(controller.emailController, 'البريد الإلكتروني', Icons.email, isReadOnly)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildField(controller.addressController, 'العنوان', Icons.location_on, isReadOnly),
                    const SizedBox(height: 25),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 10),
                    const Text('البيانات المالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 15),
                    _buildField(controller.accountNameController, 'حساب العميل', Icons.account_balance_wallet, true),
                    const SizedBox(height: 25),
                    const Divider(thickness: 1.5),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(Icons.bolt, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text('بيانات اشتراك الخدمات (اختياري)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('خاص بمحطات الكهرباء والماء (يمكن تركه فارغاً لعملاء التجزئة العاديين)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: _buildField(controller.costDataController, 'تاريخ الاشتراك', Icons.calendar_today, isReadOnly)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildField(controller.costRsomController, 'رسوم الاشتراك', Icons.receipt_long, isReadOnly)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildField(controller.costNextController, 'القراءة الحالية للعداد', Icons.speed, isReadOnly),
                  ],
                );
              }),
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Obx(() {
              bool canSave = controller.isSaveEnabled.value && !controller.isLoading.value;
              bool canEdit = !controller.isSaveEnabled.value && controller.selectedCustomer.value != null && !controller.isLoading.value;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton('جديد', Icons.create, Colors.blue, () {
                    controller.prepareNewCustomer();
                  }),

                  const SizedBox(width: 6),

                  _buildActionButton(
                    'تعديل',
                    Icons.edit,
                    Colors.teal,
                    canEdit ? controller.prepareEditCustomer : null,
                  ),

                  const SizedBox(width: 6),

                  _buildActionButton(
                      'حفظ',
                      Icons.save,
                      Colors.green,
                      canSave ? () async {
                        await controller.saveCustomer();
                        if (!controller.isLoading.value) {
                          controller.isSaveEnabled.value = false;
                        }
                      } : null
                  ),

                  const SizedBox(width: 6),

                  _buildActionButton(
                      'طباعة',
                      Icons.print,
                      Colors.purple,
                      controller.printData
                  ),

                  const SizedBox(width: 6),

                  _buildActionButton(
                      'بحث',
                      Icons.search,
                      Colors.orange,
                          () => _showSearchDialog(context, controller)
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
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
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, bool isReadOnly) {
    return TextFormField(
      controller: controller,
      readOnly: isReadOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: isReadOnly ? Colors.grey : Colors.blue),
        filled: true,
        fillColor: isReadOnly ? Colors.grey[200] : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isReadOnly ? Colors.transparent : Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
    );
  }

  void _showSearchDialog(BuildContext context, CustomerController controller) {
    controller.filterCustomers('');
    controller.mainSearchController.clear();
    Get.dialog(
      _CustomerSearchDialog(controller: controller),
    );
  }
}

class _CustomerSearchDialog extends StatelessWidget {
  final CustomerController controller;
  const _CustomerSearchDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('بحث عن عميل'),
      contentPadding: const EdgeInsets.all(16),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              controller: controller.mainSearchController,
              onChanged: controller.filterCustomers,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'بحث بالاسم أو الرقم...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: Obx(() {
                if (controller.filteredCustomers.isEmpty) {
                  return const Center(child: Text('لا توجد نتائج'));
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      showCheckboxColumn: false,
                      border: TableBorder.all(width: 1, color: Colors.grey.shade300),
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columns: const [
                        DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('الاسم', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('الهاتف', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: controller.filteredCustomers.map((customer) {
                        return DataRow(
                          onSelectChanged: (isSelected) {
                            if (isSelected ?? false) {
                              controller.displayCustomer(customer);
                              controller.isSaveEnabled.value = false;
                              Get.back();
                            }
                          },
                          cells: [
                            DataCell(Text(customer.customerNo.toString())),
                            DataCell(Text(customer.customerName)),
                            DataCell(Text(customer.phoneNumber ?? '')),
                          ],
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
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('إغلاق')),
      ],
    );
  }
}