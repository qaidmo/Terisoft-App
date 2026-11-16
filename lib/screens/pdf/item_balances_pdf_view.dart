// lib/screens/pdf/item_balances_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf/item_balances_pdf_design.dart';
import 'package:untitled4/models/item_balances_models.dart';

class ItemBalancesPdfView extends StatelessWidget {
  final List<ItemBalancesRow> reportData;
  final DateTime fromDate;
  final DateTime toDate;
  final double grandBalance;
  final double grandBalanceCost;
  final int rowCount;

  // Column visibility
  final bool showBranch;
  final bool showDepartment;
  final bool showStore;
  final bool showExpiry;
  final bool showBatch;

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

  const ItemBalancesPdfView({
    super.key,
    required this.reportData,
    required this.fromDate,
    required this.toDate,
    required this.grandBalance,
    required this.grandBalanceCost,
    required this.rowCount,
    required this.showBranch,
    required this.showDepartment,
    required this.showStore,
    required this.showExpiry,
    required this.showBatch,
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
        title: const Text('معاينة: أرصدة الأصناف'),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName:
            'Item_Balances_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        build: (format) => ItemBalancesPdfDesign.generate(
          reportData: reportData,
          fromDate: fromDate,
          toDate: toDate,
          grandBalance: grandBalance,
          grandBalanceCost: grandBalanceCost,
          rowCount: rowCount,
          showBranch: showBranch,
          showDepartment: showDepartment,
          showStore: showStore,
          showExpiry: showExpiry,
          showBatch: showBatch,
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
