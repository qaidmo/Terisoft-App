// lib/printing/collectors_pdf_view.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class CollectorsPdfView extends StatelessWidget {
  final Uint8List pdfData;
  final String reportTitle;

  const CollectorsPdfView({
    Key? key,
    required this.pdfData,
    required this.reportTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة تقرير المحصلين'),
      ),
      body: PdfPreview(
        build: (format) => pdfData,
        // خصائص لإخفاء الأزرار غير الضرورية في المعاينة
        canChangeOrientation: false,
        canChangePageFormat: false,
        // اسم الملف عند الحفظ أو المشاركة
        pdfFileName: "$reportTitle.pdf",
      ),
    );
  }
}