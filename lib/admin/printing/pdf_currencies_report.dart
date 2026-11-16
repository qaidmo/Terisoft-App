import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:untitled4/models/sun_currency.dart';

class PdfCurrenciesReport {
  static Future<Uint8List> generate({
    required List<SunCurrency> currencies,
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
      build: (context) => [_buildContent(currencies)],
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

  static pw.Widget _buildContent(List<SunCurrency> currencies) {
    final headers = ['أدنى سعر', 'أعلى سعر', 'سعر الصرف', 'الرمز', 'اسم العملة', 'الرقم'];
    final data = currencies.map((currency) {
      return [
        currency.currencyLowest.toStringAsFixed(2),
        currency.currencyHighest.toStringAsFixed(2),
        currency.currencyRate.toStringAsFixed(2),
        currency.currencySymbol,
        currency.currencyName,
        currency.currencyNo.toString(),
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
      },
    );
  }
}