import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SalesMovementPdfDesign {
  static Future<Uint8List> generate({
    required List<Map<String, dynamic>> reportData,
    required DateTime fromDate,
    required DateTime toDate,
    required double grandTotal,
    required int itemsCount,
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
      pageFormat: PdfPageFormat.a4,
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
          _buildOptimizedTable(reportData),
          pw.SizedBox(height: 10),
          pw.Divider(height: 10, thickness: 1.5),
          _buildSummary(grandTotal, itemsCount),
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
                  height: 60,
                  width: 60,
                  child: pw.ClipOval(
                    child: pw.Container(
                      color: PdfColors.white,
                      child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                    ),
                  ),
                )
                    : pw.SizedBox(height: 60),
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
          pw.SizedBox(height: 5),
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
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 5),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey200, width: 1.5)),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            thanksMessage,
            style: pw.TextStyle(font: customFont, fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('$contactInfo | $companyAddress', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey)),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('المستخدم: $userName', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text('${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildOptimizedTable(List<Map<String, dynamic>> data) {
    final headers = [
      'المستخدم',
      'المبلغ',
      'الاسم',
      'المرجع',
      'رقم الحركة',
      'اسم الحركة',
      'التاريخ',
      'م'
    ];

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
      children: headers.map((header) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: pw.Text(
          header,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
        ),
      )).toList(),
    );

    final tableRows = <pw.TableRow>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final rowColor = i % 2 == 0 ? PdfColors.blueGrey50 : PdfColors.white;

      final dateString = item['date'] as String?;
      String formattedDate = '-';
      if (dateString != null) {
        try {
          formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(dateString));
        } catch (_) {
          formattedDate = dateString;
        }
      }

      tableRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: rowColor),
        children: [
          _buildCell(item['user_name'] ?? '', align: pw.TextAlign.center),
          _buildCell(_formatCurrency(item['net_total']), align: pw.TextAlign.center, isBold: true, color: PdfColors.green900),
          _buildCell(item['customer_name'] ?? '', align: pw.TextAlign.center),
          _buildCell(item['reference_number'] ?? '', align: pw.TextAlign.center),
          _buildCell(item['transaction_number'] ?? '', align: pw.TextAlign.center, isBold: true),
          _buildCell(item['display_name'] ?? '', align: pw.TextAlign.center),
          _buildCell(formattedDate, align: pw.TextAlign.center),
          _buildCell((i + 1).toString(), align: pw.TextAlign.center, isBold: true),
        ],
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.0),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(1.0),
        5: const pw.FlexColumnWidth(1.2),
        6: const pw.FlexColumnWidth(1.2),
        7: const pw.FlexColumnWidth(0.5),
      },
      children: [
        headerRow,
        ...tableRows,
      ],
    );
  }

  static pw.Widget _buildCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildSummary(double grandTotal, int itemsCount) {
    return pw.Container(
        alignment: pw.Alignment.centerLeft,
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('إجمالي عدد الحركات: $itemsCount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Text('الإجمالي الصافي: ${_formatCurrency(grandTotal)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ]
        )
    );
  }

  static String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    double value = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat("#,###.##", "en_US");
    return formatter.format(value);
  }
}