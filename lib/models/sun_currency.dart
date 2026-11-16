// lib/models/sun_currency.dart

class SunCurrency {
  final int currencyNo;
  final String currencyName;
  final String currencyFkah;
  final String currencySymbol;
  final double currencyRate;
  final double currencyHighest;
  final double currencyLowest;
  final String? sourceId; // 👈 الإضافة الضرورية للمزامنة

  SunCurrency({
    required this.currencyNo,
    required this.currencyName,
    this.currencyFkah = '',
    this.currencySymbol = '',
    this.currencyRate = 0.0,
    this.currencyHighest = 0.0,
    this.currencyLowest = 0.0,
    this.sourceId,
  });

  // التحويل من JSON (قادم من الـ API)
  factory SunCurrency.fromJson(Map<String, dynamic> json) {
    return SunCurrency(
      currencyNo: json['currency_no'] as int? ?? 0,
      currencyName: json['currency_name'] as String? ?? 'N/A',
      currencyFkah: json['currency_fkah'] as String? ?? '',
      currencySymbol: json['currency_symbol'] as String? ?? '',
      currencyRate: (json['currency_rate'] as num?)?.toDouble() ?? 0.0,
      currencyHighest: (json['currency_highest'] as num?)?.toDouble() ?? 0.0,
      currencyLowest: (json['currency_lowest'] as num?)?.toDouble() ?? 0.0,
      sourceId: json['source_id']?.toString(), // 👈 استقبال الـ source_id
    );
  }

  // التحويل من Map (قادم من قاعدة بيانات SQLite المحلية)
  factory SunCurrency.fromMap(Map<String, dynamic> map) {
    return SunCurrency(
      currencyNo: map['currency_no'] as int,
      currencyName: map['currency_name'] as String,
      currencyFkah: map['currency_fkah'] as String,
      currencySymbol: map['currency_symbol'] as String,
      currencyRate: map['currency_rate'] as double,
      currencyHighest: map['currency_highest'] as double,
      currencyLowest: map['currency_lowest'] as double,
      sourceId: map['source_id'] as String?,
    );
  }

  // التحويل إلى Map (للحفظ في SQLite)
  Map<String, dynamic> toMap() {
    return {
      'currency_no': currencyNo,
      'currency_name': currencyName,
      'currency_fkah': currencyFkah,
      'currency_symbol': currencySymbol,
      'currency_rate': currencyRate,
      'currency_highest': currencyHighest,
      'currency_lowest': currencyLowest,
      'source_id': sourceId, // 👈 حفظ الـ source_id
    };
  }

  // Constructor فارغ للحالات الاستثنائية
  SunCurrency.empty()
      : currencyNo = -1,
        currencyName = 'عملة غير موجودة',
        currencySymbol = '---',
        currencyFkah = '',
        currencyRate = 0.0,
        currencyHighest = 0.0,
        currencyLowest = 0.0,
        sourceId = null;
}