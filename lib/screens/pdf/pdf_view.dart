import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:untitled4/screens/pdf/pdf_disegn.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:untitled4/utils/whatsapp_helper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum PdfPageType { a4, roll }

class PdfView extends StatefulWidget {
  final String transactionNumber;
  final DateTime date;
  final List<Map<String, dynamic>> products;
  final double total;
  final double tax;
  final double discount;
  final String customerName;
  final String storeName;
  final String? cashBox;
  final String currency;
  final String? collector;
  final String? salesRep;
  final double netTotal;
  final String invoiceTypeChar;
  final String? userName;
  final String? saleId;
  final double? amountPaid;
  final double? remainingAmount;
  final String? accountNo;
  final String companyName;
  final String companyAddress;
  final String contactInfo;
  final String thanksMessage;
  final String logoUrl;
  final bool showLogo;
  final String userBranchName;
  final String userDepartmentName;
  final String netTotalInWords;
  final double? customerBalance;
  final String? customerPhone;

  const PdfView({
    Key? key,
    required this.transactionNumber,
    required this.date,
    required this.products,
    required this.total,
    required this.tax,
    required this.discount,
    required this.customerName,
    required this.storeName,
    this.cashBox,
    required this.currency,
    this.collector,
    this.salesRep,
    required this.netTotal,
    required this.invoiceTypeChar,
    this.userName,
    this.saleId,
    this.amountPaid,
    this.remainingAmount,
    this.accountNo,
    required this.companyName,
    required this.companyAddress,
    required this.contactInfo,
    required this.thanksMessage,
    required this.logoUrl,
    required this.showLogo,
    required this.userBranchName,
    required this.userDepartmentName,
    required this.netTotalInWords,
    this.customerBalance,
    this.customerPhone,
  }) : super(key: key);

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView> {
  PdfPageType _selectedType = PdfPageType.a4;

  String _getInvoiceTitle() {
    switch (widget.invoiceTypeChar) {
      case 'ن': return 'فاتورة بيع نقداً';
      case 'م': return 'فاتورة بيع نقداً معلق';
      case 'ج': return 'فاتورة بيع آجل';
      case 'رن': return 'فاتورة مردود بيع نقدي';
      case 'رج': return 'فاتورة مردود بيع آجل';
      case 'رم': return 'فاتورة مردود بيع معلق';
      case 'ت': return 'فاتورة بيع نقدا';
      default: return 'فاتورة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getInvoiceTitle(),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
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
            constraints: const BoxConstraints(minHeight: 30.0, minWidth: 50.0),
            children: const [
              Text('A4', style: TextStyle(fontSize: 12)),
              Text('روول', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: PdfPreview(
        key: ValueKey(_selectedType),
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: "${_getInvoiceTitle()} - ${widget.transactionNumber}.pdf",
        canDebug: false,
        loadingWidget: const Center(child: CircularProgressIndicator()),
        actions: [
          if (widget.invoiceTypeChar == 'ج' && widget.customerPhone != null && widget.customerPhone!.isNotEmpty)
            PdfPreviewAction(
              icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
              onPressed: (context, build, pageFormat) async {
                final pdfBytes = await build(pageFormat);
                final tempDir = await getTemporaryDirectory();
                final file = File('${tempDir.path}/invoice_${widget.transactionNumber}.pdf');
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
        build: (format) => PdfInventoryData.generate(
          pageType: _selectedType,
          transactionNumber: widget.transactionNumber,
          date: widget.date,
          products: widget.products,
          total: widget.total,
          cashBox: widget.cashBox,
          collector: widget.collector ?? '',
          salesRep: widget.salesRep ?? '',
          currency: widget.currency,
          customerName: widget.customerName,
          discount: widget.discount,
          netTotal: widget.netTotal,
          storeName: widget.storeName,
          tax: widget.tax,
          userName: widget.userName,
          amountPaid: widget.amountPaid,
          remainingAmount: widget.remainingAmount,
          invoiceTypeChar: widget.invoiceTypeChar,
          accountNo: widget.accountNo,
          companyName: widget.companyName,
          companyAddress: widget.companyAddress,
          contactInfo: widget.contactInfo,
          thanksMessage: widget.thanksMessage,
          logoUrl: widget.logoUrl,
          showLogo: widget.showLogo,
          userBranchName: widget.userBranchName,
          userDepartmentName: widget.userDepartmentName,
          netTotalInWords: widget.netTotalInWords,
          customerBalance: widget.customerBalance,
        ),
      ),
    );
  }
}