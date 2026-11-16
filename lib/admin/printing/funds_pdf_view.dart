import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class FundsPdfView extends StatelessWidget {
  final Uint8List pdfData;
  final String reportTitle;

  const FundsPdfView({
    Key? key,
    required this.pdfData,
    required this.reportTitle
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة التقرير'),
      ),
      body: PdfPreview(
        build: (format) => pdfData,

        // [تعديل] إضافة هذه الخصائص لإخفاء الأزرار السفلية
        canChangeOrientation: false,
        canChangePageFormat: false,

        pdfFileName: "$reportTitle.pdf",


      ),
    );
  }
}