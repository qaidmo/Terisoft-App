// lib/models/profit_margin_models.dart
// تقرير هامش الربح — موديلات مستقلة تماماً

import 'dart:convert';
import 'package:intl/intl.dart';

class ProfitMarginRequest {
  final DateTime fromDate;
  final DateTime toDate;
  final String year;
  final int branchId;
  final String groupBy;       // "item" | "group" | "user"
  final int? userId;
  final int? departmentId;
  final String? itemGroupId;
  final bool negativeMarginOnly;
  final bool includeBranch;
  final bool includeDepartment;
  final bool includeBatch;
  final bool includeCostCenter;

  ProfitMarginRequest({
    required this.fromDate,
    required this.toDate,
    required this.year,
    required this.branchId,
    this.groupBy = 'item',
    this.userId,
    this.departmentId,
    this.itemGroupId,
    this.negativeMarginOnly = false,
    this.includeBranch = false,
    this.includeDepartment = false,
    this.includeBatch = false,
    this.includeCostCenter = false,
  });

  Map<String, dynamic> toJson() => {
        'fromDate':          fromDate.toIso8601String(),
        'toDate':            toDate.toIso8601String(),
        'year':              year,
        'branchId':          branchId,
        'groupBy':           groupBy,
        'userId':            userId,
        'departmentId':      departmentId,
        'itemGroupId':       itemGroupId,
        'negativeMarginOnly':negativeMarginOnly,
        'includeBranch':     includeBranch,
        'includeDepartment': includeDepartment,
        'includeBatch':      includeBatch,
        'includeCostCenter': includeCostCenter,
      };
}

// ---------------------------------------------------------------------------
// صف واحد من بيانات تقرير هامش الربح
// ---------------------------------------------------------------------------
class ProfitMarginRow {
  final String  primaryKey;       // رقم الصنف / رقم المجموعة / رقم المستخدم
  final String  primaryName;      // اسم الصنف / اسم المجموعة / اسم المستخدم
  final String  itemUnit;         // الوحدة (فارغة عند التجميع بغير الصنف)
  final String  branchId;
  final String  departmentId;
  final String  batchNumber;
  final String  costCenterName;
  final double  salesQty;         // كمية المبيعات
  final double  salesValue;       // قيمة المبيعات (محلية)
  final double  salesCost;        // تكلفة المبيعات
  final double  margin;           // هامش الربح = قيمة - تكلفة
  final double  profitPct;        // نسبة الربح %
  final double  balanceQty;       // كمية الرصيد
  final double  balanceCost;      // تكلفة الرصيد
  final double  balanceSalesPct;  // SalesQty / BalanceQty * 100

  // سلاسل نصية منسقة مسبقاً للعرض السريع بدون تأخير
  final String  salesQtyStr;
  final String  salesValueStr;
  final String  salesCostStr;
  final String  marginStr;
  final String  profitPctStr;
  final String  balanceQtyStr;
  final String  balanceCostStr;
  final String  balanceSalesPctStr;

  ProfitMarginRow({
    required this.primaryKey,
    required this.primaryName,
    required this.itemUnit,
    required this.branchId,
    required this.departmentId,
    required this.batchNumber,
    required this.costCenterName,
    required this.salesQty,
    required this.salesValue,
    required this.salesCost,
    required this.margin,
    required this.profitPct,
    required this.balanceQty,
    required this.balanceCost,
    required this.balanceSalesPct,
    this.salesQtyStr = '0',
    this.salesValueStr = '0',
    this.salesCostStr = '0',
    this.marginStr = '0',
    this.profitPctStr = '0%',
    this.balanceQtyStr = '0',
    this.balanceCostStr = '0',
    this.balanceSalesPctStr = '0%',
  });

  factory ProfitMarginRow.fromJson(Map<String, dynamic> json, [NumberFormat? numFormatter]) {
    final fmt = numFormatter ?? NumberFormat('#,###.##', 'en_US');
    final sQty  = (json['salesQty']        as num?)?.toDouble() ?? 0.0;
    final sVal  = (json['salesValue']       as num?)?.toDouble() ?? 0.0;
    final sCost = (json['salesCost']        as num?)?.toDouble() ?? 0.0;
    final mrg   = (json['margin']           as num?)?.toDouble() ?? 0.0;
    final pPct  = (json['profitPct']        as num?)?.toDouble() ?? 0.0;
    final bQty  = (json['balanceQty']       as num?)?.toDouble() ?? 0.0;
    final bCost = (json['balanceCost']      as num?)?.toDouble() ?? 0.0;
    final bPct  = (json['balanceSalesPct']  as num?)?.toDouble() ?? 0.0;

    return ProfitMarginRow(
      primaryKey:      json['primaryKey']?.toString()      ?? '',
      primaryName:     json['primaryName']?.toString()     ?? '',
      itemUnit:        json['itemUnit']?.toString()        ?? '',
      branchId:        json['branchId']?.toString()        ?? '',
      departmentId:    json['departmentId']?.toString()    ?? '',
      batchNumber:     json['batchNumber']?.toString()     ?? '',
      costCenterName:  json['costCenterName']?.toString()  ?? '',
      salesQty:        sQty,
      salesValue:      sVal,
      salesCost:       sCost,
      margin:          mrg,
      profitPct:       pPct,
      balanceQty:      bQty,
      balanceCost:     bCost,
      balanceSalesPct: bPct,
      salesQtyStr:        fmt.format(sQty),
      salesValueStr:      fmt.format(sVal),
      salesCostStr:       fmt.format(sCost),
      marginStr:          fmt.format(mrg),
      profitPctStr:       '${fmt.format(pPct)}%',
      balanceQtyStr:      fmt.format(bQty),
      balanceCostStr:     fmt.format(bCost),
      balanceSalesPctStr: '${fmt.format(bPct)}%',
    );
  }
}

// ---------------------------------------------------------------------------
// موديل الاستجابة الكاملة
// ---------------------------------------------------------------------------
class ProfitMarginResponse {
  final int    rowCount;
  final double grandSalesQty;
  final double grandSalesValue;
  final double grandSalesCost;
  final double grandMargin;
  final double grandBalanceQty;
  final double grandBalanceCost;
  final String grandSalesQtyStr;
  final String grandSalesValueStr;
  final String grandSalesCostStr;
  final String grandMarginStr;
  final String grandBalanceQtyStr;
  final String grandBalanceCostStr;
  final List<ProfitMarginRow> rows;

  ProfitMarginResponse({
    required this.rowCount,
    required this.grandSalesQty,
    required this.grandSalesValue,
    required this.grandSalesCost,
    required this.grandMargin,
    required this.grandBalanceQty,
    required this.grandBalanceCost,
    this.grandSalesQtyStr = '0',
    this.grandSalesValueStr = '0',
    this.grandSalesCostStr = '0',
    this.grandMarginStr = '0',
    this.grandBalanceQtyStr = '0',
    this.grandBalanceCostStr = '0',
    required this.rows,
  });

  factory ProfitMarginResponse.fromJson(Map<String, dynamic> json, [NumberFormat? numFormatter]) {
    final fmt = numFormatter ?? NumberFormat('#,###.##', 'en_US');
    final gSalesQty    = (json['grandSalesQty']    as num?)?.toDouble() ?? 0.0;
    final gSalesValue  = (json['grandSalesValue']  as num?)?.toDouble() ?? 0.0;
    final gSalesCost   = (json['grandSalesCost']   as num?)?.toDouble() ?? 0.0;
    final gMargin      = (json['grandMargin']      as num?)?.toDouble() ?? 0.0;
    final gBalanceQty  = (json['grandBalanceQty']  as num?)?.toDouble() ?? 0.0;
    final gBalanceCost = (json['grandBalanceCost'] as num?)?.toDouble() ?? 0.0;
    final list = json['rows'] as List? ?? [];

    return ProfitMarginResponse(
      rowCount:            (json['rowCount']         as num?)?.toInt()    ?? 0,
      grandSalesQty:       gSalesQty,
      grandSalesValue:     gSalesValue,
      grandSalesCost:      gSalesCost,
      grandMargin:         gMargin,
      grandBalanceQty:     gBalanceQty,
      grandBalanceCost:    gBalanceCost,
      grandSalesQtyStr:    fmt.format(gSalesQty),
      grandSalesValueStr:  fmt.format(gSalesValue),
      grandSalesCostStr:   fmt.format(gSalesCost),
      grandMarginStr:      fmt.format(gMargin),
      grandBalanceQtyStr:  fmt.format(gBalanceQty),
      grandBalanceCostStr: fmt.format(gBalanceCost),
      rows:                list.map((e) => ProfitMarginRow.fromJson(e, fmt)).toList(),
    );
  }
}

/// دالة عليا للتحليل في Isolate منفصل
ProfitMarginResponse parseProfitMarginJson(String rawJson) {
  final Map<String, dynamic> decoded = jsonDecode(rawJson) as Map<String, dynamic>;
  final fmt = NumberFormat('#,###.##', 'en_US');
  return ProfitMarginResponse.fromJson(decoded, fmt);
}
