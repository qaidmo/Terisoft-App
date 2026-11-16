import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/database_helper.dart';

class TemplateHelper {
  /// دالة تقوم بجلب الإعدادات، وفي حال عدم وجودها تعيد إعدادات افتراضية معتمدة على المزامنة
  static Future<Map<String, dynamic>> getSettings(String screenIdentifier) async {
    final db = await DatabaseHelper.instance.database;

    // 1. محاولة البحث عن القالب الخاص بالشاشة
    final List<Map<String, dynamic>> result = await db.query(
      'invoice_templates',
      where: 'screen_name_identifier = ?',
      whereArgs: [screenIdentifier],
    );

    if (result.isNotEmpty) {
      try {
        return jsonDecode(result.first['settings_json']);
      } catch (_) {}
    }

    // 2. إذا لم نجد القالب، نبحث عن "اللوجو المزامَن" في ملفات الهاتف
    String logoPath = '';
    bool showLogo = false;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final File syncedFile = File('${directory.path}/company_synced_logo.png');
      if (await syncedFile.exists()) {
        logoPath = syncedFile.path;
        showLogo = true;
      }
    } catch (_) {}

    // 3. محاولة جلب اسم الشركة والعنوان من أي قالب آخر موجود (كحل احتياطي)
    String companyName = 'اسم الشركة';
    String address = '';

    final List<Map<String, dynamic>> anyTemplate = await db.query('invoice_templates', limit: 1);
    if (anyTemplate.isNotEmpty) {
      try {
        final map = jsonDecode(anyTemplate.first['settings_json']);
        companyName = map['header_company_name'] ?? map['company_name'] ?? '';
        address = map['footer_address_details'] ?? map['address'] ?? '';
      } catch (_) {}
    }

    // 4. إرجاع إعدادات افتراضية جاهزة للطباعة
    return {
      'header_company_name': companyName,
      'footer_address_details': address,
      'logo_url': logoPath,
      'show_logo': showLogo,
      'footer_thanks_message': '',
      'footer_contact_info': '',
    };
  }
}