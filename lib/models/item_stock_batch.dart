// lib/models/item_stock_batch.dart

class ItemStockBatch {
  final String itemNo;
  final String expiryDate;
  final String? batchNo;
  final double quantity;
  final double costPrice;
  final int storeNo;
  final int branchId;        // 👈 التأكد من التسمية الصحيحة (CamelCase)
  final String? lastUpdatedStr;

  ItemStockBatch({
    required this.itemNo,
    required this.expiryDate,
    this.batchNo,
    required this.quantity,
    required this.costPrice,
    required this.storeNo,
    required this.branchId, // 👈 المعامل المطلوب
    this.lastUpdatedStr,
  });

  // 1. استقبال البيانات من الـ API (JSON)
  factory ItemStockBatch.fromJson(Map<String, dynamic> json) {
    return ItemStockBatch(
      itemNo: json['item_no'] as String? ?? '',
      expiryDate: json['expiry_date'] as String? ?? '',
      batchNo: json['batch_no'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0.0,
      storeNo: (json['store_no'] as num?)?.toInt() ?? 0,
      // 👈 تم تصحيح الخطأ هنا: تمرير القيمة لـ branchId
      branchId: (json['branch_id'] as num?)?.toInt() ?? 0,
      lastUpdatedStr: json['last_updated_str'] as String?,
    );
  }

  // 2. قراءة البيانات من SQLite (Map)
  factory ItemStockBatch.fromMap(Map<String, dynamic> map) {
    return ItemStockBatch(
      itemNo: map['item_no'] as String? ?? '',
      expiryDate: map['expiry_date'] as String? ?? '',
      batchNo: map['batch_no'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0.0,
      storeNo: map['store_no'] as int? ?? 0,
      // 👈 تم تصحيح الخطأ هنا: تغيير branch_id إلى branchId
      branchId: map['branch_id'] as int? ?? 0,
      lastUpdatedStr: map['last_updated_str'] as String?,
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'item_no': itemNo,
      'store_no': storeNo,
      'branch_id': branchId, // 👈 هنا نستخدم اسم العمود في قاعدة البيانات
      'batch_no': batchNo,
      'expiry_date': expiryDate,
      'quantity': quantity,
      'cost_price': costPrice,
      'last_updated_str': lastUpdatedStr,
    };
  }
}