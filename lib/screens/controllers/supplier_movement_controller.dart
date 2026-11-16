// lib/screens/controllers/supplier_movement_controller.dart
// GetX Controller لتقرير حركة الموردين — مستقل تماماً
// البنية المعيارية: تطابق تام مع SalesMovementNewController و ItemBalancesController

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/screens/pdf/supplier_movement_pdf_view.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../models/supplier_movement_models.dart';
import 'package:flutter/foundation.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'dart:convert';

const String _kSupplierMovementScreen = 'SupplierMovementScreen';

/// مفاتيح SharedPreferences — مسبوقة بـ sup_ لتجنب التعارض مع باقي التقارير
///
/// الأعمدة الثابتة دائماً (لا مفتاح لها):
///   رقم الحساب، صافي المشتريات، تسويات
///
/// الأعمدة الاختيارية (مفتاح لكل منها):
///   showAccountName   — اسم الحساب (افتراضي: true)
///   showSupplierName  — اسم المورد (افتراضي: false)
///   showDepartment    — القسم (افتراضي: false)
///   showBranch        — الفرع (افتراضي: false)
///   showInventoryValue— قيمة المخزون + الفارق (افتراضي: false)
///   excludeZero       — استبعاد الصفرية — فلتر جانب العميل (افتراضي: false)
const Map<String, String> _kPrefKeys = {
  'showAccountName':   'sup_show_acc_name',
  'showSupplierName':  'sup_show_supp_name',
  'showDepartment':    'sup_show_dept',
  'showBranch':        'sup_show_branch',
  'showInventoryValue':'sup_show_inv',
  'excludeZero':       'sup_excl_zero',
};

class SupplierMovementController extends GetxController {
  final ReportRepository  _reportRepository  = ReportRepository();
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final UserState         userState          = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController =
      Get.find<InvoiceTemplatesController>();

  // ---------------------------------------------------------------------------
  // فلاتر الفترة الزمنية
  // ---------------------------------------------------------------------------
  final Rx<DateTime> fromDate = DateTime.now().obs;
  final Rx<DateTime> toDate   = DateTime.now().obs;

  // ---------------------------------------------------------------------------
  // عملة الحساب
  // ---------------------------------------------------------------------------
  final Rxn<SunCurrency>    selectedCurrency      = Rxn<SunCurrency>();
  final RxList<SunCurrency> allCurrencies         = <SunCurrency>[].obs;
  final RxBool              isCurrencyListLoading = true.obs;

  // ---------------------------------------------------------------------------
  // إعدادات الأعمدة — 6 مفاتيح فقط — تُحفظ في SharedPreferences
  // ---------------------------------------------------------------------------

  // القسم 1: تجميع وإضافة أعمدة
  final RxBool showAccountName   = true.obs;   // اسم الحساب  — افتراضي مرئي
  final RxBool showSupplierName  = false.obs;  // اسم المورد  — افتراضي مخفي
  final RxBool showDepartment    = false.obs;  // القسم
  final RxBool showBranch        = false.obs;  // الفرع

  // القسم 2: فلترة وعرض
  final RxBool showInventoryValue = false.obs; // المخزون + الفارق
  final RxBool excludeZero        = false.obs; // استبعاد الصفرية

  /// Detailed Mode = showSupplierName AND showInventoryValue كلاهما مفعَّلان
  bool get isDetailedMode => showSupplierName.value && showInventoryValue.value;

  // ---------------------------------------------------------------------------
  // حالة النتائج
  // ---------------------------------------------------------------------------
  final RxBool isLoading   = false.obs;
  final RxBool hasSearched = false.obs;
  final RxList<Map<String, dynamic>> reportData = <Map<String, dynamic>>[].obs;
  final List<Map<String, dynamic>>   _rawData   = [];

  // ---------------------------------------------------------------------------
  // المجاميع العامة (تذييل الجدول)
  // ---------------------------------------------------------------------------
  final RxDouble grandOpeningBalance   = 0.0.obs;
  final RxDouble grandTotalPurchases   = 0.0.obs;
  final RxDouble grandTotalReturns     = 0.0.obs;
  final RxDouble grandNetPurchases     = 0.0.obs;
  final RxDouble grandTotalPayments    = 0.0.obs;
  final RxDouble grandTotalAdjustments = 0.0.obs;
  final RxDouble grandBalance          = 0.0.obs;

  final RxString grandOpeningBalanceStr   = '0'.obs;
  final RxString grandTotalPurchasesStr   = '0'.obs;
  final RxString grandTotalReturnsStr     = '0'.obs;
  final RxString grandNetPurchasesStr     = '0'.obs;
  final RxString grandTotalPaymentsStr    = '0'.obs;
  final RxString grandTotalAdjustmentsStr = '0'.obs;
  final RxString grandBalanceStr          = '0'.obs;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    _initDates();
    _loadSettings();
    _fetchAllCurrencies();
  }

  void _initDates() {
    final String? yearName    = userState.financialYearName;
    final int     currentYear = int.tryParse(yearName ?? '') ?? DateTime.now().year;
    fromDate.value = DateTime(currentYear, 1, 1);
    toDate.value   = DateTime(currentYear, 12, 31, 23, 59, 59);
  }

  // ---------------------------------------------------------------------------
  // تحميل وحفظ الإعدادات — SharedPreferences
  // ---------------------------------------------------------------------------
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      showAccountName.value    = prefs.getBool(_kPrefKeys['showAccountName']!)    ?? true;
      showSupplierName.value   = prefs.getBool(_kPrefKeys['showSupplierName']!)   ?? false;
      showDepartment.value     = prefs.getBool(_kPrefKeys['showDepartment']!)     ?? false;
      showBranch.value         = prefs.getBool(_kPrefKeys['showBranch']!)         ?? false;
      showInventoryValue.value = prefs.getBool(_kPrefKeys['showInventoryValue']!) ?? false;
      excludeZero.value        = prefs.getBool(_kPrefKeys['excludeZero']!)        ?? false;
    } catch (_) {
      // الإعدادات الافتراضية تبقى إن فشل الجلب
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefKeys['showAccountName']!,    showAccountName.value);
      await prefs.setBool(_kPrefKeys['showSupplierName']!,   showSupplierName.value);
      await prefs.setBool(_kPrefKeys['showDepartment']!,     showDepartment.value);
      await prefs.setBool(_kPrefKeys['showBranch']!,         showBranch.value);
      await prefs.setBool(_kPrefKeys['showInventoryValue']!, showInventoryValue.value);
      await prefs.setBool(_kPrefKeys['excludeZero']!,        excludeZero.value);
    } catch (_) {}
  }

  /// دالة التبديل الموحدة — مطابقة لـ ItemBalancesController
  void toggleSetting(String key, bool value) {
    switch (key) {
      case 'showAccountName':    showAccountName.value    = value; break;
      case 'showSupplierName':   showSupplierName.value   = value; break;
      case 'showDepartment':     showDepartment.value     = value; break;
      case 'showBranch':         showBranch.value         = value; break;
      case 'showInventoryValue': showInventoryValue.value = value; break;
      case 'excludeZero':
        excludeZero.value = value;
        if (_rawData.isNotEmpty) {
          _applyFilters();
        }
        break;
    }
    _saveSettings();
  }

  // ---------------------------------------------------------------------------
  // جلب قائمة العملات
  // ---------------------------------------------------------------------------
  Future<void> _fetchAllCurrencies() async {
    try {
      isCurrencyListLoading.value = true;
      final response = await _lookupsRepository.fetchAllCurrencies();
      allCurrencies.assignAll(response);

      if (allCurrencies.isNotEmpty) {
        final local = allCurrencies.firstWhere(
          (c) => c.currencyName.trim() == 'ريال يمني',
          orElse: () => allCurrencies.first,
        );
        selectedCurrency.value = local;
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'فشل في جلب قائمة العملات: ${e.toString()}',
          isError: true);
    } finally {
      isCurrencyListLoading.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // جلب بيانات التقرير من السيرفر
  // ---------------------------------------------------------------------------
  Future<void> fetchReportData() async {
    if (selectedCurrency.value == null) {
      AppSnackbar.showCustomSnackbar('خطأ', 'الرجاء اختيار العملة أولاً.',
          isError: true);
      return;
    }

    final String? currentYear = userState.financialYearName;
    if (currentYear == null || currentYear.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'السنة المالية غير محددة. يرجى التزامن أولاً.',
          isError: true);
      return;
    }

    isLoading.value   = true;
    hasSearched.value = true;
    reportData.clear();
    _rawData.clear();
    _resetTotals();

    try {
      final String paramHash =
          '${DateFormat('yyyy-MM-dd').format(fromDate.value)}'
          '|${DateFormat('yyyy-MM-dd').format(toDate.value)}'
          '|isDetailed:$isDetailedMode';

      try {
        final result = await _reportRepository.getSupplierMovementWithCache(
          startDate:      fromDate.value.toIso8601String(),
          endDate:        toDate.value.toIso8601String(),
          year:           currentYear,
          branchId:       userState.safeUserBranch,
          departmentId:   userState.safeUserDepartment,
          currencyId:     selectedCurrency.value!.currencyNo,
          userId:         userState.isAdmin ? null : userState.userNo,
          isDetailedMode: isDetailedMode,
        );

        final rawJson  = result.$2;

        await _processRawJsonWithIsolate(rawJson);

        try {
          final filePath = await ReportCacheFileManager.saveReportJson(
            reportType: 'SupplierMovement',
            entityId: 'ALL',
            currencyId: selectedCurrency.value!.currencyNo.toString(),
            paramsHash: paramHash,
            rawJson: rawJson,
          );

          await DatabaseHelper.instance.insertOrUpdate(
            'Offline_ReportsCache',
            {
              'ReportType':        'SupplierMovement',
              'EntityIdentifier':  'ALL',
              'CurrencyId':        selectedCurrency.value!.currencyNo.toString(),
              'ParametersHash':    paramHash,
              'file_path':         filePath,
              'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
            },
            'ReportType',
          );
        } catch (cacheErr) {
          debugPrint('Error saving SupplierMovement cache: $cacheErr');
        }

      } on OfflineFallbackException catch (e) {
        final cacheResult = await DatabaseHelper.instance.query(
          'Offline_ReportsCache',
          where: 'ReportType = ? AND CurrencyId = ? AND ParametersHash = ?',
          whereArgs: [
            'SupplierMovement',
            selectedCurrency.value!.currencyNo.toString(),
            paramHash,
          ],
        );

        if (cacheResult.isNotEmpty) {
          final syncTime = cacheResult.first['LastSyncTimestamp'].toString();
          String? rawJson;
          final filePath = cacheResult.first['file_path']?.toString();
          if (filePath != null && filePath.isNotEmpty) {
            rawJson = await ReportCacheFileManager.readReportJson(filePath);
          }

          if (e.reason == 'CONNECTION_LOST') {
            final proceed = await UiHelper.showOfflineWarningDialog(syncTime);
            if (!proceed) { isLoading.value = false; return; }
          }

          if (rawJson != null && rawJson.isNotEmpty) {
            await _processRawJsonWithIsolate(rawJson);
          } else {
            AppSnackbar.showCustomSnackbar(
              'خطأ',
              'ملف التقرير المخزن محلياً غير متاح.',
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
            isError: true);
      }
    } finally {
      isLoading.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // معالجة استجابة التقرير عبر Isolate
  // ---------------------------------------------------------------------------
  Future<void> _processRawJsonWithIsolate(String rawJson) async {
    try {
      final parsed = await compute(_parseSupplierMovementInIsolate, {
        'rawJson': rawJson,
        'isDetailedMode': isDetailedMode,
        'excludeZero': false,
      });

      final rows = List<Map<String, dynamic>>.from(parsed['rows'] as List);
      _rawData.clear();
      _rawData.addAll(rows);

      if (excludeZero.value) {
        _applyFilters();
      } else {
        reportData.assignAll(rows);

        grandOpeningBalance.value   = (parsed['grandOpeningBalance'] as num).toDouble();
        grandTotalPurchases.value   = (parsed['grandTotalPurchases'] as num).toDouble();
        grandTotalReturns.value     = (parsed['grandTotalReturns'] as num).toDouble();
        grandNetPurchases.value     = (parsed['grandNetPurchases'] as num).toDouble();
        grandTotalPayments.value    = (parsed['grandTotalPayments'] as num).toDouble();
        grandTotalAdjustments.value = (parsed['grandTotalAdjustments'] as num).toDouble();
        grandBalance.value          = (parsed['grandBalance'] as num).toDouble();

        grandOpeningBalanceStr.value   = parsed['grandOpeningBalanceStr'] as String;
        grandTotalPurchasesStr.value   = parsed['grandTotalPurchasesStr'] as String;
        grandTotalReturnsStr.value     = parsed['grandTotalReturnsStr'] as String;
        grandNetPurchasesStr.value     = parsed['grandNetPurchasesStr'] as String;
        grandTotalPaymentsStr.value    = parsed['grandTotalPaymentsStr'] as String;
        grandTotalAdjustmentsStr.value = parsed['grandTotalAdjustmentsStr'] as String;
        grandBalanceStr.value          = parsed['grandBalanceStr'] as String;
      }

    } catch (e) {
      debugPrint('Error parsing supplier movement in isolate: $e');
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ أثناء معالجة بيانات التقرير.', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // تطبيق فلتر استبعاد الصفرية (جانب العميل — لا طلب شبكة جديد)
  // ---------------------------------------------------------------------------
  void _applyFilters() {
    List<Map<String, dynamic>> filtered;
    if (excludeZero.value) {
      filtered = _rawData
          .where((row) => (row['balance'] as num) != 0)
          .toList();
    } else {
      filtered = List.from(_rawData);
    }

    if (isDetailedMode) {
      String? lastAccNo;
      for (int i = 0; i < filtered.length; i++) {
        final row = Map<String, dynamic>.from(filtered[i]);
        final String currAccNo = row['account_number']?.toString() ?? '';
        final String supplierName = row['supplier_name']?.toString() ?? '';
        if (lastAccNo != null && currAccNo == lastAccNo) {
          row['displayed_supplier_name'] = '...';
          row['is_first_row'] = false;
        } else {
          row['displayed_supplier_name'] = supplierName;
          row['is_first_row'] = true;
        }
        lastAccNo = currAccNo;
        filtered[i] = row;
      }
    }

    reportData.assignAll(filtered);
    _recalcTotals(filtered);
  }

  void _recalcTotals(List<Map<String, dynamic>> filtered) {
    final nf = NumberFormat('#,###.##', 'en_US');
    final double op = filtered.fold(0.0, (s, r) => s + (r['opening_balance'] as num));
    final double pu = filtered.fold(0.0, (s, r) => s + (r['total_purchases'] as num));
    final double re = filtered.fold(0.0, (s, r) => s + (r['total_returns'] as num));
    final double net = filtered.fold(0.0, (s, r) => s + (r['net_purchases'] as num));
    final double pay = filtered.fold(0.0, (s, r) => s + (r['total_payments'] as num));
    final double adj = filtered.fold(0.0, (s, r) => s + (r['total_adjustments'] as num));
    final double bal = filtered.fold(0.0, (s, r) => s + (r['balance'] as num));

    grandOpeningBalance.value   = op;
    grandTotalPurchases.value   = pu;
    grandTotalReturns.value     = re;
    grandNetPurchases.value     = net;
    grandTotalPayments.value    = pay;
    grandTotalAdjustments.value = adj;
    grandBalance.value          = bal;

    grandOpeningBalanceStr.value   = nf.format(op);
    grandTotalPurchasesStr.value   = nf.format(pu);
    grandTotalReturnsStr.value     = nf.format(re);
    grandNetPurchasesStr.value     = nf.format(net);
    grandTotalPaymentsStr.value    = nf.format(pay);
    grandTotalAdjustmentsStr.value = nf.format(adj);
    grandBalanceStr.value          = nf.format(bal);
  }

  void _resetTotals() {
    grandOpeningBalance.value   = 0.0;
    grandTotalPurchases.value   = 0.0;
    grandTotalReturns.value     = 0.0;
    grandNetPurchases.value     = 0.0;
    grandTotalPayments.value    = 0.0;
    grandTotalAdjustments.value = 0.0;
    grandBalance.value          = 0.0;

    grandOpeningBalanceStr.value   = '0';
    grandTotalPurchasesStr.value   = '0';
    grandTotalReturnsStr.value     = '0';
    grandNetPurchasesStr.value     = '0';
    grandTotalPaymentsStr.value    = '0';
    grandTotalAdjustmentsStr.value = '0';
    grandBalanceStr.value          = '0';
  }

  // ---------------------------------------------------------------------------
  // مسح الفلاتر
  // ---------------------------------------------------------------------------
  void clearFilters() {
    _initDates();
    reportData.clear();
    _rawData.clear();
    hasSearched.value = false;
    _resetTotals();
  }

  // ---------------------------------------------------------------------------
  // صلاحيات
  // ---------------------------------------------------------------------------
  bool canPrint() => userState.canPrint(_kSupplierMovementScreen);

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
    _invoiceTemplatesController.selectTemplate(_kSupplierMovementScreen);
    if (_invoiceTemplatesController.companyNameController.text.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'يرجى ضبط قالب التقرير في الإعدادات أولاً.',
          isError: true);
      return;
    }
    Get.to(() => SupplierMovementPdfView(
          reportData: reportData.toList(),
          fromDate: fromDate.value,
          toDate: toDate.value,
          grandOpeningBalance: grandOpeningBalance.value,
          grandTotalPurchases: grandTotalPurchases.value,
          grandTotalReturns: grandTotalReturns.value,
          grandNetPurchases: grandNetPurchases.value,
          grandTotalPayments: grandTotalPayments.value,
          grandTotalAdjustments: grandTotalAdjustments.value,
          grandBalance: grandBalance.value,
          showAccountName: showAccountName.value,
          showSupplierName: showSupplierName.value,
          showDepartment: showDepartment.value,
          showBranch: showBranch.value,
          showInventoryValue: showInventoryValue.value,
          isDetailedMode: isDetailedMode,
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
  String formatCurrency(dynamic value) {
    if (value == null) return '0';
    final double v = value is double
        ? value
        : (double.tryParse(value.toString()) ?? 0.0);
    return NumberFormat('#,###.##', 'en_US').format(v);
  }
}

/// دالة المعالجة في Isolate منفصل لتقرير حركة الموردين
Map<String, dynamic> _parseSupplierMovementInIsolate(Map<String, dynamic> params) {
  final String rawJson = params['rawJson'] as String;
  final bool isDetailedMode = params['isDetailedMode'] as bool? ?? false;
  final bool excludeZero = params['excludeZero'] as bool? ?? false;

  final Map<String, dynamic> json = jsonDecode(rawJson) as Map<String, dynamic>;
  final list = json['data'] as List?;
  if (list == null || list.isEmpty) {
    return {
      'rows': <Map<String, dynamic>>[],
      'grandOpeningBalance': 0.0,
      'grandTotalPurchases': 0.0,
      'grandTotalReturns': 0.0,
      'grandNetPurchases': 0.0,
      'grandTotalPayments': 0.0,
      'grandTotalAdjustments': 0.0,
      'grandBalance': 0.0,
      'grandOpeningBalanceStr': '0',
      'grandTotalPurchasesStr': '0',
      'grandTotalReturnsStr': '0',
      'grandNetPurchasesStr': '0',
      'grandTotalPaymentsStr': '0',
      'grandTotalAdjustmentsStr': '0',
      'grandBalanceStr': '0',
    };
  }

  final nf = NumberFormat('#,###.##', 'en_US');

  double toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  final List<Map<String, dynamic>> rows = [];
  double sumOpening = 0.0;
  double sumPurchases = 0.0;
  double sumReturns = 0.0;
  double sumNet = 0.0;
  double sumPayments = 0.0;
  double sumAdjustments = 0.0;
  double sumBalance = 0.0;

  String? lastAccNo;

  for (int i = 0; i < list.length; i++) {
    final item = list[i] as Map<String, dynamic>;
    final double balance = toDouble(item['balance']);

    if (excludeZero && balance == 0.0) {
      continue;
    }

    final double opening = toDouble(item['openingBalance'] ?? item['opening_balance']);
    final double purchases = toDouble(item['totalPurchases'] ?? item['total_purchases']);
    final double returns = toDouble(item['totalReturns'] ?? item['total_returns']);
    final double net = toDouble(item['netPurchases'] ?? item['net_purchases']);
    final double payments = toDouble(item['totalPayments'] ?? item['total_payments']);
    final double adjustments = toDouble(item['totalAdjustments'] ?? item['total_adjustments']);
    final double inventory = toDouble(item['inventoryValue'] ?? item['inventory_value']);
    final double difference = toDouble(item['difference']);

    sumOpening += opening;
    sumPurchases += purchases;
    sumReturns += returns;
    sumNet += net;
    sumPayments += payments;
    sumAdjustments += adjustments;
    sumBalance += balance;

    final String currAccNo = (item['accountNumber'] ?? item['account_number'] ?? '').toString();
    final String supplierName = (item['supplierName'] ?? item['supplier_name'] ?? '').toString();

    String displayedSupplierName = supplierName;
    bool isFirstRowForSupplier = true;

    if (isDetailedMode) {
      if (lastAccNo != null && currAccNo == lastAccNo) {
        displayedSupplierName = '...';
        isFirstRowForSupplier = false;
      } else {
        isFirstRowForSupplier = true;
      }
      lastAccNo = currAccNo;
    }

    rows.add({
      'account_number': currAccNo,
      'account_name': (item['accountName'] ?? item['account_name'] ?? '').toString(),
      'supplier_name': supplierName,
      'displayed_supplier_name': displayedSupplierName,
      'department_id': (item['departmentId'] ?? item['department_id'] ?? '').toString(),
      'branch_id': (item['branchId'] ?? item['branch_id'] ?? '').toString(),
      'opening_balance': opening,
      'opening_balance_str': nf.format(opening),
      'total_purchases': purchases,
      'total_purchases_str': nf.format(purchases),
      'total_returns': returns,
      'total_returns_str': nf.format(returns),
      'net_purchases': net,
      'net_purchases_str': nf.format(net),
      'total_payments': payments,
      'total_payments_str': nf.format(payments),
      'total_adjustments': adjustments,
      'total_adjustments_str': nf.format(adjustments),
      'balance': balance,
      'balance_str': nf.format(balance),
      'inventory_value': inventory,
      'inventory_value_str': nf.format(inventory),
      'difference': difference,
      'difference_str': nf.format(difference),
      'last_payment_date': (item['lastPaymentDate'] ?? item['last_payment_date'] ?? '').toString(),
      'invoice_date': (item['invoiceDate'] ?? item['invoice_date'] ?? '').toString(),
      'invoice_number': (item['invoiceNumber'] ?? item['invoice_number'] ?? '').toString(),
      'is_first_row': isFirstRowForSupplier,
    });
  }

  return {
    'rows': rows,
    'grandOpeningBalance': sumOpening,
    'grandTotalPurchases': sumPurchases,
    'grandTotalReturns': sumReturns,
    'grandNetPurchases': sumNet,
    'grandTotalPayments': sumPayments,
    'grandTotalAdjustments': sumAdjustments,
    'grandBalance': sumBalance,
    'grandOpeningBalanceStr': nf.format(sumOpening),
    'grandTotalPurchasesStr': nf.format(sumPurchases),
    'grandTotalReturnsStr': nf.format(sumReturns),
    'grandNetPurchasesStr': nf.format(sumNet),
    'grandTotalPaymentsStr': nf.format(sumPayments),
    'grandTotalAdjustmentsStr': nf.format(sumAdjustments),
    'grandBalanceStr': nf.format(sumBalance),
  };
}

