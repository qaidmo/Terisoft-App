// lib/models/item_card_models.dart
// تقرير بطاقة الصنف - موديلات مستقلة تماماً

import 'dart:convert';
import 'package:intl/intl.dart';

/// معلومات الوحدة مع معامل التحويل — تُستخدم في dropdown التحويل الديناميكي
class UnitInfo {
  final String name;
  final double packFactor;

  const UnitInfo({required this.name, required this.packFactor});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          packFactor == other.packFactor;

  @override
  int get hashCode => name.hashCode ^ packFactor.hashCode;

  @override
  String toString() => 'UnitInfo(name: $name, packFactor: $packFactor)';
}

class ItemCardRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final String? itemName;
  final String? batchNumber;
  final String transactionType;
  final bool excludeOpeningBalance;
  final bool excludePreviousBalance;
  final int? userId;
  final int? departmentId;

  const ItemCardRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    this.itemName,
    this.batchNumber,
    this.transactionType = 'all',
    this.excludeOpeningBalance = false,
    this.excludePreviousBalance = false,
    this.userId,
    this.departmentId,
  });

  Map<String, dynamic> toJson() => {
    'fromDate':               fromDate.toIso8601String(),
    'toDate':                 toDate.toIso8601String(),
    'year':                   year,
    'branchId':               branchId,
    'itemName':               itemName,
    'batchNumber':            batchNumber,
    'transactionType':        transactionType,
    'excludeOpeningBalance':  excludeOpeningBalance,
    'excludePreviousBalance': excludePreviousBalance,
    'userId':                 userId,
    'departmentId':           departmentId,
  };
}

class ItemCardRow {
  final String itemNo;
  final String branchName;
  final String costCenterName;
  final String accountName;
  final String storeName;
  final String referenceNumber;
  final String dateNo;           // yyyyMMdd — رقم_التاريخ
  final double unitPrice;
  final double totalAmount;
  final double totalCost;
  final String packFactor;
  final String expiryDate;
  final String customerName;     // الاسم = اسم العميل
  final String transactionNumber;
  final String description;
  final String date;
  final String itemUnit;
  final double costPrice;
  final String batchNumber;
  final double quantityOut;      // صادر
  final double quantityIn;       // وارد
  final double balance;          // الرصيد الجاري

  // Pre-formatted strings for rapid virtualized rendering
  final String quantityInStr;
  final String quantityOutStr;
  final String balanceStr;
  final String costPriceStr;
  final String formattedDate;
  final String totalCostStr;
  final String totalAmountStr;
  final String unitPriceStr;

  const ItemCardRow({
    required this.itemNo,
    required this.branchName,
    required this.costCenterName,
    required this.accountName,
    required this.storeName,
    required this.referenceNumber,
    required this.dateNo,
    required this.unitPrice,
    required this.totalAmount,
    required this.totalCost,
    required this.packFactor,
    required this.expiryDate,
    required this.customerName,
    required this.transactionNumber,
    required this.description,
    required this.date,
    required this.itemUnit,
    required this.costPrice,
    required this.batchNumber,
    required this.quantityOut,
    required this.quantityIn,
    required this.balance,
    this.quantityInStr = '',
    this.quantityOutStr = '',
    this.balanceStr = '',
    this.costPriceStr = '',
    this.formattedDate = '',
    this.totalCostStr = '',
    this.totalAmountStr = '',
    this.unitPriceStr = '',
  });

  static final NumberFormat _nf = NumberFormat('#,###.##', 'en_US');
  static final DateFormat _df = DateFormat('yyyy-MM-dd');

  static String _formatNum(double val) {
    if (val == 0.0) return '0';
    return _nf.format(val);
  }

  static String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
      }
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) return _df.format(parsed);
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  /// ينشئ نسخة محوّلة من الصف بناءً على معامل التحويل المستهدف.
  /// الكميات (وارد/صادر/رصيد) تُقسم على targetPackFactor.
  /// الأسعار (التكلفة/السعر) تُضرب في targetPackFactor.
  /// المبالغ الإجمالية لا تتغير (قيم نقدية مطلقة).
  /// يُستبدل اسم الوحدة بالوحدة المستهدفة.
  ItemCardRow copyWithConversion(double targetPackFactor, String targetUnitName) {
    if (targetPackFactor == 1.0) {
      return ItemCardRow(
        itemNo: itemNo, branchName: branchName, costCenterName: costCenterName,
        accountName: accountName, storeName: storeName, referenceNumber: referenceNumber,
        dateNo: dateNo, unitPrice: unitPrice, totalAmount: totalAmount,
        totalCost: totalCost, packFactor: packFactor, expiryDate: expiryDate,
        customerName: customerName, transactionNumber: transactionNumber,
        description: description, date: date,
        itemUnit: targetUnitName,
        costPrice: costPrice, batchNumber: batchNumber,
        quantityOut: quantityOut, quantityIn: quantityIn, balance: balance,
        quantityInStr: quantityInStr,
        quantityOutStr: quantityOutStr,
        balanceStr: balanceStr,
        costPriceStr: costPriceStr,
        formattedDate: formattedDate,
        totalCostStr: totalCostStr,
        totalAmountStr: totalAmountStr,
        unitPriceStr: unitPriceStr,
      );
    }

    final double convUnitPrice = unitPrice * targetPackFactor;
    final double convCostPrice = costPrice * targetPackFactor;
    final double convQtyOut = quantityOut / targetPackFactor;
    final double convQtyIn = quantityIn / targetPackFactor;
    final double convBalance = balance / targetPackFactor;

    return ItemCardRow(
      itemNo: itemNo, branchName: branchName, costCenterName: costCenterName,
      accountName: accountName, storeName: storeName, referenceNumber: referenceNumber,
      dateNo: dateNo,
      unitPrice:   convUnitPrice,
      totalAmount: totalAmount,   // قيمة نقدية مطلقة — لا تتغير
      totalCost:   totalCost,     // قيمة نقدية مطلقة — لا تتغير
      packFactor: packFactor, expiryDate: expiryDate,
      customerName: customerName, transactionNumber: transactionNumber,
      description: description, date: date,
      itemUnit: targetUnitName,
      costPrice:   convCostPrice,
      batchNumber: batchNumber,
      quantityOut: convQtyOut,
      quantityIn:  convQtyIn,
      balance:     convBalance,
      quantityInStr: _formatNum(convQtyIn),
      quantityOutStr: _formatNum(convQtyOut),
      balanceStr: _formatNum(convBalance),
      costPriceStr: _formatNum(convCostPrice),
      formattedDate: formattedDate,
      totalCostStr: totalCostStr,
      totalAmountStr: totalAmountStr,
      unitPriceStr: _formatNum(convUnitPrice),
    );
  }

  factory ItemCardRow.fromJson(Map<String, dynamic> json) {
    final double uPrice = (json['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final double tAmount = (json['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final double tCost = (json['totalCost'] as num?)?.toDouble() ?? 0.0;
    final double cPrice = (json['costPrice'] as num?)?.toDouble() ?? 0.0;
    final double qOut = (json['quantityOut'] as num?)?.toDouble() ?? 0.0;
    final double qIn = (json['quantityIn'] as num?)?.toDouble() ?? 0.0;
    final double bal = (json['balance'] as num?)?.toDouble() ?? 0.0;
    final String rawDate = json['date']?.toString() ?? '';

    return ItemCardRow(
      itemNo:            json['itemNo']?.toString()            ?? '',
      branchName:        json['branchName']?.toString()        ?? '',
      costCenterName:    json['costCenterName']?.toString()    ?? '',
      accountName:       json['accountName']?.toString()       ?? '',
      storeName:         json['storeName']?.toString()         ?? '',
      referenceNumber:   json['referenceNumber']?.toString()   ?? '',
      dateNo:            json['dateNo']?.toString()            ?? '',
      unitPrice:         uPrice,
      totalAmount:       tAmount,
      totalCost:         tCost,
      packFactor:        json['packFactor']?.toString()        ?? '',
      expiryDate:        json['expiryDate']?.toString()        ?? '',
      customerName:      json['customerName']?.toString()      ?? '',
      transactionNumber: json['transactionNumber']?.toString() ?? '',
      description:       json['description']?.toString()       ?? '',
      date:              rawDate,
      itemUnit:          json['itemUnit']?.toString()          ?? '',
      costPrice:         cPrice,
      batchNumber:       json['batchNumber']?.toString()       ?? '',
      quantityOut:       qOut,
      quantityIn:        qIn,
      balance:           bal,
      quantityInStr:     _formatNum(qIn),
      quantityOutStr:    _formatNum(qOut),
      balanceStr:        _formatNum(bal),
      costPriceStr:      _formatNum(cPrice),
      formattedDate:     _formatDate(rawDate),
      totalCostStr:      _formatNum(tCost),
      totalAmountStr:    _formatNum(tAmount),
      unitPriceStr:      _formatNum(uPrice),
    );
  }
}

class ItemCardResponse {
  final int rowCount;
  final double totalQuantityIn;
  final double totalQuantityOut;
  final double finalBalance;
  final String totalQuantityInStr;
  final String totalQuantityOutStr;
  final String finalBalanceStr;
  final List<ItemCardRow> rows;

  const ItemCardResponse({
    required this.rowCount,
    required this.totalQuantityIn,
    required this.totalQuantityOut,
    required this.finalBalance,
    this.totalQuantityInStr = '',
    this.totalQuantityOutStr = '',
    this.finalBalanceStr = '',
    required this.rows,
  });

  factory ItemCardResponse.fromJson(Map<String, dynamic> json) {
    final list = json['rows'] as List? ?? [];
    final double inTotal = (json['totalQuantityIn'] as num?)?.toDouble() ?? 0.0;
    final double outTotal = (json['totalQuantityOut'] as num?)?.toDouble() ?? 0.0;
    final double balTotal = (json['finalBalance'] as num?)?.toDouble() ?? 0.0;

    return ItemCardResponse(
      rowCount:         (json['rowCount']         as num?)?.toInt()    ?? 0,
      totalQuantityIn:  inTotal,
      totalQuantityOut: outTotal,
      finalBalance:     balTotal,
      totalQuantityInStr: ItemCardRow._formatNum(inTotal),
      totalQuantityOutStr: ItemCardRow._formatNum(outTotal),
      finalBalanceStr: ItemCardRow._formatNum(balTotal),
      rows:             list.map((e) => ItemCardRow.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Standalone top-level function for background isolate execution via compute()
ItemCardResponse parseItemCardJson(String rawJson) {
  final Map<String, dynamic> json = jsonDecode(rawJson);
  return ItemCardResponse.fromJson(json);
}
