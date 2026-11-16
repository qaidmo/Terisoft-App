import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StatementPdfDesign {
  static Future<Uint8List> generate({
    required String accountName,
    required String accountNumber,
    required String currencyName,
    required DateTime fromDate,
    required DateTime toDate,
    required List<Map<String, dynamic>> statementRows,
    required double openingBalance,
    required double totalDebit,
    required double totalCredit,
    required double closingBalance,
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
        } else {
          final file = File(logoUrl);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            logoImage = pw.MemoryImage(bytes);
          }
        }
      } catch (e) {
        debugPrint('Error loading logo: $e');
      }
    }

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
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
        build: (context) {
          return [
            _buildTitle(),
            pw.SizedBox(height: 10),
            _buildAccountInfo(
              accountName: accountName,
              accountNumber: accountNumber,
              currencyName: currencyName,
              fromDate: fromDate,
              toDate: toDate,
            ),
            pw.SizedBox(height: 15),
            _buildStatementTable(statementRows),
            pw.SizedBox(height: 20),
            _buildSummary(
              openingBalance: openingBalance,
              totalDebit: totalDebit,
              totalCredit: totalCredit,
              closingBalance: closingBalance,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

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
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
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

  static pw.Widget _summaryRow(String title, double value, {bool isClosing = false}) {
    final style = pw.TextStyle(
      fontSize: 12,
      fontWeight: isClosing ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: isClosing ? PdfColors.blueGrey800 : PdfColors.black,
    );
    return pw.Row(
      children: [
        pw.Text(title, style: style),
        pw.SizedBox(width: 20),
        pw.Text(_formatCurrency(value), style: style),
      ],
    );
  }

  static pw.Widget _buildTitle() {
    return pw.Container(
      alignment: pw.Alignment.center,
      child: pw.Text(
        'كشف حساب',
        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
      ),
    );
  }

  static pw.Widget _buildAccountInfo({
    required String accountName,
    required String accountNumber,
    required String currencyName,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _infoRow('اسم الحساب:', '$accountName ($accountNumber)'),
          pw.Divider(color: PdfColors.grey300),
          pw.Row(
            children: [
              pw.Expanded(child: _infoRow('العملة:', currencyName)),
              pw.Expanded(child: _infoRow('من تاريخ:', DateFormat('yyyy-MM-dd').format(fromDate))),
              pw.Expanded(child: _infoRow('إلى تاريخ:', DateFormat('yyyy-MM-dd').format(toDate))),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildStatementTable(List<Map<String, dynamic>> rows) {
    // تم عكس الترتيب لضمان ظهوره من اليمين لليسار بشكل صحيح
    final headers = ['البيان', 'المستفيد', 'النوع', 'رقم المستند', 'التاريخ', 'الرصيد', 'دائن', 'مدين', 'م'];

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey500),
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.center,
      cellAlignments: {
        0: pw.Alignment.centerRight, // البيان
        1: pw.Alignment.centerRight, // المستفيد
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(2),    // البيان (يسار)
        1: const pw.FixedColumnWidth(65),  // المستفيد
        2: const pw.FixedColumnWidth(55),  // النوع
        3: const pw.FixedColumnWidth(50),  // رقم المستند
        4: const pw.FixedColumnWidth(60),  // التاريخ
        5: const pw.FixedColumnWidth(60),  // الرصيد
        6: const pw.FixedColumnWidth(50),  // دائن
        7: const pw.FixedColumnWidth(50),  // مدين
        8: const pw.FixedColumnWidth(25),  // م (يمين)
      },
      headers: headers,
      data: List<List<dynamic>>.generate(rows.length, (index) {
        final row = rows[index];
        final balance = (row['balance'] as num?)?.toDouble() ?? 0.0;
        final credit = (row['credit'] as num?)?.toDouble() ?? 0.0;
        final debit = (row['debit'] as num?)?.toDouble() ?? 0.0;

        return [
          row['description']?.toString() ?? '',
          row['beneficiary']?.toString() ?? '',
          row['type']?.toString() ?? '',
          row['traNo']?.toString() ?? '',
          row['date']?.toString() ?? '',
          _formatCurrency(balance),
          _formatCurrency(credit),
          _formatCurrency(debit),
          (index + 1).toString(),
        ];
      }),
    );
  }

  static pw.Widget _buildSummary({
    required double openingBalance,
    required double totalDebit,
    required double totalCredit,
    required double closingBalance,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _summaryRow('الرصيد الافتتاحي:', openingBalance),
                pw.SizedBox(height: 5),
                _summaryRow('إجمالي مدين:', totalDebit),
              ],
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _summaryRow('إجمالي دائن:', totalCredit),
                pw.SizedBox(height: 5),
                _summaryRow('الرصيد الختامي:', closingBalance, isClosing: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String title, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  static String _formatCurrency(dynamic value) {
    final numValue = value is num ? value : 0;
    return NumberFormat('#,##0.00', 'en_US').format(numValue);
  }
}