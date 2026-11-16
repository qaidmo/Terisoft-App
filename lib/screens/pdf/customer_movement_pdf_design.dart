// lib/screens/pdf/customer_movement_pdf_design.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CustomerMovementPdfDesign {
  static Future<Uint8List> generate({
    required List<Map<String, dynamic>> reportData,
    required DateTime fromDate,
    required DateTime toDate,
    required String reportTitle,
    required String companyName,
    required String companyAddress,
    required String contactInfo,
    required String thanksMessage,
    required String logoUrl,
    required bool showLogo,
    required String userName,
    required String userBranchName,
    required String userDepartmentName,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Hacen_Tunisia.ttf");
    final customFont = pw.Font.ttf(fontData);
    final theme = pw.ThemeData.withFont(base: customFont, bold: customFont);

    pw.MemoryImage? logoImage;
    if (showLogo && logoUrl.isNotEmpty) {
      try {
        if (logoUrl.startsWith('http')) {
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
      }
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4.landscape,
      textDirection: pw.TextDirection.rtl,
      theme: theme,
      margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      buildBackground: (context) => pw.FullPage(
        ignoreMargins: true,
        child: pw.Container(
          margin: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
            borderRadius: pw.BorderRadius.circular(5),
          ),
        ),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (context) => _buildHeader(
          companyName: companyName,
          reportTitle: reportTitle,
          fromDate: fromDate,
          toDate: toDate,
          logoImage: logoImage,
          userBranchName: userBranchName,
          userDepartmentName: userDepartmentName,
        ),
        footer: (context) => _buildFooter(
          context: context,
          thanksMessage: thanksMessage,
          contactInfo: contactInfo,
          companyAddress: companyAddress,
          userName: userName,
          customFont: customFont,
        ),
        build: (context) => [
          _buildCustomerMovementTable(reportData),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader({
    required String companyName,
    required String reportTitle,
    required DateTime fromDate,
    required DateTime toDate,
    required pw.ImageProvider? logoImage,
    required String userBranchName,
    required String userDepartmentName,
  }) {
    final DateFormat format = DateFormat('yyyy-MM-dd');
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(5),
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
                    pw.Text(companyName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                    pw.SizedBox(height: 4),
                    pw.Text('$userDepartmentName / $userBranchName', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),

              pw.Expanded(
                flex: 1,
                child: logoImage != null
                    ? pw.SizedBox(
                  height: 80, // تعديل الارتفاع ليناسب الشكل الدائري
                  width: 80,
                  child: pw.ClipOval( // <--- ✅ هذا هو التعديل الأساسي
                    child: pw.Container(
                      color: PdfColors.white, // ضمان وجود خلفية بيضاء داخل الدائرة
                      child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                    ),
                  ),
                )
                    : pw.SizedBox(),
              ),

              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('للفترة من: ${format.format(fromDate)}', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text('إلى: ${format.format(toDate)}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              reportTitle,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter({
    required pw.Context context,
    required String thanksMessage,
    required String contactInfo,
    required String companyAddress,
    required String userName,
    required pw.Font customFont,
  }) {
    // --- ✨ إضافة خط فاصل وتنسيق أفضل للفوتر ---
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey200, width: 1.5)),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(thanksMessage,
              style: pw.TextStyle(
                  font: customFont,
                  fontSize: 12, fontWeight: pw.FontWeight.bold,)),
          pw.SizedBox(height: 6),
          pw.Text('$contactInfo | $companyAddress', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey)),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('تمت الطباعة بواسطة: $userName', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text('تاريخ الطباعة: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // --- ✅ هذه هي الدالة الصحيحة والمُحسَّنة للجدول ---
  static pw.Widget _buildCustomerMovementTable(List<Map<String, dynamic>> data) {
    final numberFormat = NumberFormat("#,##0.00", "en_US");
    final headers = [ 'عمر الدين', 'آخر سداد', 'آخر فاتورة', 'الرصيد', 'التحصيل', 'ص. المبيعات', 'المردودات', 'المبيعات', 'اسم الحساب', ];

    final tableRows = <pw.TableRow>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final balance = (item['balance'] as num?) ?? 0;
      final rowColor = i % 2 == 0 ? PdfColors.blueGrey50 : PdfColors.white;

      tableRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: rowColor),
        children: [
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['debt_age']?.toString() ?? '0', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['last_payment_date']?.toString() ?? '-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['last_invoice_date']?.toString() ?? '-', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(numberFormat.format(balance), style: pw.TextStyle(color: balance > 0 ? PdfColors.red : PdfColors.green, fontSize: 8), textAlign: pw.TextAlign.center)),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(numberFormat.format((item['collections'] as num?) ?? 0), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(numberFormat.format((item['net_sales'] as num?) ?? 0), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(numberFormat.format((item['returns'] as num?) ?? 0), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(numberFormat.format((item['sales'] as num?) ?? 0), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['customer_name'] ?? '', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
        ],
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8), 1: const pw.FlexColumnWidth(1.2), 2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.3), 4: const pw.FlexColumnWidth(1.3), 5: const pw.FlexColumnWidth(1.3),
        6: const pw.FlexColumnWidth(1.3), 7: const pw.FlexColumnWidth(1.3), 8: const pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
          children: headers.map((header) => pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              header,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            ),
          )).toList(),
        ),
        ...tableRows,
      ],
    );
  }
}