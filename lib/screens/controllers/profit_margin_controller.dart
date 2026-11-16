// lib/screens/controllers/profit_margin_controller.dart
// تحكم تقرير هامش الربح — GetX Controller مستقل تماماً

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/repositories/profit_margin_repository.dart';
import 'package:untitled4/screens/pdf/profit_margin_pdf_view.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../models/profit_margin_models.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'dart:convert';

const String _kPMScreenName = 'ProfitMarginScreen';

/// مفاتيح SharedPreferences — مسبوقة بـ pm_ لتجنب التعارض
const Map<String, String> _prefKeys = {
  'showBranch':         'pm_show_branch',
  'showDepartment':     'pm_show_dept',
  'showBatch':          'pm_show_batch',
  'showCostCenter':     'pm_show_cost_center',
  'groupByItemGroup':   'pm_group_by_item_group',
  'groupByUser':        'pm_group_by_user',
  'negativeMarginOnly': 'pm_negative_margin_only',
};

class ProfitMarginController extends GetxController {
  final ProfitMarginRepository _repository = ProfitMarginRepository();
  final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController =
      Get.find<InvoiceTemplatesController>();

  // ---------------------------------------------------------------------------
  // حالة الفلاتر
  // ---------------------------------------------------------------------------
  final Rx<DateTime> fromDate = DateTime.now().obs;
  final Rx<DateTime> toDate   = DateTime.now().obs;

  // ---------------------------------------------------------------------------
  // إعدادات الأعمدة الاختيارية (7 مفاتيح) — تُحفظ في SharedPreferences
  // ---------------------------------------------------------------------------
  final RxBool showBranch         = false.obs;  // عمود الفرع
  final RxBool showDepartment     = false.obs;  // عمود القسم
  final RxBool showBatch          = false.obs;  // عمود التشغيلة
  final RxBool showCostCenter     = false.obs;  // عمود مركز التكلفة
  final RxBool groupByItemGroup   = false.obs;  // تجميع حسب مجموعة الأصناف (حصري)
  final RxBool groupByUser        = false.obs;  // تجميع حسب المستخدم (حصري)
  final RxBool negativeMarginOnly = false.obs;  // الهامش السالب فقط

  // ---------------------------------------------------------------------------
  // حالة النتائج
  // ---------------------------------------------------------------------------
  final RxBool isLoading   = false.obs;
  final RxBool hasSearched = false.obs;
  final RxList<ProfitMarginRow> reportData = <ProfitMarginRow>[].obs;

  // المجاميع
  final RxDouble grandSalesQty    = 0.0.obs;
  final RxDouble grandSalesValue  = 0.0.obs;
  final RxDouble grandSalesCost   = 0.0.obs;
  final RxDouble grandMargin      = 0.0.obs;
  final RxDouble grandBalanceQty  = 0.0.obs;
  final RxDouble grandBalanceCost = 0.0.obs;
  final RxInt    rowCount         = 0.obs;

  // سلاسل منسقة مسبقاً للعرض الفوري بدون تأخير
  final RxString grandSalesQtyStr    = '0'.obs;
  final RxString grandSalesValueStr  = '0'.obs;
  final RxString grandSalesCostStr   = '0'.obs;
  final RxString grandMarginStr      = '0'.obs;
  final RxString grandBalanceQtyStr  = '0'.obs;
  final RxString grandBalanceCostStr = '0'.obs;

  // ---------------------------------------------------------------------------
  // قوائم الجلب من SQLite (للمستقبل — تُستخدم داخلياً للفلترة)
  // ---------------------------------------------------------------------------
  final RxList<Map<String, String>> itemGroupsList = <Map<String, String>>[].obs;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    _initDates();
    _loadSettings();
    _loadItemGroups();
  }

  void _initDates() {
    final String? yearName = userState.financialYearName;
    final int currentYear  = int.tryParse(yearName ?? '') ?? DateTime.now().year;
    fromDate.value = DateTime(currentYear, 1, 1);
    toDate.value   = DateTime(currentYear, 12, 31, 23, 59, 59);
  }

  // ---------------------------------------------------------------------------
  // تحميل وحفظ الإعدادات
  // ---------------------------------------------------------------------------
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      showBranch.value         = prefs.getBool(_prefKeys['showBranch']!)         ?? false;
      showDepartment.value     = prefs.getBool(_prefKeys['showDepartment']!)     ?? false;
      showBatch.value          = prefs.getBool(_prefKeys['showBatch']!)          ?? false;
      showCostCenter.value     = prefs.getBool(_prefKeys['showCostCenter']!)     ?? false;
      groupByItemGroup.value   = prefs.getBool(_prefKeys['groupByItemGroup']!)   ?? false;
      groupByUser.value        = prefs.getBool(_prefKeys['groupByUser']!)        ?? false;
      negativeMarginOnly.value = prefs.getBool(_prefKeys['negativeMarginOnly']!) ?? false;
    } catch (_) {
      // الإعدادات الافتراضية تبقى إن فشل الجلب
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeys['showBranch']!,         showBranch.value);
      await prefs.setBool(_prefKeys['showDepartment']!,     showDepartment.value);
      await prefs.setBool(_prefKeys['showBatch']!,          showBatch.value);
      await prefs.setBool(_prefKeys['showCostCenter']!,     showCostCenter.value);
      await prefs.setBool(_prefKeys['groupByItemGroup']!,   groupByItemGroup.value);
      await prefs.setBool(_prefKeys['groupByUser']!,        groupByUser.value);
      await prefs.setBool(_prefKeys['negativeMarginOnly']!, negativeMarginOnly.value);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // دوال التبديل العامة + التبديل الحصري للتجميع
  // ---------------------------------------------------------------------------
  void toggleSetting(String key, bool value) {
    switch (key) {
      case 'showBranch':         showBranch.value         = value; break;
      case 'showDepartment':     showDepartment.value     = value; break;
      case 'showBatch':          showBatch.value          = value; break;
      case 'showCostCenter':     showCostCenter.value     = value; break;
      case 'negativeMarginOnly': negativeMarginOnly.value = value; break;
      case 'groupByItemGroup':   _toggleGroupByItemGroup(value); return;
      case 'groupByUser':        _toggleGroupByUser(value);       return;
    }
    _saveSettings();
  }

  /// تجميع حسب مجموعة الأصناف — حصري مع تجميع المستخدم
  void _toggleGroupByItemGroup(bool value) {
    groupByItemGroup.value = value;
    if (value) groupByUser.value = false;
    _saveSettings();
  }

  /// تجميع حسب المستخدم — حصري مع تجميع المجموعة
  void _toggleGroupByUser(bool value) {
    groupByUser.value = value;
    if (value) groupByItemGroup.value = false;
    _saveSettings();
  }

  // ---------------------------------------------------------------------------
  // قيمة groupBy المشتقة من الحالة
  // ---------------------------------------------------------------------------
  String get groupBy {
    if (groupByItemGroup.value) return 'group';
    if (groupByUser.value)      return 'user';
    return 'item';
  }

  // ---------------------------------------------------------------------------
  // عنوان الأعمدة الأولين (يتغير بناءً على التجميع)
  // ---------------------------------------------------------------------------
  String get primaryKeyLabel {
    switch (groupBy) {
      case 'group': return 'رقم المجموعة';
      case 'user':  return 'رقم المستخدم';
      default:      return 'رقم الصنف';
    }
  }

  String get primaryNameLabel {
    switch (groupBy) {
      case 'group': return 'اسم المجموعة';
      case 'user':  return 'اسم المستخدم';
      default:      return 'اسم الصنف';
    }
  }

  // ---------------------------------------------------------------------------
  // جلب مجموعات الأصناف من SQLite
  // ---------------------------------------------------------------------------
  Future<void> _loadItemGroups() async {
    try {
      final db   = DatabaseHelper.instance;
      final rows = await db.query(
        'sun_item_groups',
        columns: ['group_no', 'group_name'],
        orderBy: 'group_name ASC',
      );
      itemGroupsList.assignAll(
        rows.map((r) => {
              'group_no':   r['group_no']?.toString()   ?? '',
              'group_name': r['group_name']?.toString() ?? '',
            }).toList(),
      );
    } catch (_) {
      itemGroupsList.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // جلب البيانات من السيرفر
  // ---------------------------------------------------------------------------
  Future<void> fetchReportData() async {
    final String? currentYear = userState.financialYearName;
    if (currentYear == null || currentYear.isEmpty) {
      AppSnackbar.showCustomSnackbar(
        'خطأ',
        'السنة المالية غير محددة. يرجى التزامن أولاً.',
        isError: true,
      );
      return;
    }

    isLoading.value   = true;
    hasSearched.value = true;
    reportData.clear();
    _resetTotals();

    try {
      final String paramHash =
          '${DateFormat('yyyy-MM-dd').format(fromDate.value)}'
          '|${DateFormat('yyyy-MM-dd').format(toDate.value)}'
          '|g:$groupBy'
          '|nm:${negativeMarginOnly.value ? 1 : 0}'
          '|b:${showBranch.value ? 1 : 0}'
          '|d:${showDepartment.value ? 1 : 0}'
          '|bt:${showBatch.value ? 1 : 0}'
          '|cc:${showCostCenter.value ? 1 : 0}';

      try {
        final result = await _repository.getProfitMarginWithCache(
          startDate:         fromDate.value.toIso8601String(),
          endDate:           toDate.value.toIso8601String(),
          year:              currentYear,
          branchId:          userState.safeUserBranch,
          groupBy:           groupBy,
          userId:            userState.isAdmin ? null : userState.userNo,
          departmentId:      userState.userDepartment,
          negativeMarginOnly:negativeMarginOnly.value,
          includeBranch:     showBranch.value,
          includeDepartment: showDepartment.value,
          includeBatch:      showBatch.value,
          includeCostCenter: showCostCenter.value,
        );

        ProfitMarginResponse? response = result.$1;
        final rawJson  = result.$2;

        if (response == null && rawJson.isNotEmpty) {
          response = await compute(parseProfitMarginJson, rawJson);
        }

        if (response != null) {
          _applyResponse(response);
        }

        if (rawJson.isNotEmpty) {
          try {
            final filePath = await ReportCacheFileManager.saveReportPayload(
              reportType: 'ProfitMargin',
              entityIdentifier: 'ALL',
              currencyId: '0',
              parametersHash: paramHash,
              payloadJson: rawJson,
            );

            await DatabaseHelper.instance.insertOrUpdate(
              'Offline_ReportsCache',
              {
                'ReportType':        'ProfitMargin',
                'EntityIdentifier':  'ALL',
                'CurrencyId':        '0',
                'ParametersHash':    paramHash,
                'file_path':         filePath,
                'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
              },
              'ReportType',
            );
          } catch (cacheErr) {
            debugPrint('Error saving ProfitMargin cache: $cacheErr');
          }
        }

      } on OfflineFallbackException catch (e) {
        final cacheResult = await DatabaseHelper.instance.query(
          'Offline_ReportsCache',
          where: 'ReportType = ? AND CurrencyId = ? AND ParametersHash = ?',
          whereArgs: ['ProfitMargin', '0', paramHash],
        );

        if (cacheResult.isNotEmpty) {
          final syncTime = cacheResult.first['LastSyncTimestamp'].toString();
          final storedPath = cacheResult.first['file_path']?.toString() ?? '';
          final offlineJson = await ReportCacheFileManager.readReportPayload(storedPath);
          if (e.reason == 'CONNECTION_LOST') {
            final proceed = await UiHelper.showOfflineWarningDialog(syncTime);
            if (!proceed) { isLoading.value = false; return; }
          }
          if (offlineJson != null && offlineJson.isNotEmpty) {
            final offlineData = await compute(parseProfitMarginJson, offlineJson);
            _applyResponse(offlineData);
          } else {
            throw Exception('تعذر قراءة البيانات المحفوظة محلياً');
          }
        } else {
          AppSnackbar.showCustomSnackbar(
            'خطأ',
            'لا يوجد اتصال ولا توجد بيانات محلية لهذه الفترة. يرجى الاتصال بالإنترنت.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (e is! OfflineFallbackException) {
        AppSnackbar.showCustomSnackbar(
          'خطأ في التقرير',
          e.toString().replaceAll('Exception:', '').trim(),
          isError: true,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _applyResponse(ProfitMarginResponse response) {
    reportData.assignAll(response.rows);
    rowCount.value            = response.rowCount;
    grandSalesQty.value       = response.grandSalesQty;
    grandSalesValue.value     = response.grandSalesValue;
    grandSalesCost.value      = response.grandSalesCost;
    grandMargin.value         = response.grandMargin;
    grandBalanceQty.value     = response.grandBalanceQty;
    grandBalanceCost.value    = response.grandBalanceCost;
    grandSalesQtyStr.value    = response.grandSalesQtyStr;
    grandSalesValueStr.value  = response.grandSalesValueStr;
    grandSalesCostStr.value   = response.grandSalesCostStr;
    grandMarginStr.value      = response.grandMarginStr;
    grandBalanceQtyStr.value  = response.grandBalanceQtyStr;
    grandBalanceCostStr.value = response.grandBalanceCostStr;
  }

  void _resetTotals() {
    rowCount.value            = 0;
    grandSalesQty.value       = 0.0;
    grandSalesValue.value     = 0.0;
    grandSalesCost.value      = 0.0;
    grandMargin.value         = 0.0;
    grandBalanceQty.value     = 0.0;
    grandBalanceCost.value    = 0.0;
    grandSalesQtyStr.value    = '0';
    grandSalesValueStr.value  = '0';
    grandSalesCostStr.value   = '0';
    grandMarginStr.value      = '0';
    grandBalanceQtyStr.value  = '0';
    grandBalanceCostStr.value = '0';
  }

  // ---------------------------------------------------------------------------
  // مسح الفلاتر
  // ---------------------------------------------------------------------------
  void clearFilters() {
    _initDates();
    reportData.clear();
    _resetTotals();
    hasSearched.value = false;
  }

  // ---------------------------------------------------------------------------
  // صلاحية الطباعة
  // ---------------------------------------------------------------------------
  bool canPrint() => userState.canPrint(_kPMScreenName);

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
    _invoiceTemplatesController.selectTemplate(_kPMScreenName);
    if (_invoiceTemplatesController.companyNameController.text.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'يرجى ضبط قالب التقرير في الإعدادات أولاً.',
          isError: true);
      return;
    }
    Get.to(() => ProfitMarginPdfView(
          reportData: reportData.toList(),
          fromDate: fromDate.value,
          toDate: toDate.value,
          grandSalesValue: grandSalesValue.value,
          grandSalesCost: grandSalesCost.value,
          grandMargin: grandMargin.value,
          grandSalesQty: grandSalesQty.value,
          rowCount: rowCount.value,
          showBranch: showBranch.value,
          showDepartment: showDepartment.value,
          showBatch: showBatch.value,
          showCostCenter: showCostCenter.value,
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

  // ---------------------------------------------------------------------------
  // تنسيق الأرقام
  // ---------------------------------------------------------------------------
  String formatNumber(dynamic value) {
    if (value == null) return '0';
    final double d = (value is double)
        ? value
        : (double.tryParse(value.toString()) ?? 0.0);
    return NumberFormat('#,###.##', 'en_US').format(d);
  }

  String formatPct(double value) =>
      '${NumberFormat('#,###.##', 'en_US').format(value)}%';
}
