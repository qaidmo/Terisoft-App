// lib/models/sun_account_model.dart

class SunAccount {
  final String id;
  final DateTime? createdAt;
  final String accountNumber;
  final String name;
  final String? nameEn;
  final String? parentId;
  final int accountTypeId;
  final String nature;
  final bool isTransactional;
  final bool isActive;
  final int? classificationId;
  final int? defaultCurrencyId;
  final String? sourceId;

  List<SunAccount> children = [];

  SunAccount({
    required this.id,
    this.createdAt,
    required this.accountNumber,
    required this.name,
    this.nameEn,
    this.parentId,
    required this.accountTypeId,
    required this.nature,
    required this.isTransactional,
    required this.isActive,
    this.classificationId,
    this.defaultCurrencyId,
    this.sourceId,
  });

  // 1. استقبال البيانات من الـ API (تعديل ليكون مرناً)
  factory SunAccount.fromJson(Map<String, dynamic> json) {
    return SunAccount(
      id: json['id'].toString(), // تحويل لـ String للأمان
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      accountNumber: json['account_number']?.toString() ?? 'N/A',
      name: json['name']?.toString() ?? 'اسم غير معروف',
      nameEn: json['name_en']?.toString(),
      parentId: json['parent_id']?.toString(),
      accountTypeId: int.tryParse(json['account_type_id']?.toString() ?? '0') ?? 0,
      nature: json['nature']?.toString() ?? 'مدين',

      // 👇👇 التعديل هنا: قبول true أو 1 أو "1" 👇👇
      isTransactional: json['is_transactional'] == true || json['is_transactional'] == 1 || json['is_transactional'] == '1',
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',

      classificationId: int.tryParse(json['classification_id']?.toString() ?? ''),
      defaultCurrencyId: int.tryParse(json['default_currency_id']?.toString() ?? ''),
      sourceId: json['source_id']?.toString(),
    );
  }

  // 2. قراءة البيانات من SQLite (تعديل ليكون مرناً)
  factory SunAccount.fromMap(Map<String, dynamic> map) {
    return SunAccount(
      id: map['id'].toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
      accountNumber: map['account_number']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      nameEn: map['name_en']?.toString(),
      parentId: map['parent_id']?.toString(),
      accountTypeId: map['account_type_id'] is int ? map['account_type_id'] : int.tryParse(map['account_type_id']?.toString() ?? '0') ?? 0,
      nature: map['nature']?.toString() ?? '',

      // 👇👇 التعديل الجوهري هنا: قبول كل احتمالات SQLite 👇👇
      isTransactional: map['is_transactional'] == 1 || map['is_transactional'] == '1' || map['is_transactional'] == true,
      isActive: map['is_active'] == 1 || map['is_active'] == '1' || map['is_active'] == true,

      classificationId: int.tryParse(map['classification_id']?.toString() ?? ''),
      defaultCurrencyId: int.tryParse(map['default_currency_id']?.toString() ?? ''),
      sourceId: map['source_id']?.toString(),
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'created_at': createdAt?.toIso8601String(),
      'account_number': accountNumber,
      'name': name,
      'name_en': nameEn,
      'parent_id': parentId,
      'account_type_id': accountTypeId,
      'nature': nature,
      'is_transactional': isTransactional ? 1 : 0, // الحفظ دائماً كرقم 1 أو 0
      'is_active': isActive ? 1 : 0,
      'classification_id': classificationId,
      'default_currency_id': defaultCurrencyId,
      'source_id': sourceId,
    };
  }
}