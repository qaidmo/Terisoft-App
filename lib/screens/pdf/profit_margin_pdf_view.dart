// lib/screens/pdf/profit_margin_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf/profit_margin_pdf_design.dart';
import 'package:untitled4/models/profit_margin_models.dart';

class ProfitMarginPdfView extends StatelessWidget {
  final List<ProfitMarginRow> reportData;
  final DateTime fromDate;
  final DateTime toDate;
  final double grandSalesValue;
  final double grandSalesCost;
  final double grandMargin;
  final double grandSalesQty;
  final int rowCount;

  // Column visibility
  final bool showBranch;
  final bool showDepartment;
  final bool showBatch;
  final bool showCostCenter;

  // Template / company info
  final String companyName;
  final String companyAddress;
  final String contactInfo;
  final String thanksMessage;
  final String logoUrl;
  final bool showLogo;

  // User info
  final String userName;
  final String userBranchName;
  final String userDepartmentName;

  const ProfitMarginPdfView({
    super.key,
    required this.reportData,
    required this.fromDate,
    required this.toDate,
    required this.grandSalesValue,
    required this.grandSalesCost,
    required this.grandMargin,
    required this.grandSalesQty,
    required this.rowCount,
    required this.showBranch,
    required this.showDepartment,
    required this.showBatch,
    required this.showCostCenter,
    required this.companyName,
    required this.companyAddress,
    required this.contactInfo,
    required this.thanksMessage,
    required this.logoUrl,
    required this.showLogo,
    required this.userName,
    required this.userBranchName,
    required this.userDepartmentName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة: هامش الربح'),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName:
            'Profit_Margin_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        build: (format) => ProfitMarginPdfDesign.generate(
          reportData: reportData,
          fromDate: fromDate,
          toDate: toDate,
          grandSalesValue: grandSalesValue,
          grandSalesCost: grandSalesCost,
          grandMargin: grandMargin,
          grandSalesQty: grandSalesQty,
          rowCount: rowCount,
          showBranch: showBranch,
          showDepartment: showDepartment,
          showBatch: showBatch,
          showCostCenter: showCostCenter,
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
