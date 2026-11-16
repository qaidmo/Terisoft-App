export 'offline_fallback_exception.dart';

class OfflineFallbackException implements Exception {
  final String reason; // 'CONNECTION_LOST' or 'NOT_MODIFIED'
  OfflineFallbackException(this.reason);

  @override
  String toString() => 'OfflineFallbackException: $reason';
}
