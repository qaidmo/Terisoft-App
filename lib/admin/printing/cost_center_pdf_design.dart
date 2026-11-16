// lib/screens/pdf_cost_center/cost_center_pdf_design.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:untitled4/models/cost_center_transaction.dart';
import 'package:untitled4/utils/number_to_words_converter.dart';

// --- ✅ تعديل: تم تغيير اسم الكلاس للتوافق ---
class CostCenterPdfDesign {
  // --- ✅ تعديل: الدالة الآن تستقبل كل بيانات القالب ---
  static Future<Uint8List> generate({
    required String centerName,
    required String centerNo,
    required DateTime fromDate,
    required DateTime toDate,
    required List<CostCenterTransaction> transactions,
    required double totalDebit,
    required double totalCredit,
    required double finalBalance,
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
    final fontTheme = pw.ThemeData.withFont(base: customFont, bold: customFont);

    pw.MemoryImage? logoImage;
    if (showLogo && logoUrl.isNotEmpty) {
      try {
        if (logoUrl.startsWith('http')) {
          final request = await HttpClient().getUrl(Uri.parse(logoUrl));
          final response = await request.close();
          final bytes = await consolidateHttpClientResponseBytes(response);
          logoImage = pw.MemoryImage(bytes);
        } else if (logoUrl.startsWith('/data/user/')) {
          final file = File(logoUrl);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            logoImage = pw.MemoryImage(bytes);
          }
        }
      } catch (e) {
        print('Error loading logo for report: $e');
      }
    }

    // --- ✅ إضافة: تصميم الإطار العام للصفحة ---
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4.landscape, // استخدام عرضي
      textDirection: pw.TextDirection.rtl,
      theme: fontTheme,
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
        // --- ✅ تعديل: استخدام الهيدر والفوتر الموحد ---
        header: (context) => _buildHeader(
          companyName: companyName,
          logoImage: logoImage,
          fromDate: fromDate,
          toDate: toDate,
          userBranchName: userBranchName,
          userDepartmentName: userDepartmentName,
        ),
        footer: (context) => _buildFooter(
          context: context,
          userName: userName,
          thanksMessage: thanksMessage,
          contactInfo: contactInfo,
          companyAddress: companyAddress,
          customFont: customFont,
        ),
        build: (context) => [
          _buildTitle(),
          pw.SizedBox(height: 10),
          _buildCenterInfo(
            centerName: centerName,
            centerNo: centerNo,
            fromDate: fromDate,
            toDate: toDate,
          ),
          pw.SizedBox(height: 15),
          _buildReportTable(transactions),
          pw.SizedBox(height: 20),
          _buildSummary(
            totalDebit: totalDebit,
            totalCredit: totalCredit,
            finalBalance: finalBalance,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // --- ✅ تعديل: استخدام الهيدر الموحد والاحترافي ---
  static pw.Widget _buildHeader({
    required String companyName,
    required DateTime fromDate,
    required DateTime toDate,
    required pw.ImageProvider? logoImage,
    required String userBranchName,
    required String userDepartmentName,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
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
              height: 80,
              width: 80,
              child: pw.ClipOval(
                child: pw.Container(
                  color: PdfColors.white,
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
                pw.Text('للفترة من: ${DateFormat('yyyy-MM-dd').format(fromDate)}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 2),
                pw.Text('إلى: ${DateFormat('yyyy-MM-dd').format(toDate)}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ✅ تعديل: استخدام الفوتر الموحد والاحترافي ---
  static pw.Widget _buildFooter({
    required pw.Context context,
    required String thanksMessage,
    required String contactInfo,
    required String companyAddress,
    required String userName,
    required pw.Font customFont,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey200, width: 1.5)),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            thanksMessage,
            style: pw.TextStyle(font: customFont, fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
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

  // --- 🛑 الدوال التالية خاصة بمحتوى التقرير ---

  static pw.Widget _buildTitle() {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(
        'تقرير حركات مركز تكلفة',
        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
      ),
    );
  }

  static pw.Widget _buildCenterInfo({
    required String centerName,
    required String centerNo,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _infoRow('مركز التكلفة:', '$centerName ($centerNo)'),
          _infoRow('من تاريخ:', DateFormat('yyyy-MM-dd').format(fromDate)),
          _infoRow('إلى تاريخ:', DateFormat('yyyy-MM-dd').format(toDate)),
        ],
      ),
    );
  }

  // --- ✅ تعديل: تمت إعادة بناء الجدول بالكامل لإضافة التلوين المتبادل ---
  static pw.Widget _buildReportTable(List<CostCenterTransaction> transactions) {
    final headers = ['اسم الحساب', 'رقم الحساب', 'البيان', 'رقم الحركة', 'نوع الحركة', 'التاريخ', 'الرصيد', 'دائن', 'مدين'];

    final headerRow = pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
      children: headers.map((header) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          header,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
        ),
      )).toList(),
    );

    final tableRows = <pw.TableRow>[];
    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final rowColor = i % 2 == 0 ? PdfColors.blueGrey50 : PdfColors.white;

      final rowChildren = [
        pw.Text(tx.accountName, textAlign: pw.TextAlign.center),
        pw.Text(tx.accountNumber, textAlign: pw.TextAlign.center),
        pw.Text(tx.description, textAlign: pw.TextAlign.right),
        pw.Text(tx.transactionRef, textAlign: pw.TextAlign.center),
        pw.Text(tx.transactionType, textAlign: pw.TextAlign.center),
        pw.Text(tx.transactionDate, textAlign: pw.TextAlign.center),
        pw.Text(_formatCurrency(tx.balance), textAlign: pw.TextAlign.left),
        pw.Text(_formatCurrency(tx.credit), textAlign: pw.TextAlign.left),
        pw.Text(_formatCurrency(tx.debit), textAlign: pw.TextAlign.left),
      ];

      tableRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: rowColor),
        children: rowChildren.map((widget) => pw.Container(
          padding: const pw.EdgeInsets.all(3),
          child: pw.DefaultTextStyle(
            style: const pw.TextStyle(fontSize: 8.5),
            child: widget,
          ),
        )).toList(),
      ));
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3.0), 1: const pw.FlexColumnWidth(2.0),
        2: const pw.FlexColumnWidth(4.0), 3: const pw.FlexColumnWidth(2.0),
        4: const pw.FlexColumnWidth(3.0), 5: const pw.FlexColumnWidth(2.0),
        6: const pw.FlexColumnWidth(2.0), 7: const pw.FlexColumnWidth(1.5),
        8: const pw.FlexColumnWidth(1.5),
      },
      children: [
        headerRow,
        ...tableRows,
      ],
    );
  }

  static pw.Widget _buildSummary({
    required double totalDebit,
    required double totalCredit,
    required double finalBalance,
  }) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryColumn('إجمالي مدين الفترة:', totalDebit),
                _summaryColumn('إجمالي دائن الفترة:', totalCredit),
                _summaryColumn('الرصيد النهائي:', finalBalance, isFinal: true),
              ],
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
              'فقط: ${convertNumberToWordsArabic(finalBalance.abs())}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)
          )
        ]
    );
  }

  static pw.Widget _infoRow(String title, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(width: 8),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  static pw.Widget _summaryColumn(String title, double value, {bool isFinal = false}) {
    final style = pw.TextStyle(
      fontSize: 12,
      fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: isFinal ? PdfColors.blueGrey800 : PdfColors.black,
    );
    return pw.Column(
        children: [
          pw.Text(title, style: style),
          pw.SizedBox(height: 5),
          pw.Text(_formatCurrency(value), style: style),
        ]
    );
  }
  static String _formatCurrency(dynamic value) {
    final numValue = value is num ? value : 0;
    if (numValue.truncate() == numValue) {
      return NumberFormat('#,##0', 'en_US').format(numValue);
    } else {
      return NumberFormat('#,##0.00', 'en_US').format(numValue);
    }
  }
}