import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';

class InventoryHistoryController extends GetxController {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final UserState userState = Get.find<UserState>();

  final RxList<Map<String, dynamic>> inventoryRecords = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  final DateFormat dateFormat = DateFormat('yyyy/MM/dd – HH:mm');

  @override
  void onInit() {
    super.onInit();
    loadInventoryRecords();
  }

  Future<void> loadInventoryRecords() async {
    isLoading.value = true;
    inventoryRecords.clear();

    try {
      final db = await _dbHelper.database;

      // 🔥 التصحيح هنا: تغيير invoice_id إلى sale_id
      String sql = '''
        SELECT 
          s.*,
          u.user_name,
          st.name_store as store_name,
          SUM(COALESCE(si.deficit_value, 0)) as total_deficit,
          SUM(COALESCE(si.surplus_value, 0)) as total_surplus
        FROM sales s
        LEFT JOIN sun_users u ON s.user_id = u.user_no
        LEFT JOIN sun_store st ON s.store_no = st.no_store
        -- 👇👇 تم التعديل هنا 👇👇
        LEFT JOIN sale_items si ON s.id = si.sale_id 
        WHERE s.invoice_type_char = 'م ض'
      ''';

      List<dynamic> args = [];

      // تطبيق الصلاحيات
      if (!userState.isAdmin) {
        sql += ' AND s.user_id = ?';
        args.add(userState.userNo);
      }

      // التجميع والترتيب
      sql += ' GROUP BY s.id';
      sql += ' ORDER BY s.date DESC';

      final List<Map<String, dynamic>> result = await db.rawQuery(sql, args);

      final List<Map<String, dynamic>> processedData = result.map((row) {
        return Map<String, dynamic>.from(row);
      }).toList();

      inventoryRecords.assignAll(processedData);

    } catch (e) {
      print('❌ خطأ في تحميل سجل الجرد المحلي: $e');
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تحميل سجل المحاضر: $e', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshRecords() async {
    await loadInventoryRecords();
  }
}