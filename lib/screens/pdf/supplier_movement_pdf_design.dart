// lib/screens/pdf/supplier_movement_pdf_design.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class SupplierMovementPdfDesign {
  static Future<Uint8List> generate({
    required List<Map<String, dynamic>> reportData,
    required DateTime fromDate,
    required DateTime toDate,
    required double grandOpeningBalance,
    required double grandTotalPurchases,
    required double grandTotalReturns,
    required double grandNetPurchases,
    required double grandTotalPayments,
    required double grandTotalAdjustments,
    required double grandBalance,
    required bool showAccountName,
    required bool showSupplierName,
    required bool showDepartment,
    required bool showBranch,
    required bool showInventoryValue,
    required bool isDetailedMode,
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
            border: pw.Border.all(color: PdfColors.teal800, width: 2),
            borderRadius: pw.BorderRadius.circular(5),
          ),
        ),
      ),
    );

    final reportTitle =
        isDetailedMode ? 'حركة الموردين — وضع تفصيلي' : 'حركة الموردين — ملخص';

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
          showAccountName: showAccountName,
          showSupplierName: showSupplierName,
          showDepartment: showDepartment,
          showBranch: showBranch,
          showInventoryValue: showInventoryValue,
          isDetailedMode: isDetailedMode,
        ),
        pw.SizedBox(height: 10),
        pw.Divider(height: 10, thickness: 1.5),
        _buildSummary(
          grandOpeningBalance: grandOpeningBalance,
          grandTotalPurchases: grandTotalPurchases,
          grandTotalReturns: grandTotalReturns,
          grandNetPurchases: grandNetPurchases,
          grandTotalPayments: grandTotalPayments,
          grandTotalAdjustments: grandTotalAdjustments,
          grandBalance: grandBalance,
        ),
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
        color: PdfColors.teal50,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Expanded(
            flex: 2,
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(companyName,
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900)),
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
                            child:
                                pw.Image(logoImage, fit: pw.BoxFit.cover))))
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
        ]),
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
          border: pw.Border(
              top: pw.BorderSide(color: PdfColors.teal200, width: 1.5))),
      child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text(thanksMessage,
            style: pw.TextStyle(
                font: customFont,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('$contactInfo | $companyAddress',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey)),
        pw.SizedBox(height: 6),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('المستخدم: $userName',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ]),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  static pw.Widget _buildTable(
    List<Map<String, dynamic>> data, {
    required bool showAccountName,
    required bool showSupplierName,
    required bool showDepartment,
    required bool showBranch,
    required bool showInventoryValue,
    required bool isDetailedMode,
  }) {
    // Headers declared RIGHT-TO-LEFT (rightmost Arabic column first, 'م' last)
    final headers = <String>[];
    if (isDetailedMode) {
      headers.add('رقم الفاتورة');
      headers.add('تاريخ الفاتورة');
    }
    headers.add('تاريخ آخر سداد');
    if (showInventoryValue) {
      headers.add('الفارق');
      headers.add('المخزون');
    }
    headers.add('الرصيد');
    headers.add('تسويات');
    headers.add('السداد');
    headers.add('صافي المشتريات');
    headers.add('مردودات');
    headers.add('مشتريات');
    headers.add('افتتاحي');
    if (showBranch)       headers.add('الفرع');
    if (showDepartment)   headers.add('القسم');
    if (showSupplierName) headers.add('اسم المورد');
    if (showAccountName)  headers.add('اسم الحساب');
    headers.add('رقم الحساب');
    headers.add('م');

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.teal700),
      children: headers.map((h) => _cell(h, isHeader: true)).toList(),
    );

    // Detect first-row-per-supplier for Detailed Mode balance display
    String? lastAccNo;

    final dataRows = <pw.TableRow>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final rowBg = i % 2 == 0 ? PdfColors.teal50 : PdfColors.white;
      final currAccNo = item['account_number']?.toString() ?? '';
      final isFirstRowForSupplier = currAccNo != lastAccNo;
      lastAccNo = currAccNo;

      // Cells in the same RTL order as headers (rightmost first, 'م' last)
      final cells = <pw.Widget>[];
      if (isDetailedMode) {
        cells.add(_cell(item['invoice_number']?.toString() ?? '', isBold: true));
        cells.add(_cell(item['invoice_date']?.toString() ?? ''));
      }
      cells.add(_cell(item['last_payment_date']?.toString() ?? ''));
      if (showInventoryValue) {
        cells.add(_cell(_fmt(item['difference'])));
        cells.add(_cell(_fmt(item['inventory_value']), color: PdfColors.purple700));
      }
      cells.add(_cell(isFirstRowForSupplier ? _fmt(item['balance']) : '', isBold: isFirstRowForSupplier, color: PdfColors.teal900));
      cells.add(_cell(_fmt(item['total_adjustments'])));
      cells.add(_cell(_fmt(item['total_payments']), color: PdfColors.blue700));
      cells.add(_cell(_fmt(item['net_purchases']), isBold: true));
      cells.add(_cell(_fmt(item['total_returns']), color: PdfColors.orange700));
      cells.add(_cell(_fmt(item['total_purchases']), color: PdfColors.teal700));
      cells.add(_cell(isFirstRowForSupplier ? _fmt(item['opening_balance']) : '', color: PdfColors.blueGrey700));
      if (showBranch)       cells.add(_cell(item['branch_id']?.toString() ?? ''));
      if (showDepartment)   cells.add(_cell(item['department_id']?.toString() ?? ''));
      if (showSupplierName) cells.add(_cell(item['supplier_name']?.toString() ?? '', isBold: true));
      if (showAccountName)  cells.add(_cell(item['account_name']?.toString() ?? ''));
      cells.add(_cell(currAccNo, isBold: true));
      cells.add(_cell((i + 1).toString(), isBold: true));

      dataRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: rowBg),
        children: cells,
      ));
    }

    final n = headers.length;
    final colWidths = <int, pw.TableColumnWidth>{};
    for (int i = 0; i < n; i++) {
      colWidths[i] = (i == n - 1)
          ? const pw.FixedColumnWidth(18)   // 'م' column
          : const pw.FlexColumnWidth(1);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.teal200, width: 0.5),
      columnWidths: colWidths,
      children: [headerRow, ...dataRows],
    );
  }


  // ---------------------------------------------------------------------------
  static pw.Widget _buildSummary({
    required double grandOpeningBalance,
    required double grandTotalPurchases,
    required double grandTotalReturns,
    required double grandNetPurchases,
    required double grandTotalPayments,
    required double grandTotalAdjustments,
    required double grandBalance,
  }) {
    return pw.Wrap(spacing: 16, runSpacing: 4, children: [
      _summaryItem('إجمالي الافتتاحي', grandOpeningBalance),
      _summaryItem('إجمالي المشتريات', grandTotalPurchases),
      _summaryItem('إجمالي المردودات', grandTotalReturns),
      _summaryItem('صافي المشتريات', grandNetPurchases),
      _summaryItem('إجمالي السداد', grandTotalPayments),
      _summaryItem('إجمالي التسويات', grandTotalAdjustments),
      _summaryItem('الرصيد النهائي الكلي', grandBalance, isBold: true),
    ]);
  }

  static pw.Widget _summaryItem(String label, double value,
      {bool isBold = false}) {
    return pw.Text('$label: ${_fmt(value)}',
        style: pw.TextStyle(
            fontSize: isBold ? 11 : 9,
            fontWeight:
                isBold ? pw.FontWeight.bold : pw.FontWeight.normal));
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
          fontSize: isHeader ? 7 : 6,
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
