class SaleItem {
  final String id;
  final String? saleId;
  final double quantity;
  final double total;
  final double itemPrice;
  final DateTime? createdAt;
  final int? bonusQuantity;
  final double? itemDiscount;
  final String? itemNo;
  final String itemName;
  final bool isTaxable;
  final double taxRate;
  final bool isDiscountable;
  final double? discountRate;
  final String itemUnit;
  final int? costCenterNo;

  final double packFactor;
  final String? expiryDate;

  final String? batchNumber;
  final double? stockBalance;

  final double? costPrice;
  final double? diffQuantity;
  final double? deficitValue;
  final double? surplusValue;
  final int? itemCurrencyId;
  final double? itemCurrencyRate;
  final String? pumpName;
  final double? previousReading;
  final double? currentReading;
  final double? tradTraTax;

  SaleItem({
    required this.id,
    this.saleId,
    required this.quantity,
    required this.total,
    required this.itemPrice,
    this.createdAt,
    this.bonusQuantity,
    this.itemDiscount,
    this.itemNo,
    required this.itemName,
    required this.isTaxable,
    required this.taxRate,
    required this.isDiscountable,
    this.discountRate,
    required this.itemUnit,
    this.costCenterNo,
    this.packFactor = 1.0,
    this.expiryDate,
    this.batchNumber,
    this.stockBalance,
    this.costPrice,
    this.diffQuantity,
    this.deficitValue,
    this.surplusValue,
    this.itemCurrencyId,
    this.itemCurrencyRate,
    this.pumpName,
    this.previousReading,
    this.currentReading,
    this.tradTraTax,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? itemData =
    json['sun_items'] != null ? Map<String, dynamic>.from(json['sun_items']) : null;

    return SaleItem(
      id: json['id']?.toString() ?? '',
      saleId: json['sale_id']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      itemPrice: (json['item_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
      bonusQuantity: (json['bonus_quantity'] as num?)?.toInt(),
      itemDiscount: (json['item_discount'] as num?)?.toDouble(),
      itemNo: json['item_no']?.toString(),
      itemName: itemData?['item_name']?.toString() ?? 'صنف غير معروف',
      isTaxable: (itemData?['is_taxable'] == 1 || itemData?['is_taxable'] == true),
      taxRate: (itemData?['tax_rate'] as num?)?.toDouble() ?? 0.0,
      isDiscountable: (itemData?['is_discountable'] == 1 || itemData?['is_discountable'] == true),
      discountRate: (itemData?['discount_rate'] as num?)?.toDouble(),
      costCenterNo: itemData?['cost_center_no'] as int?,
      itemUnit: json['item_unit']?.toString() ?? itemData?['item_unit']?.toString() ?? '',
      packFactor: (json['pack_factor'] as num?)?.toDouble() ?? 1.0,
      expiryDate: json['expiry_date']?.toString(),
      batchNumber: json['batch_no']?.toString(),
      stockBalance: (json['stock_balance'] as num?)?.toDouble(),
      costPrice: (json['cost_price'] as num?)?.toDouble(),
      diffQuantity: (json['diff_quantity'] as num?)?.toDouble(),
      deficitValue: (json['deficit_value'] as num?)?.toDouble(),
      surplusValue: (json['surplus_value'] as num?)?.toDouble(),
      itemCurrencyId: (json['item_currency_id'] as num?)?.toInt() ?? 1,
      itemCurrencyRate: (json['item_currency_rate'] as num?)?.toDouble() ?? 1.0,
      pumpName: json['pump_name']?.toString() ?? itemData?['pump_name']?.toString(),
      previousReading: (json['previous_reading'] as num?)?.toDouble() ?? (itemData?['previous_reading'] as num?)?.toDouble(),
      currentReading: (json['current_reading'] as num?)?.toDouble() ?? (itemData?['current_reading'] as num?)?.toDouble(),
      tradTraTax: (json['trad_tra_tax'] as num?)?.toDouble() ?? (json['tradTraTax'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty && int.tryParse(id) != null) 'id': int.parse(id),
      'sale_id': saleId != null ? int.tryParse(saleId!) : null,
      'quantity': quantity,
      'total': total,
      'item_price': itemPrice,
      'created_at': createdAt?.toIso8601String(),
      'bonus_quantity': bonusQuantity,
      'item_discount': itemDiscount,
      'item_no': itemNo,
      'pack_factor': packFactor,
      'expiry_date': expiryDate,
      'item_unit': itemUnit,
      'batch_no': batchNumber,
      'stock_balance': stockBalance,
      'cost_price': costPrice,
      'diff_quantity': diffQuantity,
      'deficit_value': deficitValue,
      'surplus_value': surplusValue,
      'item_currency_id': itemCurrencyId,
      'item_currency_rate': itemCurrencyRate,
      'pump_name': pumpName,
      'previous_reading': previousReading,
      'current_reading': currentReading,
      'trad_tra_tax': tradTraTax ?? 0.0,
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': int.tryParse(id),
      'itemNo': itemNo,
      'itemName': itemName,
      'itemUnit': itemUnit,
      'quantity': quantity,
      'bonusQuantity': bonusQuantity ?? 0,
      'itemPrice': itemPrice,
      'itemDiscount': itemDiscount ?? 0.0,
      'total': total,
      'packFactor': packFactor,
      'expiryDate': expiryDate,
      'batchNo': batchNumber,
      'stockBalance': stockBalance,
      'diffQuantity': diffQuantity,
      'deficitValue': deficitValue,
      'surplusValue': surplusValue,
      'costPrice': costPrice,
      'itemCurrencyId': itemCurrencyId ?? 1,
      'itemCurrencyRate': itemCurrencyRate ?? 1.0,
      'pumpName': pumpName,
      'previousReading': previousReading,
      'currentReading': currentReading,
      'tradTraTax': tradTraTax ?? 0.0,
    };
  }
}