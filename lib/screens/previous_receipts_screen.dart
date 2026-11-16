import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/screens/controllers/previous_receipts_controller.dart';

class PreviousReceiptsScreen extends StatefulWidget {
  const PreviousReceiptsScreen({super.key});

  @override
  State<PreviousReceiptsScreen> createState() => _PreviousReceiptsScreenState();
}

class _PreviousReceiptsScreenState extends State<PreviousReceiptsScreen> {
  final ScrollController _scrollController = ScrollController();
  late final PreviousReceiptsController controller;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>? ?? {};
    final String receiptType = arguments['invoiceType'] ?? 'ق';
    controller = Get.put(
      PreviousReceiptsController(),
      tag: receiptType,
    );
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      controller.loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getTitle() {
    switch (controller.currentReceiptType.value) {
      case 'ق': return 'سجل سندات القبض';
      case 'ص': return 'سجل سندات الصرف';
      default: return 'السندات السابقة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(_getTitle(), style: const TextStyle(color: Colors.white, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 3,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: controller.refreshReceipts,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        } else if (controller.receipts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text('لا توجد سندات محفوظة محلياً لهذا النوع.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        } else {
          final showLoadingMore = controller.isLoadingMore.value;
          return ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            itemCount: controller.receipts.length + (showLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < controller.receipts.length) {
                return _buildReceiptItem(controller.receipts[index], controller);
              } else {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            },
          );
        }
      }),
    );
  }

  Widget _buildReceiptItem(Map<String, dynamic> receipt, PreviousReceiptsController controller) {
    // 1. معالجة البيانات
    final DateTime? receiptDate = DateTime.tryParse(receipt['date']?.toString() ?? '');
    final String formattedDate = receiptDate != null
        ? controller.dateFormat.format(receiptDate.toLocal())
        : 'تاريخ غير معروف';

    final String transactionNumber = receipt['transaction_number']?.toString() ?? 'بدون رقم';

    // البيانات القادمة من الـ JOIN أو الجدول المباشر
    final String accountName = receipt['account_name']?.toString() ?? 'غير محدد';
    final String userName = receipt['user_name']?.toString() ?? 'غير معروف';
    final String cashBox = receipt['cash_box']?.toString() ?? '';
    final String currency = receipt['currency']?.toString() ?? '';

    final String totalAmount = (receipt['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00';

    // حالة المزامنة (1 = متزامن، 0 = غير متزامن)
    final bool isSynced = (receipt['is_synced'] == 1);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '# $transactionNumber',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            // عرض أيقونة المزامنة
            if (!isSynced)
              const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.orange, semanticLabel: 'غير متزامن')
            else
              const Icon(Icons.check_circle_outline, size: 18, color: Colors.green, semanticLabel: 'متزامن'),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 10),
            _buildInfoRow(Icons.person, 'المستخدم: $userName'),
            _buildInfoRow(Icons.calendar_today, 'التاريخ: $formattedDate'),
            _buildInfoRow(Icons.account_circle, 'الحساب: $accountName'),
            if (cashBox.isNotEmpty) _buildInfoRow(Icons.inbox, 'الصندوق: $cashBox'),

            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (currency.isNotEmpty)
                  Text(currency, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  'الإجمالي: $totalAmount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // ✨✨ التعديل الهام جداً للتعامل مع SQLite ✨✨
          // في SQLite المعرف يكون int، لذا نحوله لـ String لضمان التوافق مع ما تتوقعه الشاشات الأخرى
          final String? receiptId = receipt['id']?.toString();

          if (receiptId != null) {
            Get.back(result: receiptId);
          } else {
            controller.showMessage('خطأ: معرف السند مفقود.', isError: true);
          }
        },
      ),
    );
  }

  // دالة مساعدة لتنسيق الصفوف (نفس المستخدمة في الفواتير)
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}