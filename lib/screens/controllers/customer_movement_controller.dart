import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/models/sun_customer.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/screens/pdf/customer_movement_pdf_view.dart';
import 'package:untitled4/user_state.dart';
import '../../models/customer_activity_models.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../utils/snackbar_helper.dart';

const String _kCurrentScreenName = 'ClientsMovementScreen';

class CustomerMovementController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final ReportRepository _reportRepository = ReportRepository();
  final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController =
  Get.find<InvoiceTemplatesController>();

  late Rx<DateTime> fromDate;
  late Rx<DateTime> toDate;
  final Rxn<SunCustomer> selectedCustomer = Rxn<SunCustomer>();
  final Rxn<SunCurrency> selectedCurrency = Rxn<SunCurrency>();
  final RxList<SunCurrency> allCurrencies = <SunCurrency>[].obs;
  final RxBool isCurrencyListLoading = true.obs;

  final RxBool isLoading = false.obs;
  final RxBool hasSearched = false.obs;
  final RxList<Map<String, dynamic>> reportData = <Map<String, dynamic>>[].obs;
  final RxList<SunCustomer> allCustomers = <SunCustomer>[].obs;
  final RxBool isCustomerListLoading = true.obs;
  String? _lastLoadedRawJson;

  @override
  void onInit() {
    super.onInit();
    if (!userState.canAccessScreen(_kCurrentScreenName)) {
      AppSnackbar.showCustomSnackbar(
          'صلاحيات', 'ليس لديك صلاحية الوصول لهذه الشاشة.');
      Future.delayed(Duration.zero, () => Get.back());
      return;
    }

    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month, 1).obs;
    toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59).obs;

    _fetchAllCustomers();
    _fetchAllCurrencies();
  }

  Future<void> _fetchAllCustomers() async {
    try {
      isCustomerListLoading.value = true;
      final response = await _lookupsRepository.fetchAllCustomers();
      allCustomers.assignAll(response);
    } catch (e) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'فشل في جلب قائمة العملاء: ${e.toString()}',
          isError: true);
    } finally {
      isCustomerListLoading.value = false;
    }
  }

  Future<void> _fetchAllCurrencies() async {
    try {
      isCurrencyListLoading.value = true;
      final response = await _lookupsRepository.fetchAllCurrencies();
      allCurrencies.assignAll(response);

      if (allCurrencies.isNotEmpty) {
        final localCurrency = allCurrencies.firstWhere(
              (c) => c.currencyName.trim() == 'ريال يمني',
          orElse: () => allCurrencies.first,
        );
        selectedCurrency.value = localCurrency;
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'فشل في جلب قائمة العملات: ${e.toString()}',
          isError: true);
    } finally {
      isCurrencyListLoading.value = false;
    }
  }

  Future<void> fetchReportData() async {
    if (selectedCurrency.value == null) {
      AppSnackbar.showCustomSnackbar('خطأ', 'الرجاء اختيار العملة أولاً.',
          isError: true);
      return;
    }

    isLoading.value = true;
    hasSearched.value = true;
    reportData.clear();

    try {
      String? currentYear = userState.financialYearName;
      if (currentYear == null || currentYear.isEmpty) {
        currentYear = DateTime.now().year.toString();
      }

      int branchId = userState.safeUserBranch;
      int departmentId = userState.safeUserDepartment;

      try {
        final result = await _reportRepository.getCustomerActivitySummaryWithCache(
          startDate: fromDate.value.toIso8601String(),
          endDate: toDate.value.toIso8601String(),
          year: currentYear,
          branchId: branchId,
          departmentId: departmentId,
          currencyId: selectedCurrency.value!.currencyNo,
          userId: null,
        );

        final rawJson = result.$2;
        _lastLoadedRawJson = rawJson;

        String paramHash = '${DateFormat('yyyy-MM-dd').format(fromDate.value)}|${DateFormat('yyyy-MM-dd').format(toDate.value)}';
          await _processRawJsonWithIsolate(rawJson);

        // حفظ ملف الكاش
        try {
          final filePath = await ReportCacheFileManager.saveReportJson(
          reportType: 'CustomerActivity',
          entityId: 'ALL',
          currencyId: selectedCurrency.value!.currencyNo.toString(),
          paramsHash: paramHash,
          rawJson: rawJson,
        );

        await DatabaseHelper.instance.insertOrUpdate(
          'Offline_ReportsCache',
          {
            'ReportType': 'CustomerActivity',
            'EntityIdentifier': 'ALL',
            'CurrencyId': selectedCurrency.value!.currencyNo.toString(),
            'ParametersHash': paramHash,
            'file_path': filePath,
            'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
          },
          'ReportType'
        );

        final String sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
        await DatabaseHelper.instance.database.then((db) =>
            db.delete('Offline_ReportsCache',
                where: "ReportType = 'CustomerActivity' AND LastSyncTimestamp < ?",
                whereArgs: [sevenDaysAgo]));
        } catch (cacheErr) {
          debugPrint('Error saving CustomerActivity cache: $cacheErr');
        }

        // _processRawJsonWithIsolate already executed above
      } on OfflineFallbackException catch (e) {
        String offlineHash = '${DateFormat('yyyy-MM-dd').format(fromDate.value)}|${DateFormat('yyyy-MM-dd').format(toDate.value)}';
        final cacheResult = await DatabaseHelper.instance.query(
          'Offline_ReportsCache',
          columns: ['LastSyncTimestamp', 'file_path', 'ParametersHash'],
          where: 'ReportType = ? AND CurrencyId = ? AND ParametersHash = ?',
          whereArgs: ['CustomerActivity', selectedCurrency.value!.currencyNo.toString(), offlineHash]
        );

        if (cacheResult.isNotEmpty) {
          final syncTime = cacheResult.first['LastSyncTimestamp'];
          final preFilePath = cacheResult.first['file_path']?.toString();
          String? rawJson = (preFilePath != null && preFilePath.isNotEmpty)
              ? await ReportCacheFileManager.readReportJson(preFilePath)
              : null;
          String lockedDatesRange = cacheResult.first['ParametersHash'].toString();
          
          if (lockedDatesRange.contains('|')) {
             var dates = lockedDatesRange.split('|');
             if (dates.length == 2) {
                var d1 = DateTime.tryParse(dates[0]);
                var d2 = DateTime.tryParse(dates[1]);
                if (d1 != null && d2 != null) {
                   lockedDatesRange = '${d1.year}-${d1.month}-${d1.day} إلى ${d2.year}-${d2.month}-${d2.day}';
                }
             }
          }

          if (e.reason == 'CONNECTION_LOST') {
            bool proceed = await UiHelper.showOfflineWarningDialog(syncTime.toString(), lockedDateRange: lockedDatesRange);
            if (!proceed) {
              isLoading.value = false;
              return;
            }
          }

          // rawJson pre-read above
          final filePath = cacheResult.first['file_path']?.toString();
          if (filePath != null && filePath.isNotEmpty && rawJson == null) {
            rawJson = await ReportCacheFileManager.readReportJson(filePath);
          }
          if (rawJson == null || rawJson.isEmpty) {
            // PayloadJson column removed in v25
          }

          if (rawJson != null && rawJson.isNotEmpty) {
            _lastLoadedRawJson = rawJson;
            await _processRawJsonWithIsolate(rawJson);
          } else {
            AppSnackbar.showCustomSnackbar('خطأ', 'ملف التقرير المخزن محلياً غير متاح.', isError: true);
          }
        } else {
          AppSnackbar.showCustomSnackbar('خطأ', 'البيانات المحلية غير متوفرة لهذا النطاق الزمني المحدد. يرجى الاتصال بالإنترنت.', isError: true);
        }
      }
    } catch (e) {
      if (e is! OfflineFallbackException) {
        AppSnackbar.showCustomSnackbar('خطأ', 'فشل في جلب بيانات التقرير: ${e.toString()}', isError: true);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _processRawJsonWithIsolate(String rawJson) async {
    try {
      final parsed = await compute(_parseCustomerMovementInIsolate, {
        'rawJson': rawJson,
        'customerName': selectedCustomer.value?.customerName,
      });

      reportData.assignAll(parsed);
      if (reportData.isEmpty && hasSearched.value) {
        AppSnackbar.showCustomSnackbar(
          'معلومات',
          'لا توجد بيانات مطابقة للعميل المحدد في الفترة المحددة.',
        );
      }
    } catch (e) {
      debugPrint('Error parsing customer activity in isolate: $e');
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ أثناء معالجة بيانات التقرير.', isError: true);
    }
  }

  void clearFilters() {
    _lastLoadedRawJson = null;
    selectedCustomer.value = null;
    reportData.clear();
    hasSearched.value = false;
    final now = DateTime.now();
    fromDate.value = DateTime(now.year, now.month, 1);
    toDate.value = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  }

  void setCustomer(SunCustomer customer) {
    selectedCustomer.value = customer;
    if (_lastLoadedRawJson != null && _lastLoadedRawJson!.isNotEmpty) {
      _processRawJsonWithIsolate(_lastLoadedRawJson!);
    }
  }

  void setCurrency(SunCurrency currency) {
    selectedCurrency.value = currency;
  }

  void removeSelectedCustomer() {
    selectedCustomer.value = null;
    if (_lastLoadedRawJson != null && _lastLoadedRawJson!.isNotEmpty) {
      _processRawJsonWithIsolate(_lastLoadedRawJson!);
    }
  }

  bool canPrint() {
    return userState.canPrint(_kCurrentScreenName);
  }

  void printReport() {
    if (!canPrint()) {
      AppSnackbar.showCustomSnackbar(
          'صلاحيات', 'ليس لديك صلاحية طباعة هذا التقرير.');
      return;
    }
    if (reportData.isEmpty) {
      AppSnackbar.showCustomSnackbar('خطأ', 'لا توجد بيانات لطباعتها.',
          isError: true);
      return;
    }

    _invoiceTemplatesController.selectTemplate(_kCurrentScreenName);

    if (_invoiceTemplatesController.companyNameController.text.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'يرجى ضبط قالب التقرير في الإعدادات أولاً.',
          isError: true);
      return;
    }

    String reportTitle = 'تقرير حركة العملاء';
    if (selectedCustomer.value != null) {
      reportTitle = 'كشف حساب العميل: ${selectedCustomer.value!.customerName}';
    }

    Get.to(() => CustomerMovementPdfView(
      reportData: reportData.toList(),
      fromDate: fromDate.value,
      toDate: toDate.value,
      reportTitle: reportTitle,
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
  }
}

/// دالة المعالجة في Isolate منفصل لتقرير حركة العملاء
List<Map<String, dynamic>> _parseCustomerMovementInIsolate(Map<String, dynamic> params) {
  final String rawJson = params['rawJson'] as String;
  final String? filterCustomerName = params['customerName'] as String?;

  final Map<String, dynamic> json = jsonDecode(rawJson) as Map<String, dynamic>;
  final list = json['data'] as List?;
  if (list == null || list.isEmpty) return [];

  final nf = NumberFormat('#,##0.00', 'en_US');
  final List<Map<String, dynamic>> result = [];

  for (var item in list) {
    final map = item as Map<String, dynamic>;
    final String cName = map['customerName']?.toString() ?? '';
    if (filterCustomerName != null && filterCustomerName.isNotEmpty && cName != filterCustomerName) {
      continue;
    }

    final double openingBalance = (map['openingBalance'] as num?)?.toDouble() ?? 0.0;
    final double sales = (map['totalSales'] as num?)?.toDouble() ?? 0.0;
    final double returns = (map['totalReturns'] as num?)?.toDouble() ?? 0.0;
    final double netSales = (map['netSales'] as num?)?.toDouble() ?? 0.0;
    final double collections = (map['totalCollections'] as num?)?.toDouble() ?? 0.0;
    final double collPct = (map['collectionPercentage'] as num?)?.toDouble() ?? 0.0;
    final double balance = (map['periodBalance'] as num?)?.toDouble() ?? 0.0;
    final double balPct = (map['balancePercentage'] as num?)?.toDouble() ?? 0.0;
    final String lastInv = map['lastInvoiceDate']?.toString() ?? '-';
    final String lastPay = map['lastPaymentDate']?.toString() ?? '-';
    final int debtAge = (map['debtAge'] as num?)?.toInt() ?? 0;

    result.add({
      'customer_name': cName,
      'customer_no': map['customerNo']?.toString() ?? '',
      'openingBalance': openingBalance,
      'sales': sales,
      'returns': returns,
      'net_sales': netSales,
      'collections': collections,
      'collection_percentage': collPct,
      'balance': balance,
      'balance_percentage': balPct,
      'last_invoice_date': lastInv,
      'last_payment_date': lastPay,
      'debt_age': debtAge,
      // Pre-formatted strings for instantaneous virtualized rendering
      'openingBalanceStr': nf.format(openingBalance),
      'salesStr': nf.format(sales),
      'returnsStr': nf.format(returns),
      'net_salesStr': nf.format(netSales),
      'collectionsStr': nf.format(collections),
      'collection_percentageStr': '${collPct.toStringAsFixed(1)}%',
      'balanceStr': nf.format(balance),
      'balance_percentageStr': '${balPct.toStringAsFixed(1)}%',
    });
  }

  return result;
}