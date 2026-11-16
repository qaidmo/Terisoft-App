import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:untitled4/models/sun_store.dart'; // تأكد من استيراد موديل المخزن

class PdfStoresReport {
  static Future<Uint8List> generate({
    required List<SunStore> stores,
    required String reportTitle,
    String? userName,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Hacen_Tunisia.ttf");
    final customFont = pw.Font.ttf(fontData);
    final theme = pw.ThemeData.withFont(base: customFont, bold: customFont);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: theme,
      header: (context) => _buildHeader(reportTitle),
      footer: (context) => _buildFooter(userName),
      build: (context) => [_buildContent(stores)],
    ));

    return pdf.save();
  }

  static pw.Widget _buildHeader(String reportTitle) {
    return pw.Column(
      children: [
        pw.Text(reportTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _buildFooter(String? userName) {
    final printDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [

        pw.Text('تاريخ الطباعة: $printDate', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
      ],
    );
  }

  static pw.Widget _buildContent(List<SunStore> stores) {
    final headers = ['اسم الحساب', 'رقم الحساب', 'اسم الفرع', 'اسم المخزن', 'الرقم'];

    final data = stores.map((store) {
      return [
        store.linkedAccount?.name ?? 'غير مربوط',
        store.linkedAccount?.accountNumber ?? '-',
        store.linkedBranch?.branchName ?? 'غير مربوط', // لعرض اسم الفرع
        store.nameStore,
        store.noStore.toString(),
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerRight,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(1),
      },
    );
  }
}