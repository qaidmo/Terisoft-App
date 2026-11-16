import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:untitled4/screens/pdf/pdf_view.dart';

const double baseFontSize = 12.0;
const double baseFontSizeRoll = 8.0;

class PdfInventoryData {
  static Future<Uint8List> generate({
    required PdfPageType pageType,
    required String transactionNumber,
    required DateTime date,
    required List<Map<String, dynamic>> products,
    required double total,
    required double tax,
    required double discount,
    required String customerName,
    required String storeName,
    String? cashBox,
    required String currency,
    required String collector,
    required String salesRep,
    required double netTotal,
    required String invoiceTypeChar,
    String? userName,
    String? saleId,
    double? amountPaid,
    double? remainingAmount,
    String? accountNo,
    required String companyName,
    required String companyAddress,
    required String contactInfo,
    required String thanksMessage,
    required String logoUrl,
    required bool showLogo,
    required String userBranchName,
    required String userDepartmentName,
    Uint8List? pickedLogoBytes,
    required String netTotalInWords,
    double? customerBalance,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/ARIAL.TTF");
    final customFont = pw.Font.ttf(fontData);
    final theme = pw.ThemeData.withFont(base: customFont, bold: customFont);

    pw.MemoryImage? logoImage;
    if (showLogo) {
      if (pickedLogoBytes != null) {
        logoImage = pw.MemoryImage(pickedLogoBytes);
      } else if (logoUrl.isNotEmpty) {
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
          print(e);
        }
      }
    }

    if (pageType == PdfPageType.a4) {
      final String formattedDate = DateFormat('yyyy/MM/dd').format(date);
      final String printDate = DateFormat('yyyy/MM_dd').format(DateTime.now());

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        maxPages: 100,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        theme: theme,
        header: (context) => _buildA4Header(
          formattedDate,
          baseFontSize + 4,
          transactionNumber,
          logoImage,
          companyName,
          userBranchName,
          userDepartmentName,
          _getInvoiceTitle(invoiceTypeChar),
        ),
        footer: (context) => _buildA4Footer(
          baseFontSize,
          printDate,
          userName,
          thanksMessage,
          contactInfo,
          companyAddress,
        ),
        build: (context) => _buildA4Content(
            customerName: customerName,
            storeName: storeName,
            invoiceTypeChar: invoiceTypeChar,
            cashBox: cashBox,
            currency: currency,
            collector: collector,
            salesRep: salesRep,
            amountPaid: amountPaid,
            remainingAmount: remainingAmount,
            products: products,
            total: total,
            discount: discount,
            tax: tax,
            netTotal: netTotal,
            netTotalInWords: netTotalInWords,
            customerBalance: customerBalance),
      ));
    } else {
      const pageW = 80 * PdfPageFormat.mm;
      const pageFormat = PdfPageFormat(pageW, double.infinity, marginAll: 4 * PdfPageFormat.mm);
      pdf.addPage(pw.Page(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (context) => _buildRollContent(
            date: date, transactionNumber: transactionNumber, logoImage: logoImage,
            companyName: companyName, invoiceTypeChar: invoiceTypeChar,
            contactInfo: contactInfo, customerName: customerName,
            storeName: storeName, cashBox: cashBox, collector: collector,
            salesRep: salesRep, products: products, total: total,
            discount: discount, tax: tax, netTotal: netTotal,
            currency: currency, userName: userName, thanksMessage: thanksMessage,
            userBranchName: userBranchName,
            userDepartmentName: userDepartmentName,
            netTotalInWords: netTotalInWords,
            companyAddress: companyAddress,
            customerBalance: customerBalance),
      ));
    }

    return pdf.save();
  }

  static String _getInvoiceTitle(String invoiceTypeChar) {
    switch (invoiceTypeChar) {
      case 'ن': return 'فاتورة مبيعات نقداً';
      case 'ت': return 'فاتورة بيع نقداً';
      case 'م': return 'فاتورة بيع نقداً معلق';
      case 'ج': return 'فاتورة بيع آجل';
      case 'رن': return 'فاتورة مردود بيع نقدي';
      case 'رج': return 'فاتورة مردود بيع آجل';
      case 'رم': return 'فاتورة مردود بيع معلق';
      default: return 'فاتورة';
    }
  }

  static pw.Widget _buildA4Header(
      String date,
      double fontSize,
      String transactionNumber,
      pw.ImageProvider? logoImage,
      String companyName,
      String userBranchName,
      String userDepartmentName,
      String invoiceTitle,
      ) {
    final double regularFontSize = fontSize - 4;

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: pdfColorBlack, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: 5),
                    pw.Text(companyName, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('الفرع: $userBranchName', style: pw.TextStyle(fontSize: regularFontSize + 2, color: pdfColorBlack)),
                    pw.Text('القسم: $userDepartmentName', style: pw.TextStyle(fontSize: regularFontSize + 2, color: pdfColorBlack)),
                    pw.SizedBox(height: 4),
                  ],
                ),
              ),
              if (logoImage != null)
                pw.Flexible(child: pw.Image(logoImage, height: 100, fit: pw.BoxFit.contain)),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    _buildInfoRow('رقم الفاتورة:', transactionNumber, regularFontSize + 2),
                    _buildInfoRow('التاريخ:', date, regularFontSize + 2),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              invoiceTitle,
              style: pw.TextStyle(
                fontSize: regularFontSize + 8,
                fontWeight: pw.FontWeight.bold,
                decoration: pw.TextDecoration.underline,
                color: const PdfColor.fromInt(0xff216BB4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildA4Footer(
      double fontSize,
      String printDate,
      String? userName,
      String thanksMessage,
      String contactInfo,
      String companyAddress,
      ) {
    return pw.Column(
      children: [
        pw.Text(thanksMessage,
            style: pw.TextStyle(fontSize: fontSize + 2, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(contactInfo,
            style: pw.TextStyle(fontSize: fontSize, color: pdfPrimaryColor)),
        pw.SizedBox(height: 6),
        pw.Text(companyAddress,
            style: pw.TextStyle(fontSize: fontSize, color: pdfPrimaryColor)),
        pw.SizedBox(height: 16),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8.0),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'تمت الطباعة بواسطة: ${userName ?? 'غير معروف'}',
                  style: pw.TextStyle(fontSize: fontSize, color: pdfPrimaryColor),
                  maxLines: 1,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text('بتاريخ: $printDate',
                  style: pw.TextStyle(fontSize: fontSize, color: pdfPrimaryColor)),
            ],
          ),
        )
      ],
    );
  }

  static List<pw.Widget> _buildA4Content({
    required String customerName,
    required String storeName,
    required String invoiceTypeChar,
    String? cashBox,
    required String currency,
    required String collector,
    required String salesRep,
    double? amountPaid,
    double? remainingAmount,
    required List<Map<String, dynamic>> products,
    required double total,
    required double discount,
    required double tax,
    required double netTotal,
    required String netTotalInWords,
    double? customerBalance,
  }) {
    bool hasPumpReadings = products.any((p) => (p['current_reading'] != null && double.tryParse(p['current_reading'].toString()) != 0) || (p['previous_reading'] != null && double.tryParse(p['previous_reading'].toString()) != 0) || (p['pump_name'] != null && p['pump_name'].toString().isNotEmpty));
    return [
      pw.SizedBox(height: 15),
      pw.Container(
        padding: const pw.EdgeInsets.all(4),
        margin: const pw.EdgeInsets.symmetric(horizontal: 0),
        decoration: pw.BoxDecoration(
          color: pdfWhite,
          border: pw.Border.all(color: pdfColorBlack),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(12.0),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdfColorBlack),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(child: _info('الزبون:', customerName, baseFontSize)),
                        pw.Expanded(child: _info('المخزن:', storeName, baseFontSize)),
                      ],
                    ),
                    if (invoiceTypeChar != 'ج' && invoiceTypeChar != 'رج')
                      pw.Row(
                        children: [
                          pw.Expanded(child: _info('الصندوق:', cashBox ?? '', baseFontSize)),
                          pw.Expanded(child: _info('العملة:', currency, baseFontSize)),
                        ],
                      )
                    else
                      pw.Row(
                        children: [
                          pw.Expanded(child: _info('العملة:', currency, baseFontSize)),
                          if (salesRep.isNotEmpty)
                            pw.Expanded(child: _info('المندوب:', salesRep, baseFontSize))
                          else
                            pw.Expanded(child: pw.SizedBox()),
                        ],
                      ),
                    if (invoiceTypeChar != 'ج' && invoiceTypeChar != 'رج')
                      pw.Row(
                        children: [
                          if (collector.isNotEmpty)
                            pw.Expanded(child: _info('المحصل:', collector, baseFontSize))
                          else
                            pw.Expanded(child: pw.SizedBox()),
                          if (salesRep.isNotEmpty)
                            pw.Expanded(child: _info('المندوب:', salesRep, baseFontSize))
                          else
                            pw.Expanded(child: pw.SizedBox()),
                        ],
                      )
                    else
                      pw.Row(
                        children: [
                          if (collector.isNotEmpty)
                            pw.Expanded(child: _info('المحصل:', collector, baseFontSize))
                          else
                            pw.Expanded(child: pw.SizedBox()),
                          pw.Expanded(child: pw.SizedBox()),
                        ],
                      ),
                    if (amountPaid != null || remainingAmount != null)
                      pw.Column(
                        children: [
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              pw.Expanded(child: _info('المبلغ المدفوع:', _formatCurrency(amountPaid ?? 0), baseFontSize)),
                              pw.Expanded(child: _info('المبلغ المتبقي:', _formatCurrency(remainingAmount ?? 0), baseFontSize)),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              (products.isEmpty)
                  ? pw.Text('لا توجد أصناف مضافة', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: baseFontSize + 1))
                  : (invoiceTypeChar == 'ت') 
                    ? pw.Table(
                        border: pw.TableBorder.all(color: pdfColorBlack),
                        columnWidths: hasPumpReadings ? const {
                          0: pw.IntrinsicColumnWidth(flex: 1.5),
                          1: pw.IntrinsicColumnWidth(flex: 1.5),
                          2: pw.IntrinsicColumnWidth(flex: 1.0),
                          3: pw.IntrinsicColumnWidth(flex: 1.5),
                          4: pw.IntrinsicColumnWidth(flex: 1.5),
                          5: pw.IntrinsicColumnWidth(flex: 1.0),
                          6: pw.FlexColumnWidth(2.0),
                          7: pw.IntrinsicColumnWidth(flex: 1.5),
                        } : const {
                          0: pw.IntrinsicColumnWidth(flex: 1.5),
                          1: pw.IntrinsicColumnWidth(flex: 1.5),
                          2: pw.IntrinsicColumnWidth(flex: 1.0),
                          3: pw.IntrinsicColumnWidth(flex: 1.0),
                          4: pw.FlexColumnWidth(2.5),
                          5: pw.IntrinsicColumnWidth(flex: 1.0),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xffE0F2F7)),
                            children: [
                              _tableCell('الإجمالي', isHeader: true, fontSize: baseFontSize),
                              _tableCell('السعر', isHeader: true, fontSize: baseFontSize),
                              _tableCell('الكمية', isHeader: true, fontSize: baseFontSize),
                              if (hasPumpReadings) _tableCell('ق. حالية', isHeader: true, fontSize: baseFontSize),
                              if (hasPumpReadings) _tableCell('ق. سابقة', isHeader: true, fontSize: baseFontSize),
                              _tableCell('الوحدة', isHeader: true, fontSize: baseFontSize),
                              _tableCell('اسم الصنف', isHeader: true, fontSize: baseFontSize),
                              _tableCell('رقم الصنف', isHeader: true, fontSize: baseFontSize),
                            ],
                          ),
                          for (final product in products)
                            pw.TableRow(
                              decoration: const pw.BoxDecoration(color: pdfWhite),
                              children: [
                                _tableCell(_formatCurrency(product['total_item'] ?? 0), fontSize: baseFontSize - 1),
                                _tableCell(_formatCurrency(product['item_price'] ?? 0), fontSize: baseFontSize - 1),
                                _tableCell((product['quantity'] ?? 0).toString(), fontSize: baseFontSize - 1),
                                if (hasPumpReadings) _tableCell((product['current_reading'] ?? 0).toString(), fontSize: baseFontSize - 1),
                                if (hasPumpReadings) _tableCell((product['previous_reading'] ?? 0).toString(), fontSize: baseFontSize - 1),
                                _tableCell(product['item_unit']?.toString() ?? '-', fontSize: baseFontSize - 1),
                                _tableCell(product['item_name']?.toString() ?? '-', fontSize: baseFontSize - 1),
                                _tableCell(product['item_no']?.toString() ?? '-', fontSize: baseFontSize - 1),
                              ],
                            ),
                        ],
                      )
                    : pw.Table(
                        border: pw.TableBorder.all(color: pdfColorBlack),
                        columnWidths: const {
                          0: pw.IntrinsicColumnWidth(flex: 1.5),
                          1: pw.IntrinsicColumnWidth(flex: 1.5),
                          2: pw.IntrinsicColumnWidth(flex: 1.5),
                          3: pw.IntrinsicColumnWidth(flex: 1.0),
                          4: pw.IntrinsicColumnWidth(flex: 1.0),
                          5: pw.IntrinsicColumnWidth(flex: 1.0),
                          6: pw.FlexColumnWidth(2.5),
                          7: pw.IntrinsicColumnWidth(flex: 1.5),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xffE0F2F7)),
                            children: [
                              _tableCell('الإجمالي', isHeader: true, fontSize: baseFontSize),
                              _tableCell('الخصم', isHeader: true, fontSize: baseFontSize),
                              _tableCell('السعر', isHeader: true, fontSize: baseFontSize),
                              _tableCell('ك.ص', isHeader: true, fontSize: baseFontSize),
                              _tableCell('الكمية', isHeader: true, fontSize: baseFontSize),
                              _tableCell('الوحدة', isHeader: true, fontSize: baseFontSize),
                              _tableCell('اسـم الصنف', isHeader: true, fontSize: baseFontSize),
                              _tableCell('الرقم', isHeader: true, fontSize: baseFontSize),
                            ],
                          ),
                          for (final product in products)
                            pw.TableRow(
                              decoration: const pw.BoxDecoration(color: pdfWhite),
                              children: [
                                _tableCell(_formatCurrency(product['total_item'] ?? 0), fontSize: baseFontSize - 1),
                                _tableCell(_formatCurrency(product['item_discount'] ?? 0), fontSize: baseFontSize - 1),
                                _tableCell(_formatCurrency(product['item_price'] ?? 0), fontSize: baseFontSize - 1),
                                _tableCell((product['bonus_quantity'] ?? 0).toString(), fontSize: baseFontSize - 1),
                                _tableCell((product['quantity'] ?? 0).toString(), fontSize: baseFontSize - 1),
                                _tableCell(product['item_unit']?.toString() ?? '-', fontSize: baseFontSize - 1),
                                _tableCell(product['item_name']?.toString() ?? '-', fontSize: baseFontSize - 1),
                                _tableCell(product['item_no']?.toString() ?? '-', fontSize: baseFontSize - 1),
                              ],
                            ),
                        ],
                      ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdfColorBlack),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    _totalRow('الإجمالي', total, fontSize: baseFontSize + 2),
                    if (invoiceTypeChar != 'ت') _totalRow('الخصم', discount, fontSize: baseFontSize + 2),
                    if (invoiceTypeChar != 'ت') _totalRow('الضريبة', tax, fontSize: baseFontSize + 2),
                    pw.Divider(height: 16),
                    _totalRow(
                      'الصافي',
                      netTotal,
                      isTotal: true,
                      fontSize: baseFontSize + 1,
                      textValue: netTotalInWords,
                      currency: currency,
                    ),
                    if (customerBalance != null && customerBalance != 0 && ['ج', 'رج', 'م', 'رم'].contains(invoiceTypeChar))
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 8),
                        child: pw.Center(
                          child: pw.Text(
                            '${customerBalance < 0 ? 'ملحوظة: الرصيد لكم' : 'ملحوظة: الرصيد عليكم'} ${_formatCurrency(customerBalance.abs())} $currency',
                            style: pw.TextStyle(fontSize: baseFontSize + 2, fontWeight: pw.FontWeight.bold, color: pdfColorBlack),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  static pw.Widget _info(String label, String value, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.normal, fontSize: fontSize + 4),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: fontSize + 2, color: pdfColorBlack),
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, double fontSize) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Wrap(
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize)),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false, required double fontSize}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4.0, vertical: 6),
      child: pw.Text(
        text,
        maxLines: 2,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: isHeader ? fontSize + 2 : fontSize - 1,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: pdfColorBlack,
        ),
      ),
    );
  }

  static pw.Widget _totalRow(String label, double value, {bool isTotal = false, required double fontSize, String? textValue, String? currency}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (isTotal && textValue != null && textValue.isNotEmpty)
            pw.Expanded(
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  '$label: $textValue ${currency ?? ''}',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    fontSize: isTotal ? fontSize + 8 : fontSize + 3,
                    color: isTotal ? pdfPrimaryColor : pdfColorBlack,
                    fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            )
          else
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: isTotal ? fontSize + 8 : fontSize + 3,
                    color: isTotal ? pdfPrimaryColor : pdfColorBlack)),
          pw.Text(
              _formatCurrency(value),
              style: pw.TextStyle(
                  fontSize: isTotal ? fontSize + 8 : fontSize + 2,
                  color: isTotal ? pdfPrimaryColor : pdfColorBlack,
                  fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static String _formatCurrency(dynamic value) {
    final num numValue = value is num ? value : 0;

    if (numValue == numValue.round()) {
      return NumberFormat('#,##0', 'en_US').format(numValue);
    } else {
      return NumberFormat('#,##0.00', 'en_US').format(numValue);
    }
  }

  static pw.Widget _buildRollContent({
    required String userBranchName,
    required String userDepartmentName,
    required String netTotalInWords,
    required String companyAddress,
    required DateTime date,
    required String transactionNumber,
    pw.ImageProvider? logoImage,
    required String companyName,
    required String invoiceTypeChar,
    required String contactInfo,
    required String customerName,
    required String storeName,
    String? cashBox,
    required String collector,
    required String salesRep,
    required List<Map<String, dynamic>> products,
    required double total,
    required double discount,
    required double tax,
    required double netTotal,
    required String currency,
    String? userName,
    required String thanksMessage,
    double? customerBalance,
  }) {
    bool hasPumpReadings = products.any((p) => (p['current_reading'] != null && double.tryParse(p['current_reading'].toString()) != 0) || (p['previous_reading'] != null && double.tryParse(p['previous_reading'].toString()) != 0) || (p['pump_name'] != null && p['pump_name'].toString().isNotEmpty));
    
    final pw.BoxDecoration sectionDecoration = pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey700, width: 0.5),
      borderRadius: pw.BorderRadius.circular(4),
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logoImage != null) pw.Image(logoImage, height: 40),
            if (logoImage != null) pw.SizedBox(height: 3),
            pw.Text(companyName, style: pw.TextStyle(fontSize: baseFontSizeRoll + 3, fontWeight: pw.FontWeight.bold)),
            pw.Text('الفرع: $userBranchName', style: const pw.TextStyle(fontSize: baseFontSizeRoll)),
            pw.Text('القسم: $userDepartmentName', style: const pw.TextStyle(fontSize: baseFontSizeRoll)),
            pw.Divider(height: 8, thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
            pw.Row(
                children: [
                  pw.Expanded(child: _rollInfoRow('رقم الفاتورة:', transactionNumber)),
                  pw.SizedBox(width: 5),
                  pw.Expanded(child: _rollInfoRow('التاريخ:', DateFormat('yyyy-MM-dd').format(date))),
                ]
            ),
            pw.Divider(height: 8, thickness: 0.5),
            pw.Text(_getInvoiceTitle(invoiceTypeChar), style: pw.TextStyle(fontSize: baseFontSizeRoll + 2, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 6),

            pw.Container(
              decoration: sectionDecoration,
              padding: const pw.EdgeInsets.all(4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _rollInfoRow('الزبون:', customerName),
                        _rollInfoRow('المخزن:', storeName),
                        _rollInfoRow('العملة:', currency),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (collector.isNotEmpty)
                          _rollInfoRow('المحصل:', collector),
                        if (salesRep.isNotEmpty)
                          _rollInfoRow('المندوب:', salesRep),
                        if (cashBox != null && cashBox.isNotEmpty) _rollInfoRow('الصندوق:', cashBox),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            (invoiceTypeChar == 'ت') 
              ? pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: hasPumpReadings ? const {
                    0: pw.FlexColumnWidth(1.6),
                    1: pw.FlexColumnWidth(1.4),
                    2: pw.FlexColumnWidth(1.2),
                    3: pw.FlexColumnWidth(1.2),
                    4: pw.FlexColumnWidth(1.2),
                    5: pw.FlexColumnWidth(2.8),
                  } : const {
                    0: pw.FlexColumnWidth(1.6),
                    1: pw.FlexColumnWidth(1.4),
                    2: pw.FlexColumnWidth(1.2),
                    3: pw.FlexColumnWidth(1.2),
                    4: pw.FlexColumnWidth(2.8),
                  },
                  children: [
                    pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xffE0F2F7)),
                        children: [
                          _rollTableCell('الاجمالي', isHeader: true),
                          _rollTableCell('السعر', isHeader: true),
                          _rollTableCell('الكمية', isHeader: true),
                          if (hasPumpReadings) _rollTableCell('حالية', isHeader: true),
                          if (hasPumpReadings) _rollTableCell('سابقة', isHeader: true),
                          _rollTableCell('الصنف', isHeader: true, align: pw.TextAlign.center),
                        ]
                    ),
                    for (final product in products)
                      pw.TableRow(
                          children: [
                            _rollTableCell(_formatCurrency(product['total_item'] ?? 0)),
                            _rollTableCell(_formatCurrency(product['item_price'] ?? 0)),
                            _rollTableCell((product['quantity'] ?? 0).toString()),
                            if (hasPumpReadings) _rollTableCell((product['current_reading'] ?? 0).toString()),
                            if (hasPumpReadings) _rollTableCell((product['previous_reading'] ?? 0).toString()),
                            _rollTableCell('${hasPumpReadings ? (product['pump_name'] ?? '-') + '\\n' : ''}${product['item_name'] ?? ''}', align: pw.TextAlign.center),
                          ]
                      ),
                  ]
              )
              : pw.Table(
                  border: pw.TableBorder.all(width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1.6),
                    1: pw.FlexColumnWidth(1.2),
                    2: pw.FlexColumnWidth(1.4),
                    3: pw.FlexColumnWidth(1.0),
                    4: pw.FlexColumnWidth(1.0),
                    5: pw.FlexColumnWidth(2.8),
                    6: pw.FlexColumnWidth(1.0),
                  },
                  children: [
                    pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xffE0F2F7)),
                        children: [
                          _rollTableCell('الاجمالي', isHeader: true),
                          _rollTableCell('الخصم', isHeader: true),
                          _rollTableCell('السعر', isHeader: true),
                          _rollTableCell('الكمية', isHeader: true),
                          _rollTableCell('الوحدة', isHeader: true),
                          _rollTableCell('الصنف', isHeader: true, align: pw.TextAlign.center),
                          _rollTableCell('رقم', isHeader: true),
                        ]
                    ),
                    for (final product in products)
                      pw.TableRow(
                          children: [
                            _rollTableCell(_formatCurrency(product['total_item'] ?? 0)),
                            _rollTableCell(_formatCurrency(product['item_discount'] ?? 0)),
                            _rollTableCell(_formatCurrency(product['item_price'] ?? 0)),
                            _rollTableCell((product['quantity'] ?? 0).toString()),
                            _rollTableCell(product['item_unit']?.toString() ?? '-'),
                            _rollTableCell(product['item_name'] ?? '', align: pw.TextAlign.center),
                            _rollTableCell(product['item_no']?.toString() ?? '-'),
                          ]
                      ),
                  ]
              ),
            pw.SizedBox(height: 6),

            pw.Container(
                decoration: sectionDecoration,
                padding: const pw.EdgeInsets.all(4),
                child: pw.Column(
                    children: [
                      _rollTotalRow('الإجمالي:', _formatCurrency(total)),
                      if (invoiceTypeChar != 'ت') _rollTotalRow('الخصم:', _formatCurrency(discount)),
                      if (invoiceTypeChar != 'ت') _rollTotalRow('الضريبة:', _formatCurrency(tax)),
                      pw.Divider(height: 5, color: PdfColors.grey700),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 1),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              flex: 5,
                              child: pw.Row(children: [
                                pw.Text('الصافي: ', style: pw.TextStyle(fontSize: baseFontSizeRoll + 1, fontWeight: pw.FontWeight.bold)),
                                pw.Expanded(child: pw.Text('$netTotalInWords $currency.', style: pw.TextStyle(fontSize: baseFontSizeRoll, fontWeight: pw.FontWeight.bold))),
                              ]),
                            ),
                            pw.SizedBox(width: 5),
                            pw.Text(_formatCurrency(netTotal), style: pw.TextStyle(fontSize: baseFontSizeRoll + 1, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (customerBalance != null && customerBalance != 0 && ['ج', 'رج', 'م', 'رم'].contains(invoiceTypeChar))
                        pw.Column(
                          children: [
                            pw.Divider(height: 5, color: PdfColors.grey700),
                            pw.Center(
                              child: pw.Text(
                                '${customerBalance < 0 ? 'ملحوظة: الرصيد لكم' : 'ملحوظة: الرصيد عليكم'} ${_formatCurrency(customerBalance.abs())} $currency',
                                style: pw.TextStyle(fontSize: baseFontSizeRoll, fontWeight: pw.FontWeight.bold, color: pdfColorBlack),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                    ]
                )
            ),
            pw.SizedBox(height: 6),

            pw.Text(thanksMessage, style: pw.TextStyle(fontSize: baseFontSizeRoll, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text(contactInfo, style: const pw.TextStyle(fontSize: baseFontSizeRoll)),
            pw.Text(companyAddress, style: const pw.TextStyle(fontSize: baseFontSizeRoll)),
            pw.SizedBox(height: 3),
            if (userName != null) pw.Text('المستخدم: $userName', style: const pw.TextStyle(fontSize: baseFontSizeRoll - 1)),
          ]
      ),
    );
  }

  static pw.Widget _rollTableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? baseFontSizeRoll - 0.5 : baseFontSizeRoll - 1.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _rollTotalRow(String label, String value, {bool isTotal = false}) {
    final style = pw.TextStyle(
      fontSize: isTotal ? baseFontSizeRoll + 1 : baseFontSizeRoll,
      fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [ pw.Text(label, style: style), pw.Text(value, style: style), ]
      ),
    );
  }

  static pw.Widget _rollInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: baseFontSizeRoll, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 3),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: baseFontSizeRoll))),
          ]
      ),
    );
  }

  static const PdfColor pdfPrimaryColor = PdfColor.fromInt(0xff216BB4);
  static const PdfColor pdfColorBlack = PdfColor.fromInt(0xff000000);
  static const PdfColor pdfWhite = PdfColor.fromInt(0xffffffff);
}