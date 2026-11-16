import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

enum PdfPageType { a4, roll }

const double baseFontSize = 12.0;
const double baseFontSizeRoll = 8;

class PdfInvoiceData {
  static Future<Uint8List> generate({
    required PdfPageType pageType,
    required String transactionNumber,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String accountName,
    required String? cashBox,
    required String currency,
    required String invoiceTypeChar,
    required String? userName,
    String? receiptId,
    String? paymentId,
    required String? costCenter,
    required String? description,
    required String amountInWords,
    required String companyName,
    required String companyAddress,
    required String contactInfo,
    required String thanksMessage,
    required String logoUrl,
    required bool showLogo,
    required String userBranchName,
    required String userDepartmentName,
    Uint8List? pickedLogoBytes,
    String? collectorName,
    String? recipientName,
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
          print('Error loading logo: $e');
        }
      }
    }

    if (pageType == PdfPageType.a4) {
      final String formattedDate = DateFormat('yyyy/MM/dd').format(date);
      final String printDate = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        maxPages: 100,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        theme: theme,
        header: (context) => _buildA4Header(
            formattedDate, baseFontSize + 4, transactionNumber, logoImage,
            companyName, userBranchName, userDepartmentName, _getInvoiceTitle(invoiceTypeChar)),
        footer: (context) => _buildA4Footer(
            baseFontSize, printDate, userName, thanksMessage, contactInfo, companyAddress),
        build: (context) => _buildA4Content(
            items: items, totalAmount: totalAmount, accountName: accountName,
            cashBox: cashBox, currency: currency, invoiceTypeChar: invoiceTypeChar,
            costCenter: costCenter, description: description, amountInWords: amountInWords,
            collectorName: collectorName, recipientName: recipientName,
            customerBalance: customerBalance),
      ));
    } else {
      const pageW = 80 * PdfPageFormat.mm;
      const pageFormat = PdfPageFormat(pageW, double.infinity, marginAll: 4 * PdfPageFormat.mm);
      pdf.addPage(pw.Page(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (context) => _buildVoucherRollContent(
            date: date, transactionNumber: transactionNumber, logoImage: logoImage,
            companyName: companyName, userBranchName: userBranchName,
            userDepartmentName: userDepartmentName, invoiceTypeChar: invoiceTypeChar,
            contactInfo: contactInfo, companyAddress: companyAddress,
            accountName: accountName, cashBox: cashBox, currency: currency,
            collectorName: collectorName, costCenter: costCenter, description: description,
            items: items, totalAmount: totalAmount, amountInWords: amountInWords,
            userName: userName, thanksMessage: thanksMessage,
            customerBalance: customerBalance),
      ));
    }

    return pdf.save();
  }

  static String _getInvoiceTitle(String invoiceTypeChar) {
    switch (invoiceTypeChar) {
      case 'ق': return 'سند قبض نقدي';
      case 'ص': return 'سند صرف نقدي';
      default: return 'سند';
    }
  }

  static pw.Widget _buildA4Header(
      String date, double fontSize, String transactionNumber, pw.ImageProvider? logoImage,
      String companyName, String userBranchName, String userDepartmentName, String invoiceTitle,
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
                    pw.Text(companyName, style: pw.TextStyle(fontSize: fontSize + 4, fontWeight: pw.FontWeight.bold)),
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
      double fontSize, String printDate, String? userName,
      String thanksMessage, String contactInfo, String companyAddress,
      ) {
    return pw.Column(
      children: [
        pw.Text(thanksMessage, style: pw.TextStyle(fontSize: fontSize + 2, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(contactInfo, style: pw.TextStyle(fontSize: fontSize, color: pdfPrimaryColor)),
        pw.SizedBox(height: 6),
        pw.Text(companyAddress, style: pw.TextStyle(fontSize: fontSize, color: pdfPrimaryColor)),
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
              pw.Text('بتاريخ: $printDate', style: pw.TextStyle(fontSize: fontSize, color: pdfPrimaryColor)),
            ],
          ),
        )
      ],
    );
  }

  static List<pw.Widget> _buildA4Content({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String accountName,
    required String? cashBox,
    required String currency,
    required String invoiceTypeChar,
    required String? costCenter,
    required String? description,
    required String amountInWords,
    required String? collectorName,
    String? recipientName,
    double? customerBalance,
  }) {
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
                        invoiceTypeChar == 'ق'
                            ? pw.Expanded(child: _info('العميــل:', accountName, baseFontSize))
                            : pw.Expanded(child: _info('المستلــم:', accountName, baseFontSize)),
                        pw.Expanded(child: _info('الصندوق:', cashBox ?? 'غير محدد', baseFontSize)),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _info('العملة:', currency, baseFontSize)),
                        invoiceTypeChar == 'ق'
                            ? (collectorName != null && collectorName.isNotEmpty)
                            ? pw.Expanded(child: _info('المحصل:', collectorName, baseFontSize))
                            : pw.Expanded(child: pw.SizedBox())
                            : pw.Expanded(child: _info('مركز التكلفة:', costCenter ?? 'لا يوجد', baseFontSize)),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _info('البيــان:', description ?? 'لا يوجد', baseFontSize)),
                        pw.Expanded(child: pw.SizedBox()),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              (items.isEmpty)
                  ? pw.Text('لا توجد بنود', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: baseFontSize + 1))
                  : pw.Table(
                border: pw.TableBorder.all(color: pdfColorBlack),
                columnWidths: const {
                  0: pw.IntrinsicColumnWidth(flex: 1.5), 1: pw.IntrinsicColumnWidth(flex: 1),
                  2: pw.IntrinsicColumnWidth(flex: 1), 3: pw.IntrinsicColumnWidth(flex: 1.5),
                  4: pw.FlexColumnWidth(3), 5: pw.IntrinsicColumnWidth(flex: 2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xffE0F2F7)),
                    children: [
                      _tableCell('المبلغ المعادل', isHeader: true, fontSize: baseFontSize),
                      _tableCell('سعر الصرف', isHeader: true, fontSize: baseFontSize),
                      _tableCell('العملة', isHeader: true, fontSize: baseFontSize),
                      _tableCell('المبلغ', isHeader: true, fontSize: baseFontSize),
                      _tableCell('الحساب', isHeader: true, fontSize: baseFontSize),
                      _tableCell('رقم الحساب', isHeader: true, fontSize: baseFontSize),
                    ],
                  ),
                  for (final item in items)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: pdfWhite),
                      children: [
                        _tableCell(_formatCurrency(item['equivalent_amount'] ?? 0), fontSize: baseFontSize - 1),
                        _tableCell(_formatCurrency(item['exchange_rate'] ?? 1.0), fontSize: baseFontSize - 1),
                        _tableCell(item['item_currency']?.toString() ?? '-', fontSize: baseFontSize - 1),
                        _tableCell(_formatCurrency(item['amount'] ?? 0), fontSize: baseFontSize - 1),
                        _tableCell(item['account_name']?.toString() ?? '-', fontSize: baseFontSize - 1),
                        _tableCell(item['account_no']?.toString() ?? '-', fontSize: baseFontSize - 1),
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
                    _totalRow('الإجمالي', totalAmount, isTotal: true, fontSize: baseFontSize + 1),
                    pw.SizedBox(height: 8),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: _totalRow('المبلغ كتابةً', amountInWords, isText: true, fontSize: baseFontSize + 1, currencyValue: currency),
                    ),
                    if (customerBalance != null && customerBalance != 0)
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
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.normal, fontSize: fontSize + 4)),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: fontSize + 2, color: pdfColorBlack), maxLines: 3),
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

  static pw.Widget _totalRow(String label, dynamic value, {bool isTotal = false, bool isText = false, required double fontSize, String? currencyValue}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: isTotal || isText ? fontSize + 4 : fontSize + 2,
                  color: isTotal || isText ? pdfPrimaryColor : pdfColorBlack)),
          pw.Text(
              isText
                  ? (currencyValue != null && currencyValue.isNotEmpty ? '$value $currencyValue' : value)
                  : _formatCurrency(value),
              style: pw.TextStyle(
                  fontSize: isTotal || isText ? fontSize + 4 : fontSize + 2,
                  color: isTotal || isText ? pdfPrimaryColor : pdfColorBlack)),
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

  static const PdfColor pdfPrimaryColor = PdfColor.fromInt(0xff216BB4);
  static const PdfColor pdfColorBlack = PdfColor.fromInt(0xff000000);
  static const PdfColor pdfWhite = PdfColor.fromInt(0xffffffff);

  static pw.Widget _buildVoucherRollContent({
    required DateTime date,
    required String transactionNumber,
    pw.ImageProvider? logoImage,
    required String companyName,
    required String userBranchName,
    required String userDepartmentName,
    required String invoiceTypeChar,
    required String contactInfo,
    required String companyAddress,
    required String accountName,
    String? cashBox,
    required String currency,
    String? collectorName,
    String? costCenter,
    String? description,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String amountInWords,
    String? userName,
    required String thanksMessage,
    double? customerBalance,
  }) {
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
            pw.Text('$userDepartmentName / $userBranchName', style: const pw.TextStyle(fontSize: baseFontSizeRoll)),
            pw.Divider(height: 8, thickness: 0.5),
            pw.Text(_getInvoiceTitle(invoiceTypeChar), style: pw.TextStyle(fontSize: baseFontSizeRoll + 2, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 5),

            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('رقم السند: ', style: pw.TextStyle(fontSize: baseFontSizeRoll, fontWeight: pw.FontWeight.bold)),
                        pw.Text(transactionNumber, style: const pw.TextStyle(fontSize: baseFontSizeRoll)),
                      ]
                  ),
                  pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text('التاريخ: ', style: pw.TextStyle(fontSize: baseFontSizeRoll, fontWeight: pw.FontWeight.bold)),
                        pw.Text(DateFormat('yyyy-MM-dd').format(date), style: const pw.TextStyle(fontSize: baseFontSizeRoll)),
                      ]
                  ),
                ]
            ),

            pw.Divider(height: 8, borderStyle: pw.BorderStyle.dashed),

            pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _rollInfoRow(
                            invoiceTypeChar == 'ق' ? 'استلمت من الاخ/ ' : 'المستلــم:',
                            accountName
                        ),
                        if (cashBox != null && cashBox.isNotEmpty)
                          _rollInfoRow('الصندوق:', cashBox),

                        if (invoiceTypeChar == 'ق' && collectorName != null && collectorName.isNotEmpty)
                          _rollInfoRow('المحصل:', collectorName),

                        if (invoiceTypeChar == 'ص' && costCenter != null && costCenter.isNotEmpty)
                          _rollInfoRow('مركز التكلفة:', costCenter),
                      ]
                  )),
                  pw.SizedBox(width: 5),
                  pw.Expanded(child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _rollInfoRow('العملة:', currency),
                        _rollInfoRow('البيــان:', description ?? '-'),
                      ]
                  )),
                ]
            ),

            pw.Divider(height: 8, borderStyle: pw.BorderStyle.dashed),

            pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.8), 1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.2), 3: pw.FlexColumnWidth(1.8),
                  4: pw.FlexColumnWidth(3),   5: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xffE0F2F7)),
                      children: [
                        _rollTableCell('مقابل', isHeader: true),
                        _rollTableCell('سعر', isHeader: true),
                        _rollTableCell('عملة', isHeader: true),
                        _rollTableCell('المبلغ', isHeader: true),
                        _rollTableCell('الحساب', isHeader: true, align: pw.TextAlign.center),
                        _rollTableCell('رقم ح', isHeader: true),
                      ]
                  ),
                  for (final item in items)
                    pw.TableRow(
                        children: [
                          _rollTableCell(_formatCurrency(item['equivalent_amount'] ?? 0)),
                          _rollTableCell((item['exchange_rate'] ?? 1.0).toStringAsFixed(2)),
                          _rollTableCell(item['item_currency']?.toString() ?? '-'),
                          _rollTableCell(_formatCurrency(item['amount'] ?? 0)),
                          _rollTableCell(item['account_name']?.toString() ?? '-', align: pw.TextAlign.right),
                          _rollTableCell(item['account_no']?.toString() ?? '-'),
                        ]
                    ),
                ]
            ),

            pw.Divider(height: 8, borderStyle: pw.BorderStyle.dashed),

            _rollTotalRow('الإجمالي:', _formatCurrency(totalAmount), isTotal: true),
            pw.SizedBox(height: 5),
            _rollInfoRow('المبلغ كتابةً:', '$amountInWords $currency'),

            if (customerBalance != null && customerBalance != 0)
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

            pw.Divider(height: 8),
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

  static pw.Widget _rollInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: baseFontSizeRoll, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 3),
            pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: baseFontSizeRoll))),
          ]
      ),
    );
  }

  static pw.Widget _rollTableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(2),
      child: pw.Text(
        text, textAlign: align,
        style: pw.TextStyle(
          fontSize: isHeader ? baseFontSizeRoll : baseFontSizeRoll - 1,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _rollTotalRow(String label, String value, {bool isTotal = false}) {
    final style = pw.TextStyle(
      fontSize: isTotal ? baseFontSizeRoll + 2 : baseFontSizeRoll,
      fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [ pw.Text(label, style: style), pw.Text(value, style: style), ]
      ),
    );
  }
}

class PdfFileHelper {
  static Future<File> saveDocument({
    required String name,
    required pw.Document pdf,
  }) async {
    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }
}