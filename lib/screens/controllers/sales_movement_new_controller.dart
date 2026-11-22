// lib/screens/controllers/sales_movement_new_controller.dart
// تقرير حركة المبيعات الجديد - GetX Controller مستقل تماماً

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/screens/pdf/sales_movement_new_pdf_view.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../models/sales_movement_models.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/services/offline_report_query_service.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

const String _kSMScreenName = 'SalesMovementNewScreen';

class SalesMovementNewController extends GetxController {
  final ReportRepository _reportRepository = ReportRepository();
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController =
      Get.find<InvoiceTemplatesController>();

  // ---------------------------------------------------------------------------
  // Filter State
  // ---------------------------------------------------------------------------
  final Rx<DateTime> fromDate = DateTime.now().obs;
  final Rx<DateTime> toDate = DateTime.now().obs;

  final RxString selectedReportType = 'all'.obs;
  final RxList<Map<String, String>> reportTypes = <Map<String, String>>[].obs;

  // ---------------------------------------------------------------------------
  // Result State
  // ---------------------------------------------------------------------------
  final RxBool isLoading = false.obs;
  final RxBool hasSearched = false.obs;
  final RxList<Map<String, dynamic>> reportData = <Map<String, dynamic>>[].obs;
  final RxDouble grandNetValue = 0.0.obs;
  final RxDouble grandFinalValue = 0.0.obs;
  final RxInt itemsCount = 0.obs;

  // ---------------------------------------------------------------------------
  // 9 Column Visibility Toggles
  // ---------------------------------------------------------------------------
  final RxBool showDate = true.obs;           // Toggle 1
  final RxBool showInvoiceNumber = true.obs;  // Toggle 2
  final RxBool showTransType = true.obs;      // Toggle 3
  final RxBool showBeneficiary = true.obs;    // Toggle 4
  final RxBool showAccountName = true.obs;    // Toggle 5
  final RxBool showUserName = true.obs;       // Toggle 6
  final RxBool showBranch = false.obs;        // Toggle 7 — UI column only
  final RxBool showDepartment = false.obs;    // Toggle 8 — UI column only
  final RxBool showTaxDiscount = false.obs;   // Toggle 9 — Expand financial columns

  // SharedPreferences keys — prefixed 'smn_' to avoid collisions
  static const Map<String, String> _prefKeys = {
    'showDate': 'smn_show_date',
    'showInvoiceNumber': 'smn_show_invoice',
    'showTransType': 'smn_show_trans_type',
    'showBeneficiary': 'smn_show_beneficiary',
    'showAccountName': 'smn_show_account',
    'showUserName': 'smn_show_user',
    'showBranch': 'smn_show_branch',
    'showDepartment': 'smn_show_dept',
    'showTaxDiscount': 'smn_show_tax',
  };

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    _initDates();
    _loadStaticReportTypes();
    _loadSettings();
  }

  void _initDates() {
    String? yearName = userState.financialYearName;
    int currentYear =
        int.tryParse(yearName ?? '') ?? DateTime.now().year;
    fromDate.value = DateTime(currentYear, 1, 1);
    toDate.value = DateTime(currentYear, 12, 31, 23, 59, 59);
  }

  void _loadStaticReportTypes() {
    reportTypes.assignAll([
      {'value': 'all', 'display': 'الكل'},
      {'value': 'ن', 'display': 'المبيعات النقدية فقط'},
      {'value': 'ج', 'display': 'المبيعات الآجلة فقط'},
    ]);
  }



  // ---------------------------------------------------------------------------
  // Settings Persistence
  // ---------------------------------------------------------------------------
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      showDate.value = prefs.getBool(_prefKeys['showDate']!) ?? true;
      showInvoiceNumber.value =
          prefs.getBool(_prefKeys['showInvoiceNumber']!) ?? true;
      showTransType.value =
          prefs.getBool(_prefKeys['showTransType']!) ?? true;
      showBeneficiary.value =
          prefs.getBool(_prefKeys['showBeneficiary']!) ?? true;
      showAccountName.value =
          prefs.getBool(_prefKeys['showAccountName']!) ?? true;
      showUserName.value = prefs.getBool(_prefKeys['showUserName']!) ?? true;
      showBranch.value = prefs.getBool(_prefKeys['showBranch']!) ?? false;
      showDepartment.value =
          prefs.getBool(_prefKeys['showDepartment']!) ?? false;
      showTaxDiscount.value =
          prefs.getBool(_prefKeys['showTaxDiscount']!) ?? false;
    } catch (_) {
      // Defaults remain if prefs fail
    }
  }

  void toggleSetting(String key, bool value) {
    switch (key) {
      case 'showDate':
        showDate.value = value;
        break;
      case 'showInvoiceNumber':
        showInvoiceNumber.value = value;
        break;
      case 'showTransType':
        showTransType.value = value;
        break;
      case 'showBeneficiary':
        showBeneficiary.value = value;
        break;
      case 'showAccountName':
        showAccountName.value = value;
        break;
      case 'showUserName':
        showUserName.value = value;
        break;
      case 'showBranch':
        showBranch.value = value;
        break;
      case 'showDepartment':
        showDepartment.value = value;
        break;
      case 'showTaxDiscount':
        showTaxDiscount.value = value;
        break;
    }
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeys['showDate']!, showDate.value);
      await prefs.setBool(
          _prefKeys['showInvoiceNumber']!, showInvoiceNumber.value);
      await prefs.setBool(_prefKeys['showTransType']!, showTransType.value);
      await prefs.setBool(
          _prefKeys['showBeneficiary']!, showBeneficiary.value);
      await prefs.setBool(
          _prefKeys['showAccountName']!, showAccountName.value);
      await prefs.setBool(_prefKeys['showUserName']!, showUserName.value);
      await prefs.setBool(_prefKeys['showBranch']!, showBranch.value);
      await prefs.setBool(_prefKeys['showDepartment']!, showDepartment.value);
      await prefs.setBool(
          _prefKeys['showTaxDiscount']!, showTaxDiscount.value);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Data Fetching — Security Enforced
  // ---------------------------------------------------------------------------
  Future<void> fetchReportData() async {
    final String? currentYear = userState.financialYearName;
    if (currentYear == null || currentYear.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'السنة المالية غير محددة',
          isError: true);
      return;
    }

    isLoading.value = true;
    hasSearched.value = true;
    reportData.clear();
    grandNetValue.value = 0.0;
    grandFinalValue.value = 0.0;
    itemsCount.value = 0;

    try {
      final String paramHash =
          '${DateFormat('yyyy-MM-dd').format(fromDate.value)}'
          '|${DateFormat('yyyy-MM-dd').format(toDate.value)}'
          '|${selectedReportType.value}';

      try {
        final result = await _reportRepository.getSalesMovementWithCache(
          startDate: fromDate.value.toIso8601String(),
          endDate: toDate.value.toIso8601String(),
          year: currentYear,
          branchId: userState.safeUserBranch,
          transactionType: selectedReportType.value,
          userId: userState.isAdmin ? null : userState.userNo,
          departmentId: userState.userDepartment,
        );

        final rawJson  = result.$2;

        // 1. معالجة عبر compute Isolate واحد وعرض البيانات فوراً
        await _processInIsolate(rawJson);

        // 2. حفظ ملف الكاش المحلي في مسار المستندات
        final String entityIdStr = '${userState.safeUserBranch}_${userState.userDepartment ?? 0}';
        try {
          final fileName = ReportCacheFileManager.generateFileName(
            reportType: 'SalesMovementNew',
            entityId: entityIdStr,
            currencyId: '0',
            paramsHash: paramHash,
          );
          final filePath = await ReportCacheFileManager.saveCacheFile(fileName, rawJson);

          final db = await DatabaseHelper.instance.database;
          await db.insert('Offline_ReportsCache', {
            'ReportType': 'SalesMovementNew',
            'EntityIdentifier': entityIdStr,
            'CurrencyId': '0',
            'ParametersHash': paramHash,
            'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
            'file_path': filePath,
            'ledger_signature': '',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          debugPrint('Error saving SalesMovementNew cache file: $e');
        }

      } on OfflineFallbackException catch (e) {
        bool handled = false;
        final String entityIdStr = '${userState.safeUserBranch}_${userState.userDepartment ?? 0}';
        try {
          final cached = await OfflineReportQueryService.findCachedReportWithFallback(
            reportType: 'SalesMovementNew',
            entityId: entityIdStr,
            currencyId: '0',
            exactParamsHash: paramHash,
            year: currentYear,
            branchId: userState.safeUserBranch,
          );

          if (cached != null) {
            if (e.reason == 'CONNECTION_LOST') {
              final proceed = await UiHelper.showOfflineWarningDialog(
                cached.lastSyncTimestamp,
              );
              if (!proceed) {
                isLoading.value = false;
                return;
              }
            }
            await _processInIsolate(cached.rawJson);
            handled = true;
          }
        } catch (err) {
          debugPrint('Error reading SalesMovementNew cache: $err');
        }

        if (!handled) {
          AppSnackbar.showCustomSnackbar(
            'خطأ',
            'لا يوجد اتصال ولا توجد بيانات محلية لهذه الفترة. يرجى الاتصال بالإنترنت.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (e is! OfflineFallbackException) {
        AppSnackbar.showCustomSnackbar('خطأ',
            e.toString().replaceAll('Exception:', '').trim(),
            isError: true);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _processInIsolate(String rawJson) async {
    final result = await compute(_parseSalesMovementNewInIsolate, rawJson);

    final items = (result['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    reportData.assignAll(items);
    grandNetValue.value = (result['grandNetValue'] as num?)?.toDouble() ?? 0.0;
    grandFinalValue.value = (result['grandFinalValue'] as num?)?.toDouble() ?? 0.0;
    itemsCount.value = (result['itemsCount'] as num?)?.toInt() ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    double value = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat('#,###.##', 'en_US');
    return formatter.format(value);
  }

  String getDisplayTypeName(String char) {
    final item = reportTypes.firstWhere(
      (e) => e['value'] == char,
      orElse: () => {'display': char},
    );
    return item['display'] ?? char;
  }

  void clearFilters() {
    selectedReportType.value = 'all';
    _initDates();
    reportData.clear();
    grandNetValue.value = 0.0;
    grandFinalValue.value = 0.0;
    itemsCount.value = 0;
    hasSearched.value = false;
  }

  bool canPrint() {
    return userState.canPrint(_kSMScreenName);
  }

  void printReport() {
    if (!canPrint()) {
      AppSnackbar.showCustomSnackbar('صلاحيات', 'ليس لديك صلاحية طباعة هذا التقرير.');
      return;
    }
    if (reportData.isEmpty) {
      AppSnackbar.showCustomSnackbar('خطأ', 'لا توجد بيانات لطباعتها. يرجى عرض التقرير أولاً.',
          isError: true);
      return;
    }
    _invoiceTemplatesController.selectTemplate(_kSMScreenName);
    if (_invoiceTemplatesController.companyNameController.text.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'يرجى ضبط قالب التقرير في الإعدادات أولاً.',
          isError: true);
      return;
    }
    Get.to(() => SalesMovementNewPdfView(
          reportData: reportData.toList(),
          fromDate: fromDate.value,
          toDate: toDate.value,
          grandNetValue: grandNetValue.value,
          grandFinalValue: grandFinalValue.value,
          itemsCount: itemsCount.value,
          reportTitle: 'حركة المبيعات',
          showDate: showDate.value,
          showInvoiceNumber: showInvoiceNumber.value,
          showTransType: showTransType.value,
          showBeneficiary: showBeneficiary.value,
          showAccountName: showAccountName.value,
          showUserName: showUserName.value,
          showBranch: showBranch.value,
          showDepartment: showDepartment.value,
          showTaxDiscount: showTaxDiscount.value,
          companyName:
              _invoiceTemplatesController.companyNameController.text,
          companyAddress:
              _invoiceTemplatesController.addressDetailsController.text,
          contactInfo:
              _invoiceTemplatesController.contactInfoController.text,
          thanksMessage:
              _invoiceTemplatesController.thanksMessageController.text,
          logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
          showLogo: _invoiceTemplatesController.showLogo.value,
          userName: userState.safeUserName,
          userBranchName: userState.safeUserBranchName,
          userDepartmentName: userState.safeUserDepartmentName,
        ));
  }
}

/// دالة العزل الخلفي: تقوم بفك تشفير JSON، وتنسيق الأرقام والتواريخ دفعة واحدة في مسار واحد
Map<String, dynamic> _parseSalesMovementNewInIsolate(String rawJson) {
  final Map<String, dynamic> jsonResponse = jsonDecode(rawJson);
  final List<dynamic> itemsList = jsonResponse['items'] as List<dynamic>? ?? [];

  final DateFormat outputFormat = DateFormat('yyyy-MM-dd');
  final NumberFormat numberFormat = NumberFormat("#,##0.00", "en_US");

  final List<Map<String, dynamic>> mapped = [];

  for (final rawItem in itemsList) {
    if (rawItem is! Map<String, dynamic>) continue;

    final String typeId = rawItem['transactionTypeId']?.toString() ?? '';
    String typeChar = '';
    switch (typeId) {
      case '601': typeChar = 'ن'; break;
      case '602': typeChar = 'رن'; break;
      case '603': typeChar = 'ج'; break;
      case '604': typeChar = 'رج'; break;
      case '633': typeChar = 'م'; break;
      case '634': typeChar = 'رم'; break;
      case '201': typeChar = 'ق'; break;
      case '202': typeChar = 'ص'; break;
      default: typeChar = typeId; break;
    }

    final double grossTotal = (rawItem['grossTotal'] as num?)?.toDouble() ?? 0.0;
    final double discountAmount = (rawItem['discountAmount'] as num?)?.toDouble() ?? 0.0;
    final double taxAmount = (rawItem['taxAmount'] as num?)?.toDouble() ?? 0.0;
    final double netValue = (rawItem['netValue'] as num?)?.toDouble() ?? 0.0;
    final double finalValue = (rawItem['finalValue'] as num?)?.toDouble() ?? 0.0;

    final String dateStr = rawItem['date']?.toString() ?? '';
    String formattedDate = '-';
    if (dateStr.isNotEmpty) {
      try {
        final parsed = DateTime.parse(dateStr);
        formattedDate = outputFormat.format(parsed);
      } catch (_) {
        formattedDate = dateStr;
      }
    }

    mapped.add({
      'id': rawItem['transactionId']?.toString() ?? '',
      'transaction_number': rawItem['transactionNumber']?.toString() ?? '',
      'date': dateStr,
      'formatted_date': formattedDate,
      'time': rawItem['time']?.toString() ?? '',
      'transaction_type_id': typeId,
      'transaction_type_name': rawItem['transactionTypeName']?.toString() ?? '',
      'invoice_type_char': typeChar,
      'beneficiary_name': rawItem['beneficiaryName']?.toString() ?? '',
      'account_name': rawItem['accountName']?.toString() ?? '',
      'user_name': rawItem['userName']?.toString() ?? '',
      'branch_name': rawItem['branchName']?.toString() ?? '',
      'department_name': rawItem['departmentName']?.toString() ?? '',
      'gross_total': grossTotal,
      'gross_total_str': numberFormat.format(grossTotal),
      'discount_amount': discountAmount,
      'discount_amount_str': numberFormat.format(discountAmount),
      'tax_amount': taxAmount,
      'tax_amount_str': numberFormat.format(taxAmount),
      'net_value': netValue,
      'net_value_str': numberFormat.format(netValue),
      'final_value': finalValue,
      'final_value_str': numberFormat.format(finalValue),
    });
  }

  return {
    'items': mapped,
    'grandNetValue': (jsonResponse['grandNetValue'] as num?)?.toDouble() ?? 0.0,
    'grandFinalValue': (jsonResponse['grandFinalValue'] as num?)?.toDouble() ?? 0.0,
    'itemsCount': (jsonResponse['itemsCount'] as num?)?.toInt() ?? mapped.length,
  };
}
