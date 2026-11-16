import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/screens/controllers/previous_invoices_controller.dart';

class PreviousInvoicesScreen extends StatefulWidget {
  const PreviousInvoicesScreen({super.key});

  @override
  State<PreviousInvoicesScreen> createState() => _PreviousInvoicesScreenState();
}

class _PreviousInvoicesScreenState extends State<PreviousInvoicesScreen> {
  final ScrollController _scrollController = ScrollController();
  late final PreviousInvoicesController controller;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments as Map<String, dynamic>? ?? {};
    final String invoiceType = arguments['invoiceType'] ?? 'default';
    controller = Get.put(
      PreviousInvoicesController(),
      tag: invoiceType,
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

  // تحديد عنوان الصفحة بناءً على النوع
  String _getTitle() {
    switch (controller.currentInvoiceType.value) {
      case 'ن': return 'سجل البيع النقدي';
      case 'م': return 'سجل البيع المعلق';
      case 'ج': return 'سجل البيع الآجل';
      case 'رن': return 'سجل مردود نقدي';
      case 'رج': return 'سجل مردود آجل';
      case 'رم': return 'سجل مردود معلق';
      case 'م ض': return 'سجل محاضر الجرد'; // تمت إضافتها لدعم الجرد
      case 'ت': return 'سجل بيع المحطات';
      case 'ك ن':
      case 'ك ج':
      case 'ك ن,ك ج': return 'سجل فواتير الخدمات (كهرباء وماء)';
      default: return 'الفواتير السابقة';
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
            onPressed: controller.refreshInvoices,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        } else if (controller.invoices.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 60, color: Colors.grey),
                SizedBox(height: 10),
                Text('لا توجد فواتير محفوظة محلياً لهذا النوع.', style: TextStyle(color: Colors.grey)),
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
            itemCount: controller.invoices.length + (showLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < controller.invoices.length) {
                return _buildInvoiceItem(controller.invoices[index], controller);
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

  Widget _buildInvoiceItem(Map<String, dynamic> invoice, PreviousInvoicesController controller) {
    // 1. معالجة التاريخ
    final DateTime? invoiceDate = DateTime.tryParse(invoice['date']?.toString() ?? '');
    // ضبط التوقيت المحلي للعرض
    final String formattedDate = invoiceDate != null
        ? controller.dateFormat.format(invoiceDate.toLocal())
        : 'تاريخ غير معروف';

    // 2. قراءة البيانات المباشرة (Flat Data) القادمة من SQLite JOIN
    final String transactionNumber = invoice['transaction_number']?.toString() ?? 'بدون رقم';
    final String customerName = invoice['customer_name']?.toString() ?? 'عميل غير محدد';

    // البيانات القادمة من الجداول المرتبطة (Left Join)
    final String userName = invoice['user_name']?.toString() ?? 'غير معروف';
    final String storeName = invoice['name_store']?.toString() ?? 'مخزن غير محدد';
    final String boxName = invoice['box_name']?.toString() ?? ''; // قد يكون فارغاً في الآجل

    final String netTotal = (invoice['net_total'] as num?)?.toStringAsFixed(2) ?? '0.00';

    // حالة المزامنة (اختياري: لعرض أيقونة)
    final bool isSynced = (invoice['is_synced'] == 1);

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
            // عرض حالة المزامنة (اختياري)
            if (!isSynced)
              const Icon(Icons.cloud_upload_outlined, size: 18, color: Colors.orange, semanticLabel: 'غير متزامن')
            else
              const Icon(Icons.check_circle_outline, size: 18, color: Colors.green, semanticLabel: 'متزامن'),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 10), // خط فاصل جمالي
            _buildInfoRow(Icons.person, 'المستخدم: $userName'),
            _buildInfoRow(Icons.calendar_today, 'التاريخ: $formattedDate'),
            if (boxName.isNotEmpty) _buildInfoRow(Icons.inbox, 'الصندوق: $boxName'),
            _buildInfoRow(Icons.store, 'المخزن: $storeName'),
            _buildInfoRow(Icons.account_circle, 'العميل: $customerName'),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'الصافي: $netTotal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          // استرجاع المعرف (ID) وإعادته للشاشة السابقة
          final String? invoiceId = invoice['id']?.toString();
          if (invoiceId == null) {
            controller.showMessage('خطأ: معرف الفاتورة مفقود.', isError: true);
            return;
          }
          Get.back(result: invoiceId);
        },
      ),
    );
  }

  // دالة مساعدة لبناء صفوف المعلومات بشكل أنيق
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