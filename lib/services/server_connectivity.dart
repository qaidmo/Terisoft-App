import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_fallback_exception.dart';

/// Shared utility for checking connectivity to our specific server.
///
/// Replaces the old `InternetAddress.lookup('google.com')` pattern which
/// checked general internet availability. This utility targets our own
/// server's `check-connection` endpoint with a short timeout, enabling
/// fast offline fallback for reports and other cached data flows.
class ServerConnectivity {
  static const String _serverPort = '5000';
  static const Duration _timeout = Duration(milliseconds: 1800);

  /// Shared persistent HTTP client for connection pooling (Keep-Alive).
  static final http.Client client = http.Client();

  /// Returns `true` if our server's `check-connection` endpoint responds
  /// with HTTP 200 within [_timeout]. Returns `false` on any failure
  /// (timeout, socket error, non-200, missing config, etc.).
  ///
  /// This is intentionally a silent check — it never throws.
  static Future<bool> isServerReachable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? serverAddress = prefs.getString('server_address');
      if (serverAddress == null || serverAddress.trim().isEmpty) return false;

      serverAddress = serverAddress.trim();
      var baseUrl = serverAddress.contains('://')
          ? serverAddress
          : 'http://$serverAddress';
      if (baseUrl.endsWith('/')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }

      final url = '$baseUrl/api/CoreData/check-connection';
      final response = await client.get(Uri.parse(url)).timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Ensures the backend server is reachable within [_timeout] (1.8s),
  /// or immediately throws [OfflineFallbackException] ('CONNECTION_LOST')
  /// to trigger the instant offline fallback flow without waiting for
  /// long report HTTP timeouts (30s–60s).
  static Future<void> ensureServerReachable() async {
    final reachable = await isServerReachable();
    if (!reachable) {
      throw OfflineFallbackException('CONNECTION_LOST');
    }
  }
}
