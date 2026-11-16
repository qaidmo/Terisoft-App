// lib/screens/pdf/item_card_pdf_design.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:untitled4/models/item_card_models.dart';

class ItemCardPdfDesign {
  static Future<Uint8List> generate({
    required List<ItemCardRow> reportData,
    required DateTime fromDate,
    required DateTime toDate,
    required double totalQuantityIn,
    required double totalQuantityOut,
    required double finalBalance,
    required int rowCount,
    required String selectedUnitName,
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

    pdf.addPage(pw.MultiPage(
      pageTheme: pageTheme,
      header: (context) => _buildHeader(
        companyName:        companyName,
        fromDate:           fromDate,
        toDate:             toDate,
        selectedUnitName:   selectedUnitName,
        logoImage:          logoImage,
        userBranchName:     userBranchName,
        userDepartmentName: userDepartmentName,
      ),
      footer: (context) => _buildFooter(
        context:        context,
        thanksMessage:  thanksMessage,
        contactInfo:    contactInfo,
        companyAddress: companyAddress,
        userName:       userName,
        customFont:     customFont,
      ),
      build: (context) => [
        _buildTable(reportData),
        pw.SizedBox(height: 10),
        pw.Divider(height: 10, thickness: 1.5),
        _buildSummary(
          totalQuantityIn:  totalQuantityIn,
          totalQuantityOut: totalQuantityOut,
          finalBalance:     finalBalance,
          rowCount:         rowCount,
        ),
      ],
    ));

    return pdf.save();
  }

  // ---------------------------------------------------------------------------
  static pw.Widget _buildHeader({
    required String companyName,
    required DateTime fromDate,
    required DateTime toDate,
    required String selectedUnitName,
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
                            child: pw.Image(logoImage, fit: pw.BoxFit.cover))))
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
            child: pw.Text('تقرير بطاقة الصنف',
                style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline))),
        if (selectedUnitName.isNotEmpty)
          pw.Center(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 3),
              child: pw.Text('الوحدة المحوّلة: $selectedUnitName',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal700)),
            ),
          ),
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
  static pw.Widget _buildTable(List<ItemCardRow> data) {
    // Headers declared RIGHT-TO-LEFT (rightmost Arabic column first, 'م' last)
    final headers = [
      'مركز التكلفة', 'اسم الحساب', 'الفرع', 'رقم الصنف', 'المخزن',
      'مرجع', 'رقم_التاريخ', 'السعر', 'المبلغ', 'التكاليف',
      'علبة/كرتون', 'تاريخ انتهاء', 'الاسم', 'رقم الحركة', 'البيان',
      'التاريخ', 'الوحدة', 'التكلفة', 'رقم القطعة', 'الرصيد',
      'منصرف', 'وارد', 'م'
    ];

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.teal700),
      children: headers.map((h) => _cell(h, isHeader: true)).toList(),
    );

    final dataRows = <pw.TableRow>[];
    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      final rowBg = i % 2 == 0 ? PdfColors.teal50 : PdfColors.white;

      String dateStr = row.date;
      try {
        if (dateStr.contains('/')) {
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            dateStr =
                '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          }
        } else if (dateStr.isNotEmpty) {
          dateStr = DateFormat('yyyy-MM-dd').format(DateTime.parse(dateStr));
        }
      } catch (_) {}

      final balanceColor =
          row.balance >= 0 ? PdfColors.teal800 : PdfColors.red700;
      final inColor   = row.quantityIn  > 0 ? PdfColors.green700 : PdfColors.black;
      final outColor  = row.quantityOut > 0 ? PdfColors.red700   : PdfColors.black;

      // Cells in same RTL order as headers (rightmost first, 'م' last)
      dataRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: rowBg),
        children: [
          _cell(row.costCenterName),
          _cell(row.accountName),
          _cell(row.branchName),
          _cell(row.itemNo, isBold: true),
          _cell(row.storeName),
          _cell(row.referenceNumber),
          _cell(row.dateNo),
          _cell(_fmt(row.unitPrice)),
          _cell(_fmt(row.totalAmount), isBold: true),
          _cell(_fmt(row.totalCost)),
          _cell(row.packFactor),
          _cell(row.expiryDate),
          _cell(row.customerName),
          _cell(row.transactionNumber, isBold: true),
          _cell(row.description),
          _cell(dateStr),
          _cell(row.itemUnit),
          _cell(_fmt(row.costPrice)),
          _cell(row.batchNumber),
          _cell(_fmt(row.balance),     isBold: true, color: balanceColor),
          _cell(_fmt(row.quantityOut), color: outColor),
          _cell(_fmt(row.quantityIn),  color: inColor),
          _cell((i + 1).toString(), isBold: true),
        ],
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.teal200, width: 0.5),
      columnWidths: {
        0:  const pw.FlexColumnWidth(1.2),  // مركز التكلفة
        1:  const pw.FlexColumnWidth(1.5),  // اسم الحساب
        2:  const pw.FlexColumnWidth(1.0),  // الفرع
        3:  const pw.FlexColumnWidth(1.2),  // رقم الصنف
        4:  const pw.FlexColumnWidth(1.2),  // المخزن
        5:  const pw.FlexColumnWidth(1.0),  // مرجع
        6:  const pw.FlexColumnWidth(1.0),  // رقم_التاريخ
        7:  const pw.FlexColumnWidth(0.8),  // السعر
        8:  const pw.FlexColumnWidth(1.0),  // المبلغ
        9:  const pw.FlexColumnWidth(1.0),  // التكاليف
        10: const pw.FlexColumnWidth(0.8),  // علبة/كرتون
        11: const pw.FlexColumnWidth(1.0),  // تاريخ انتهاء
        12: const pw.FlexColumnWidth(1.5),  // الاسم
        13: const pw.FlexColumnWidth(1.2),  // رقم الحركة
        14: const pw.FlexColumnWidth(1.5),  // البيان
        15: const pw.FlexColumnWidth(1.0),  // التاريخ
        16: const pw.FlexColumnWidth(0.8),  // الوحدة
        17: const pw.FlexColumnWidth(0.8),  // التكلفة
        18: const pw.FlexColumnWidth(1.0),  // رقم القطعة
        19: const pw.FlexColumnWidth(1.0),  // الرصيد
        20: const pw.FlexColumnWidth(0.8),  // منصرف
        21: const pw.FlexColumnWidth(0.8),  // وارد
        22: const pw.FlexColumnWidth(0.4),  // م
      },
      children: [headerRow, ...dataRows],
    );
  }

  // ---------------------------------------------------------------------------
  static pw.Widget _buildSummary({
    required double totalQuantityIn,
    required double totalQuantityOut,
    required double finalBalance,
    required int rowCount,
  }) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
        pw.Text('عدد الأسطر: $rowCount',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Wrap(spacing: 20, children: [
          pw.Text('إجمالي وارد: ${_fmt(totalQuantityIn)}',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.green700)),
          pw.Text('إجمالي صادر: ${_fmt(totalQuantityOut)}',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.red700)),
          pw.Text('الرصيد النهائي: ${_fmt(finalBalance)}',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.teal800)),
        ]),
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
          fontSize: isHeader ? 6 : 5,
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
