// lib/screens/pdf/sales_movement_new_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf/sales_movement_new_pdf_design.dart';

class SalesMovementNewPdfView extends StatelessWidget {
  final List<Map<String, dynamic>> reportData;
  final DateTime fromDate;
  final DateTime toDate;
  final double grandNetValue;
  final double grandFinalValue;
  final int itemsCount;
  final String reportTitle;

  // Column visibility flags
  final bool showDate;
  final bool showInvoiceNumber;
  final bool showTransType;
  final bool showBeneficiary;
  final bool showAccountName;
  final bool showUserName;
  final bool showBranch;
  final bool showDepartment;
  final bool showTaxDiscount;

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

  const SalesMovementNewPdfView({
    super.key,
    required this.reportData,
    required this.fromDate,
    required this.toDate,
    required this.grandNetValue,
    required this.grandFinalValue,
    required this.itemsCount,
    required this.reportTitle,
    required this.showDate,
    required this.showInvoiceNumber,
    required this.showTransType,
    required this.showBeneficiary,
    required this.showAccountName,
    required this.showUserName,
    required this.showBranch,
    required this.showDepartment,
    required this.showTaxDiscount,
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
        title: Text('معاينة: $reportTitle'),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName:
            'Sales_Movement_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        build: (format) => SalesMovementNewPdfDesign.generate(
          reportData: reportData,
          fromDate: fromDate,
          toDate: toDate,
          grandNetValue: grandNetValue,
          grandFinalValue: grandFinalValue,
          itemsCount: itemsCount,
          reportTitle: reportTitle,
          showDate: showDate,
          showInvoiceNumber: showInvoiceNumber,
          showTransType: showTransType,
          showBeneficiary: showBeneficiary,
          showAccountName: showAccountName,
          showUserName: showUserName,
          showBranch: showBranch,
          showDepartment: showDepartment,
          showTaxDiscount: showTaxDiscount,
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
