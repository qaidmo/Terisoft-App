// lib/models/sun_account_currency.dart
class SunAccountCurrency {
  final String accountId; // الـ GUID القادم من الـ API
  final int currencyId;

  SunAccountCurrency({required this.accountId, required this.currencyId});

  factory SunAccountCurrency.fromJson(Map<String, dynamic> json) {
    return SunAccountCurrency(
      accountId: json['account_id'] as String,
      currencyId: json['currency_id'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'account_id': accountId,
    'currency_id': currencyId,
  };
}