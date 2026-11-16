import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- 1. استيراد الحزمة

class SupabaseManager extends GetxService {
  static SupabaseClient? _client;

  Future<SupabaseManager> init() async {
    // 2. الحصول على نسخة من SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // 3. قراءة بيانات الاتصال المحفوظة
    final supabaseUrl = prefs.getString('company_supabase_url');
    final supabaseKey = prefs.getString('company_supabase_key');

    if (supabaseUrl == null || supabaseKey == null) {
      // هذا الشرط يجب ألا يحدث أبدًا في التدفق الجديد، لكنه جيد كإجراء وقائي
      throw Exception('Company credentials are not saved locally!');
    }

    // 4. تهيئة Supabase باستخدام البيانات المحفوظة
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
    _client = Supabase.instance.client;
    return this;
  }

  static SupabaseClient get client {
    if (_client == null) throw Exception('Supabase is not initialized');
    return _client!;
  }
}