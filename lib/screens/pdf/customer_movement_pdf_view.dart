// lib/screens/pdf/customer_movement_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf/customer_movement_pdf_design.dart';

class CustomerMovementPdfView extends StatelessWidget {
  final List<Map<String, dynamic>> reportData;
  final DateTime fromDate;
  final DateTime toDate;
  final String reportTitle;
  final String companyName;
  final String companyAddress;
  final String contactInfo;
  final String thanksMessage;
  final String logoUrl;
  final bool showLogo;
  final String userName;
  // --- ✅ إضافة: متغيرات الفرع والقسم ---
  final String userBranchName;
  final String userDepartmentName;

  const CustomerMovementPdfView({
    super.key,
    required this.reportData,
    required this.fromDate,
    required this.toDate,
    required this.reportTitle,
    required this.companyName,
    required this.companyAddress,
    required this.contactInfo,
    required this.thanksMessage,
    required this.logoUrl,
    required this.showLogo,
    required this.userName,
    // --- ✅ إضافة: استقبال المتغيرات في الكونستركتور ---
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
        pdfFileName: 'Customer_Movement_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        build: (format) => CustomerMovementPdfDesign.generate(
          reportData: reportData,
          fromDate: fromDate,
          toDate: toDate,
          reportTitle: reportTitle,
          companyName: companyName,
          companyAddress: companyAddress,
          contactInfo: contactInfo,
          thanksMessage: thanksMessage,
          logoUrl: logoUrl,
          showLogo: showLogo,
          userName: userName,
          // --- ✅ إضافة: تمرير البيانات إلى مصمم الـ PDF ---
          userBranchName: userBranchName,
          userDepartmentName: userDepartmentName,
        ),
      ),
    );
  }
}