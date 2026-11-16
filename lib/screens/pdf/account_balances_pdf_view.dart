// lib/screens/pdf/account_balances_pdf_view.dart
// عارض PDF لتقرير أرصدة الحسابات — مستقل تماماً

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf/account_balances_pdf_design.dart';

class AccountBalancesPdfView extends StatelessWidget {
  // --- التقرير القياسي ---
  final List<Map<String, dynamic>> reportData;
  final DateTime fromDate;
  final DateTime toDate;
  final String reportTitle;
  final String groupingMode;
  final Map<String, double> grandTotals;

  // --- هامش الأرباح (اختياري) ---
  final bool showProfitMargin;
  final List<Map<String, dynamic>> profitMarginData;
  final Map<String, double> pmGrandTotals;

  // --- معلومات الشركة والمستخدم ---
  final String companyName;
  final String companyAddress;
  final String contactInfo;
  final String thanksMessage;
  final String logoUrl;
  final bool showLogo;
  final String userName;
  final String userBranchName;
  final String userDepartmentName;

  const AccountBalancesPdfView({
    super.key,
    required this.reportData,
    required this.fromDate,
    required this.toDate,
    required this.reportTitle,
    required this.groupingMode,
    required this.grandTotals,
    required this.companyName,
    required this.companyAddress,
    required this.contactInfo,
    required this.thanksMessage,
    required this.logoUrl,
    required this.showLogo,
    required this.userName,
    required this.userBranchName,
    required this.userDepartmentName,
    this.showProfitMargin = false,
    this.profitMarginData = const [],
    this.pmGrandTotals = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('معاينة: $reportTitle'),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName:
            'Account_Balances_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        build: (format) => AccountBalancesPdfDesign.generate(
          reportData: reportData,
          fromDate: fromDate,
          toDate: toDate,
          reportTitle: reportTitle,
          groupingMode: groupingMode,
          grandTotals: grandTotals,
          showProfitMargin: showProfitMargin,
          profitMarginData: profitMarginData,
          pmGrandTotals: pmGrandTotals,
          companyName: companyName,
          companyAddress: companyAddress,
          contactInfo: contactInfo,
          thanksMessage: thanksMessage,
          logoUrl: logoUrl,
          showLogo: showLogo,
          userName: userName,
          userBranchName: userBranchName,
          userDepartmentName: userDepartmentName,
        ),
      ),
    );
  }
}
