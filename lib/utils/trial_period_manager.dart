import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../core/database_helper.dart'; // ✅ الاستيراد الصحيح
import 'package:untitled4/screens/controllers/home_controller.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';

enum TrialSaveCheckResult {
  allow,
  blocked,
  userCancelled,
}

class TrialPeriodManager {
  /// الحد الأقصى للحركات التجريبية لكل نوع فاتورة لكل مستخدم
  static const int _trialLimit = 20;

  static Future<TrialSaveCheckResult> checkOnSave({
    required String invoiceTypeChar,
  }) async {
    final HomeController homeController = Get.find<HomeController>();
    if (homeController.isLicensed.value) {
      return TrialSaveCheckResult.allow;
    }

    final UserState userState = Get.find<UserState>();
    final int? userNo = userState.userNo;
    if (userNo == null) {
      AppSnackbar.showCustomSnackbar('خطأ', 'لم يتم العثور على بيانات المستخدم!', isError: true);
      return TrialSaveCheckResult.blocked;
    }

    // ✅ التعديل: القراءة من SQLite بدلاً من Supabase
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> result = await db.query(
      'user_invoice_sequences',
      columns: ['last_sequence'],
      where: 'user_no = ? AND invoice_type_char = ?',
      whereArgs: [userNo, invoiceTypeChar],
      limit: 1,
    );

    final int currentCount = result.isNotEmpty ? (result.first['last_sequence'] as int) : 0;

    if (currentCount >= _trialLimit) {
      AppSnackbar.showCustomSnackbar(
        'الحد الأقصى',
        'لقد استنفدت الحركات التجريبية لهذه الشاشة. يرجى تفعيل التطبيق.',
        isError: true,
      );
      return TrialSaveCheckResult.blocked;
    }

    if (currentCount == _trialLimit - 1) {
      final bool? wantsToContinue = await _showCustomTrialDialog(
        title: 'تنبيه أخير!',
        content: 'هذه هي آخر حركة تجريبية متبقية لك في هذه الشاشة.\nهل تريد المتابعة في الحفظ؟',
        iconData: Icons.warning_amber_rounded,
        iconColor: Colors.amber.shade700,
        actions: [
          OutlinedButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
            child: const Text('نعم، متابعة'),
          ),
        ],
      );
      if (wantsToContinue != true) {
        return TrialSaveCheckResult.userCancelled;
      }
    }

    return TrialSaveCheckResult.allow;
  }

  static Future<void> handlePostSave({
    required String invoiceTypeChar,
    required String screenTitle,
  }) async {
    final HomeController homeController = Get.find<HomeController>();
    if (homeController.isLicensed.value) return;

    final UserState userState = Get.find<UserState>();
    final int? userNo = userState.userNo;
    if (userNo == null) return;

    // ✅ التعديل: القراءة من SQLite للتحقق من العداد الجديد
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> result = await db.query(
      'user_invoice_sequences',
      columns: ['last_sequence'],
      where: 'user_no = ? AND invoice_type_char = ?',
      whereArgs: [userNo, invoiceTypeChar],
      limit: 1,
    );

    final int newCount = result.isNotEmpty ? (result.first['last_sequence'] as int) : 0;

    if (newCount >= _trialLimit) {
      await _showCustomTrialDialog(
        title: 'انتهت الفترة التجريبية',
        content: 'لقد استنفدت جميع الحركات التجريبية لشاشة "$screenTitle".\nسيتم الآن إغلاق الشاشة يرجي تفعيل الترخيص.',
        iconData: Icons.block,
        iconColor: Colors.red.shade700,
        isDismissible: false,
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('موافق'),
          ),
        ],
      );
      Get.back();
    }
  }

  static Future<bool> checkOnEntry({
    required String invoiceTypeChar,
  }) async {
    final HomeController homeController = Get.find<HomeController>();
    if (homeController.isLicensed.value) return true;

    final UserState userState = Get.find<UserState>();
    final int? userNo = userState.userNo;
    if (userNo == null) return false;

    // ✅ التعديل: القراءة من SQLite
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> result = await db.query(
      'user_invoice_sequences',
      columns: ['last_sequence'],
      where: 'user_no = ? AND invoice_type_char = ?',
      whereArgs: [userNo, invoiceTypeChar],
      limit: 1,
    );

    final int currentCount = result.isNotEmpty ? (result.first['last_sequence'] as int) : 0;

    return currentCount < _trialLimit;
  }

  static Future<T?> _showCustomTrialDialog<T>({
    required String title,
    required String content,
    required IconData iconData,
    required Color iconColor,
    required List<Widget> actions,
    bool isDismissible = true,
  }) {
    return Get.dialog<T>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: iconColor.withOpacity(0.1),
                child: Icon(iconData, color: iconColor, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: actions,
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: isDismissible,
    );
  }
}