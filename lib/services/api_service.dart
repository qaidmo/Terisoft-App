import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'server_connectivity.dart';

class ApiService {
  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final String? serverAddress = prefs.getString('server_address');

    if (serverAddress == null || serverAddress.isEmpty) {
      throw Exception('عنوان السيرفر غير مضبوط. يرجى الدخول للإعدادات.');
    }

    return 'http://$serverAddress';
  }

  Future<dynamic> get(String endpoint, {Duration timeout = const Duration(seconds: 15)}) async {
    try {
      final reachable = await ServerConnectivity.isServerReachable();
      if (!reachable) {
        throw Exception('تعذر الوصول للسيرفر. تأكد من أن السيرفر يعمل والشبكة متصلة.');
      }

      final String baseUrl = await _getBaseUrl();
      final Uri url = Uri.parse('$baseUrl/$endpoint');

      log('🚀 جاري طلب البيانات من: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(timeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('انتهى وقت الاتصال بالسيرفر. السيرفر مشغول أو غير متاح.');
    } on SocketException catch (e) {
      log('❌ خطأ اتصال في ApiService (SocketException): $e');
      throw Exception('تعذر الاتصال بالسيرفر. يرجى التأكد من تشغيل الخادم.');
    } catch (e) {
      log('❌ خطأ في ApiService عند طلب ($endpoint): $e');
      rethrow;
    }
  }

  // 👇 هذه هي الدالة التي أضفناها للإرسال
  Future<dynamic> post(String endpoint, Map<String, dynamic> data, {Duration timeout = const Duration(seconds: 45)}) async {
    try {
      final reachable = await ServerConnectivity.isServerReachable();
      if (!reachable) {
        throw Exception('تعذر الوصول للسيرفر. تأكد من أن السيرفر يعمل والشبكة متصلة.');
      }

      final String baseUrl = await _getBaseUrl();
      final Uri url = Uri.parse('$baseUrl/$endpoint');

      log('🚀 جاري إرسال البيانات (POST) إلى: $url');
      log('📦 البيانات المرسلة: ${jsonEncode(data)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data), // تحويل البيانات إلى JSON
      ).timeout(timeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception('انتهى وقت الاتصال بالسيرفر. السيرفر مشغول أو غير متاح.');
    } on SocketException catch (e) {
      log('❌ خطأ اتصال في ApiService (SocketException): $e');
      throw Exception('تعذر الاتصال بالسيرفر. يرجى التأكد من تشغيل الخادم.');
    } catch (e) {
      log('❌ خطأ في ApiService عند إرسال ($endpoint): $e');
      rethrow;
    }
  }

  dynamic _handleResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201: // إضافة 201 لأن بعض السيرفرات تعيدها عند الإنشاء
        return jsonDecode(response.body);
      case 400:
      // محاولة قراءة رسالة الخطأ من السيرفر إن وجدت
        String msg = 'طلب خاطئ من التطبيق (400)';
        try {
          final body = jsonDecode(response.body);
          if(body is String) {
            msg = body;
          } else if (body['message'] != null) msg = body['message'];
          else if (body['error'] != null) msg = body['error'];
        } catch(_) {}
        throw Exception(msg);
      case 401:
        throw Exception('غير مصرح لك بالوصول (401)');
      case 404:
        throw Exception('المورد المطلوب غير موجود على السيرفر (404)');
      case 500:
        log('Internal Server Error 500: ${response.body}');
        throw Exception('حدث خطأ داخلي في السيرفر (500). يرجى المحاولة لاحقاً.');
      default:
        throw Exception('خطأ غير متوقع: ${response.statusCode}');
    }
  }
}