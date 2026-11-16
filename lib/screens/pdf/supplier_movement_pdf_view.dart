// lib/screens/pdf/supplier_movement_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf/supplier_movement_pdf_design.dart';

class SupplierMovementPdfView extends StatelessWidget {
  final List<Map<String, dynamic>> reportData;
  final DateTime fromDate;
  final DateTime toDate;

  // Grand totals
  final double grandOpeningBalance;
  final double grandTotalPurchases;
  final double grandTotalReturns;
  final double grandNetPurchases;
  final double grandTotalPayments;
  final double grandTotalAdjustments;
  final double grandBalance;

  // Column visibility flags
  final bool showAccountName;
  final bool showSupplierName;
  final bool showDepartment;
  final bool showBranch;
  final bool showInventoryValue;
  final bool isDetailedMode;

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

  const SupplierMovementPdfView({
    super.key,
    required this.reportData,
    required this.fromDate,
    required this.toDate,
    required this.grandOpeningBalance,
    required this.grandTotalPurchases,
    required this.grandTotalReturns,
    required this.grandNetPurchases,
    required this.grandTotalPayments,
    required this.grandTotalAdjustments,
    required this.grandBalance,
    required this.showAccountName,
    required this.showSupplierName,
    required this.showDepartment,
    required this.showBranch,
    required this.showInventoryValue,
    required this.isDetailedMode,
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
        title: const Text('معاينة: حركة الموردين'),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName:
            'Supplier_Movement_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        build: (format) => SupplierMovementPdfDesign.generate(
          reportData: reportData,
          fromDate: fromDate,
          toDate: toDate,
          grandOpeningBalance: grandOpeningBalance,
          grandTotalPurchases: grandTotalPurchases,
          grandTotalReturns: grandTotalReturns,
          grandNetPurchases: grandNetPurchases,
          grandTotalPayments: grandTotalPayments,
          grandTotalAdjustments: grandTotalAdjustments,
          grandBalance: grandBalance,
          showAccountName: showAccountName,
          showSupplierName: showSupplierName,
          showDepartment: showDepartment,
          showBranch: showBranch,
          showInventoryValue: showInventoryValue,
          isDetailedMode: isDetailedMode,
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
