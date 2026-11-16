import 'package:intl/intl.dart';

class ItemMovementRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final String transactionType;
  final int? userId;
  final int? departmentId;
  final String? itemGroupId;

  ItemMovementRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    this.transactionType = 'all',
    this.userId,
    this.departmentId,
    this.itemGroupId,
  });

  Map<String, dynamic> toJson() => {
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'year': year,
        'branchId': branchId,
        'transactionType': transactionType,
        'userId': userId,
        'departmentId': departmentId,
        'itemGroupId': itemGroupId,
      };
}

// ---------------------------------------------------------------------------
// صف واحد من بيانات التقرير (34 عمود)
// ---------------------------------------------------------------------------
class ItemMovementRow {
  // بيانات الصنف
  final String itemNo;
  final String itemName;
  final String itemUnit;
  final String packFactor;

  // الكميات
  final double quantity;
  final double freeQuantity;
  final String quantityStr;
  final String freeQuantityStr;

  // الأسعار
  final double unitPrice;
  final double totalAmount;
  final double netUnitPrice;
  final double freeValue;
  final String unitPriceStr;
  final String totalAmountStr;
  final String netUnitPriceStr;
  final String freeValueStr;

  // بيانات الحركة
  final String date;
  final String formattedDate;
  final String description;
  final String transactionNumber;
  final String referenceNumber;
  final String customerName;
  final String expiryDate;
  final String batchNumber;

  // القيم المالية
  final double netAmount;
  final String currency;
  final double costPrice;
  final double totalCost;
  final double margin;
  final double exchangeRate;
  final double localNetAmount;
  final String netAmountStr;
  final String costPriceStr;
  final String totalCostStr;
  final String marginStr;
  final String exchangeRateStr;
  final String localNetAmountStr;

  // بيانات الحساب
  final String accountNumber;
  final String accountName;
  final String costCenterName;

  // المندوب والمحصل
  final String salespersonName;
  final String collectorName;

  // الفرع والقسم
  final String branchId;
  final String departmentId;

  // المخزن والمستخدم
  final String storeNo;
  final String storeName;
  final String userName;

  // نوع الحركة
  final String transactionTypeId;
  final String transactionTypeName;

  ItemMovementRow({
    required this.itemNo,
    required this.itemName,
    required this.itemUnit,
    required this.packFactor,
    required this.quantity,
    required this.freeQuantity,
    this.quantityStr = '',
    this.freeQuantityStr = '',
    required this.unitPrice,
    required this.totalAmount,
    required this.netUnitPrice,
    required this.freeValue,
    this.unitPriceStr = '',
    this.totalAmountStr = '',
    this.netUnitPriceStr = '',
    this.freeValueStr = '',
    required this.date,
    this.formattedDate = '',
    required this.description,
    required this.transactionNumber,
    required this.referenceNumber,
    required this.customerName,
    required this.expiryDate,
    required this.batchNumber,
    required this.netAmount,
    required this.currency,
    required this.costPrice,
    required this.totalCost,
    required this.margin,
    required this.exchangeRate,
    required this.localNetAmount,
    this.netAmountStr = '',
    this.costPriceStr = '',
    this.totalCostStr = '',
    this.marginStr = '',
    this.exchangeRateStr = '',
    this.localNetAmountStr = '',
    required this.accountNumber,
    required this.accountName,
    required this.costCenterName,
    required this.salespersonName,
    required this.collectorName,
    required this.branchId,
    required this.departmentId,
    required this.storeNo,
    required this.storeName,
    required this.userName,
    required this.transactionTypeId,
    required this.transactionTypeName,
  });

  static final NumberFormat _nf = NumberFormat('#,###.##', 'en_US');
  static final DateFormat _df = DateFormat('yyyy-MM-dd');

  factory ItemMovementRow.fromJson(Map<String, dynamic> json) {
    final nf = _nf;
    final double qty       = (json['quantity'] as num?)?.toDouble() ?? 0.0;
    final double freeQty   = (json['freeQuantity'] as num?)?.toDouble() ?? 0.0;
    final double uPrice    = (json['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final double totAmt    = (json['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final double netUPrice = (json['netUnitPrice'] as num?)?.toDouble() ?? 0.0;
    final double freeVal   = (json['freeValue'] as num?)?.toDouble() ?? 0.0;
    final double netAmt    = (json['netAmount'] as num?)?.toDouble() ?? 0.0;
    final double cPrice    = (json['costPrice'] as num?)?.toDouble() ?? 0.0;
    final double totCost   = (json['totalCost'] as num?)?.toDouble() ?? 0.0;
    final double mrg       = (json['margin'] as num?)?.toDouble() ?? 0.0;
    final double exRate    = (json['exchangeRate'] as num?)?.toDouble() ?? 1.0;
    final double locNetAmt = (json['localNetAmount'] as num?)?.toDouble() ?? 0.0;

    final String rawDate = json['date']?.toString() ?? '';
    String fDate = rawDate;
    if (rawDate.isNotEmpty) {
      try {
        if (rawDate.contains('/')) {
          final parts = rawDate.split('/');
          if (parts.length == 3) {
            fDate = '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          }
        } else {
          final p = DateTime.tryParse(rawDate);
          if (p != null) fDate = _df.format(p);
        }
      } catch (_) {}
    }

    return ItemMovementRow(
      itemNo:              json['itemNo']?.toString() ?? '',
      itemName:            json['itemName']?.toString() ?? '',
      itemUnit:            json['itemUnit']?.toString() ?? '',
      packFactor:          json['packFactor']?.toString() ?? '',
      quantity:            qty,
      freeQuantity:        freeQty,
      quantityStr:         nf.format(qty),
      freeQuantityStr:     nf.format(freeQty),
      unitPrice:           uPrice,
      totalAmount:         totAmt,
      netUnitPrice:        netUPrice,
      freeValue:           freeVal,
      unitPriceStr:        nf.format(uPrice),
      totalAmountStr:      nf.format(totAmt),
      netUnitPriceStr:     nf.format(netUPrice),
      freeValueStr:        nf.format(freeVal),
      date:                rawDate,
      formattedDate:       fDate,
      description:         json['description']?.toString() ?? '',
      transactionNumber:   json['transactionNumber']?.toString() ?? '',
      referenceNumber:     json['referenceNumber']?.toString() ?? '',
      customerName:        json['customerName']?.toString() ?? '',
      expiryDate:          json['expiryDate']?.toString() ?? '',
      batchNumber:         json['batchNumber']?.toString() ?? '',
      netAmount:           netAmt,
      currency:            json['currency']?.toString() ?? '',
      costPrice:           cPrice,
      totalCost:           totCost,
      margin:              mrg,
      exchangeRate:        exRate,
      localNetAmount:      locNetAmt,
      netAmountStr:        nf.format(netAmt),
      costPriceStr:        nf.format(cPrice),
      totalCostStr:        nf.format(totCost),
      marginStr:           nf.format(mrg),
      exchangeRateStr:     nf.format(exRate),
      localNetAmountStr:   nf.format(locNetAmt),
      accountNumber:       json['accountNumber']?.toString() ?? '',
      accountName:         json['accountName']?.toString() ?? '',
      costCenterName:      json['costCenterName']?.toString() ?? '',
      salespersonName:     json['salespersonName']?.toString() ?? '',
      collectorName:       json['collectorName']?.toString() ?? '',
      branchId:            json['branchId']?.toString() ?? '',
      departmentId:        json['departmentId']?.toString() ?? '',
      storeNo:             json['storeNo']?.toString() ?? '',
      storeName:           json['storeName']?.toString() ?? '',
      userName:            json['userName']?.toString() ?? '',
      transactionTypeId:   json['transactionTypeId']?.toString() ?? '',
      transactionTypeName: json['transactionTypeName']?.toString() ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// موديل الاستجابة الكاملة
// ---------------------------------------------------------------------------
class ItemMovementResponse {
  final int rowCount;
  final double grandTotalAmount;
  final double grandNetAmount;
  final double grandTotalCost;
  final double grandMargin;
  final String grandTotalAmountStr;
  final String grandNetAmountStr;
  final String grandTotalCostStr;
  final String grandMarginStr;
  final List<ItemMovementRow> rows;

  ItemMovementResponse({
    required this.rowCount,
    required this.grandTotalAmount,
    required this.grandNetAmount,
    required this.grandTotalCost,
    required this.grandMargin,
    this.grandTotalAmountStr = '0',
    this.grandNetAmountStr = '0',
    this.grandTotalCostStr = '0',
    this.grandMarginStr = '0',
    required this.rows,
  });

  factory ItemMovementResponse.fromJson(Map<String, dynamic> json) {
    final nf = ItemMovementRow._nf;
    final varList = json['rows'] as List? ?? [];
    final double gTotAmt = (json['grandTotalAmount'] as num?)?.toDouble() ?? 0.0;
    final double gNetAmt = (json['grandNetAmount'] as num?)?.toDouble() ?? 0.0;
    final double gTotCost = (json['grandTotalCost'] as num?)?.toDouble() ?? 0.0;
    final double gMrg = (json['grandMargin'] as num?)?.toDouble() ?? 0.0;

    return ItemMovementResponse(
      rowCount:          (json['rowCount'] as num?)?.toInt() ?? 0,
      grandTotalAmount:  gTotAmt,
      grandNetAmount:    gNetAmt,
      grandTotalCost:    gTotCost,
      grandMargin:       gMrg,
      grandTotalAmountStr: nf.format(gTotAmt),
      grandNetAmountStr:   nf.format(gNetAmt),
      grandTotalCostStr:   nf.format(gTotCost),
      grandMarginStr:      nf.format(gMrg),
      rows:              varList.map((e) => ItemMovementRow.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
