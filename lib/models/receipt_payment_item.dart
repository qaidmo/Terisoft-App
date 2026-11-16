class ReceiptPaymentItem {
  final int? id;
  final DateTime createdAt;
  final int receiptPaymentId;
  final String accountNo;
  final String accountName;
  final double amount;
  final String itemCurrency;
  final int? itemCurrencyId;
  final double exchangeRate;
  final double equivalentAmount;
  final String? controlAccountId;

  ReceiptPaymentItem({
    this.id,
    required this.createdAt,
    required this.receiptPaymentId,
    required this.accountNo,
    required this.accountName,
    required this.amount,
    required this.itemCurrency,
    this.itemCurrencyId,
    required this.exchangeRate,
    required this.equivalentAmount,
    this.controlAccountId,
  });

  factory ReceiptPaymentItem.fromJson(Map<String, dynamic> json) {
    return ReceiptPaymentItem(
      id: json['id'] as int?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      receiptPaymentId: (json['receipt_payment_id'] as num).toInt(),
      accountNo: json['account_no']?.toString() ?? '',
      accountName: json['account_name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      itemCurrency: json['item_currency']?.toString() ?? '',
      itemCurrencyId: json['item_currency_id'] != null ? int.tryParse(json['item_currency_id'].toString()) : 1,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      equivalentAmount: (json['equivalent_amount'] as num?)?.toDouble() ?? 0.0,
      controlAccountId: json['control_account_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'receipt_payment_id': receiptPaymentId,
      'account_no': accountNo,
      'account_name': accountName,
      'amount': amount,
      'item_currency': itemCurrency,
      'exchange_rate': exchangeRate,
      'equivalent_amount': equivalentAmount,
      'control_account_id': controlAccountId,
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': id ?? 0,
      'receiptPaymentId': receiptPaymentId,
      'accountNo': accountNo,
      'accountName': accountName,
      'amount': amount,
      'itemCurrency': itemCurrency,
      'itemCurrencyId': itemCurrencyId ?? 1,
      'exchangeRate': exchangeRate,
      'equivalentAmount': equivalentAmount,
      'controlAccountId': controlAccountId,
    };
  }
}