import 'dart:io'; // 👈 تم إضافة هذه المكتبة لعرض الصور المحلية
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/user_state.dart';

class InvoiceTemplatesPage extends StatelessWidget {
  final InvoiceTemplatesController controller = Get.find<InvoiceTemplatesController>();
  final UserState userState = Get.find<UserState>();

  InvoiceTemplatesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة شكل الفواتير',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),

      body: Obx(() {
        // 1. حالة التحميل
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. حالة عدم وجود قوالب (بعد انتهاء التحميل)
        if (controller.availableTemplatesForDropdown.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'فشل تحميل القوالب. لا توجد قوالب متاحة ولا شاشات مُعرّفة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          );
        }

        // 3. عرض محتوى الصفحة
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: MediaQuery.of(context).padding.bottom + 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. اختيار القالب
              _buildSectionTitle('اختيار قالب الفاتورة / إضافة قالب جديد'),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: controller.selectedScreenIdentifier.value.isEmpty
                    ? null
                    : controller.selectedScreenIdentifier.value,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'اختر نوع الفاتورة/الشاشة',
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                items: controller.availableTemplatesForDropdown.map((template) {
                  final isNew = template['isNew'] == 'true';
                  return DropdownMenuItem<String>(
                    value: template['identifier'],
                    child: Text(
                      template['display']!,
                      style: TextStyle(
                        color: isNew ? Colors.blue.shade800 : Colors.black,
                        fontWeight: isNew ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    controller.selectTemplate(newValue);
                  }
                },
              ),
              const SizedBox(height: 24),

              // ✅ عرض اسم القالب/الشاشة المُختارة بوضوح
              if (controller.selectedTemplate.value != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('القالب/الشاشة المُختارة:'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: controller.selectedTemplate.value!['id'] == null ? Colors.amber.shade100 : Colors.blue.shade50,
                        border: Border.all(color: controller.selectedTemplate.value!['id'] == null ? Colors.amber.shade300 : Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        controller.selectedTemplate.value!['template_display_name'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: controller.selectedTemplate.value!['id'] == null ? Colors.black : Colors.blue.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

              // 2. إعدادات الترويسة العلوية
              _buildSectionTitle('إعدادات الترويسة العلوية'),
              const SizedBox(height: 8),
              TextFormField(
                controller: controller.companyNameController,
                decoration: InputDecoration(
                  labelText: 'اسم الشركة',
                  hintText: 'مثال: شركة تيرا سوفت لتقنية المعلومات',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
              const SizedBox(height: 16),

              // عرض القسم / الفرع ديناميكياً
              _buildSectionTitle('القسم / الفرع (يعرض حسب دخول المستخدم)'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50],
                  border: Border.all(color: Colors.blueGrey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Obx(() => Text(
                  '${userState.safeUserDepartmentName} / ${userState.safeUserBranchName}',
                  style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade700),
                  textDirection: TextDirection.rtl,
                )),
              ),
              const SizedBox(height: 24),

              // 3. الشعار (تم التعديل ليكون محلياً فقط)
              _buildSectionTitle('الشعار'),
              const SizedBox(height: 8),

              // 👇 تم التعديل: زر واحد فقط لاختيار الصورة محلياً
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => controller.pickAndProcessLogo(), // 👈 الدالة الجديدة بدون باراميتر
                  icon: const Icon(Icons.photo_library),
                  label: const Text('اختيار شعار من الجهاز'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // زر إزالة الشعار
              if (controller.pickedLogoBytes != null || (controller.currentLogoUrl.value.isNotEmpty))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => controller.clearPickedLogo(),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('إزالة الشعار'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // عرض الشعار الحالي أو المختار
              Obx(() {
                final String currentLogoUrl = controller.currentLogoUrl.value;
                final Uint8List? pickedLogoBytes = controller.pickedLogoBytes;

                // 1. إذا اختار المستخدم صورة جديدة الآن (نعرضها من الذاكرة)
                if (pickedLogoBytes != null) {
                  return _buildLogoDisplay(
                    Image.memory(
                      pickedLogoBytes,
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  );
                }
                // 2. إذا كان هناك شعار محفوظ مسبقاً (نعرضه من الملف المحلي)
                else if (currentLogoUrl.isNotEmpty) {
                  return _buildLogoDisplay(
                    // 👇 تم التعديل: استخدام File بدلاً من Network
                    Image.file(
                      File(currentLogoUrl),
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.broken_image, size: 40, color: Colors.grey[400]),
                    ),
                  );
                } else {
                  return _buildLogoDisplay(
                    const Icon(Icons.image, size: 40, color: Colors.grey),
                  );
                }
              }),
              const SizedBox(height: 16),

              Obx(() => SwitchListTile(
                title: const Text('إظهار الشعار في الفاتورة'),
                value: controller.showLogo.value,
                onChanged: (bool value) {
                  controller.showLogo.value = value;
                },
                activeThumbColor: Colors.blue.shade800,
              )),
              const SizedBox(height: 24),

              // 4. إعدادات الترويسة السفلية
              _buildSectionTitle('إعدادات الترويسة السفلية'),
              const SizedBox(height: 8),
              TextFormField(
                controller: controller.thanksMessageController,
                decoration: InputDecoration(
                  labelText: 'رسالة الشكر',
                  hintText: 'مثال: شكراً لثقتكم بنا!',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller.contactInfoController,
                decoration: InputDecoration(
                  labelText: 'معلومات الاتصال (الهاتف/البريد)',
                  hintText: 'مثال: للاستفسار: 0123456789',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller.addressDetailsController,
                decoration: InputDecoration(
                  labelText: 'عنوان الشركة التفصيلي',
                  hintText: 'مثال: صنعاء - شارع صخر - المبنى رقم 123',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
              const SizedBox(height: 32),

              // زر الحفظ
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => controller.saveTemplateSettings(),
                  icon: const Icon(Icons.save),
                  label: Text(
                      controller.selectedTemplate.value?['id'] == null ? 'إضافة وحفظ القالب الجديد' : 'حفظ التغييرات',
                      style: const TextStyle(fontSize: 16)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: controller.selectedTemplate.value?['id'] == null ? Colors.amber.shade700 : Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }

  Widget _buildLogoDisplay(Widget child) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}