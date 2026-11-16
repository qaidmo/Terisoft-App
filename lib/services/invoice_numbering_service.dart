import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/user_state.dart';

/// Single branch-aware invoice-numbering path (D3, D5).
///
/// The prefix is *computed* from (UID, active branch, department) and never read
/// from the stored `user_group` identity column. The sequence counter itself is
/// per-(user, invoice type) and shared across branches: the prefix differs per
/// branch so numbers stay globally unique, while trial counters keep per-user
/// semantics and cannot be reset by branch-hopping.
class InvoiceNumberingService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Prefix format `{UID==0 ? 'AD' : 'A'}{UID}{BranchId}{SectionId}`
  /// (mirrors `PeopleController.GetUsers` `user_group`).
  String buildPrefix(int userNo, int branchId, int department) {
    final uid = userNo == 0 ? 'AD' : 'A';
    return '$uid$userNo$branchId$department';
  }

  /// Authoritative allocation — must run inside the caller's transaction so the
  /// sequence bump is atomic with the invoice insert.
  Future<String> allocateNextNumber(Transaction txn, int userNo, String typeChar) async {
    final userState = Get.find<UserState>();
    final prefix = buildPrefix(
      userNo,
      userState.safeUserBranch,
      userState.safeUserDepartment,
    );

    final seqRes = await txn.query(
      'user_invoice_sequences',
      columns: ['last_sequence'],
      where: 'user_no = ? AND invoice_type_char = ?',
      whereArgs: [userNo, typeChar],
    );

    int nextSequence;
    if (seqRes.isNotEmpty) {
      final int currentSeq = seqRes.first['last_sequence'] as int;
      nextSequence = currentSeq + 1;
      await txn.update(
        'user_invoice_sequences',
        {'last_sequence': nextSequence},
        where: 'user_no = ? AND invoice_type_char = ?',
        whereArgs: [userNo, typeChar],
      );
    } else {
      nextSequence = 1;
      await txn.insert('user_invoice_sequences', {
        'user_no': userNo,
        'invoice_type_char': typeChar,
        'last_sequence': nextSequence,
      });
    }

    return '$prefix${nextSequence.toString().padLeft(7, '0')}';
  }

  /// Read-only estimate for the header preview controllers (R6: a race may make
  /// the real number differ; allocation happens inside the save transaction).
  Future<String> previewNextNumber(int userNo, String typeChar) async {
    final userState = Get.find<UserState>();
    final prefix = buildPrefix(
      userNo,
      userState.safeUserBranch,
      userState.safeUserDepartment,
    );

    final seqRes = await _dbHelper.query(
      'user_invoice_sequences',
      columns: ['last_sequence'],
      where: 'user_no = ? AND invoice_type_char = ?',
      whereArgs: [userNo, typeChar],
    );

    final int lastSequence = seqRes.isNotEmpty ? seqRes.first['last_sequence'] as int : 0;
    final int nextSequence = lastSequence + 1;
    return '$prefix${nextSequence.toString().padLeft(7, '0')}';
  }
}
