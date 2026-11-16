// lib/screens/pdf_cost_center/cost_center_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/models/cost_center_transaction.dart';
import 'package:untitled4/admin/printing/cost_center_pdf_design.dart';

class CostCenterReportPdfView extends StatelessWidget {
  // Center Info
  final String centerName;
  final String centerNo;
  final DateTime fromDate;
  final DateTime toDate;
  // Report Data
  final List<CostCenterTransaction> transactions;
  // Summary Data
  final double totalDebit;
  final double totalCredit;
  final double finalBalance;

  // --- ✅ إضافة: كل بيانات القالب والمستخدم ---
  final String companyName;
  final String companyAddress;
  final String contactInfo;
  final String thanksMessage;
  final String logoUrl;
  final bool showLogo;
  final String userName;
  final String userBranchName;
  final String userDepartmentName;

  const CostCenterReportPdfView({
    super.key,
    required this.centerName,
    required this.centerNo,
    required this.fromDate,
    required this.toDate,
    required this.transactions,
    required this.totalDebit,
    required this.totalCredit,
    required this.finalBalance,
    // --- ✅ إضافة: استقبال كل البيانات الجديدة ---
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
        title: const Text('معاينة تقرير مركز التكلفة'),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'CostCenter_${centerNo}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        // ملاحظة: تم تصحيح اسم الكلاس ليتطابق مع ملف import
        build: (format) => CostCenterPdfDesign.generate(
          // --- ✅ تمرير كل البيانات إلى مصمم الـ PDF ---
          centerName: centerName,
          centerNo: centerNo,
          fromDate: fromDate,
          toDate: toDate,
          transactions: transactions,
          totalDebit: totalDebit,
          totalCredit: totalCredit,
          finalBalance: finalBalance,
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