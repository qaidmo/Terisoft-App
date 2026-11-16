// lib/admin/views/permissions_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/permissions_controller.dart';

class PermissionsScreen extends StatelessWidget {
  PermissionsScreen({super.key});

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<String> _priceRelevantScreens = [
    'CashSaleScreen',
    'CreditSaleScreen',
    'AbsoluteCashSaleScreen',
    'CashSaleReturnScreen',
    'CreditSaleReturnScreen',
    'AbsoluteCashSaleReturnScreen',
  ];

  @override
  Widget build(BuildContext context) {
    final PermissionsController controller = Get.put(PermissionsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('صلاحيات المستخدمين'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          MediaQuery.of(context).padding.bottom + 80.0,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildInputField(
                      controller: controller.userNoController,
                      label: 'رقم المستخدم',
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCheckbox(
                          controllerValue: controller.isAdmin,
                          title: 'مستخدم مسؤول',
                          onChanged: null,
                        ),
                        _buildCheckbox(
                          controllerValue: controller.isAccountActive,
                          title: 'الحساب نشط',
                          onChanged: (val) {
                            controller.isAccountActive.value = val!;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInputField(
                controller: controller.userNameController,
                label: 'اسم المستخدم',
                readOnly: true,
              ),
              const SizedBox(height: 12),
              _buildInputField(controller: controller.branchNameController, label: 'الفرع', readOnly: true),
              const SizedBox(height: 12),
              _buildInputField(controller: controller.departmentNameController, label: 'القسم', readOnly: true),
              const SizedBox(height: 12),
              _buildInputField(controller: controller.boxNameController, label: 'الصندوق', readOnly: true),
              const SizedBox(height: 12),
              _buildInputField(controller: controller.storeNameController, label: 'المخزن', readOnly: true),
              const SizedBox(height: 24),
              _buildSectionTitle('إعادة تعيين كلمة السر (اتركه فارغاً لعدم التغيير)'),
              const SizedBox(height: 12),
              Obx(() => _buildInputField(
                controller: controller.passwordController,
                label: 'كلمة السر الجديدة',
                isPassword: true,
                isObscured: controller.passwordObscured.value,
                onToggleVisibility: controller.togglePasswordObscure,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 4) {
                    return 'يجب أن تكون 4 أحرف على الأقل';
                  }
                  return null;
                },
              )),
              const SizedBox(height: 12),
              Obx(() => _buildInputField(
                controller: controller.confirmPasswordController,
                label: 'تأكيد كلمة السر',
                isPassword: true,
                isObscured: controller.passwordObscured.value,
                onToggleVisibility: controller.togglePasswordObscure,
                validator: (value) {
                  if (controller.passwordController.text.isNotEmpty && value != controller.passwordController.text) {
                    return 'كلمات السر غير متطابقة';
                  }
                  return null;
                },
              )),
              const SizedBox(height: 24),

              _buildPermissionsSection(context, controller),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context, controller),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required RxBool controllerValue,
    required String title,
    required ValueChanged<bool?>? onChanged,
  }) {
    return InkWell(
      onTap: onChanged != null ? () => onChanged(!controllerValue.value) : null,
      child: Row(
        children: [
          Obx(() => Checkbox(
            value: controllerValue.value,
            onChanged: onChanged,
            activeColor: Colors.blue.shade700,
          )),
          Text(title),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      obscureText: isObscured,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: onToggleVisibility,
        )
            : null,
      ),
      validator: validator,
    );
  }

  Widget _buildBottomNavBar(BuildContext context, PermissionsController controller) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), spreadRadius: 0, blurRadius: 10),
        ],
      ),
      child: Obx(() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
              icon: controller.isLoading.value
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(controller.isLoading.value ? 'جاري الحفظ...' : 'حفظ التغييرات'),
              onPressed: controller.isLoading.value ? null : () {
                if (_formKey.currentState!.validate()) {
                  controller.saveChanges();
                }
              }
          ),
          ElevatedButton.icon(
              icon: const Icon(Icons.search_outlined),
              label: const Text('بحث عن مستخدم'),
              onPressed: controller.isLoading.value ? null : () => _showUserSearchDialog(context, controller)
          ),
        ],
      )),
    );
  }

  Widget _buildPermissionsSection(BuildContext context, PermissionsController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('صلاحيات الشاشات'),
            Row(
              children: [
                ElevatedButton(onPressed: () => controller.setAllPermissions(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('تحديد الكل')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () => controller.setAllPermissions(false), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('إلغاء الكل')),
              ],
            )
          ],
        ),
        const SizedBox(height: 12),
        _buildPermissionsTable(context, controller),
      ],
    );
  }


  Widget _buildPermissionsTable(BuildContext context, PermissionsController controller) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(() => DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
          columns: const [
            DataColumn(label: Text('اسم الشاشة', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Center(child: Text('دخول', style: TextStyle(fontWeight: FontWeight.bold)))),
            DataColumn(label: Center(child: Text('إضافة', style: TextStyle(fontWeight: FontWeight.bold)))),
            DataColumn(label: Center(child: Text('تعديل', style: TextStyle(fontWeight: FontWeight.bold)))),
            DataColumn(label: Center(child: Text('بحث', style: TextStyle(fontWeight: FontWeight.bold)))),
            DataColumn(label: Center(child: Text('طباعة', style: TextStyle(fontWeight: FontWeight.bold)))),
            DataColumn(label: Center(child: Text('تغيير السعر', style: TextStyle(fontWeight: FontWeight.bold)))),
          ],
          rows: controller.allScreens.map((screenData) {
            final screenName = screenData['name']!;
            final permissions = controller.currentPermissions[screenName] ?? {};
            final bool isPriceRelevant = _priceRelevantScreens.contains(screenName);

            return DataRow(
              cells: [
                DataCell(Text(screenData['display']!)),
                DataCell(Center(child: Checkbox(value: permissions['access'], onChanged: (val) { controller.currentPermissions[screenName]!['access'] = val!; controller.currentPermissions.refresh(); }, activeColor: Colors.blue.shade700,))),
                DataCell(Center(child: Checkbox(value: permissions['add'], onChanged: (val) { controller.currentPermissions[screenName]!['add'] = val!; controller.currentPermissions.refresh(); }, activeColor: Colors.blue.shade700,))),
                DataCell(Center(child: Checkbox(value: permissions['edit'], onChanged: (val) { controller.currentPermissions[screenName]!['edit'] = val!; controller.currentPermissions.refresh(); }, activeColor: Colors.blue.shade700,))),
                DataCell(Center(child: Checkbox(value: permissions['search'], onChanged: (val) { controller.currentPermissions[screenName]!['search'] = val!; controller.currentPermissions.refresh(); }, activeColor: Colors.blue.shade700,))),
                DataCell(Center(child: Checkbox(value: permissions['print'], onChanged: (val) { controller.currentPermissions[screenName]!['print'] = val!; controller.currentPermissions.refresh(); }, activeColor: Colors.blue.shade700,))),

                DataCell(Center(child: Checkbox(
                  value: isPriceRelevant ? (permissions['change_price'] ?? false) : false,
                  onChanged: isPriceRelevant
                      ? (val) {
                    controller.currentPermissions[screenName]!['change_price'] = val!;
                    controller.currentPermissions.refresh();
                  }
                      : null, // هذا السطر هو ما يقوم بالتضليل

                  activeColor: Colors.blue.shade700,
                ))),
              ],
            );
          }).toList(),
        )),
      ),
    );
  }

  void _showUserSearchDialog(BuildContext context, PermissionsController controller) {
    controller.userSearchController.clear();
    Get.dialog(AlertDialog(
      title: const Text('بحث عن مستخدم'),
      content: _UserSearchDialogContent(controller: controller),
      actions: [TextButton(onPressed: () => Get.back(), child: const Text('إغلاق'))],
    ), barrierDismissible: false);
  }
}

class _UserSearchDialogContent extends StatelessWidget {
  final PermissionsController controller;
  const _UserSearchDialogContent({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.maxFinite,
      height: MediaQuery.of(context).size.height * 0.5,
      child: Column(
        children: [
          TextField(
            controller: controller.userSearchController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'ابحث بالاسم...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Obx(() => SingleChildScrollView(
              child: DataTable(
                border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('رقم المستخدم', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('اسم المستخدم', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: controller.filteredUsers.map((user) => DataRow(
                  onSelectChanged: (s) {
                    if (s ?? false) {
                      controller.loadUserForEditing(user['user_no']);
                      Get.back();
                    }
                  },
                  cells: [
                    DataCell(Text(user['user_no'].toString())),
                    DataCell(Text(user['user_name'])),
                  ],
                )).toList(),
              ),
            )),
          ),
        ],
      ),
    );
  }
}