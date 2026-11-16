// lib/screens/pdf/sales_movement_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf/sales_movement_pdf_design.dart';

class SalesMovementPdfView extends StatelessWidget {
  final List<Map<String, dynamic>> reportData;
  final DateTime fromDate;
  final DateTime toDate;
  final double grandTotal;
  final int itemsCount;
  final String reportTitle;
  final String companyName;
  final String companyAddress;
  final String contactInfo;
  final String thanksMessage;
  final String logoUrl;
  final bool showLogo;
  final String userName;
  final String userBranchName;
  final String userDepartmentName;

  const SalesMovementPdfView({
    super.key,
    required this.reportData,
    required this.fromDate,
    required this.toDate,
    required this.grandTotal,
    required this.itemsCount,
    required this.reportTitle,
    // --- ✅ إضافة: استقبال المتغيرات الجديدة في الكونستركتور ---
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
        pdfFileName: 'Financial_Movement_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        build: (format) => SalesMovementPdfDesign.generate(
          // --- ✅ إضافة: تمرير كل البيانات الجديدة إلى مصمم الـ PDF ---
          reportData: reportData,
          fromDate: fromDate,
          toDate: toDate,
          grandTotal: grandTotal,
          itemsCount: itemsCount,
          reportTitle: reportTitle,
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