import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyLastSyncDate = 'last_sync_date';

  // دالة لحفظ تاريخ آخر مزامنة ناجحة
  Future<void> saveLastSyncDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSyncDate, date);
  }

  // دالة لاسترجاع تاريخ آخر مزامنة
  // إذا لم توجد (أول مرة تشغيل)، تعيد null
  Future<String?> getLastSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastSyncDate);
  }

  // دالة لمسح التاريخ (نحتاجها إذا أردنا إجبار التطبيق على مزامنة كاملة من الصفر)
  Future<void> clearSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastSyncDate);
  }
}