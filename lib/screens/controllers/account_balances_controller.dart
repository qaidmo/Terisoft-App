import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/services/offline_report_query_service.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/account_balances_models.dart';
import '../../models/cost_center_profit_margin_models.dart';
import '../pdf/account_balances_pdf_view.dart';

class AccountBalancesController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final ReportRepository _reportRepository = ReportRepository();
  final InvoiceTemplatesController _invoiceTemplatesController =
      Get.find<InvoiceTemplatesController>();
  final UserState userState = Get.find<UserState>();

  String? _lastLoadedRawJson;

  // --- Filter state ---
  late Rx<DateTime> fromDate;
  late Rx<DateTime> toDate;
  final RxList<Map<String, dynamic>> allBranches = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> selectedBranch = Rxn<Map<String, dynamic>>();

  // --- Currency: always local currency — no dropdown, always null ---
  // (currencyId = null means "local currency / no filter" on the server)

  // --- Grouping mode (single-choice) ---
  final RxString selectedMode = 'byMovementAccount'.obs;

  // قائمة الأوضاع المدعومة
  static const List<Map<String, String>> groupingModes = [
    {'key': 'byMovementAccount',   'label': 'حسب الحساب الحركي'},
    {'key': 'byTransactionName',   'label': 'حسب اسم الحركة'},
    {'key': 'byCostCenter',        'label': 'حسب مراكز التكلفة'},
    {'key': 'byBeneficiary',       'label': 'حسب اسم المستفيد'},
    {'key': 'byCostCenterAndAccount', 'label': 'حسب المركز والحساب'},
    {'key': 'analyticalAll',       'label': 'الحساب تحليلي'},
  ];

  // --- Settings state ---
  final RxBool excludeZero = false.obs;

  // --- Result state ---
  final RxBool isLoading = false.obs;
  final RxList<AccountBalancesRow> rows = <AccountBalancesRow>[].obs;

  // Grand totals
  final RxDouble grandOpeningDebit = 0.0.obs;
  final RxDouble grandOpeningCredit = 0.0.obs;
  final RxDouble grandPeriodDebit = 0.0.obs;
  final RxDouble grandPeriodCredit = 0.0.obs;
  final RxDouble grandTotalDebit = 0.0.obs;
  final RxDouble grandTotalCredit = 0.0.obs;
  final RxDouble grandBalanceDebit = 0.0.obs;
  final RxDouble grandBalanceCredit = 0.0.obs;
  final RxDouble grandNetBalance = 0.0.obs;
  final RxDouble grandValue = 0.0.obs;

  // ---- Profit Margin mode state ----
  final RxBool showProfitMargin = false.obs;
  final RxList<CostCenterProfitMarginRow> profitMarginRows = <CostCenterProfitMarginRow>[].obs;
  final RxDouble pmGrandNetCogs    = 0.0.obs;
  final RxDouble pmGrandGrossSales = 0.0.obs;
  final RxDouble pmGrandReturns    = 0.0.obs;
  final RxDouble pmGrandNetSales   = 0.0.obs;
  final RxDouble pmGrandNetProfit  = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month, 1).obs;
    toDate = DateTime(now.year, now.month + 1, 0).obs;
    _loadBranches();
    _loadSettings();
  }

  // =========================================================================
  // تحميل إعدادات العرض
  // =========================================================================
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      excludeZero.value = prefs.getBool('ab_excl_zero') ?? false;
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> toggleSetting(String settingName, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (settingName == 'excludeZero') {
        excludeZero.value = value;
        await prefs.setBool('ab_excl_zero', value);
      }
      
      // إعادة تقييم الفلترة دون جلب من الخادم مجدداً عبر المعالجة المعزولة السريعة
      if (_lastLoadedRawJson != null && _lastLoadedRawJson!.isNotEmpty) {
        isLoading.value = true;
        try {
          await _processRawJsonWithIsolate(_lastLoadedRawJson!);
        } finally {
          isLoading.value = false;
        }
      } else if (rows.isNotEmpty) {
        fetchReport();
      }
    } catch (e) {
      debugPrint('Error saving setting: $e');
    }
  }

  // =========================================================================
  // تحميل الفروع
  // =========================================================================
  Future<void> _loadBranches() async {
    try {
      var data = await _lookupsRepository.fetchAllBranches();
      final userBranchId = userState.safeUserBranch;

      if (!userState.isAdmin) {
        data = data
            .where((b) =>
                b['branch_id'].toString() == userBranchId.toString())
            .toList();
      }

      allBranches.assignAll(data);
      final match = data.firstWhereOrNull(
          (b) => b['branch_id'].toString() == userBranchId.toString());
      selectedBranch.value = match;
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تحميل الفروع.',
          isError: true);
    }
  }

  void onBranchSelected(Map<String, dynamic>? branch) {
    selectedBranch.value = branch;
    clearResults();
  }

  // =========================================================================
  // تغيير وضع التجميع
  // =========================================================================
  void onModeChanged(String? mode) {
    if (mode != null) {
      selectedMode.value = mode;
      // هامش الربح متاح فقط لوضع مراكز التكلفة
      if (mode != 'byCostCenter') {
        showProfitMargin.value = false;
      }
      clearResults();
    }
  }

  void onProfitMarginToggled(bool? value) {
    if (selectedMode.value != 'byCostCenter') return;
    showProfitMargin.value = value ?? false;
    clearResults();
  }

  /// بناء مفتاح الكاش
  String _buildParametersHash(int branchId, int? departmentId, int? currencyId, String mode) {
    return 'B${branchId}_D${departmentId ?? 0}_C${currencyId ?? 0}_M$mode';
  }

  // =========================================================================
  // جلب التقرير
  // =========================================================================
  Future<void> fetchReport() async {
    // --- هامش الربح: مسار بديل مستقل ---
    if (showProfitMargin.value && selectedMode.value == 'byCostCenter') {
      await fetchProfitMarginReport();
      return;
    }

    isLoading.value = true;
    clearResults();

    try {
      final int effectiveBranchId =
          (selectedBranch.value?['branch_id'] as int?) ?? userState.safeUserBranch;

      // القسم مقفل على جلسة المستخدم — لا يوجد dropdown
      final int? effectiveDeptId = userState.safeUserDepartment > 0
          ? userState.safeUserDepartment
          : null;

      // العملة: دائماً العملة المحلية (null = بدون فلتر عملة)
      const int? effectiveCurrencyId = null;

      String year = userState.safeFinancialYearName;
      if (year == 'غير محددة' || year.isEmpty) {
        year = fromDate.value.year.toString();
      }

      final String parametersHash = _buildParametersHash(
          effectiveBranchId, effectiveDeptId, effectiveCurrencyId, selectedMode.value);

      try {
        final result = await _reportRepository.getAccountBalancesWithCache(
          startDate: fromDate.value.toIso8601String(),
          endDate: toDate.value.toIso8601String(),
          year: year,
          branchId: effectiveBranchId,
          departmentId: effectiveDeptId,
          currencyId: effectiveCurrencyId,
          groupingMode: selectedMode.value,
        );

        final rawJson = result.$2;
        _lastLoadedRawJson = rawJson;

        await _processRawJsonWithIsolate(rawJson);

        // حفظ ملف الكاش وتسجيله في قاعدة البيانات
        try {
          final filePath = await ReportCacheFileManager.saveReportJsonByIdentifier(
            reportType: 'AccountBalances',
            identifier: '${selectedMode.value}_$parametersHash',
            jsonContent: rawJson,
          );

          await DatabaseHelper.instance.insertOrUpdate(
            'Offline_ReportsCache',
            {
              'ReportType': 'AccountBalances',
              'EntityIdentifier': selectedMode.value,
              'CurrencyId': (effectiveCurrencyId ?? 0).toString(),
              'ParametersHash': parametersHash,
              'file_path': filePath,
              'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
            },
            'ReportType',
          );
        } catch (cacheErr) {
          debugPrint('Error saving AccountBalances cache: $cacheErr');
        }
      } on OfflineFallbackException catch (e) {
        // --- Offline fallback ---
        final cacheResult = await DatabaseHelper.instance.query(
          'Offline_ReportsCache',
          columns: ['LastSyncTimestamp', 'file_path'],
          where:
              'ReportType = ? AND EntityIdentifier = ? AND CurrencyId = ? AND ParametersHash = ?',
          whereArgs: [
            'AccountBalances',
            selectedMode.value,
            (effectiveCurrencyId ?? 0).toString(),
            parametersHash,
          ],
        );

        if (cacheResult.isNotEmpty) {
          final syncTime = cacheResult.first['LastSyncTimestamp'];
          String? rawJson;
          final filePath = cacheResult.first['file_path']?.toString();
          if (filePath != null && filePath.isNotEmpty) {
            rawJson = await ReportCacheFileManager.readReportJson(filePath);
          }

          if (e.reason == 'CONNECTION_LOST') {
            bool proceed =
                await UiHelper.showOfflineWarningDialog(syncTime.toString());
            if (!proceed) {
              isLoading.value = false;
              return;
            }
          }

          if (rawJson != null && rawJson.isNotEmpty) {
            _lastLoadedRawJson = rawJson;
            await _processRawJsonWithIsolate(rawJson);
          } else {
            AppSnackbar.showCustomSnackbar(
              'خطأ',
              'ملف التقرير المخزن محلياً غير متاح.',
              isError: true,
            );
          }
        } else {
          final preSynced = await OfflineReportQueryService.queryPreSyncedSummaryCache(
            reportType: 'AccountBalances',
            branchId: effectiveBranchId,
            year: year,
          );
          if (preSynced != null) {
            if (e.reason == 'CONNECTION_LOST') {
              bool proceed = await UiHelper.showOfflineWarningDialog(preSynced.lastSyncTimestamp);
              if (!proceed) {
                isLoading.value = false;
                return;
              }
            }
            _lastLoadedRawJson = preSynced.rawJson;
            await _processRawJsonWithIsolate(preSynced.rawJson);
          } else {
            AppSnackbar.showCustomSnackbar(
              'خطأ',
              'لا يوجد اتصال بالإنترنت ولا توجد بيانات سابقة محفوظة.',
              isError: true,
            );
          }
        }
      }
    } catch (e) {
      if (e is! OfflineFallbackException) {
        AppSnackbar.showCustomSnackbar(
          'خطأ',
          'فشل في جلب التقرير: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================================
  // جلب تقرير هامش أرباح مراكز التكلفة
  // =========================================================================
  Future<void> fetchProfitMarginReport() async {
    isLoading.value = true;
    clearResults();

    try {
      final int effectiveBranchId =
          (selectedBranch.value?['branch_id'] as int?) ?? userState.safeUserBranch;

      final int? effectiveDeptId = userState.safeUserDepartment > 0
          ? userState.safeUserDepartment
          : null;

      String year = userState.safeFinancialYearName;
      if (year == 'غير محددة' || year.isEmpty) {
        year = fromDate.value.year.toString();
      }

      final response = await _reportRepository.getCostCenterProfitMargin(
        startDate: fromDate.value.toIso8601String(),
        endDate:   toDate.value.toIso8601String(),
        year:       year,
        branchId:   effectiveBranchId,
        departmentId: effectiveDeptId,
      );

      if (response.rows.isEmpty) {
        AppSnackbar.showCustomSnackbar(
            'معلومات', 'لا توجد بيانات مبيعات لمراكز التكلفة في الفترة المحددة.');
        return;
      }

      profitMarginRows.assignAll(response.rows);
      pmGrandNetCogs.value    = response.grandNetCogs;
      pmGrandGrossSales.value = response.grandGrossSales;
      pmGrandReturns.value    = response.grandReturns;
      pmGrandNetSales.value   = response.grandNetSales;
      pmGrandNetProfit.value  = response.grandNetProfit;
    } catch (e) {
      AppSnackbar.showCustomSnackbar(
        'خطأ',
        'فشل في جلب تقرير هامش الربح: ${e.toString()}',
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // =========================================================================
  // معالجة الاستجابة في Isolate منفصل
  // =========================================================================
  Future<void> _processRawJsonWithIsolate(String rawJson) async {
    try {
      final result = await compute(_parseAccountBalancesInIsolate, {
        'rawJson': rawJson,
        'excludeZero': excludeZero.value,
        'mode': selectedMode.value,
      });

      final List<AccountBalancesRow> parsedRows =
          (result['rows'] as List).cast<AccountBalancesRow>();
      final Map<String, double> totals =
          (result['grandTotals'] as Map).cast<String, double>();

      if (parsedRows.isEmpty) {
        clearResults();
        AppSnackbar.showCustomSnackbar(
          'معلومات',
          excludeZero.value
              ? 'جميع الحسابات أرصدتها صفرية أو لا توجد بيانات.'
              : 'لا توجد بيانات في الفترة المحددة بهذا الوضع.',
        );
        return;
      }

      rows.assignAll(parsedRows);
      grandOpeningDebit.value = totals['grandOpeningDebit'] ?? 0.0;
      grandOpeningCredit.value = totals['grandOpeningCredit'] ?? 0.0;
      grandPeriodDebit.value = totals['grandPeriodDebit'] ?? 0.0;
      grandPeriodCredit.value = totals['grandPeriodCredit'] ?? 0.0;
      grandTotalDebit.value = totals['grandTotalDebit'] ?? 0.0;
      grandTotalCredit.value = totals['grandTotalCredit'] ?? 0.0;
      grandBalanceDebit.value = totals['grandBalanceDebit'] ?? 0.0;
      grandBalanceCredit.value = totals['grandBalanceCredit'] ?? 0.0;
      grandNetBalance.value = totals['grandNetBalance'] ?? 0.0;
      grandValue.value = totals['grandValue'] ?? 0.0;
    } catch (e) {
      debugPrint('Error parsing account balances in isolate: $e');
      AppSnackbar.showCustomSnackbar(
        'خطأ',
        'حدث خطأ أثناء معالجة بيانات التقرير.',
        isError: true,
      );
    }
  }

  // =========================================================================
  // مسح النتائج
  // =========================================================================
  void clearResults() {
    _lastLoadedRawJson = null;
    rows.clear();
    grandOpeningDebit.value = 0.0;
    grandOpeningCredit.value = 0.0;
    grandPeriodDebit.value = 0.0;
    grandPeriodCredit.value = 0.0;
    grandTotalDebit.value = 0.0;
    grandTotalCredit.value = 0.0;
    grandBalanceDebit.value = 0.0;
    grandBalanceCredit.value = 0.0;
    grandNetBalance.value = 0.0;
    grandValue.value = 0.0;
    // مسح حالة هامش الربح
    profitMarginRows.clear();
    pmGrandNetCogs.value    = 0.0;
    pmGrandGrossSales.value = 0.0;
    pmGrandReturns.value    = 0.0;
    pmGrandNetSales.value   = 0.0;
    pmGrandNetProfit.value  = 0.0;
  }

  void clearForm() {
    final now = DateTime.now();
    fromDate.value = DateTime(now.year, now.month, 1);
    toDate.value = DateTime(now.year, now.month + 1, 0);
    selectedMode.value = 'byMovementAccount';
    clearResults();
  }

  // =========================================================================
  // طباعة PDF
  // =========================================================================
  void printReport() {
    _invoiceTemplatesController.selectTemplate('AccountBalancesScreen');
    if (_invoiceTemplatesController.companyNameController.text.isEmpty) {
      _invoiceTemplatesController.selectTemplate('AccountStatementScreen');
    }

    // --- هامش الأرباح: مسار طباعة مستقل ---
    if (showProfitMargin.value && profitMarginRows.isNotEmpty) {
      Get.to(() => AccountBalancesPdfView(
            reportData: const [],
            fromDate: fromDate.value,
            toDate: toDate.value,
            reportTitle: 'تقرير هامش أرباح مراكز التكلفة',
            groupingMode: 'byCostCenter',
            grandTotals: const {},
            showProfitMargin: true,
            profitMarginData: profitMarginRows
                .map((r) => {
                      'costCenterId':   r.costCenterId,
                      'costCenterName': r.costCenterName,
                      'netCogs':        r.netCogs,
                      'grossSales':     r.grossSales,
                      'returns':        r.returns,
                      'netSales':       r.netSales,
                      'netProfit':      r.netProfit,
                      'profitPct':      r.profitPct,
                    })
                .toList(),
            pmGrandTotals: {
              'pmGrandNetCogs':    pmGrandNetCogs.value,
              'pmGrandGrossSales': pmGrandGrossSales.value,
              'pmGrandReturns':    pmGrandReturns.value,
              'pmGrandNetSales':   pmGrandNetSales.value,
              'pmGrandNetProfit':  pmGrandNetProfit.value,
            },
            companyName: _invoiceTemplatesController.companyNameController.text,
            companyAddress:
                _invoiceTemplatesController.addressDetailsController.text,
            contactInfo: _invoiceTemplatesController.contactInfoController.text,
            thanksMessage:
                _invoiceTemplatesController.thanksMessageController.text,
            logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
            showLogo: _invoiceTemplatesController.showLogo.value,
            userName: userState.safeUserName,
            userBranchName: userState.safeUserBranchName,
            userDepartmentName: userState.safeUserDepartmentName,
          ));
      return;
    }

    // --- التقرير القياسي ---
    if (rows.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'لا توجد بيانات لطباعتها. يرجى عرض التقرير أولاً.',
          isError: true);
      return;
    }

    final modeName = groupingModes
        .firstWhere((m) => m['key'] == selectedMode.value,
            orElse: () => {'label': 'أرصدة الحسابات'})['label']!;

    Get.to(() => AccountBalancesPdfView(
          reportData: rows.map((r) => r.toJson()).toList(),
          fromDate: fromDate.value,
          toDate: toDate.value,
          reportTitle: 'تقرير أرصدة الحسابات - $modeName',
          groupingMode: selectedMode.value,
          companyName: _invoiceTemplatesController.companyNameController.text,
          companyAddress:
              _invoiceTemplatesController.addressDetailsController.text,
          contactInfo: _invoiceTemplatesController.contactInfoController.text,
          thanksMessage:
              _invoiceTemplatesController.thanksMessageController.text,
          logoUrl: _invoiceTemplatesController.currentLogoUrl.value,
          showLogo: _invoiceTemplatesController.showLogo.value,
          userName: userState.safeUserName,
          userBranchName: userState.safeUserBranchName,
          userDepartmentName: userState.safeUserDepartmentName,
          grandTotals: {
            'grandOpeningDebit':  grandOpeningDebit.value,
            'grandOpeningCredit': grandOpeningCredit.value,
            'grandPeriodDebit':   grandPeriodDebit.value,
            'grandPeriodCredit':  grandPeriodCredit.value,
            'grandTotalDebit':    grandTotalDebit.value,
            'grandTotalCredit':   grandTotalCredit.value,
            'grandBalanceDebit':  grandBalanceDebit.value,
            'grandBalanceCredit': grandBalanceCredit.value,
            'grandNetBalance':    grandNetBalance.value,
            'grandValue':         grandValue.value,
          },
        ));
  }
}

/// دالة المعالجة في Isolate منفصل لتقرير أرصدة الحسابات
Map<String, dynamic> _parseAccountBalancesInIsolate(Map<String, dynamic> params) {
  final String rawJson = params['rawJson'] as String;
  final bool excludeZero = params['excludeZero'] as bool;
  final String mode = params['mode'] as String;

  final Map<String, dynamic> json = jsonDecode(rawJson) as Map<String, dynamic>;
  final list = json['rows'] as List?;
  if (list == null || list.isEmpty) {
    return {
      'rows': <AccountBalancesRow>[],
      'grandTotals': <String, double>{},
    };
  }

  String combine(String a, String b) {
    if (a.isEmpty && b.isEmpty) return '';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a - $b';
  }

  final nf = NumberFormat('#,##0.00', 'en_US');

  final List<AccountBalancesRow> parsedRows = [];
  double grandOpeningDebit = 0.0;
  double grandOpeningCredit = 0.0;
  double grandPeriodDebit = 0.0;
  double grandPeriodCredit = 0.0;
  double grandTotalDebit = 0.0;
  double grandTotalCredit = 0.0;
  double grandBalanceDebit = 0.0;
  double grandBalanceCredit = 0.0;

  for (final item in list) {
    final map = item as Map<String, dynamic>;
    final double netBalance = (map['netBalance'] as num?)?.toDouble() ?? 0.0;
    if (excludeZero && netBalance == 0) {
      continue;
    }

    final String entityId = map['entityId']?.toString() ?? '';
    final String entityName = map['entityName']?.toString() ?? '';
    final String accountName = map['accountName']?.toString() ?? '';
    final String beneficiaryName = map['beneficiaryName']?.toString() ?? '';
    final String costCenterName = map['costCenterName']?.toString() ?? '';

    final double openingDebit = (map['openingDebit'] as num?)?.toDouble() ?? 0.0;
    final double openingCredit = (map['openingCredit'] as num?)?.toDouble() ?? 0.0;
    final double periodDebit = (map['periodDebit'] as num?)?.toDouble() ?? 0.0;
    final double periodCredit = (map['periodCredit'] as num?)?.toDouble() ?? 0.0;
    final double totalDebit = (map['totalDebit'] as num?)?.toDouble() ?? 0.0;
    final double totalCredit = (map['totalCredit'] as num?)?.toDouble() ?? 0.0;
    final double balanceDebit = (map['balanceDebit'] as num?)?.toDouble() ?? 0.0;
    final double balanceCredit = (map['balanceCredit'] as num?)?.toDouble() ?? 0.0;
    final double val = (map['value'] as num?)?.toDouble() ?? 0.0;

    String col1;
    String col2;
    switch (mode) {
      case 'byMovementAccount':
      case 'analyticalAll':
        col1 = entityId;
        col2 = entityName;
        break;
      case 'byTransactionName':
        col1 = entityId;
        col2 = entityName;
        break;
      case 'byCostCenter':
        col1 = entityId;
        col2 = entityName;
        break;
      case 'byBeneficiary':
        col1 = '';
        col2 = combine(beneficiaryName, accountName);
        break;
      case 'byCostCenterAndAccount':
        col1 = entityId;
        col2 = combine(costCenterName, entityName);
        break;
      default:
        col1 = entityId;
        col2 = entityName;
    }

    parsedRows.add(AccountBalancesRow(
      entityId: entityId,
      entityName: entityName,
      accountName: accountName,
      beneficiaryName: beneficiaryName,
      costCenterName: costCenterName,
      openingDebit: openingDebit,
      openingCredit: openingCredit,
      periodDebit: periodDebit,
      periodCredit: periodCredit,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      balanceDebit: balanceDebit,
      balanceCredit: balanceCredit,
      netBalance: netBalance,
      value: val,
      openingDebitStr: nf.format(openingDebit),
      openingCreditStr: nf.format(openingCredit),
      periodDebitStr: nf.format(periodDebit),
      periodCreditStr: nf.format(periodCredit),
      totalDebitStr: nf.format(totalDebit),
      totalCreditStr: nf.format(totalCredit),
      balanceDebitStr: nf.format(balanceDebit),
      balanceCreditStr: nf.format(balanceCredit),
      netBalanceStr: nf.format(netBalance),
      valueStr: nf.format(val),
      col1: col1,
      col2: col2,
    ));

    grandOpeningDebit += openingDebit;
    grandOpeningCredit += openingCredit;
    grandPeriodDebit += periodDebit;
    grandPeriodCredit += periodCredit;
    grandTotalDebit += totalDebit;
    grandTotalCredit += totalCredit;
    grandBalanceDebit += balanceDebit;
    grandBalanceCredit += balanceCredit;
  }

  final double computedNet = grandTotalDebit - grandTotalCredit;

  return {
    'rows': parsedRows,
    'grandTotals': {
      'grandOpeningDebit': grandOpeningDebit,
      'grandOpeningCredit': grandOpeningCredit,
      'grandPeriodDebit': grandPeriodDebit,
      'grandPeriodCredit': grandPeriodCredit,
      'grandTotalDebit': grandTotalDebit,
      'grandTotalCredit': grandTotalCredit,
      'grandBalanceDebit': grandBalanceDebit,
      'grandBalanceCredit': grandBalanceCredit,
      'grandNetBalance': computedNet,
      'grandValue': computedNet.abs(),
    }
  };
}

