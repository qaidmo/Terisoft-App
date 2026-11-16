// lib/models/sun_account.dart

import 'dart:convert';

class SunAccount {
  final String id;
  final String accountNo;
  final String accountName;
  final String currency;
  final String? phoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  SunAccount({
    required this.id,
    required this.accountNo,
    required this.accountName,
    required this.currency,
    this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  // دالة لتحويل خريطة (Map) من JSON إلى كائن SunAccount
  factory SunAccount.fromJson(Map<String, dynamic> json) {
    return SunAccount(
      id: json['id']?.toString() ?? '', // ✅ تم التعديل هنا
      accountNo: json['account_no']?.toString() ?? '', // ✅ تم التعديل هنا
      accountName: json['account_name']?.toString() ?? '', // ✅ تم التعديل هنا
      currency: json['currency']?.toString() ?? '', // ✅ تم التعديل هنا
      phoneNumber: json['phone_number']?.toString(), // ✅ هذا كان صحيحاً
      createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()), // ✅ تم التعديل هنا
      updatedAt: DateTime.parse(json['updated_at']?.toString() ?? DateTime.now().toIso8601String()), // ✅ تم التعديل هنا
    );
  }

  // دالة لتحويل كائن SunAccount إلى خريطة (Map) جاهزة للإرسال إلى JSON/Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_no': accountNo,
      'account_name': accountName,
      'currency': currency,
      'phone_number': phoneNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // دالة toString مفيدة لتصحيح الأخطاء (debugging)
  @override
  String toString() {
    return 'SunAccount(id: $id, accountNo: $accountNo, accountName: $accountName, currency: $currency, phoneNumber: $phoneNumber, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  // دالة copyWith لإنشاء نسخة من الكائن مع تغيير بعض القيم
  SunAccount copyWith({
    String? id,
    String? accountNo,
    String? accountName,
    String? currency,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SunAccount(
      id: id ?? this.id,
      accountNo: accountNo ?? this.accountNo,
      accountName: accountName ?? this.accountName,
      currency: currency ?? this.currency,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}