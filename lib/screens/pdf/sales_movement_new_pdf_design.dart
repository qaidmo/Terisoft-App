// lib/screens/pdf/sales_movement_new_pdf_design.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SalesMovementNewPdfDesign {
  static Future<Uint8List> generate({
    required List<Map<String, dynamic>> reportData,
    required DateTime fromDate,
    required DateTime toDate,
    required double grandNetValue,
    required double grandFinalValue,
    required int itemsCount,
    required String reportTitle,
    required bool showDate,
    required bool showInvoiceNumber,
    required bool showTransType,
    required bool showBeneficiary,
    required bool showAccountName,
    required bool showUserName,
    required bool showBranch,
    required bool showDepartment,
    required bool showTaxDiscount,
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
    final fontData = await rootBundle.load('assets/fonts/Hacen_Tunisia.ttf');
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
            logoImage = pw.MemoryImage(await file.readAsBytes());
          }
        }
      } catch (_) {}
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

    pdf.addPage(pw.MultiPage(
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
        _buildTable(
          reportData,
          showDate: showDate,
          showInvoiceNumber: showInvoiceNumber,
          showTransType: showTransType,
          showBeneficiary: showBeneficiary,
          showAccountName: showAccountName,
          showUserName: showUserName,
          showBranch: showBranch,
          showDepartment: showDepartment,
          showTaxDiscount: showTaxDiscount,
        ),
        pw.SizedBox(height: 10),
        pw.Divider(height: 10, thickness: 1.5),
        _buildSummary(
            grandNetValue: grandNetValue,
            grandFinalValue: grandFinalValue,
            itemsCount: itemsCount),
      ],
    ));

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  static pw.Widget _buildHeader({
    required String companyName,
    required String reportTitle,
    required DateTime fromDate,
    required DateTime toDate,
    required pw.ImageProvider? logoImage,
    required String userBranchName,
    required String userDepartmentName,
  }) {
    final fmt = DateFormat('yyyy-MM-dd');
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey900)),
                    pw.SizedBox(height: 4),
                    pw.Text('$userDepartmentName / $userBranchName',
                        style: const pw.TextStyle(fontSize: 9)),
                  ]),
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
                              child: pw.Image(logoImage,
                                  fit: pw.BoxFit.cover))))
                  : pw.SizedBox(height: 60),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('من: ${fmt.format(fromDate)}',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text('إلى: ${fmt.format(toDate)}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ]),
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Center(
            child: pw.Text(reportTitle,
                style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline))),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
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
          border:
              pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey200, width: 1.5))),
      child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text(thanksMessage,
            style: pw.TextStyle(
                font: customFont,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('$contactInfo | $companyAddress',
            style:
                const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey)),
        pw.SizedBox(height: 6),
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('المستخدم: $userName',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ]),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  static pw.Widget _buildTable(
    List<Map<String, dynamic>> data, {
    required bool showDate,
    required bool showInvoiceNumber,
    required bool showTransType,
    required bool showBeneficiary,
    required bool showAccountName,
    required bool showUserName,
    required bool showBranch,
    required bool showDepartment,
    required bool showTaxDiscount,
  }) {
    // Headers declared RIGHT-TO-LEFT (rightmost Arabic column first, 'م' last)
    final headers = <String>[];
    headers.add('الإجمالي النهائي');
    headers.add('الصافي');
    if (showTaxDiscount) {
      headers.add('الضريبة');
      headers.add('الخصم');
      headers.add('الإجمالي');
    }
    if (showDepartment)    headers.add('القسم');
    if (showBranch)        headers.add('الفرع');
    if (showUserName)      headers.add('المستخدم');
    if (showAccountName)   headers.add('اسم الحساب');
    if (showBeneficiary)   headers.add('المستفيد');
    if (showTransType)     headers.add('نوع الحركة');
    if (showInvoiceNumber) headers.add('رقم الفاتورة');
    if (showDate)          headers.add('التاريخ');
    headers.add('م');

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      children: headers.map((h) => _cell(h, isHeader: true)).toList(),
    );

    final dataRows = <pw.TableRow>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final rowBg = i % 2 == 0 ? PdfColors.blueGrey50 : PdfColors.white;

      String dateStr = item['date']?.toString() ?? '';
      try {
        if (dateStr.isNotEmpty) {
          dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(dateStr));
        }
      } catch (_) {}

      // Cells in the same RTL order as headers (rightmost first, 'م' last)
      final cells = <pw.Widget>[];
      cells.add(_cell(_fmt(item['final_value']), isBold: true));
      cells.add(_cell(_fmt(item['net_value']), isBold: true, color: PdfColors.green800));
      if (showTaxDiscount) {
        cells.add(_cell(_fmt(item['tax_amount'])));
        cells.add(_cell(_fmt(item['discount_amount']), color: PdfColors.orange800));
        cells.add(_cell(_fmt(item['gross_total']), color: PdfColors.teal800));
      }
      if (showDepartment)    cells.add(_cell(item['department_name']?.toString() ?? ''));
      if (showBranch)        cells.add(_cell(item['branch_name']?.toString() ?? ''));
      if (showUserName)      cells.add(_cell(item['user_name']?.toString() ?? ''));
      if (showAccountName)   cells.add(_cell(item['account_name']?.toString() ?? ''));
      if (showBeneficiary)   cells.add(_cell(item['beneficiary_name']?.toString() ?? ''));
      if (showTransType)     cells.add(_cell(item['transaction_type_name']?.toString() ?? ''));
      if (showInvoiceNumber) cells.add(_cell(item['transaction_number']?.toString() ?? '', isBold: true));
      if (showDate)          cells.add(_cell(dateStr));
      cells.add(_cell((i + 1).toString(), isBold: true));

      dataRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: rowBg),
        children: cells,
      ));
    }

    // Column widths: index 0 = rightmost content, last index = 'م' fixed width
    final n = headers.length;
    final colWidths = <int, pw.TableColumnWidth>{};
    for (int i = 0; i < n; i++) {
      colWidths[i] = (i == n - 1)
          ? const pw.FixedColumnWidth(20)   // 'م' column
          : const pw.FlexColumnWidth(1);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey200, width: 0.5),
      columnWidths: colWidths,
      children: [headerRow, ...dataRows],
    );
  }

  // ---------------------------------------------------------------------------
  static pw.Widget _buildSummary({
    required double grandNetValue,
    required double grandFinalValue,
    required int itemsCount,
  }) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('عدد الحركات: $itemsCount',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text('الإجمالي الصافي: ${_fmt(grandNetValue)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.SizedBox(height: 2),
        pw.Text('الإجمالي النهائي: ${_fmt(grandFinalValue)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  static pw.Widget _cell(String text,
      {bool isHeader = false, bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7,
          fontWeight:
              (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : (color ?? PdfColors.black),
        ),
      ),
    );
  }

  static String _fmt(dynamic amount) {
    if (amount == null) return '0';
    final v = double.tryParse(amount.toString()) ?? 0.0;
    return NumberFormat('#,###.##', 'en_US').format(v);
  }
}
