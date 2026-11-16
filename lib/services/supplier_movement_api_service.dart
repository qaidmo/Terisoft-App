// lib/services/supplier_movement_api_service.dart
// خدمة API مستقلة تماماً لتقرير حركة الموردين
// تتصل بـ POST /api/Reports/supplier-activity

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/supplier_movement_models.dart';
import 'offline_fallback_exception.dart';
import 'server_connectivity.dart';

class SupplierMovementApiService {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? baseUrl = prefs.getString('server_address');

    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('يرجى ضبط عنوان السيرفر في شاشة الإعدادات أولاً.');
    }

    baseUrl = baseUrl.trim();
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'http://$baseUrl';
    }
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  void _handleError(http.Response response) {
    try {
      if (response.body.isNotEmpty) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        String serverMessage = errorData['message'] ??
            errorData['error'] ??
            errorData['title'] ??
            'خطأ غير محدد من السيرفر';
        if (errorData['details'] != null) {
          serverMessage += '\n\nالتفاصيل التقنية:\n${errorData['details']}';
        }
        throw Exception(serverMessage);
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) rethrow;
    }
    switch (response.statusCode) {
      case 400:
        throw Exception('طلب غير صحيح (400). تأكد من صحة البيانات المدخلة.');
      case 401:
        throw Exception('غير مصرح (401). يرجى تسجيل الدخول مجدداً.');
      case 404:
        throw Exception('الخدمة غير موجودة (404). تأكد من رابط السيرفر.');
      case 500:
        throw Exception('خطأ داخلي في السيرفر (500).');
      default:
        throw Exception('حدث خطأ غير متوقع: رمز الحالة ${response.statusCode}');
    }
  }

  // ---------------------------------------------------------------------------
  // Main fetch method (original — no cache)
  // ---------------------------------------------------------------------------
  Future<SupplierMovementResponse> fetchSupplierMovement(
      SupplierMovementRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/supplier-activity');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return SupplierMovementResponse.fromJson(
            decoded as Map<String, dynamic>);
      } else {
        _handleError(response);
        throw Exception('Unknown error');
      }
    } on OfflineFallbackException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } on Exception {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // WithCache variant — returns (Model, rawJsonString) for offline support
  // ---------------------------------------------------------------------------
  Future<(SupplierMovementResponse?, String)> fetchSupplierMovementWithCache(
      SupplierMovementRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/supplier-activity');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final rawBody = utf8.decode(response.bodyBytes);
        return (null, rawBody);
      } else {
        _handleError(response);
        throw Exception('Unreachable');
      }
    } on TimeoutException {
      throw OfflineFallbackException('CONNECTION_LOST');
    } on SocketException {
      throw OfflineFallbackException('CONNECTION_LOST');
    } catch (e) {
      if (e is OfflineFallbackException) rethrow;
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }
}
