import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// (ملاحظة: هذا مثال توضيحي. لا يزال يتطلب دمج مكتبات الطباعة الفعلية مثل bluetooth_print أو flutter_esc_pos_printer)

class InvoiceScreen extends StatelessWidget {
  final String transactionNumber;
  final DateTime date;
  final List<Map<String, dynamic>> products;
  final double total;
  final double tax;
  final double discount;
  final String customerName;
  final String storeName;
  final String cashBox;
  final String currency;
  final String collector;
  final String salesRep;
  final double netTotal;

  final String? userName;

  final String? saleId;
  final double? amountPaid;
  final double? remainingAmount;


  const InvoiceScreen({
    super.key,
    required this.transactionNumber,
    required this.date,
    required this.products,
    required this.total,
    required this.tax,
    required this.discount,
    required this.customerName,
    required this.storeName,
    required this.cashBox,
    required this.currency,
    required this.collector,
    required this.salesRep,
    required this.netTotal,
    this.userName,
    this.saleId,
    this.amountPaid,
    this.remainingAmount,
  });


  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('yyyy/MM/dd').format(date);
    final String printDate = DateFormat('yyyy/MM/dd').format(DateTime.now());

    final double screenWidth = MediaQuery.of(context).size.width;
    final double scaleFactor = 0.9;
    final double baseFontSize = 10.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'فاتورة بيع نقداً',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
        actions: [
          // **أيقونة الطباعة الجديدة**
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: () => _showPrinterOptions(context), // استدعاء الدالة لعرض الخيارات
            tooltip: 'طباعة الفاتورة',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8.0),
          child: Center(
            child: Transform.scale(
              scale: scaleFactor,
              child: Container(
                width: screenWidth / scaleFactor * 0.9,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderSection(formattedDate, baseFontSize + 4),
                      const SizedBox(height: 12),
                      _buildCustomerInfoSection(baseFontSize),
                      const SizedBox(height: 12),
                      _buildProductsTable(baseFontSize),
                      const SizedBox(height: 16),
                      _buildTotalsSection(baseFontSize),
                      const SizedBox(height: 16),
                      _buildFooterSection(baseFontSize),
                      const SizedBox(height: 16),
                      _buildPrintInfoSection(printDate, baseFontSize),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- دالة جديدة لعرض خيارات الطابعة ---
  void _showPrinterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap( // Wrap يسمح للأطفال باللف إلى سطر جديد إذا لم يكن هناك مساحة كافية
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('طباعة عبر بلوتوث'),
                onTap: () {
                  Navigator.pop(bc); // إغلاق الـ BottomSheet
                  _handlePrint('Bluetooth Printer');
                },
              ),
              ListTile(
                leading: const Icon(Icons.network_check),
                title: const Text('طباعة عبر الشبكة (IP)'),
                onTap: () {
                  Navigator.pop(bc);
                  _handlePrint('Network Printer');
                },
              ),
              ListTile(
                leading: const Icon(Icons.usb), // قد تحتاج لمكتبة للطباعة عبر USB
                title: const Text('طباعة حرارية صغيرة (POS)'),
                onTap: () {
                  Navigator.pop(bc);
                  _handlePrint('Thermal POS Printer');
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('حفظ كملف PDF / مشاركة'),
                onTap: () {
                  Navigator.pop(bc);
                  _handlePrint('Save as PDF');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- دالة لمعالجة الطباعة (هنا يتم دمج منطق الطباعة الفعلي) ---
  void _handlePrint(String printerType) {
    // هنا، ستقوم بتطبيق المنطق الفعلي للطباعة بناءً على 'printerType'
    // ستحتاج إلى:
    // 1. مكتبات Flutter للطباعة (مثل: bluetooth_print, flutter_esc_pos_printer, printing)
    // 2. كود لتحويل بيانات الفاتورة إلى تنسيق قابل للطباعة (مثل ESC/POS للطابعات الحرارية، أو PDF)
    // 3. منطق الاتصال بالطابعة وإرسال البيانات.

    // حالياً، سنعرض فقط رسالة بسيطة
    print('سأقوم بالطباعة باستخدام: $printerType');
    // يمكنك إضافة SnackBar هنا للمستخدم
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('جاري الطباعة باستخدام $printerType...')));
  }

  Widget _buildHeaderSection(String date, double fontSize) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 5),
              Text('شركة تيرا سوفت',
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800)),
              const SizedBox(height: 4),
              Text('صنعاء - شارع صخر',
                  style: TextStyle(fontSize: fontSize - 2, color: Colors.grey.shade600))
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(child: Image.asset('assets/logo.png', height: 50, width: 100)),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('رقم الفاتورة:', transactionNumber, fontSize - 2),
              _buildInfoRow('التاريخ:', date, fontSize - 2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfoSection(double fontSize) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _info('الزبون:', customerName, fontSize)),
              Expanded(child: _info('المخزن:', storeName, fontSize)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _info('الصندوق:', cashBox, fontSize)),
              Expanded(child: _info('العملة:', currency, fontSize)),
            ],
          ),
          Row(
            children: [
              Expanded(child: _info('المحصل:', collector, fontSize)),
              Expanded(child: _info('المندوب:', salesRep, fontSize)),
            ],
          ),
          if (amountPaid != null || remainingAmount != null)
            Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _info('المبلغ المدفوع:', _formatCurrency(amountPaid ?? 0), fontSize)),
                    Expanded(child: _info('المبلغ المتبقي:', _formatCurrency(remainingAmount ?? 0), fontSize)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _info(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: fontSize),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: fontSize)),
        ],
      ),
    );
  }

  Widget _buildProductsTable(double fontSize) {
    if (products.isEmpty) {
      return Text('لا توجد أصناف مضافة', textAlign: TextAlign.center, style: TextStyle(fontSize: fontSize + 1));
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(2.5),
        2: IntrinsicColumnWidth(),
        3: IntrinsicColumnWidth(),
        4: FlexColumnWidth(1.5),
        5: FlexColumnWidth(1.5),
        6: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade300),
          children: [
            _tableCell('رقم الصنف', isHeader: true, fontSize: fontSize),
            _tableCell('الصنف', isHeader: true, fontSize: fontSize),
            _tableCell('الكمية', isHeader: true, fontSize: fontSize),
            _tableCell('ك.ب', isHeader: true, fontSize: fontSize),
            _tableCell('السعر', isHeader: true, fontSize: fontSize),
            _tableCell('الخصم', isHeader: true, fontSize: fontSize),
            _tableCell('الإجمالي', isHeader: true, fontSize: fontSize),
          ],
        ),
        for (final product in products)
          TableRow(children: [
            _tableCell(product['item_no']?.toString() ?? '-', fontSize: fontSize -1),
            _tableCell(product['item_name']?.toString() ?? '-', fontSize: fontSize -1),
            _tableCell((product['quantity'] ?? 0).toString(), fontSize: fontSize -1),
            _tableCell((product['bonus_quantity'] ?? 0).toString(), fontSize: fontSize -1),
            _tableCell(_formatCurrency(product['item_price'] ?? 0), fontSize: fontSize -1),
            _tableCell(_formatCurrency(product['item_discount'] ?? 0), fontSize: fontSize -1),
            _tableCell(_formatCurrency(product['total_item'] ?? 0), fontSize: fontSize -1),
          ]),
      ],
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, required double fontSize}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isHeader ? fontSize : fontSize -1,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.black : Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildTotalsSection(double fontSize) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          _totalRow('الإجمالي', total, fontSize: fontSize),
          _totalRow('الخصم', discount, fontSize: fontSize),
          _totalRow('الضريبة', tax, fontSize: fontSize),
          const Divider(height: 16),
          _totalRow('الصافي', netTotal, isTotal: true, fontSize: fontSize + 1),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool isTotal = false, required double fontSize}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isTotal ? fontSize + 2 : fontSize,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                  color: isTotal ? Colors.blue.shade800 : Colors.black87)),
          Text(_formatCurrency(value),
              style: TextStyle(
                  fontSize: isTotal ? fontSize + 2 : fontSize,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                  color: isTotal ? Colors.blue.shade800 : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildFooterSection(double fontSize) {
    return Column(
      children: [
        Text('شكراً لثقتكم بنا',
            style: TextStyle(fontSize: fontSize + 2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('للاستفسار: 0123456789',
            style: TextStyle(fontSize: fontSize - 1, color: Colors.grey.shade600))
      ],
    );
  }

  Widget _buildPrintInfoSection(String printDate, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text('تمت الطباعة بواسطة: ${userName ?? 'غير معروف'}',
              style: TextStyle(fontSize: fontSize - 1, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text('بتاريخ: $printDate',
              style: TextStyle(fontSize: fontSize - 1, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    final numValue = value is num ? value : 0;
    return NumberFormat('#,##0.00', 'en_US').format(numValue);
  }
}