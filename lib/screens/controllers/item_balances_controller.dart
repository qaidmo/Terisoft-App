// lib/screens/controllers/item_balances_controller.dart
// تحكم تقرير أرصدة الأصناف — GetX Controller مستقل تماماً

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/repositories/item_balances_repository.dart';
import 'package:untitled4/screens/pdf/item_balances_pdf_view.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../models/item_balances_models.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'dart:convert';

/// مفاتيح SharedPreferences — مسبوقة بـ ib_ لتجنب التعارض مع باقي التقارير
const Map<String, String> _kPrefKeys = {
  // أعمدة اختيارية
  'showBranch':             'ib_show_branch',
  'showDepartment':         'ib_show_dept',
  'showStore':              'ib_show_store',
  'showExpiry':             'ib_show_expiry',
  'showBatch':              'ib_show_batch',
  // فلاتر جانب السيرفر
  'excludeZeros':           'ib_excl_zeros',
  'negativeQtyOnly':        'ib_neg_qty',
  'excludePreviousBalance': 'ib_excl_prev_bal',
  'zeroBalancesOnly':       'ib_zero_bal',
};

class ItemBalancesController extends GetxController {
  final ItemBalancesRepository _repository = ItemBalancesRepository();
  final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController =
      Get.find<InvoiceTemplatesController>();

  // ---------------------------------------------------------------------------
  // فلاتر الفترة الزمنية
  // ---------------------------------------------------------------------------
  final Rx<DateTime> fromDate = DateTime.now().obs;
  final Rx<DateTime> toDate   = DateTime.now().obs;

  // ---------------------------------------------------------------------------
  // 9 إعدادات — تُحفظ في SharedPreferences بمسبقة ib_
  // ---------------------------------------------------------------------------

  // القسم 1: أعمدة اختيارية (تؤثر على GROUP BY والـ SELECT في SQL)
  final RxBool showBranch     = false.obs;  // حسب الفرع
  final RxBool showDepartment = false.obs;  // حسب القسم
  final RxBool showStore      = false.obs;  // حسب المخزن (يضيف StoreNo+StoreName+ItemBalance)
  final RxBool showExpiry     = false.obs;  // حسب تاريخ الانتهاء
  final RxBool showBatch      = false.obs;  // حسب الدفعة

  // القسم 2: فلاتر جانب السيرفر
  final RxBool excludeZeros           = false.obs;
  final RxBool negativeQtyOnly        = false.obs;
  final RxBool excludePreviousBalance = false.obs;
  final RxBool zeroBalancesOnly       = false.obs;

  // ---------------------------------------------------------------------------
  // حالة النتائج
  // ---------------------------------------------------------------------------
  final RxBool isLoading   = false.obs;
  final RxBool hasSearched = false.obs;
  final RxList<ItemBalancesRow> reportData = <ItemBalancesRow>[].obs;

  // المجاميع
  final RxDouble grandBalance        = 0.0.obs;
  final RxDouble grandBalanceCost    = 0.0.obs;
  final RxDouble grandSalesQty       = 0.0.obs;
  final RxDouble grandPurchaseQty    = 0.0.obs;
  final RxString grandBalanceStr     = '0'.obs;
  final RxString grandBalanceCostStr = '0'.obs;
  final RxString grandSalesQtyStr    = '0'.obs;
  final RxString grandPurchaseQtyStr = '0'.obs;
  final RxInt    rowCount            = 0.obs;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    _initDates();
    _loadSettings();
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
      showBranch.value             = prefs.getBool(_kPrefKeys['showBranch']!)             ?? false;
      showDepartment.value         = prefs.getBool(_kPrefKeys['showDepartment']!)         ?? false;
      showStore.value              = prefs.getBool(_kPrefKeys['showStore']!)              ?? false;
      showExpiry.value             = prefs.getBool(_kPrefKeys['showExpiry']!)             ?? false;
      showBatch.value              = prefs.getBool(_kPrefKeys['showBatch']!)              ?? false;
      excludeZeros.value           = prefs.getBool(_kPrefKeys['excludeZeros']!)           ?? false;
      negativeQtyOnly.value        = prefs.getBool(_kPrefKeys['negativeQtyOnly']!)        ?? false;
      excludePreviousBalance.value = prefs.getBool(_kPrefKeys['excludePreviousBalance']!) ?? false;
      zeroBalancesOnly.value       = prefs.getBool(_kPrefKeys['zeroBalancesOnly']!)       ?? false;
    } catch (_) {
      // الإعدادات الافتراضية تبقى إن فشل الجلب
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefKeys['showBranch']!,             showBranch.value);
      await prefs.setBool(_kPrefKeys['showDepartment']!,         showDepartment.value);
      await prefs.setBool(_kPrefKeys['showStore']!,              showStore.value);
      await prefs.setBool(_kPrefKeys['showExpiry']!,             showExpiry.value);
      await prefs.setBool(_kPrefKeys['showBatch']!,              showBatch.value);
      await prefs.setBool(_kPrefKeys['excludeZeros']!,           excludeZeros.value);
      await prefs.setBool(_kPrefKeys['negativeQtyOnly']!,        negativeQtyOnly.value);
      await prefs.setBool(_kPrefKeys['excludePreviousBalance']!,  excludePreviousBalance.value);
      await prefs.setBool(_kPrefKeys['zeroBalancesOnly']!,       zeroBalancesOnly.value);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // دالة التبديل الموحدة
  // ---------------------------------------------------------------------------
  void toggleSetting(String key, bool value) {
    switch (key) {
      case 'showBranch':             showBranch.value             = value; break;
      case 'showDepartment':         showDepartment.value         = value; break;
      case 'showStore':              showStore.value              = value; break;
      case 'showExpiry':             showExpiry.value             = value; break;
      case 'showBatch':              showBatch.value              = value; break;
      case 'excludeZeros':           excludeZeros.value           = value; break;
      case 'negativeQtyOnly':        negativeQtyOnly.value        = value; break;
      case 'excludePreviousBalance': excludePreviousBalance.value = value; break;
      case 'zeroBalancesOnly':       zeroBalancesOnly.value       = value; break;
    }
    _saveSettings();
  }

  // ---------------------------------------------------------------------------
  // جلب البيانات
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
          '|b:${showBranch.value ? 1 : 0}'
          '|d:${showDepartment.value ? 1 : 0}'
          '|s:${showStore.value ? 1 : 0}'
          '|e:${showExpiry.value ? 1 : 0}'
          '|bt:${showBatch.value ? 1 : 0}'
          '|ez:${excludeZeros.value ? 1 : 0}'
          '|nq:${negativeQtyOnly.value ? 1 : 0}'
          '|ep:${excludePreviousBalance.value ? 1 : 0}'
          '|zb:${zeroBalancesOnly.value ? 1 : 0}';

      try {
        final result = await _repository.getItemBalancesWithCache(
          startDate:             fromDate.value.toIso8601String(),
          endDate:               toDate.value.toIso8601String(),
          year:                  currentYear,
          branchId:              userState.safeUserBranch,
          userId:                userState.isAdmin ? null : userState.userNo,
          departmentId:          userState.userDepartment,
          includeBranch:         showBranch.value,
          includeDepartment:     showDepartment.value,
          includeStore:          showStore.value,
          includeExpiry:         showExpiry.value,
          includeBatch:          showBatch.value,
          excludeZeros:          excludeZeros.value,
          negativeQtyOnly:       negativeQtyOnly.value,
          excludePreviousBalance:excludePreviousBalance.value,
          zeroBalancesOnly:      zeroBalancesOnly.value,
        );

        final rawJson = result.$2;

        // تحليل البيانات في خلفية النظام Isolate وعرضها فوراً
        final response = await compute(parseItemBalancesJson, rawJson);
        _applyResponse(response);

        // حفظ في ملف الكاش الخارجي
        try {
          final String filePath = await ReportCacheFileManager.saveReportPayload(
            reportType: 'ItemBalances',
            entityId: 'ALL',
            parametersHash: paramHash,
            rawJson: rawJson,
          );

          await DatabaseHelper.instance.insertOrUpdate(
            'Offline_ReportsCache',
            {
              'ReportType':        'ItemBalances',
              'EntityIdentifier':  'ALL',
              'CurrencyId':        '0',
              'ParametersHash':    paramHash,
              'file_path':         filePath,
              'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
            },
            'ReportType',
          );
        } catch (cacheErr) {
          debugPrint('Error saving ItemBalances cache: $cacheErr');
        }

      } on OfflineFallbackException catch (e) {
        final cacheResult = await DatabaseHelper.instance.query(
          'Offline_ReportsCache',
          where: 'ReportType = ? AND CurrencyId = ? AND ParametersHash = ?',
          whereArgs: ['ItemBalances', '0', paramHash],
        );

        if (cacheResult.isNotEmpty) {
          final syncTime = cacheResult.first['LastSyncTimestamp'].toString();
          final filePath = cacheResult.first['file_path']?.toString();
          String? rawPayload;
          if (filePath != null && filePath.isNotEmpty) {
            rawPayload = await ReportCacheFileManager.readReportPayload(filePath);
          }

          if (e.reason == 'CONNECTION_LOST') {
            final proceed = await UiHelper.showOfflineWarningDialog(syncTime);
            if (!proceed) { isLoading.value = false; return; }
          }

          if (rawPayload != null && rawPayload.isNotEmpty) {
            final response = await compute(parseItemBalancesJson, rawPayload);
            _applyResponse(response);
          } else {
            AppSnackbar.showCustomSnackbar(
              'خطأ',
              'ملف الكاش المحلي غير موجود أو تالف.',
              isError: true,
            );
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

  void _applyResponse(ItemBalancesResponse response) {
    reportData.assignAll(response.rows);
    rowCount.value            = response.rowCount;
    grandBalance.value        = response.grandBalance;
    grandBalanceCost.value    = response.grandBalanceCost;
    grandSalesQty.value       = response.grandSalesQty;
    grandPurchaseQty.value    = response.grandPurchaseQty;
    grandBalanceStr.value     = response.grandBalanceStr.isNotEmpty ? response.grandBalanceStr : formatNumber(response.grandBalance);
    grandBalanceCostStr.value = response.grandBalanceCostStr.isNotEmpty ? response.grandBalanceCostStr : formatNumber(response.grandBalanceCost);
    grandSalesQtyStr.value    = response.grandSalesQtyStr.isNotEmpty ? response.grandSalesQtyStr : formatNumber(response.grandSalesQty);
    grandPurchaseQtyStr.value = response.grandPurchaseQtyStr.isNotEmpty ? response.grandPurchaseQtyStr : formatNumber(response.grandPurchaseQty);
  }

  void _resetTotals() {
    rowCount.value            = 0;
    grandBalance.value        = 0.0;
    grandBalanceCost.value    = 0.0;
    grandSalesQty.value       = 0.0;
    grandPurchaseQty.value    = 0.0;
    grandBalanceStr.value     = '0';
    grandBalanceCostStr.value = '0';
    grandSalesQtyStr.value    = '0';
    grandPurchaseQtyStr.value = '0';
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
  // تنسيق الأرقام
  // ---------------------------------------------------------------------------
  String formatNumber(dynamic value) {
    if (value == null) return '0';
    final double d = value is double ? value : (double.tryParse(value.toString()) ?? 0.0);
    return NumberFormat('#,###.##', 'en_US').format(d);
  }

  bool canPrint() => userState.canPrint('ItemBalancesScreen');

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
    _invoiceTemplatesController.selectTemplate('ItemBalancesScreen');
    if (_invoiceTemplatesController.companyNameController.text.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'يرجى ضبط قالب التقرير في الإعدادات أولاً.',
          isError: true);
      return;
    }
    Get.to(() => ItemBalancesPdfView(
          reportData: reportData.toList(),
          fromDate: fromDate.value,
          toDate: toDate.value,
          grandBalance: grandBalance.value,
          grandBalanceCost: grandBalanceCost.value,
          rowCount: rowCount.value,
          showBranch: showBranch.value,
          showDepartment: showDepartment.value,
          showStore: showStore.value,
          showExpiry: showExpiry.value,
          showBatch: showBatch.value,
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
