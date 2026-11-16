// lib/screens/inventory_history_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/screens/controllers/inventory_history_controller.dart';

class InventoryHistoryScreen extends StatelessWidget {
  const InventoryHistoryScreen({super.key});

  // دالة تنسيق الأرقام الموحدة (لإزالة الأصفار العشرية الزائدة)
  String _formatSmart(double? value) {
    if (value == null) return '0';
    if (value == 0) return '0'; // تحسين: إذا كان صفر يعرض صفر مباشرة
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceAll(RegExp(r"0*$"), "").replaceAll(RegExp(r"\.$"), "");
  }

  @override
  Widget build(BuildContext context) {
    // حقن الكنترولر الجديد (الذي يعمل على SQLite)
    final InventoryHistoryController controller = Get.put(InventoryHistoryController());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سجل محاضر الجرد',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadInventoryRecords, // دالة التحديث من الكنترولر المحلي
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        } else if (controller.inventoryRecords.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text('لا توجد محاضر جرد محفوظة محلياً.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        } else {
          return ListView.builder(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            itemCount: controller.inventoryRecords.length,
            itemBuilder: (context, index) =>
                _buildInventoryCard(controller.inventoryRecords[index], context, controller),
          );
        }
      }),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> record, BuildContext context, InventoryHistoryController controller) {
    // جلب البيانات من الماب القادمة من SQLite
    final String transactionNumber = record['transaction_number']?.toString() ?? '---';
    final String storeName = record['store_name'] ?? '---'; // تم ضبط الاسم في الكنترولر ليطابق هذا المفتاح
    final String userName = record['user_name'] ?? '---';

    // معالجة التاريخ من النص المحفوظ في قاعدة البيانات
    final DateTime? date = DateTime.tryParse(record['date']?.toString() ?? '');
    final String formattedDate = date != null ? controller.dateFormat.format(date) : '---';

    // الأرقام المالية (تأتي جاهزة من جملة SQL SUM)
    final double deficit = (record['total_deficit'] as num?)?.toDouble() ?? 0.0;
    final double surplus = (record['total_surplus'] as num?)?.toDouble() ?? 0.0;

    // صافي الفارق يمكن حسابه هنا للعرض أو جلبه من net_total إذا كان مخزناً
    // ملاحظة: في الجرد، عادة net_total يعبر عن القيمة المالية، هنا سنستخدم القيمة المخزنة
    final double netDiff = (record['net_total'] as num?)?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final String? id = record['id']?.toString();
          if (id != null) {
            Get.back(result: id); // ✅ إرجاع المعرف (ID) للشاشة السابقة لفتح التفاصيل
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. السطر العلوي: رقم المحضر + التاريخ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '# $transactionNumber',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                    ),
                  ),
                  Text(formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              const Divider(height: 16),

              // 2. المخزن والمستخدم
              Row(
                children: [
                  const Icon(Icons.store, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(storeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(userName, style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),

              // 3. ملخص الأرقام (عجز - فائض - صافي)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('إجمالي العجز', deficit, Colors.red.shade700),
                    Container(width: 1, height: 30, color: Colors.grey.shade300), // فاصل عمودي
                    _buildStatColumn('إجمالي الفائض', surplus, Colors.green.shade700),
                    Container(width: 1, height: 30, color: Colors.grey.shade300), // فاصل عمودي
                    // هنا نعرض صافي القيمة (Net Total)
                    _buildStatColumn('صافي الفارق', netDiff, Colors.black, isBold: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, double value, Color color, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          _formatSmart(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}