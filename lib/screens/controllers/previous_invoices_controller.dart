import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';

class PreviousInvoicesController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final UserState userState = Get.find<UserState>();

  final RxList<Map<String, dynamic>> invoices = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  int _offset = 0;
  static const int pageSize = 50;
  final RxString currentInvoiceType = ''.obs;
  final RxString searchMode = ''.obs; // 'view' (للعرض) أو 'select' (للاختيار من شاشات أخرى)

  final DateFormat dateFormat = DateFormat('yyyy/MM/dd – HH:mm');

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    if (arguments != null && arguments is Map<String, dynamic>) {
      currentInvoiceType.value = arguments['invoiceType'] ?? '';
      searchMode.value = arguments['mode'] ?? 'view';
    } else {
      currentInvoiceType.value = '';
      print('⚠️ تحذير: فتح الشاشة بدون تحديد نوع الفاتورة');
    }
    loadInvoices(refresh: true);
  }

  Future<void> loadInvoices({bool refresh = true}) async {
    if (refresh) {
      isLoading.value = true;
      _offset = 0;
      hasMore.value = true;
      invoices.clear();
    } else {
      if (isLoadingMore.value || !hasMore.value) return;
      isLoadingMore.value = true;
    }

    try {
      final db = await _dbHelper.database;

      // بناء جملة الاستعلام (Query Builder)
      // نقوم بعمل JOIN لجلب أسماء الصناديق والمخازن والمستخدمين بدلاً من الأرقام فقط
      String sql = '''
        SELECT 
          s.*,
          u.user_name,
          st.name_store,
          b.box_name
        FROM sales s
        LEFT JOIN sun_users u ON s.user_id = u.user_no
        LEFT JOIN sun_store st ON s.store_no = st.no_store
        LEFT JOIN sun_boxes b ON s.box_no = b.box_no
        WHERE 1=1
      ''';

      List<dynamic> args = [];

      // 1. تصفية حسب نوع الفاتورة
      if (currentInvoiceType.value.isNotEmpty) {
        if (currentInvoiceType.value.contains(',')) {
          final types = currentInvoiceType.value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          final placeholders = List.filled(types.length, '?').join(', ');
          sql += ' AND s.invoice_type_char IN ($placeholders)';
          args.addAll(types);
        } else {
          sql += ' AND s.invoice_type_char = ?';
          args.add(currentInvoiceType.value);
        }
      }

      // 2. تصفية حسب الصلاحيات (إذا لم يكن أدمن، يرى فواتيره فقط)
      if (!userState.isAdmin) {
        sql += ' AND s.user_id = ?';
        args.add(userState.userNo);
      }

      // الترتيب: الأحدث أولاً مع ترقيم كسول (Pagination)
      sql += ' ORDER BY s.date DESC LIMIT ? OFFSET ?';
      args.add(pageSize);
      args.add(_offset);

      final List<Map<String, dynamic>> result = await db.rawQuery(sql, args);

      // تحويل النتيجة لقائمة قابلة للتعديل
      final List<Map<String, dynamic>> processedInvoices = result.map((row) {
        return Map<String, dynamic>.from(row);
      }).toList();

      if (processedInvoices.length < pageSize) {
        hasMore.value = false;
      }
      _offset += processedInvoices.length;

      if (refresh) {
        invoices.assignAll(processedInvoices);
      } else {
        invoices.addAll(processedInvoices);
      }

    } catch (e) {
      print('❌ خطأ في تحميل الفواتير المحلية: $e');
      showMessage('فشل تحميل السجل المحلي: $e', isError: true);
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!isLoading.value && !isLoadingMore.value && hasMore.value) {
      await loadInvoices(refresh: false);
    }
  }

  // دالة مساعدة لتحديث القائمة يدوياً (مثلاً بعد العودة من تفاصيل فاتورة)
  Future<void> refreshInvoices() async {
    await loadInvoices(refresh: true);
  }

  void showMessage(String message, {bool isError = true}) {
    if (Get.isSnackbarOpen) {
      Get.closeCurrentSnackbar();
    }
    final String title = isError ? 'خطأ' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }
}