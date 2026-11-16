// lib/models/full_receipt.dart

import 'receipt_payment_item.dart';
import 'sun_receipt.dart';

class FullReceipt {
  final SunReceipt receipt;
  final List<ReceiptPaymentItem> items;

  FullReceipt({
    required this.receipt,
    required this.items,
  });

  factory FullReceipt.fromJson(Map<String, dynamic> json) {
    return FullReceipt(
      receipt: SunReceipt.fromJson(json),
      items: (json['receipt_payment_items'] as List<dynamic>? ?? [])
          .map((itemJson) => ReceiptPaymentItem.fromJson(itemJson))
          .toList(),
    );
  }
}