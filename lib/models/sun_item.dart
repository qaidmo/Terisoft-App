class SunItem {
  final String itemNo;
  final String itemName;
  final String? itemBarcode;
  final String itemUnit;
  final double itemPrice;
  final String? itemGroupNo;
  final String? groupName;
  final int currencyNo;
  final int? costCenterNo;
  final String? inventoryAccountId;
  final String? cogsAccountId;
  final String? salesRevenueAccountId;
  final String? salesDiscountAccountId;
  final bool isTaxable;
  final double taxRate;
  final double? discountRate;
  final bool isDiscountable;
  final bool isCashReserved;
  final String? sourceId;
  final String? lastUpdated;
  final String? averageCost;
  final String? sectionNo;

  SunItem({
    required this.itemNo,
    required this.itemName,
    this.itemBarcode,
    required this.itemUnit,
    required this.itemPrice,
    this.itemGroupNo,
    this.groupName,
    required this.currencyNo,
    this.costCenterNo,
    this.inventoryAccountId,
    this.cogsAccountId,
    this.salesRevenueAccountId,
    this.salesDiscountAccountId,
    required this.isTaxable,
    required this.taxRate,
    this.discountRate,
    required this.isDiscountable,
    required this.isCashReserved,
    this.sourceId,
    this.lastUpdated,
    this.averageCost,
    this.sectionNo,
  });

  factory SunItem.fromJson(Map<String, dynamic> json) {
    return SunItem(
      itemNo: json['item_no'] as String,
      itemName: json['item_name'] as String? ?? 'N/A',
      itemBarcode: json['item_barcode'] as String?,
      itemUnit: json['item_unit'] as String? ?? '',
      itemPrice: (json['item_price'] as num?)?.toDouble() ?? 0.0,
      itemGroupNo: json['item_group_no']?.toString(),
      groupName: json['group_name'] as String?,
      currencyNo: json['currency_no'] as int? ?? 1,
      costCenterNo: json['cost_center_no'] as int?,
      inventoryAccountId: json['inventory_account_id'] as String?,
      cogsAccountId: json['cogs_account_id'] as String?,
      salesRevenueAccountId: json['sales_revenue_account_id'] as String?,
      salesDiscountAccountId: json['sales_discount_account_id'] as String?,
      isTaxable: json['is_taxable'] == true,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0.0,
      discountRate: (json['discount_rate'] as num?)?.toDouble(),
      isDiscountable: json['is_discountable'] == true,
      isCashReserved: json['is_cash_reserved'] == true,
      sourceId: json['source_id']?.toString(),
      lastUpdated: json['last_updated'] as String?,
      averageCost: json['average_cost'] as String?,
      sectionNo: json['section_no'] as String?,
    );
  }

  factory SunItem.fromMap(Map<String, dynamic> map) {
    return SunItem(
      itemNo: map['item_no'] as String,
      itemName: map['item_name'] as String,
      itemBarcode: map['item_barcode'] as String?,
      itemUnit: map['item_unit'] as String,
      itemPrice: map['item_price'] as double,
      itemGroupNo: map['item_group_no']?.toString(),
      groupName: map['group_name'] as String?,
      currencyNo: map['currency_no'] as int,
      costCenterNo: map['cost_center_no'] as int?,
      inventoryAccountId: map['inventory_account_id'] as String?,
      cogsAccountId: map['cogs_account_id'] as String?,
      salesRevenueAccountId: map['sales_revenue_account_id'] as String?,
      salesDiscountAccountId: map['sales_discount_account_id'] as String?,
      isTaxable: map['is_taxable'] == 1,
      taxRate: map['tax_rate'] as double,
      discountRate: map['discount_rate'] as double?,
      isDiscountable: map['is_discountable'] == 1,
      isCashReserved: map['is_cash_reserved'] == 1,
      sourceId: map['source_id'] as String?,
      lastUpdated: map['last_updated'] as String?,
      averageCost: map['average_cost'] as String?,
      sectionNo: map['section_no']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item_no': itemNo,
      'item_name': itemName,
      'item_barcode': itemBarcode,
      'item_unit': itemUnit,
      'item_price': itemPrice,
      'item_group_no': itemGroupNo,
      'currency_no': currencyNo,
      'cost_center_no': costCenterNo,
      'inventory_account_id': inventoryAccountId,
      'cogs_account_id': cogsAccountId,
      'sales_revenue_account_id': salesRevenueAccountId,
      'sales_discount_account_id': salesDiscountAccountId,
      'is_taxable': isTaxable ? 1 : 0,
      'tax_rate': taxRate,
      'discount_rate': discountRate,
      'is_discountable': isDiscountable ? 1 : 0,
      'is_cash_reserved': isCashReserved ? 1 : 0,
      'source_id': sourceId,
      'last_updated': lastUpdated,
      'average_cost': averageCost,
      'section_no': sectionNo,
    };
  }

  SunItem copyWith({
    String? itemNo,
    String? itemName,
    String? itemBarcode,
    String? itemUnit,
    double? itemPrice,
    String? itemGroupNo,
    String? groupName,
    int? currencyNo,
    int? costCenterNo,
    String? inventoryAccountId,
    String? cogsAccountId,
    String? salesRevenueAccountId,
    String? salesDiscountAccountId,
    bool? isTaxable,
    double? taxRate,
    double? discountRate,
    bool? isDiscountable,
    bool? isCashReserved,
    String? sourceId,
    String? lastUpdated,
    String? averageCost,
    String? sectionNo,
  }) {
    return SunItem(
      itemNo: itemNo ?? this.itemNo,
      itemName: itemName ?? this.itemName,
      itemBarcode: itemBarcode ?? this.itemBarcode,
      itemUnit: itemUnit ?? this.itemUnit,
      itemPrice: itemPrice ?? this.itemPrice,
      itemGroupNo: itemGroupNo ?? this.itemGroupNo,
      groupName: groupName ?? this.groupName,
      currencyNo: currencyNo ?? this.currencyNo,
      costCenterNo: costCenterNo ?? this.costCenterNo,
      inventoryAccountId: inventoryAccountId ?? this.inventoryAccountId,
      cogsAccountId: cogsAccountId ?? this.cogsAccountId,
      salesRevenueAccountId: salesRevenueAccountId ?? this.salesRevenueAccountId,
      salesDiscountAccountId: salesDiscountAccountId ?? this.salesDiscountAccountId,
      isTaxable: isTaxable ?? this.isTaxable,
      taxRate: taxRate ?? this.taxRate,
      discountRate: discountRate ?? this.discountRate,
      isDiscountable: isDiscountable ?? this.isDiscountable,
      isCashReserved: isCashReserved ?? this.isCashReserved,
      sourceId: sourceId ?? this.sourceId,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      averageCost: averageCost ?? this.averageCost,
      sectionNo: sectionNo ?? this.sectionNo,
    );
  }
}