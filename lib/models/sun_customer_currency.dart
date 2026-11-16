// lib/models/sun_customer_currency.dart

class SunCustomerCurrency {
  final int customerNo;
  final int currencyNo;

  SunCustomerCurrency({
    required this.customerNo,
    required this.currencyNo,
  });

  factory SunCustomerCurrency.fromJson(Map<String, dynamic> json) {
    return SunCustomerCurrency(
      customerNo: json['customer_no'] as int,
      currencyNo: json['currency_no'] as int,
    );
  }

  factory SunCustomerCurrency.fromMap(Map<String, dynamic> map) {
    return SunCustomerCurrency(
      customerNo: map['customer_no'] as int,
      currencyNo: map['currency_no'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customer_no': customerNo,
      'currency_no': currencyNo,
    };
  }
}