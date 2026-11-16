import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfInventoryData {
  static Future<Uint8List> generateCompositeInvoice({
    required Set<String> receiptsToPrint,
    required String headerL,
    required String headerR,
    required String branchAddress,
    required Uint8List? companyLogoBytes,
    String? logoUrl,
    bool showLogo = true,
    required String transactionNumber,
    required String orderNumber,
    String? tableNumber,
    required DateTime date,
    required String customerName,
    required List<Map<String, dynamic>> products,
    required double discount,
    required double tax,
    required double netTotal,
    required String netTotalInWords,
    required String userName,
    required String orderTypeId,
    required String traLstId,
    required String currencyName,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/ARIAL.TTF");
    final customFont = pw.Font.ttf(fontData);
    final theme = pw.ThemeData.withFont(base: customFont, bold: customFont);

    pw.MemoryImage? logoImage;
    if (showLogo) {
      if (companyLogoBytes != null) {
        logoImage = pw.MemoryImage(companyLogoBytes);
      } else if (logoUrl != null && logoUrl.isNotEmpty) {
        try {
          if (logoUrl.startsWith('/assets/')) {
            final ByteData assetData = await rootBundle.load(logoUrl.substring(1));
            logoImage = pw.MemoryImage(assetData.buffer.asUint8List());
          } else if (logoUrl.startsWith('http')) {
            final request = await HttpClient().getUrl(Uri.parse(logoUrl));
            final response = await request.close();
            final bytes = await consolidateHttpClientResponseBytes(response);
            logoImage = pw.MemoryImage(bytes);
          } else {
            final file = File(logoUrl);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              logoImage = pw.MemoryImage(bytes);
            }
          }
        } catch (e) {
          debugPrint('Error loading logo in Restaurant PDF: $e');
        }
      }
    }

    const pageW = 80 * PdfPageFormat.mm;
    const pageFormat =
    PdfPageFormat(pageW, double.infinity, marginAll: 2 * PdfPageFormat.mm);

    if (receiptsToPrint.contains('customer')) {
      pdf.addPage(pw.Page(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (context) => _buildSingleReceipt(
          logoImage: logoImage,
          headerL: headerL,
          headerR: headerR,
          branchAddress: branchAddress,
          invoiceTitle: '(فاتورة خاصة بالزبون)',
          transactionNumber: transactionNumber,
          tableNumber: tableNumber,
          orderNumber: orderNumber,
          date: date,
          products: products,
          discount: discount,
          tax: tax,
          netTotal: netTotal,
          netTotalInWords: netTotalInWords,
          userName: userName,
          receiptType: 'customer',
          customerName: customerName,
          orderTypeId: orderTypeId,
          traLstId: traLstId,
          currencyName: currencyName,
        ),
      ));
    }

    if (receiptsToPrint.contains('waiter')) {
      pdf.addPage(pw.Page(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (context) => _buildSingleReceipt(
          logoImage: logoImage,
          headerL: headerL,
          headerR: headerR,
          branchAddress: branchAddress,
          invoiceTitle: '(خاصة بالمباشر)',
          transactionNumber: transactionNumber,
          orderNumber: orderNumber,
          date: date,
          products: products,
          discount: discount,
          tax: tax,
          netTotal: netTotal,
          netTotalInWords: netTotalInWords,
          userName: userName,
          receiptType: 'kitchen',
          customerName: customerName,
          orderTypeId: orderTypeId,
          traLstId: traLstId,
          currencyName: currencyName,
        ),
      ));
    }

    if (receiptsToPrint.contains('kitchen')) {
      final Map<String, List<Map<String, dynamic>>> itemsByCategory = {};
      for (var item in products) {
        final categoryName = item['categoryName'] ?? 'قسم عام';
        if (!itemsByCategory.containsKey(categoryName)) {
          itemsByCategory[categoryName] = [];
        }
        itemsByCategory[categoryName]!.add(item);
      }
      itemsByCategory.forEach((categoryName, items) {
        pdf.addPage(pw.Page(
          pageFormat: pageFormat,
          textDirection: pw.TextDirection.rtl,
          theme: theme,
          build: (context) => _buildDepartmentSlip(
            categoryName: categoryName,
            transactionNumber: transactionNumber,
            orderNumber: orderNumber,
            date: date,
            products: items,
            userName: userName,
          ),
        ));
      });
    }

    return pdf.save();
  }

  static pw.Widget _buildSingleReceipt({
    required pw.ImageProvider? logoImage,
    required String headerL,
    required String headerR,
    required String branchAddress,
    required String invoiceTitle,
    required String transactionNumber,
    required String orderNumber,
    required DateTime date,
    required String customerName,
    required List<Map<String, dynamic>> products,
    required double discount,
    required double tax,
    required double netTotal,
    required String netTotalInWords,
    required String userName,
    required String receiptType,
    required String orderTypeId,
    required String traLstId,
    required String currencyName,
    String? tableNumber,
  }) {
    final double totalQuantity =
    products.fold(0.0, (sum, item) => sum + (item['quantity'] ?? 0));
    final double totalBeforeDiscountAndTax =
    products.fold(0.0, (sum, item) => sum + (item['total'] ?? 0));

    var finalInvoiceTitle = invoiceTitle;

    if (receiptType == 'customer') {
      final paymentType = traLstId == '803' ? 'اجل' : 'نقدا';
      final orderType = orderTypeId == '1' ? ' سفري' : '';
      finalInvoiceTitle = '(فاتورة $paymentType خاصة بالزبون$orderType)';
    }

    final content = pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logoImage != null) pw.Image(logoImage, height: 40, width: 40),
        if (logoImage != null) pw.SizedBox(height: 1 * PdfPageFormat.mm),
        pw.Text(headerR, style: pw.TextStyle(fontSize: 10, color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
        pw.Text(headerL, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        if (branchAddress.isNotEmpty) pw.Text(branchAddress, style: const pw.TextStyle(fontSize: 8)),
        pw.Divider(height: 4, thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
        pw.Text(finalInvoiceTitle, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow('رقم الفاتورة:', transactionNumber),
                _buildInfoRow('تاريخ الفاتورة:', DateFormat('dd/MM/yyyy').format(date)),
                _buildInfoRow('رقم الطلبية:', orderNumber),
                if (tableNumber != null && tableNumber.isNotEmpty)
                  _buildInfoRow('رقم الطاولة:', tableNumber),
                  _buildInfoRow('اسم العميل:', customerName),
              ]),
        ),
        pw.Divider(height: 4, thickness: 0.5),
        receiptType == 'customer'
            ? _buildCustomerItemsTable(products)
            : _buildKitchenItemsTable(products),
        pw.Divider(height: 4, thickness: 0.5),
        if (receiptType == 'customer' || receiptType == 'kitchen')
          _buildTotalsSection(
            totalQuantity: totalQuantity,
            totalBefore: totalBeforeDiscountAndTax,
            discount: discount,
            tax: tax,
            netTotal: netTotal,
            netTotalInWords: netTotalInWords,
          ),
        if (receiptType == 'customer' && traLstId == '803')
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              "ملحوظة: الرصيد عليكم لهذه الفاتورة ${netTotal.round().toString()} $currencyName",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
        pw.Divider(height: 4, thickness: 0.5),
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(userName, style: const pw.TextStyle(fontSize: 7)),
              pw.Text(DateFormat('dd/MM/yyyy h:mm:ss a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 7)),
            ]),
        pw.SizedBox(height: 2),
        if (receiptType == 'customer')
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: transactionNumber,
              height: 25,
              width: 120,
              textStyle: const pw.TextStyle(fontSize: 0),
            ),
          ),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
        pw.Divider(height: 1, thickness: 0.2, borderStyle: pw.BorderStyle.dotted),
        pw.SizedBox(height: 1 * PdfPageFormat.mm),
        pw.Center(
          child: pw.Text(
            'برمجة وتصميم شركة تيرا سوفت',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ),

      ],
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(1 * PdfPageFormat.mm),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
      child: content,
    );
  }

  static pw.Widget _buildDepartmentSlip({
    required String categoryName,
    required String transactionNumber,
    required String orderNumber,
    required DateTime date,
    required List<Map<String, dynamic>> products,
    required String userName,
  }) {
    final content = pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('( $categoryName)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow('رقـم الفـاتــورة:', transactionNumber),
                _buildInfoRow('تـاريـخ الفـاتــورة:', DateFormat('dd/MM/yyyy').format(date)),
                _buildInfoRow('رقـم الطلـبية:', orderNumber),
              ]),
        ),
        pw.Divider(height: 4, thickness: 0.5),
        _buildDepartmentItemsTable(products),
        pw.Divider(height: 4, thickness: 0.5),
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(userName, style: const pw.TextStyle(fontSize: 7)),
              pw.Text(DateFormat('dd/MM/yyyy h:mm:ss a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 7)),
            ]),
      ],
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(1 * PdfPageFormat.mm),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
      child: content,
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.RichText(
          textAlign: pw.TextAlign.right,
          text: pw.TextSpan(style: const pw.TextStyle(fontSize: 8), children: [
            pw.TextSpan(text: label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: ' $value'),
          ])),
    );
  }

  static pw.Widget _buildCustomerItemsTable(List<Map<String, dynamic>> products) {
    final headers = ['الإجمالي', 'السعر', 'الكمية', 'اسم الصنف', 'م'];
    final data = products.asMap().entries.map((entry) {
      int index = entry.key;
      var prod = entry.value;
      final fullItemName = '${prod['unit']} ${prod['itemName']}';
      return [
        (prod['total'] as num).round().toString(),
        (prod['price'] as num).round().toString(),
        _formatQuantity(prod['quantity'] as num),
        fullItemName,
        (index + 1).toString(),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 1),
      cellStyle: const pw.TextStyle(fontSize: 7),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {3: pw.Alignment.center},
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(3.5),
        4: const pw.FlexColumnWidth(0.5),
      },
      headers: headers,
      data: data,
    );
  }

  static pw.Widget _buildKitchenItemsTable(List<Map<String, dynamic>> products) {
    final headers = ['الإجمالي', 'السعر', 'الكمية', 'التفاصيــــل', 'الكود'];
    final data = products.map((prod) {
      final fullItemName = '${prod['unit']} ${prod['itemName']}';
      return [
        (prod['total'] as num).round().toString(),
        (prod['price'] as num).round().toString(),
        _formatQuantity(prod['quantity'] as num),
        fullItemName,
        prod['itemId'],
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 1),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {3: pw.Alignment.center},
      columnWidths: {
        0: const pw.FlexColumnWidth(1.6),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FlexColumnWidth(2.8),
        4: const pw.FlexColumnWidth(1.5),
      },
      headers: headers,
      data: data,
    );
  }

  static pw.Widget _buildDepartmentItemsTable(List<Map<String, dynamic>> products) {
    final headers = ['الملاحظات', 'الكمية', 'اسم الصنف', 'م'];

    final data = products.asMap().entries.map((entry) {
      int index = entry.key;
      var prod = entry.value;
      final fullItemName = '${prod['unit']} ${prod['itemName']}';
      final note = prod['notes'] as String? ?? '';
      return [note, _formatQuantity(prod['quantity'] as num), fullItemName, (index + 1),];
    }).toList();

    return pw.TableHelper.fromTextArray(
      cellPadding: const pw.EdgeInsets.symmetric(vertical: 1),
      cellStyle: const pw.TextStyle(fontSize: 7),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
      cellAlignment: pw.Alignment.center,
      cellAlignments: { 0: pw.Alignment.center, 2: pw.Alignment.center,},
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(0.5),
      },
      headers: headers,
      data: data,
    );
  }

  static pw.Widget _buildTotalsSection({
    required double totalQuantity,
    required double totalBefore,
    required double discount,
    required double tax,
    required double netTotal,
    required String netTotalInWords,
  }) {
    pw.Widget buildInfoText(String label, String value) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
        child: pw.RichText(
          text: pw.TextSpan(style: const pw.TextStyle(fontSize: 8), children: [
            pw.TextSpan(
                text: label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: ' $value'),
          ],),),);
    }

    return pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        buildInfoText(' الإجمالي : ', _formatQuantity(totalBefore)),
                        if (discount > 0)
                          buildInfoText('الخصم : ', _formatQuantity(discount)),
                      ]),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        buildInfoText('عدد القطع: ', _formatQuantity(totalQuantity)),
                        if (tax > 0)
                          buildInfoText('الضريبة : ', _formatQuantity(tax)),
                      ]),
                ]),
              ]),
          pw.Divider(height: 2, thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                    child: pw.Text("اجمالي الفاتورة", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Container(
                    width: 50,
                    alignment: pw.Alignment.center,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                    child: pw.Text(netTotal.round().toString(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                ]),
          ),
          pw.SizedBox(height: 1),
          pw.Text(netTotalInWords, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ]);
  }

  static String _formatQuantity(num quantity) {
    final format = NumberFormat("#,##0.##");
    return format.format(quantity);
  }
}
