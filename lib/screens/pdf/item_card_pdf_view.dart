// lib/screens/pdf/item_card_pdf_view.dart

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/screens/pdf/item_card_pdf_design.dart';
import 'package:untitled4/models/item_card_models.dart';

class ItemCardPdfView extends StatelessWidget {
  final List<ItemCardRow> reportData;
  final DateTime fromDate;
  final DateTime toDate;
  final double totalQuantityIn;
  final double totalQuantityOut;
  final double finalBalance;
  final int rowCount;
  final String selectedUnitName;

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

  const ItemCardPdfView({
    super.key,
    required this.reportData,
    required this.fromDate,
    required this.toDate,
    required this.totalQuantityIn,
    required this.totalQuantityOut,
    required this.finalBalance,
    required this.rowCount,
    required this.selectedUnitName,
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
        title: const Text('معاينة: بطاقة صنف'),
      ),
      body: PdfPreview(
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName:
            'Item_Card_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
        build: (format) => ItemCardPdfDesign.generate(
          reportData:       reportData,
          fromDate:         fromDate,
          toDate:           toDate,
          totalQuantityIn:  totalQuantityIn,
          totalQuantityOut: totalQuantityOut,
          finalBalance:     finalBalance,
          rowCount:         rowCount,
          selectedUnitName: selectedUnitName,
          companyName:      companyName,
          companyAddress:   companyAddress,
          contactInfo:      contactInfo,
          thanksMessage:    thanksMessage,
          logoUrl:          logoUrl,
          showLogo:         showLogo,
          userName:         userName,
          userBranchName:   userBranchName,
          userDepartmentName: userDepartmentName,
        ),
      ),
    );
  }
}
