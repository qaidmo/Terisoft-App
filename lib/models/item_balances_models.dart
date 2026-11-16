// lib/models/item_balances_models.dart
// تقرير أرصدة الأصناف — موديلات مستقلة تماماً

import 'dart:convert';
import 'package:intl/intl.dart';

class ItemBalancesRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;

  // أمان نطاق البيانات
  final int? userId;
  final int? departmentId;

  // أعمدة اختيارية
  final bool includeBranch;
  final bool includeDepartment;
  final bool includeStore;    // يضيف StoreNo + StoreName + ItemBalance
  final bool includeExpiry;
  final bool includeBatch;

  // فلاتر جانب السيرفر
  final bool excludeZeros;
  final bool negativeQtyOnly;
  final bool excludePreviousBalance;
  final bool zeroBalancesOnly;

  ItemBalancesRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    this.userId,
    this.departmentId,
    this.includeBranch = false,
    this.includeDepartment = false,
    this.includeStore = false,
    this.includeExpiry = false,
    this.includeBatch = false,
    this.excludeZeros = false,
    this.negativeQtyOnly = false,
    this.excludePreviousBalance = false,
    this.zeroBalancesOnly = false,
  });

  Map<String, dynamic> toJson() => {
        'fromDate':              fromDate.toIso8601String(),
        'toDate':                toDate.toIso8601String(),
        'year':                  year,
        'branchId':              branchId,
        'userId':                userId,
        'departmentId':          departmentId,
        'includeBranch':         includeBranch,
        'includeDepartment':     includeDepartment,
        'includeStore':          includeStore,
        'includeExpiry':         includeExpiry,
        'includeBatch':          includeBatch,
        'excludeZeros':          excludeZeros,
        'negativeQtyOnly':       negativeQtyOnly,
        'excludePreviousBalance':excludePreviousBalance,
        'zeroBalancesOnly':      zeroBalancesOnly,
      };
}

// ---------------------------------------------------------------------------
// صف واحد من بيانات التقرير
// ---------------------------------------------------------------------------
class ItemBalancesRow {
  // 4 أعمدة ثابتة
  final String  itemNo;
  final String  itemName;
  final String  itemUnit;
  final double  sellingPrice;

  // أعمدة اختيارية وسطية
  final String  branchId;
  final String  departmentId;
  final String  storeNo;
  final String  storeName;
  final String  expiryDate;
  final String  batchNumber;

  // 16 عمود بيانات رئيسية
  final double  balanceQty;
  final double  unitCost;
  final double  balanceCost;
  final double  openingQty;
  final double  purchaseQty;
  final double  salesQty;
  final double  otherQty;
  final double  endingQty;
  final double  balanceAtSelling;
  final double  incomingQty;
  final double  outgoingQty;
  final double  buyQty;
  final double  sellQty;
  final double  returnSellQty;
  final double  bonusQty;
  final double  salesBonusQty;

  // عمود نهائي مشروط (يُعرض فقط عند includeStore)
  final double  itemBalance;

  // Pre-formatted display strings
  final String sellingPriceStr;
  final String balanceQtyStr;
  final String unitCostStr;
  final String balanceCostStr;
  final String openingQtyStr;
  final String purchaseQtyStr;
  final String salesQtyStr;
  final String otherQtyStr;
  final String endingQtyStr;
  final String balanceAtSellingStr;
  final String incomingQtyStr;
  final String outgoingQtyStr;
  final String buyQtyStr;
  final String sellQtyStr;
  final String returnSellQtyStr;
  final String bonusQtyStr;
  final String salesBonusQtyStr;
  final String itemBalanceStr;

  ItemBalancesRow({
    required this.itemNo,
    required this.itemName,
    required this.itemUnit,
    required this.sellingPrice,
    required this.branchId,
    required this.departmentId,
    required this.storeNo,
    required this.storeName,
    required this.expiryDate,
    required this.batchNumber,
    required this.balanceQty,
    required this.unitCost,
    required this.balanceCost,
    required this.openingQty,
    required this.purchaseQty,
    required this.salesQty,
    required this.otherQty,
    required this.endingQty,
    required this.balanceAtSelling,
    required this.incomingQty,
    required this.outgoingQty,
    required this.buyQty,
    required this.sellQty,
    required this.returnSellQty,
    required this.bonusQty,
    required this.salesBonusQty,
    required this.itemBalance,
    this.sellingPriceStr = '',
    this.balanceQtyStr = '',
    this.unitCostStr = '',
    this.balanceCostStr = '',
    this.openingQtyStr = '',
    this.purchaseQtyStr = '',
    this.salesQtyStr = '',
    this.otherQtyStr = '',
    this.endingQtyStr = '',
    this.balanceAtSellingStr = '',
    this.incomingQtyStr = '',
    this.outgoingQtyStr = '',
    this.buyQtyStr = '',
    this.sellQtyStr = '',
    this.returnSellQtyStr = '',
    this.bonusQtyStr = '',
    this.salesBonusQtyStr = '',
    this.itemBalanceStr = '',
  });

  static final NumberFormat _nf = NumberFormat('#,###.##', 'en_US');

  static String _formatNum(double val) {
    if (val == 0.0) return '0';
    return _nf.format(val);
  }

  factory ItemBalancesRow.fromJson(Map<String, dynamic> json) {
    final double sPrice = (json['sellingPrice'] as num?)?.toDouble() ?? 0.0;
    final double bQty = (json['balanceQty'] as num?)?.toDouble() ?? 0.0;
    final double uCost = (json['unitCost'] as num?)?.toDouble() ?? 0.0;
    final double bCost = (json['balanceCost'] as num?)?.toDouble() ?? 0.0;
    final double oQty = (json['openingQty'] as num?)?.toDouble() ?? 0.0;
    final double pQty = (json['purchaseQty'] as num?)?.toDouble() ?? 0.0;
    final double sQty = (json['salesQty'] as num?)?.toDouble() ?? 0.0;
    final double othQty = (json['otherQty'] as num?)?.toDouble() ?? 0.0;
    final double eQty = (json['endingQty'] as num?)?.toDouble() ?? 0.0;
    final double bAtSelling = (json['balanceAtSelling'] as num?)?.toDouble() ?? 0.0;
    final double inQty = (json['incomingQty'] as num?)?.toDouble() ?? 0.0;
    final double outQty = (json['outgoingQty'] as num?)?.toDouble() ?? 0.0;
    final double bQtyVal = (json['buyQty'] as num?)?.toDouble() ?? 0.0;
    final double slQty = (json['sellQty'] as num?)?.toDouble() ?? 0.0;
    final double retQty = (json['returnSellQty'] as num?)?.toDouble() ?? 0.0;
    final double bonQty = (json['bonusQty'] as num?)?.toDouble() ?? 0.0;
    final double sBonQty = (json['salesBonusQty'] as num?)?.toDouble() ?? 0.0;
    final double itmBal = (json['itemBalance'] as num?)?.toDouble() ?? 0.0;

    return ItemBalancesRow(
      itemNo:           json['itemNo']?.toString()          ?? '',
      itemName:         json['itemName']?.toString()        ?? '',
      itemUnit:         json['itemUnit']?.toString()        ?? '',
      sellingPrice:     sPrice,
      branchId:         json['branchId']?.toString()        ?? '',
      departmentId:     json['departmentId']?.toString()    ?? '',
      storeNo:          json['storeNo']?.toString()         ?? '',
      storeName:        json['storeName']?.toString()       ?? '',
      expiryDate:       json['expiryDate']?.toString()      ?? '',
      batchNumber:      json['batchNumber']?.toString()     ?? '',
      balanceQty:       bQty,
      unitCost:         uCost,
      balanceCost:      bCost,
      openingQty:       oQty,
      purchaseQty:      pQty,
      salesQty:         sQty,
      otherQty:         othQty,
      endingQty:        eQty,
      balanceAtSelling: bAtSelling,
      incomingQty:      inQty,
      outgoingQty:      outQty,
      buyQty:           bQtyVal,
      sellQty:          slQty,
      returnSellQty:    retQty,
      bonusQty:         bonQty,
      salesBonusQty:    sBonQty,
      itemBalance:      itmBal,
      sellingPriceStr:    _formatNum(sPrice),
      balanceQtyStr:      _formatNum(bQty),
      unitCostStr:        _formatNum(uCost),
      balanceCostStr:     _formatNum(bCost),
      openingQtyStr:      _formatNum(oQty),
      purchaseQtyStr:     _formatNum(pQty),
      salesQtyStr:        _formatNum(sQty),
      otherQtyStr:        _formatNum(othQty),
      endingQtyStr:       _formatNum(eQty),
      balanceAtSellingStr:_formatNum(bAtSelling),
      incomingQtyStr:     _formatNum(inQty),
      outgoingQtyStr:     _formatNum(outQty),
      buyQtyStr:          _formatNum(bQtyVal),
      sellQtyStr:         _formatNum(slQty),
      returnSellQtyStr:   _formatNum(retQty),
      bonusQtyStr:        _formatNum(bonQty),
      salesBonusQtyStr:   _formatNum(sBonQty),
      itemBalanceStr:     _formatNum(itmBal),
    );
  }
}

// ---------------------------------------------------------------------------
// موديل الاستجابة الكاملة
// ---------------------------------------------------------------------------
class ItemBalancesResponse {
  final int    rowCount;
  final double grandBalance;
  final double grandBalanceCost;
  final double grandSalesQty;
  final double grandPurchaseQty;
  final String grandBalanceStr;
  final String grandBalanceCostStr;
  final String grandSalesQtyStr;
  final String grandPurchaseQtyStr;
  final List<ItemBalancesRow> rows;

  ItemBalancesResponse({
    required this.rowCount,
    required this.grandBalance,
    required this.grandBalanceCost,
    required this.grandSalesQty,
    required this.grandPurchaseQty,
    this.grandBalanceStr = '',
    this.grandBalanceCostStr = '',
    this.grandSalesQtyStr = '',
    this.grandPurchaseQtyStr = '',
    required this.rows,
  });

  factory ItemBalancesResponse.fromJson(Map<String, dynamic> json) {
    final list = json['rows'] as List? ?? [];
    final double gBal = (json['grandBalance'] as num?)?.toDouble() ?? 0.0;
    final double gBalCost = (json['grandBalanceCost'] as num?)?.toDouble() ?? 0.0;
    final double gSales = (json['grandSalesQty'] as num?)?.toDouble() ?? 0.0;
    final double gPurch = (json['grandPurchaseQty'] as num?)?.toDouble() ?? 0.0;

    return ItemBalancesResponse(
      rowCount:            (json['rowCount'] as num?)?.toInt() ?? 0,
      grandBalance:        gBal,
      grandBalanceCost:    gBalCost,
      grandSalesQty:       gSales,
      grandPurchaseQty:    gPurch,
      grandBalanceStr:     ItemBalancesRow._formatNum(gBal),
      grandBalanceCostStr: ItemBalancesRow._formatNum(gBalCost),
      grandSalesQtyStr:    ItemBalancesRow._formatNum(gSales),
      grandPurchaseQtyStr: ItemBalancesRow._formatNum(gPurch),
      rows:                list.map((e) => ItemBalancesRow.fromJson(e)).toList(),
    );
  }
}

/// Standalone top-level function for background isolate execution via compute()
ItemBalancesResponse parseItemBalancesJson(String rawJson) {
  final Map<String, dynamic> json = jsonDecode(rawJson);
  return ItemBalancesResponse.fromJson(json);
}
