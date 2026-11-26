import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account_statement_models.dart';
import '../models/customer_activity_models.dart';
import '../models/transaction_history_models.dart';
import '../models/cost_center_report_models.dart';
import '../models/sales_movement_models.dart';
import '../models/account_balances_models.dart';
import '../models/cost_center_profit_margin_models.dart';
import 'offline_fallback_exception.dart';
import 'server_connectivity.dart';

class ReportsApiService {

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
          serverMessage += "\n\nالتفاصيل التقنية:\n${errorData['details']}";
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
  // 1. Account Statement (Legacy Native Returns Model)
  // ---------------------------------------------------------------------------
  Future<AccountStatementResponse> fetchAccountStatement(AccountStatementRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/account-statement');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30)); 

      if (response.statusCode == 200) {
        late final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return AccountStatementResponse.fromJson(jsonResponse);
      } else {
        _handleError(response);
        throw Exception('Unreachable'); 
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال. السيرفر لا يستجيب.');
    } on SocketException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } on OfflineFallbackException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  // ---------------------------------------------------------------------------
  // 1. Account Statement (Legacy Native Returns Model)
  // ---------------------------------------------------------------------------
  Future<CostCenterReportResponse> fetchCostCenterTransactions(CostCenterReportRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/cost-center');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30)); 

      if (response.statusCode == 200) {
        late final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return CostCenterReportResponse.fromJson(jsonResponse);
      } else {
        _handleError(response);
        throw Exception('Unreachable'); 
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال. السيرفر لا يستجيب.');
    } on SocketException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } on OfflineFallbackException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  // ---------------------------------------------------------------------------
  // 1b. Cost Center (With Cache / Offline Support)
  // ---------------------------------------------------------------------------
  Future<(CostCenterReportResponse?, String)> fetchCostCenterTransactionsWithCache(
      CostCenterReportRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/cost-center');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return (null, response.body);
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

  // ---------------------------------------------------------------------------
  // 1. Account Statement (Direct 200 OK Online + Instant Offline Fallback)
  // ---------------------------------------------------------------------------
  Future<(AccountStatementResponse?, String)> fetchAccountStatementWithCache(AccountStatementRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/account-statement');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Return raw JSON string directly — the controller will parse + process
        // in a single compute() isolate, avoiding double-isolate overhead.
        return (null, response.body);
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

  // ---------------------------------------------------------------------------
  // 2. Transaction History (Legacy)
  // ---------------------------------------------------------------------------
  Future<TransactionHistoryResponse> fetchTransactionHistory(TransactionHistoryRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/transaction-history');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        late final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return TransactionHistoryResponse.fromJson(jsonResponse);
      } else {
        _handleError(response); 
        throw Exception('Unreachable');
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال. السيرفر لا يستجيب.');
    } on SocketException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } on OfflineFallbackException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  // ---------------------------------------------------------------------------
  // 2. Transaction History (With Cache)
  // ---------------------------------------------------------------------------
  Future<(TransactionHistoryResponse?, String)> fetchTransactionHistoryWithCache(TransactionHistoryRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/transaction-history');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // فك التشفير يتم داخل Isolate واحد في الـ Controller لتفادي تجميد الواجهة
        return (null, response.body);
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

  // ---------------------------------------------------------------------------
  // 3. Customer Activity (Legacy)
  // ---------------------------------------------------------------------------
  Future<CustomerActivityResponse> fetchCustomerActivity(CustomerActivityRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/customer-activity');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 45)); 

      if (response.statusCode == 200) {
        late final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return CustomerActivityResponse.fromJson(jsonResponse);
      } else {
        _handleError(response);
        throw Exception('Unreachable');
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال. حجم البيانات كبير أو السيرفر مشغول.');
    } on SocketException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } on OfflineFallbackException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  // ---------------------------------------------------------------------------
  // 3. Customer Activity (With Cache)
  // ---------------------------------------------------------------------------
  Future<(CustomerActivityResponse?, String)> fetchCustomerActivityWithCache(CustomerActivityRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/customer-activity');

    try {
      await ServerConnectivity.ensureServerReachable();
      final response = await ServerConnectivity.client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 45)); 

      if (response.statusCode == 200) {
        return (null, response.body);
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

  // ---------------------------------------------------------------------------
  // Sales Movement — New Dedicated Report (مستقل تماماً)
  // ---------------------------------------------------------------------------
  Future<SalesMovementResponse> fetchSalesMovement(SalesMovementRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/sales-movement');

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
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        late final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return SalesMovementResponse.fromJson(jsonResponse);
      } else {
        _handleError(response);
        throw Exception('Unreachable');
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال. السيرفر لا يستجيب.');
    } on SocketException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } on OfflineFallbackException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  // ---------------------------------------------------------------------------
  // Sales Movement — New Report (With Cache / Offline Support)
  // ---------------------------------------------------------------------------
  Future<(SalesMovementResponse?, String)> fetchSalesMovementWithCache(
      SalesMovementRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/sales-movement');

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
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // فك التشفير يتم داخل Isolate واحد في الـ Controller لتفادي تجميد الواجهة
        return (null, response.body);
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

  // ---------------------------------------------------------------------------
  // Account Balances — تقرير أرصدة الحسابات (مستقل تماماً)
  // ---------------------------------------------------------------------------
  Future<AccountBalancesResponse> fetchAccountBalances(
      AccountBalancesRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/account-balances');

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
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        late final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return AccountBalancesResponse.fromJson(jsonResponse);
      } else {
        _handleError(response);
        throw Exception('Unreachable');
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال. السيرفر لا يستجيب.');
    } on SocketException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } on OfflineFallbackException {
      throw Exception('تعذر الاتصال بالسيرفر. تأكد من الإنترنت أو العنوان.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  // ---------------------------------------------------------------------------
  // Account Balances — With Cache / Offline Support
  // ---------------------------------------------------------------------------
  Future<(AccountBalancesResponse?, String)> fetchAccountBalancesWithCache(
      AccountBalancesRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url = Uri.parse('$baseUrl/api/Reports/account-balances');

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
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        return (null, response.body);
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

  // ---------------------------------------------------------------------------
  // Cost Center Profit Margin — هامش أرباح مراكز التكلفة
  // ---------------------------------------------------------------------------
  Future<CostCenterProfitMarginResponse> fetchCostCenterProfitMargin(
      CostCenterProfitMarginRequest request) async {
    final String baseUrl = await _getBaseUrl();
    final Uri url =
        Uri.parse('$baseUrl/api/Reports/cost-center-profit-margin');

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
        late final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        return await compute(_parseCostCenterProfitMarginResponse, response.body);
      } else {
        _handleError(response);
        throw Exception('Unreachable');
      }
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال. السيرفر لا يستجيب.');
    } on SocketException {
      throw Exception('تعذر الاتصال بالسيرفر.');
    } on OfflineFallbackException {
      throw Exception('تعذر الاتصال بالسيرفر.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }
}

/// فك تشفير استجابة كشف الحساب في خيط خلفي معزول عبر compute()
AccountStatementResponse _parseAccountStatementResponse(String responseBody) {
  final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
  return AccountStatementResponse.fromJson(jsonResponse);
}

CostCenterProfitMarginResponse _parseCostCenterProfitMarginResponse(String responseBody) {
  final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
  return CostCenterProfitMarginResponse.fromJson(jsonResponse);
}