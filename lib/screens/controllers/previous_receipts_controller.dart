import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';

class PreviousReceiptsController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final UserState userState = Get.find<UserState>();

  // قائمة السندات (بيانات مسطحة وجاهزة للعرض)
  final RxList<Map<String, dynamic>> receipts = <Map<String, dynamic>>[].obs;

  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  int _offset = 0;
  static const int pageSize = 50;
  final RxString currentReceiptType = ''.obs; // 'ق' = قبض، 'ص' = صرف

  final DateFormat dateFormat = DateFormat('yyyy/MM/dd – HH:mm');

  @override
  void onInit() {
    super.onInit();

    // استقبال نوع السند من الشاشة السابقة
    final arguments = Get.arguments;
    if (arguments != null && arguments is Map<String, dynamic>) {
      currentReceiptType.value = arguments['invoiceType'] ?? 'ق';
    } else {
      currentReceiptType.value = 'ق';
      print('⚠️ تحذير: فتح شاشة السندات السابقة بدون تحديد النوع.');
    }

    loadReceipts(refresh: true);
  }

  Future<void> loadReceipts({bool refresh = true}) async {
    if (refresh) {
      isLoading.value = true;
      _offset = 0;
      hasMore.value = true;
      receipts.clear();
    } else {
      if (isLoadingMore.value || !hasMore.value) return;
      isLoadingMore.value = true;
    }

    try {
      final db = await _dbHelper.database;

      // 1. بناء جملة الاستعلام (SQL Query Builder)
      // نستخدم LEFT JOIN لجلب اسم المستخدم مباشرة مع بيانات السند
      String sql = '''
        SELECT 
          r.*,
          u.user_name
        FROM sun_receipt r
        LEFT JOIN sun_users u ON r.user_id = u.user_no
        WHERE 1=1
      ''';

      List<dynamic> args = [];

      // 2. تصفية حسب نوع السند (قبض 'ق' / صرف 'ص')
      if (currentReceiptType.value.isNotEmpty) {
        sql += ' AND r.invoice_type_char = ?';
        args.add(currentReceiptType.value);
      }

      // 3. تصفية حسب الصلاحيات (إذا لم يكن أدمن، يرى سنداته فقط)
      if (!userState.isAdmin) {
        sql += ' AND r.user_id = ?';
        args.add(userState.userNo);
      }

      // 4. الترتيب: الأحدث أولاً مع ترقيم كسول (Pagination)
      sql += ' ORDER BY r.date DESC LIMIT ? OFFSET ?';
      args.add(pageSize);
      args.add(_offset);

      // تنفيذ الاستعلام
      final List<Map<String, dynamic>> result = await db.rawQuery(sql, args);

      final List<Map<String, dynamic>> processedReceipts = result.map((row) {
        return Map<String, dynamic>.from(row);
      }).toList();

      if (processedReceipts.length < pageSize) {
        hasMore.value = false;
      }
      _offset += processedReceipts.length;

      if (refresh) {
        receipts.assignAll(processedReceipts);
      } else {
        receipts.addAll(processedReceipts);
      }

    } catch (e) {
      print('❌ خطأ في تحميل السندات المحلية: $e');
      showMessage('فشل تحميل سجل السندات: $e', isError: true);
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!isLoading.value && !isLoadingMore.value && hasMore.value) {
      await loadReceipts(refresh: false);
    }
  }

  // دالة لتحديث القائمة يدوياً (عند السحب للتحديث أو العودة من التعديل)
  Future<void> refreshReceipts() async {
    await loadReceipts(refresh: true);
  }

  void showMessage(String message, {bool isError = true}) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }
}