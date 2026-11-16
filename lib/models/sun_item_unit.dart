// lib/models/sun_item_unit.dart

class SunItemUnit {
  final String? unitId;
  final String? itemNo;
  final String? unitName;
  final int unitIndex;
  final double conversionFactor;
  final double salePrice;
  final String? barcode;
  final bool isActive;

  // 1. 👇 الإضافة الجديدة: حقل تاريخ التعديل
  final String? lastUpdated;

  SunItemUnit({
    this.unitId,
    this.itemNo,
    this.unitName,
    required this.unitIndex,
    required this.conversionFactor,
    required this.salePrice,
    this.barcode,
    this.isActive = true,
    // 2. 👇 الإضافة في الكونستركتور
    this.lastUpdated,
  });

  // 1. استقبال البيانات من الـ API (JSON)
  factory SunItemUnit.fromJson(Map<String, dynamic> json) {
    return SunItemUnit(
      unitId: json['unit_id']?.toString(),
      itemNo: json['item_no']?.toString(),
      unitName: json['unit_name'] as String?,
      unitIndex: json['unit_index'] as int? ?? 0,
      conversionFactor: (json['conversion_factor'] as num?)?.toDouble() ?? 1.0,
      salePrice: (json['sale_price'] as num?)?.toDouble() ?? 0.0,
      barcode: json['barcode'] as String?,
      isActive: json['is_active'] == true,
      // 3. 👇 استقبال التاريخ من السيرفر
      lastUpdated: json['last_updated'] as String?,
    );
  }

  // 2. قراءة البيانات من SQLite (Map)
  factory SunItemUnit.fromMap(Map<String, dynamic> map) {
    return SunItemUnit(
      unitId: map['unit_id'] as String?,
      itemNo: map['item_no'] as String?,
      unitName: map['unit_name'] as String?,
      unitIndex: map['unit_index'] as int,
      conversionFactor: map['conversion_factor'] as double,
      salePrice: map['sale_price'] as double,
      barcode: map['barcode'] as String?,
      isActive: map['is_active'] == 1,
      // 4. 👇 قراءة التاريخ من قاعدة البيانات المحلية
      lastUpdated: map['last_updated'] as String?,
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'unit_id': unitId,
      'item_no': itemNo,
      'unit_name': unitName,
      'unit_index': unitIndex,
      'conversion_factor': conversionFactor,
      'sale_price': salePrice,
      'barcode': barcode,
      'is_active': isActive ? 1 : 0,
      // 5. 👇 حفظ التاريخ في العمود الجديد
      'last_updated': lastUpdated,
    };
  }
}