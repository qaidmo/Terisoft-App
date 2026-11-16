import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import 'package:untitled4/screens/pdf_design/pdf_receipt_data.dart';
import 'package:path_provider/path_provider.dart';
import 'package:untitled4/utils/whatsapp_helper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ReceiptPdfViewerScreen extends StatefulWidget {
  final String transactionNumber;
  final DateTime date;
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final String accountName;
  final String? cashBox;
  final String currency;
  final String? costCenter;
  final String? description;
  final String amountInWords;
  final String invoiceTypeChar;

  final String? userName;
  final String? receiptId;
  final String? paymentId;

  final String? collectorName;
  final String? recipientName;

  final String userBranchName;
  final String userDepartmentName;

  final String companyName;
  final String companyAddress;
  final String contactInfo;
  final String thanksMessage;
  final String logoUrl;
  final bool showLogo;
  final double? customerBalance;
  final String? customerPhone;

  const ReceiptPdfViewerScreen({
    super.key,
    required this.transactionNumber,
    required this.date,
    required this.items,
    required this.totalAmount,
    required this.accountName,
    this.cashBox,
    required this.currency,
    this.costCenter,
    this.description,
    required this.amountInWords,
    required this.invoiceTypeChar,
    this.userName,
    this.receiptId,
    this.paymentId,
    this.collectorName,
    this.recipientName,
    required this.userBranchName,
    required this.userDepartmentName,
    required this.companyName,
    required this.companyAddress,
    required this.contactInfo,
    required this.thanksMessage,
    required this.logoUrl,
    required this.showLogo,
    this.customerBalance,
    this.customerPhone,
  });

  @override
  State<ReceiptPdfViewerScreen> createState() => _ReceiptPdfViewerScreenState();
}

class _ReceiptPdfViewerScreenState extends State<ReceiptPdfViewerScreen> {
  PdfPageType _selectedType = PdfPageType.a4;

  String _getReceiptTitle() {
    switch (widget.invoiceTypeChar) {
      case 'ق':
        return 'سند قبض نقداً';
      case 'ص':
        return 'سند صرف نقداً';
      default:
        return 'سند';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getReceiptTitle(), style: const TextStyle(color: Colors.white, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 3,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Get.back(result: true);
          },
        ),
        actions: [
          ToggleButtons(
            isSelected: [_selectedType == PdfPageType.a4, _selectedType == PdfPageType.roll],
            onPressed: (index) {
              setState(() {
                _selectedType = index == 0 ? PdfPageType.a4 : PdfPageType.roll;
              });
            },
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.blue.shade800,
            color: Colors.white,
            fillColor: Colors.white,
            splashColor: Colors.blue.shade100,
            constraints: const BoxConstraints(minHeight: 30.0, minWidth: 60.0),
            children: const [
              Text('A4'),
              Text('روول'),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: PdfPreview(
        key: ValueKey(_selectedType),
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: "${_getReceiptTitle()} - ${widget.transactionNumber}.pdf",
        canDebug: false,
        loadingWidget: const Center(child: CircularProgressIndicator()),
        useActions: true,
        actions: [
          if (widget.customerPhone != null && widget.customerPhone!.isNotEmpty)
            PdfPreviewAction(
              icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
              onPressed: (context, build, pageFormat) async {
                final pdfBytes = await build(pageFormat);
                final tempDir = await getTemporaryDirectory();
                final file = File('${tempDir.path}/voucher_${widget.transactionNumber}.pdf');
                await file.writeAsBytes(pdfBytes);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري فتح واتساب...')),
                  );
                }

                await WhatsAppHelper.sendPdf(
                  pdfFile: file,
                  phoneNumber: widget.customerPhone!,
                  showMessage: (msg) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    }
                  },
                );
              },
            ),
        ],
        padding: const EdgeInsets.symmetric(vertical: 16),
        build: (format) => PdfInvoiceData.generate(
          pageType: _selectedType,
          transactionNumber: widget.transactionNumber,
          date: widget.date,
          items: widget.items,
          totalAmount: widget.totalAmount,
          accountName: widget.accountName,
          cashBox: widget.cashBox,
          currency: widget.currency,
          costCenter: widget.costCenter,
          description: widget.description,
          amountInWords: widget.amountInWords,
          invoiceTypeChar: widget.invoiceTypeChar,
          userName: widget.userName,
          receiptId: widget.receiptId,
          paymentId: widget.paymentId,
          collectorName: widget.collectorName,
          recipientName: widget.recipientName,
          companyName: widget.companyName,
          companyAddress: widget.companyAddress,
          contactInfo: widget.contactInfo,
          thanksMessage: widget.thanksMessage,
          logoUrl: widget.logoUrl,
          showLogo: widget.showLogo,
          userBranchName: widget.userBranchName,
          userDepartmentName: widget.userDepartmentName,
          customerBalance: widget.customerBalance,
        ),
      ),
    );
  }
}