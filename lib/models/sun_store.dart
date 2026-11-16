// lib/models/sun_store.dart

import 'sun_account_model.dart';
import 'sun_branch.dart';

class SunStore {
  final int noStore;
  final String nameStore;
  final int? branchId;
  final String? inventoryAccountId;
  final String? sourceId; // 👈 مضاف للمزامنة

  // حقول للعرض والطباعة (يتم تعبئتها من الكنترولر عند الحاجة)
  SunAccount? linkedAccount;
  SunBranch? linkedBranch;

  SunStore({
    required this.noStore,
    required this.nameStore,
    this.branchId,
    this.inventoryAccountId,
    this.sourceId,
    this.linkedAccount,
    this.linkedBranch,
  });

  // 1. استقبال البيانات من الـ API (JSON مسطح)
  factory SunStore.fromJson(Map<String, dynamic> json) {
    return SunStore(
      noStore: json['no_store'] as int? ?? 0,
      nameStore: json['name_store'] as String? ?? 'اسم غير محدد',
      branchId: json['branch_id'] as int?,
      inventoryAccountId: json['inventory_account_id'] as String?,
      sourceId: json['source_id']?.toString(),
    );
  }

  // 2. قراءة البيانات من SQLite (Map)
  factory SunStore.fromMap(Map<String, dynamic> map) {
    return SunStore(
      noStore: map['no_store'] as int,
      nameStore: map['name_store'] as String,
      branchId: map['branch_id'] as int?,
      inventoryAccountId: map['inventory_account_id'] as String?,
      sourceId: map['source_id'] as String?,
    );
  }

  // 3. تحويل الكائن إلى Map للحفظ في SQLite
  Map<String, dynamic> toMap() {
    return {
      'no_store': noStore,
      'name_store': nameStore,
      'branch_id': branchId,
      'inventory_account_id': inventoryAccountId,
      'source_id': sourceId,
    };
  }
}