import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// مدير كاش ملفات التقارير المحلية
/// يقوم بحفظ وقراءة ملفات الـ JSON الكبيرة في مسار المستندات المحلي
/// لتفادي انهيار SQLite بسبب حد الـ CursorWindow (2MB)
class ReportCacheFileManager {
  static const String _subDirectory = 'reports_cache';

  /// إرجاع أو إنشاء مجلد الكاش المحلي
  static Future<Directory> getCacheDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDocDir.path}/$_subDirectory');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// تنظيف وتجهيز اسم الملف لمنع أي رموز غير صالحة في نظام الملفات
  static String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  /// توليد اسم ملف قياسي استناداً إلى معطيات التقرير
  static String generateFileName({
    required String reportType,
    required String entityId,
    required String currencyId,
    required String paramsHash,
  }) {
    final cleanReportType = _sanitizeFileName(reportType);
    final cleanEntityId   = _sanitizeFileName(entityId);
    final cleanCurrencyId = _sanitizeFileName(currencyId);
    final cleanParamsHash = _sanitizeFileName(paramsHash);

    return '${cleanReportType}_${cleanEntityId}_${cleanCurrencyId}_${cleanParamsHash}.json';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Core save / read methods
  // ─────────────────────────────────────────────────────────────────────────

  /// حفظ محتوى الـ JSON في ملف مستقل وإرجاع مساره المحلي المطلق
  static Future<String> saveReportJson({
    required String reportType,
    required String entityId,
    required String currencyId,
    required String paramsHash,
    required String rawJson,
  }) async {
    final cacheDir = await getCacheDirectory();
    final fileName = generateFileName(
      reportType: reportType,
      entityId:   entityId,
      currencyId: currencyId,
      paramsHash: paramsHash,
    );
    final file = File('${cacheDir.path}/$fileName');
    await file.writeAsString(rawJson, flush: false);
    return file.path;
  }

  /// قراءة محتوى ملف الـ JSON المحلي وإرجاعه كنص
  static Future<String?> readReportJson(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// التحقق من وجود ملف الكاش
  static Future<bool> reportFileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (_) {
      return false;
    }
  }

  /// حذف ملف الكاش المحدد
  static Future<void> deleteReportFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// تفريغ كامل مجلد كاش التقارير
  static Future<void> clearAllReportsCache() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Convenience aliases — used by controllers with different naming conventions
  // ─────────────────────────────────────────────────────────────────────────

  /// saveReportJson variant used by account_balances_controller,
  /// cost_center_report_controller, customer_movement_controller.
  /// Accepts (identifier:, jsonContent:) and maps to the canonical signature.
  // ignore: avoid_shadowing_type_parameters
  static Future<String> saveReportJsonByIdentifier({
    required String reportType,
    required String identifier,
    required String jsonContent,
  }) =>
      saveReportJson(
        reportType: reportType,
        entityId:   identifier,
        currencyId: '0',
        paramsHash: identifier,
        rawJson:    jsonContent,
      );

  /// saveReportPayload — used by profit_margin_controller,
  /// item_balances_controller, item_card_controller.
  /// All extra named params are optional with sensible defaults.
  static Future<String> saveReportPayload({
    required String reportType,
    String entityId        = 'ALL',
    String entityIdentifier = '',
    String currencyId      = '0',
    String parametersHash  = '',
    String payloadJson     = '',
    String rawJson         = '',
  }) {
    final effectiveEntityId    = entityIdentifier.isNotEmpty ? entityIdentifier : entityId;
    final effectivePayload     = payloadJson.isNotEmpty ? payloadJson : rawJson;
    final effectiveParamsHash  = parametersHash.isNotEmpty ? parametersHash : effectiveEntityId;
    return saveReportJson(
      reportType: reportType,
      entityId:   effectiveEntityId,
      currencyId: currencyId,
      paramsHash: effectiveParamsHash,
      rawJson:    effectivePayload,
    );
  }

  /// readReportPayload — alias used by profit_margin_controller,
  /// item_balances_controller, item_card_controller
  static Future<String?> readReportPayload(String filePath) =>
      readReportJson(filePath);

  /// saveCacheFile — used by sales_movement_controller,
  /// sales_movement_new_controller.
  /// Accepts a pre-generated fileName from generateFileName().
  static Future<String> saveCacheFile(String fileName, String content) async {
    final cacheDir = await getCacheDirectory();
    final file = File('${cacheDir.path}/$fileName');
    await file.writeAsString(content, flush: false);
    return file.path;
  }

  /// readCacheFile — alias used by sales_movement_controller,
  /// sales_movement_new_controller
  static Future<String?> readCacheFile(String filePath) =>
      readReportJson(filePath);
}
