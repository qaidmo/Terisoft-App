// lib/printing/item_groups_pdf_view.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class ItemGroupsPdfView extends StatelessWidget {
  final Uint8List pdfData;
  final String reportTitle;

  const ItemGroupsPdfView({
    Key? key,
    required this.pdfData,
    required this.reportTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة تقرير مجموعات الأصناف'),
      ),
      body: PdfPreview(
        build: (format) => pdfData,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: "$reportTitle.pdf",
      ),
    );
  }
}