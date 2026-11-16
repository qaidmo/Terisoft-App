// lib/screens/pdf/item_movement_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf/item_movement_pdf_design.dart';
import 'package:untitled4/models/item_movement_models.dart';

class ItemMovementPdfView extends StatelessWidget {
  final List<ItemMovementRow> reportData;
  final DateTime fromDate;
  final DateTime toDate;
  final double grandTotalAmount;
  final double grandNetAmount;
  final double grandTotalCost;
  final double grandMargin;
  final int rowCount;

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

  const ItemMovementPdfView({
    super.key,
    required this.reportData,
    required this.fromDate,
    required this.toDate,
    required this.grandTotalAmount,
    required this.grandNetAmount,
    required this.grandTotalCost,
    required this.grandMargin,
    required this.rowCount,
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
        title: const Text('معاينة: حركة الأصناف'),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName:
            'Item_Movement_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        build: (format) => ItemMovementPdfDesign.generate(
          reportData: reportData,
          fromDate: fromDate,
          toDate: toDate,
          grandTotalAmount: grandTotalAmount,
          grandNetAmount: grandNetAmount,
          grandTotalCost: grandTotalCost,
          grandMargin: grandMargin,
          rowCount: rowCount,
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
