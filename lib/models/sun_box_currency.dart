// lib/models/sun_box_currency.dart

class SunBoxCurrency {
  final int boxNo;
  final int currencyNo;

  SunBoxCurrency({
    required this.boxNo,
    required this.currencyNo,
  });

  factory SunBoxCurrency.fromJson(Map<String, dynamic> json) {
    return SunBoxCurrency(
      boxNo: json['box_no'] as int,
      currencyNo: json['currency_no'] as int,
    );
  }

  factory SunBoxCurrency.fromMap(Map<String, dynamic> map) {
    return SunBoxCurrency(
      boxNo: map['box_no'] as int,
      currencyNo: map['currency_no'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'box_no': boxNo,
      'currency_no': currencyNo,
    };
  }
}