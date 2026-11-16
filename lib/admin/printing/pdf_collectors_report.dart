// lib/printing/pdf_collectors_report.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfCollectorsReport {
  // [تم التعديل] الدالة الآن تستقبل قائمة من نوع Map
  static Future<Uint8List> generate({
    required List<Map<String, dynamic>> collectors,
    required String reportTitle,
    String? userName,
  }) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Hacen_Tunisia.ttf");
    final customFont = pw.Font.ttf(fontData);
    final theme = pw.ThemeData.withFont(base: customFont, bold: customFont);

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      textDirection: pw.TextDirection.rtl,
      theme: theme,
      buildBackground: (context) {
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(
            margin: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: 2),
            ),
          ),
        );
      },
    );

    pdf.addPage(pw.MultiPage(
      pageTheme: pageTheme,
      header: (context) => _buildHeader(reportTitle),
      footer: (context) => _buildFooter(userName),
      // [تم التعديل] تمرير قائمة المحصلين لدالة المحتوى
      build: (context) => [_buildContent(collectors)],
    ));

    return pdf.save();
  }

  // دالة بناء الهيدر (تبقى كما هي)
  static pw.Widget _buildHeader(String reportTitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          reportTitle,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.5),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // دالة بناء الفوتر (تبقى كما هي)
  static pw.Widget _buildFooter(String? userName) {
    final printDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
          children: [
            pw.Text('المختص: ........................', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('التوقيع: ........................', style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1.5, color: PdfColors.black),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('المستخدم: ${userName ?? 'غير معروف'}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            pw.Text('تاريخ الطباعة: $printDate', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          ],
        ),
      ],
    );
  }

  // --- [تم التعديل بالكامل] ---
  /// دالة بناء المحتوى الخاص بجدول المحصلين
  static pw.Widget _buildContent(List<Map<String, dynamic>> collectors) {
    // تحديد أعمدة جدول المحصلين
    final headers = ['الفرع', 'الحساب المرتبط', 'رقم الهاتف', 'اسم المحصل', 'الرقم'];

    // تحويل قائمة المحصلين إلى صيغة يقبلها الجدول
    final data = collectors.map((collector) {
      return [
        collector['branch']?['branch_name'] ?? '-',
        collector['account']?['name'] ?? '-',
        collector['phone_number'] ?? '-',
        collector['collector_name'] ?? '-',
        collector['collector_no']?.toString() ?? '-',
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      // تحديد محاذاة النص داخل الخلايا
      cellAlignments: {
        0: pw.Alignment.centerRight,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.center,
      },
      headerAlignment: pw.Alignment.center,
      // تحديد عرض الأعمدة
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(0.8),
      },
    );
  }
}