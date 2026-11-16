// lib/screens/pdf/account_balances_pdf_design.dart
// مصمم PDF لتقرير أرصدة الحسابات — مستقل تماماً
//
// ملاحظة RTL: pw.Table يرسم الخلايا من اليسار إلى اليمين بغض النظر عن textDirection.
// لذلك تُعكس قوائم الأعمدة (الأيسر بصرياً أولاً، م في الأخير = أقصى يمين الصفحة).

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AccountBalancesPdfDesign {
  static Future<Uint8List> generate({
    // --- بيانات التقرير القياسي ---
    required List<Map<String, dynamic>> reportData,
    required DateTime fromDate,
    required DateTime toDate,
    required String reportTitle,
    required String groupingMode,
    required Map<String, double> grandTotals,
    // --- هامش الأرباح (اختياري) ---
    bool showProfitMargin = false,
    List<Map<String, dynamic>> profitMarginData = const [],
    Map<String, double> pmGrandTotals = const {},
    // --- معلومات الشركة والمستخدم ---
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
        // ignore logo load errors
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
        build: (context) => showProfitMargin
            ? [
                _buildProfitMarginDataTable(profitMarginData),
                pw.SizedBox(height: 10),
                _buildProfitMarginTotalsRow(pmGrandTotals),
              ]
            : [
                _buildDataTable(reportData, groupingMode),
                pw.SizedBox(height: 10),
                _buildTotalsRow(grandTotals),
              ],
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // Header
  // =========================================================================
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
                    pw.Text(companyName,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey900)),
                    pw.SizedBox(height: 4),
                    pw.Text('$userDepartmentName / $userBranchName',
                        style: const pw.TextStyle(fontSize: 9)),
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
                    pw.Text('للفترة من: ${format.format(fromDate)}',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text('إلى: ${format.format(toDate)}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              reportTitle,
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Footer
  // =========================================================================
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
        border: pw.Border(
            top: pw.BorderSide(color: PdfColors.blueGrey200, width: 1.5)),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(thanksMessage,
              style: pw.TextStyle(
                  font: customFont,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('$contactInfo | $companyAddress',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.blueGrey)),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('تمت الطباعة بواسطة: $userName',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey)),
              pw.Text(
                  'صفحة ${context.pageNumber} من ${context.pagesCount}',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey)),
              pw.Text(
                  'تاريخ الطباعة: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // جدول الأرصدة القياسي (13 عموداً) — مُصحَّح RTL
  //
  // pw.Table يرسم من اليسار إلى اليمين على الصفحة دائماً.
  // لذلك نضع الأعمدة بترتيب عكسي: الأيسر بصرياً أولاً، "م" في الأخير
  // (= أقصى يمين الصفحة العربية).
  // =========================================================================
  static pw.Widget _buildDataTable(
      List<Map<String, dynamic>> data, String mode) {
    final nf = NumberFormat("#,##0.00", "en_US");

    // --- تحديد تسميتي عمودَي الكيان بناءً على الوضع ---
    // كل الأوضاع: 2 عمود كيان ثابت (كما في الشاشة)
    String entityCol1Label; // الأيمن (رقم الحساب / رقم المركز …)
    String entityCol2Label; // الأيسر منه  (اسم الحساب / اسم المستفيد …)

    switch (mode) {
      case 'byCostCenter':
        entityCol1Label = 'رقم المركز';
        entityCol2Label = 'اسم المركز';
        break;
      case 'byBeneficiary':
        entityCol1Label = '';
        entityCol2Label = 'اسم المستفيد';
        break;
      case 'byCostCenterAndAccount':
        entityCol1Label = 'رقم الحساب';
        entityCol2Label = 'مركز التكلفة - الحساب';
        break;
      case 'byTransactionName':
        entityCol1Label = 'كود الحركة';
        entityCol2Label = 'اسم الحركة';
        break;
      default:
        // byMovementAccount / analyticalAll
        entityCol1Label = 'رقم الحساب';
        entityCol2Label = 'اسم الحساب';
    }

    // --- رؤوس الأعمدة بترتيب RTL (الأيسر على الصفحة أولاً، م أخيراً) ---
    final headers = <String>[
      'القيمة',       // col 13
      'الرصيد',       // col 12
      'الرصيد دائن',  // col 11
      'الرصيد مدين',  // col 10
      'إجمالي دائن',  // col 9
      'إجمالي مدين',  // col 8
      'الفترة دائن',  // col 7
      'الفترة مدين',  // col 6
      'افتتاحي دائن', // col 5
      'افتتاحي مدين', // col 4
      entityCol2Label, // col 3
      entityCol1Label, // col 2
      'م',            // col 1 — أقصى يمين
    ];

    // --- بناء صفوف البيانات ---
    final tableRows = <pw.TableRow>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final rowColor = i % 2 == 0 ? PdfColors.blueGrey50 : PdfColors.white;
      final netBalance = (item['netBalance'] as num?)?.toDouble() ?? 0.0;

      // حل قيم عمودَي الكيان حسب الوضع (نفس منطق الشاشة)
      String col1, col2;
      switch (mode) {
        case 'byBeneficiary':
          col1 = '';
          final ben  = item['beneficiaryName']?.toString() ?? '';
          final acc  = item['accountName']?.toString() ?? '';
          col2 = (ben.isNotEmpty && acc.isNotEmpty) ? '$ben - $acc'
               : ben.isNotEmpty ? ben : acc;
          break;
        case 'byCostCenterAndAccount':
          col1 = item['entityId']?.toString() ?? '';
          final cc   = item['costCenterName']?.toString() ?? '';
          final en   = item['entityName']?.toString() ?? '';
          col2 = (cc.isNotEmpty && en.isNotEmpty) ? '$cc - $en'
               : cc.isNotEmpty ? cc : en;
          break;
        default:
          col1 = item['entityId']?.toString() ?? '';
          col2 = item['entityName']?.toString() ?? '';
      }

      // خلايا بترتيب RTL (مرايا الرؤوس)
      final cells = <pw.Widget>[
        _numCell(nf.format((item['value'] as num?) ?? 0)),
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(
            nf.format(netBalance),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: netBalance >= 0 ? PdfColors.green800 : PdfColors.red800,
            ),
          ),
        ),
        _numCell(nf.format((item['balanceCredit'] as num?) ?? 0)),
        _numCell(nf.format((item['balanceDebit'] as num?) ?? 0)),
        _numCell(nf.format((item['totalCredit'] as num?) ?? 0)),
        _numCell(nf.format((item['totalDebit'] as num?) ?? 0)),
        _numCell(nf.format((item['periodCredit'] as num?) ?? 0)),
        _numCell(nf.format((item['periodDebit'] as num?) ?? 0)),
        _numCell(nf.format((item['openingCredit'] as num?) ?? 0)),
        _numCell(nf.format((item['openingDebit'] as num?) ?? 0)),
        _cell(col2),
        _cell(col1),
        _cell('${i + 1}', bold: true),  // م — أقصى يمين
      ];

      tableRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: rowColor),
        children: cells,
      ));
    }

    // عرض الأعمدة: الأعمدة المالية أضيق، عمود الاسم أوسع
    final n = headers.length; // 13
    final colWidths = <int, pw.TableColumnWidth>{};
    for (int i = 0; i < n; i++) {
      if (i == n - 1) {
        // م — ضيق جداً (أقصى يمين)
        colWidths[i] = const pw.FixedColumnWidth(18);
      } else if (i == n - 2) {
        // entityCol1 — رقم الحساب
        colWidths[i] = const pw.FixedColumnWidth(38);
      } else if (i == n - 3) {
        // entityCol2 — اسم الحساب (أوسع)
        colWidths[i] = const pw.FlexColumnWidth(2.2);
      } else {
        // الأعمدة المالية العشرة
        colWidths[i] = const pw.FlexColumnWidth(1);
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      columnWidths: colWidths,
      children: [
        // صف الرؤوس
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      h,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 7,
                          color: PdfColors.white),
                    ),
                  ))
              .toList(),
        ),
        ...tableRows,
      ],
    );
  }

  // =========================================================================
  // جدول هامش أرباح مراكز التكلفة (9 أعمدة) — مُصحَّح RTL
  // =========================================================================
  static pw.Widget _buildProfitMarginDataTable(
      List<Map<String, dynamic>> data) {
    final nf = NumberFormat("#,##0.00", "en_US");

    // رؤوس بترتيب RTL (الأيسر بصرياً أولاً، م أخيراً)
    const headers = <String>[
      'نسبة الربح %',     // col 9
      'صافي الربح',       // col 8
      'صافي المبيعات',    // col 7
      'المردودات',        // col 6
      'المبيعات',         // col 5
      'صافي المنصرف',     // col 4
      'اسم القسم',        // col 3
      'رقم المركز',       // col 2
      'م',               // col 1 — أقصى يمين
    ];

    final tableRows = <pw.TableRow>[];
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final rowColor = i % 2 == 0 ? PdfColors.blueGrey50 : PdfColors.white;
      final netProfit = (item['netProfit'] as num?)?.toDouble() ?? 0.0;
      final profitPct = (item['profitPct'] as num?)?.toDouble() ?? 0.0;

      final cells = <pw.Widget>[
        // نسبة الربح %
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(
            '${nf.format(profitPct)}%',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: profitPct >= 0 ? PdfColors.green800 : PdfColors.red800,
            ),
          ),
        ),
        // صافي الربح
        pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(
            nf.format(netProfit),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: netProfit >= 0 ? PdfColors.green800 : PdfColors.red800,
            ),
          ),
        ),
        _numCell(nf.format((item['netSales'] as num?) ?? 0)),
        _numCell(nf.format((item['returns'] as num?) ?? 0)),
        _numCell(nf.format((item['grossSales'] as num?) ?? 0)),
        _numCell(nf.format((item['netCogs'] as num?) ?? 0)),
        _cell(item['costCenterName']?.toString() ?? ''),
        _cell(item['costCenterId']?.toString() ?? '', bold: true),
        _cell('${i + 1}', bold: true), // م — أقصى يمين
      ];

      tableRows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: rowColor),
        children: cells,
      ));
    }

    // عرض الأعمدة
    const colWidths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(42),   // نسبة الربح %
      1: pw.FlexColumnWidth(1.1),   // صافي الربح
      2: pw.FlexColumnWidth(1.1),   // صافي المبيعات
      3: pw.FlexColumnWidth(1),     // المردودات
      4: pw.FlexColumnWidth(1.1),   // المبيعات
      5: pw.FlexColumnWidth(1.1),   // صافي المنصرف
      6: pw.FlexColumnWidth(2),     // اسم القسم (أوسع)
      7: pw.FixedColumnWidth(38),   // رقم المركز
      8: pw.FixedColumnWidth(18),   // م
    };

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      columnWidths: colWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey600),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      h,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 7,
                          color: PdfColors.white),
                    ),
                  ))
              .toList(),
        ),
        ...tableRows,
      ],
    );
  }

  // =========================================================================
  // خلايا مساعدة
  // =========================================================================
  static pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
              fontSize: 7,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _numCell(String text, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 7,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color)),
    );
  }

  // =========================================================================
  // صف مجاميع التقرير القياسي
  // =========================================================================
  static pw.Widget _buildTotalsRow(Map<String, double> totals) {
    final nf = NumberFormat("#,##0.00", "en_US");
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey100,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _totalItem('افتتاحي مدين', nf.format(totals['grandOpeningDebit'] ?? 0)),
          _totalItem('افتتاحي دائن', nf.format(totals['grandOpeningCredit'] ?? 0)),
          _totalItem('الفترة مدين',  nf.format(totals['grandPeriodDebit'] ?? 0)),
          _totalItem('الفترة دائن',  nf.format(totals['grandPeriodCredit'] ?? 0)),
          _totalItem('الرصيد مدين',  nf.format(totals['grandBalanceDebit'] ?? 0)),
          _totalItem('الرصيد دائن',  nf.format(totals['grandBalanceCredit'] ?? 0)),
          _totalItem('صافي الرصيد',  nf.format(totals['grandNetBalance'] ?? 0),
              color: (totals['grandNetBalance'] ?? 0) >= 0
                  ? PdfColors.green800
                  : PdfColors.red800),
        ],
      ),
    );
  }

  // =========================================================================
  // صف مجاميع تقرير هامش الأرباح
  // =========================================================================
  static pw.Widget _buildProfitMarginTotalsRow(Map<String, double> totals) {
    final nf = NumberFormat("#,##0.00", "en_US");
    final netProfit = totals['pmGrandNetProfit'] ?? 0.0;
    final netCogs   = totals['pmGrandNetCogs']   ?? 0.0;
    final pct = netCogs == 0 ? 0.0 : (netProfit / netCogs * 100);

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey100,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _totalItem('صافي المنصرف',   nf.format(netCogs)),
          _totalItem('المبيعات',        nf.format(totals['pmGrandGrossSales'] ?? 0)),
          _totalItem('المردودات',       nf.format(totals['pmGrandReturns'] ?? 0)),
          _totalItem('صافي المبيعات',  nf.format(totals['pmGrandNetSales'] ?? 0)),
          _totalItem('صافي الربح',     nf.format(netProfit),
              color: netProfit >= 0 ? PdfColors.green800 : PdfColors.red800),
          _totalItem('نسبة الربح %',   '${nf.format(pct)}%',
              color: pct >= 0 ? PdfColors.green800 : PdfColors.red800),
        ],
      ),
    );
  }

  static pw.Widget _totalItem(String label, String value, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 7, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: color ?? PdfColors.black)),
      ],
    );
  }
}
