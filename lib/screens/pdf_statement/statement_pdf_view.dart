// lib/pdf_statement/statement_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf_statement/statement_pdf_design.dart';

class StatementPdfView extends StatelessWidget {
  // Account Info
  final String accountName;
  final String accountNumber;
  final String currencyName;
  final DateTime fromDate;
  final DateTime toDate;
  // Statement Data
  final List<Map<String, dynamic>> statementRows;
  // Summary Data
  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;

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

  const StatementPdfView({
    super.key,
    required this.accountName,
    required this.accountNumber,
    required this.currencyName,
    required this.fromDate,
    required this.toDate,
    required this.statementRows,
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
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
        title: const Text('معاينة كشف الحساب'),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'Account_Statement_${accountNumber}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        // ملاحظة: تم تصحيح اسم الكلاس ليتطابق مع ملف import
        build: (format) => StatementPdfDesign.generate(
          // --- ✅ تمرير كل البيانات إلى مصمم الـ PDF ---
          accountName: accountName,
          accountNumber: accountNumber,
          currencyName: currencyName,
          fromDate: fromDate,
          toDate: toDate,
          statementRows: statementRows,
          openingBalance: openingBalance,
          totalDebit: totalDebit,
          totalCredit: totalCredit,
          closingBalance: closingBalance,
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