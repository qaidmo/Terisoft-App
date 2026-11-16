// lib/models/sun_box.dart

import 'sun_account_model.dart'; // 👈 تأكد من استيراد موديل الحساب

class SunBox {
  final int? boxNo;
  final String boxName;
  final String? accountId;
  final String? controlAccountId;
  final String? sourceId;

  // 👈 تعديل: أعدنا الحقل ولكن كمتغير غير نهائي (Non-final) ليقبل التعبئة لاحقاً
  SunAccount? linkedAccount;
  List<int> currencyNos;

  SunBox({
    this.boxNo,
    required this.boxName,
    this.accountId,
    this.controlAccountId,
    this.sourceId,
    this.linkedAccount, // متاح في الـ Constructor
    this.currencyNos = const [],
  });

  // 1. استقبال البيانات من الـ API
  factory SunBox.fromJson(Map<String, dynamic> json) {
    return SunBox(
      boxNo: json['box_no'] as int?,
      boxName: json['box_name'] as String? ?? 'صندوق غير محدد',
      accountId: json['account_id'] as String?,
      controlAccountId: json['control_account_id'] as String?,
      sourceId: json['source_id']?.toString(),
    );
  }

  // 2. قراءة البيانات من SQLite
  factory SunBox.fromMap(Map<String, dynamic> map) {
    return SunBox(
      boxNo: map['box_no'] as int?,
      boxName: map['box_name'] as String,
      accountId: map['account_id'] as String?,
      controlAccountId: map['control_account_id'] as String?,
      sourceId: map['source_id'] as String?,
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'box_no': boxNo,
      'box_name': boxName,
      'account_id': accountId,
      'control_account_id': controlAccountId,
      'source_id': sourceId,
    };
  }
}