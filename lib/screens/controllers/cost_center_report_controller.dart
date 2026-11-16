import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/models/cost_center.dart';
import 'package:untitled4/models/cost_center_transaction.dart';
import 'package:untitled4/models/cost_center_report_models.dart';
import 'package:untitled4/admin/printing/cost_center_pdf_view.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/user_state.dart';

import '../../utils/snackbar_helper.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

const String _kCurrentScreenName = 'CostCenterScreen';

class CostCenterReportController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final ReportRepository _reportRepository = ReportRepository();
  final UserState userState = Get.find<UserState>();

  var isLoading = false.obs;
  var transactions = <CostCenterTransaction>[].obs;
  var startDate = Rxn<DateTime>();
  var endDate = Rxn<DateTime>();

  var selectedCostCenter = Rx<CostCenter?>(null);
  var allCostCenters = <CostCenter>[].obs;
  var filteredCostCenters = <CostCenter>[].obs;
  late TextEditingController searchController;

  @override
  void onInit() {
    super.onInit();

    if (!userState.canAccessScreen(_kCurrentScreenName)) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'ليس لديك الصلاحية للوصول إلى هذه الشاشة.',
          isError: true);
      Future.delayed(Duration.zero, () => Get.back());
      return;
    }

    searchController = TextEditingController();
    searchController.addListener(() => filterCenters(searchController.text));

    final now = DateTime.now();
    startDate.value = DateTime(now.year, now.month, 1);
    endDate.value = now;

    fetchAllCostCenters();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: startDate.value ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: endDate.value ?? DateTime(2030),
    );
    if (picked != null) startDate.value = picked;
  }

  Future<void> selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: endDate.value ?? DateTime.now(),
      firstDate: startDate.value ?? DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      endDate.value =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    }
  }

  Future<void> fetchAllCostCenters() async {
    try {
      final response = await _lookupsRepository.fetchAllCostCenters();
      allCostCenters
          .assignAll(response.map((data) => CostCenter.fromJson(data)).toList());
      filteredCostCenters.value = allCostCenters;
    } catch (e) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'فشل في جلب قائمة مراكز التكلفة: ${e.toString()}',
          isError: true);
    }
  }

  void filterCenters(String query) {
    if (query.isEmpty) {
      filteredCostCenters.value = allCostCenters;
    } else {
      filteredCostCenters.value = allCostCenters.where((center) {
        return center.centerName.toLowerCase().contains(query.toLowerCase()) ||
            center.centerNo.toString().contains(query);
      }).toList();
    }
  }

  void selectCostCenter(CostCenter center) {
    selectedCostCenter.value = center;
    transactions.clear();
    Get.back();
  }

  Future<void> fetchReportData() async {
    if (selectedCostCenter.value == null) {
      AppSnackbar.showCustomSnackbar('خطأ', 'يرجى اختيار مركز تكلفة أولاً.',
          isError: true);
      return;
    }
    if (startDate.value == null || endDate.value == null) {
      AppSnackbar.showCustomSnackbar('خطأ', 'يرجى تحديد فترة زمنية صالحة.',
          isError: true);
      return;
    }

    isLoading.value = true;
    transactions.clear();

    try {
      final String paramHash =
          '${DateFormat('yyyy-MM-dd').format(startDate.value!)}'
          '|${DateFormat('yyyy-MM-dd').format(endDate.value!)}';
      final String entityId = selectedCostCenter.value!.centerNo.toString();

      try {
        final result = await _reportRepository.getCostCenterTransactionsWithCache(
          costCenterNo: selectedCostCenter.value!.centerNo,
          fromDate:     startDate.value!.toIso8601String(),
          toDate:       endDate.value!.toIso8601String(),
        );

        final rawJson = result.$2;
          await _processRawJsonWithIsolate(rawJson);

        // حفظ ملف الكاش
        // حفظ ملف الكاش
        try {
          final filePath = await ReportCacheFileManager.saveReportJson(
          reportType: 'CostCenter',
          entityId: entityId,
          currencyId: '0',
          paramsHash: paramHash,
          rawJson: rawJson,
        );

        await DatabaseHelper.instance.insertOrUpdate(
          'Offline_ReportsCache',
          {
            'ReportType':        'CostCenter',
            'EntityIdentifier':  entityId,
            'CurrencyId':        '0',
            'ParametersHash':    paramHash,
            'file_path':         filePath,
            'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
          },
          'ReportType',
        );

        } catch (cacheErr) {
          debugPrint('Error saving CostCenter cache: $cacheErr');
        }

        // _processRawJsonWithIsolate already executed above

      } on OfflineFallbackException catch (e) {
        final cacheResult = await DatabaseHelper.instance.query(
          'Offline_ReportsCache',
          columns: ['LastSyncTimestamp', 'file_path'],
          where:
              'ReportType = ? AND EntityIdentifier = ? AND CurrencyId = ? AND ParametersHash = ?',
          whereArgs: ['CostCenter', entityId, '0', paramHash],
        );

        if (cacheResult.isNotEmpty) {
          final syncTime = cacheResult.first['LastSyncTimestamp'].toString();
          final preFilePath = cacheResult.first['file_path']?.toString();
          String? rawJson = (preFilePath != null && preFilePath.isNotEmpty)
              ? await ReportCacheFileManager.readReportJson(preFilePath)
              : null;
          if (e.reason == 'CONNECTION_LOST') {
            final proceed = await UiHelper.showOfflineWarningDialog(syncTime);
            if (!proceed) { isLoading.value = false; return; }
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
          'خطأ',
          'فشل في جلب حركات مركز التكلفة: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _processRawJsonWithIsolate(String rawJson) async {
    try {
      final parsed = await compute(_parseCostCenterTransactionsInIsolate, rawJson);
      transactions.assignAll(parsed);
      if (transactions.isEmpty) {
        AppSnackbar.showCustomSnackbar(
            'ملاحظة', 'لا توجد حركات لعرضها في هذه الفترة.');
      }
    } catch (e) {
      debugPrint('Error parsing cost center transactions in isolate: $e');
      AppSnackbar.showCustomSnackbar(
        'خطأ',
        'حدث خطأ أثناء معالجة بيانات التقرير.',
        isError: true,
      );
    }
  }

  Future<void> printReport() async {
    if (!userState.canPrint(_kCurrentScreenName)) {
      AppSnackbar.showCustomSnackbar(
          'صلاحيات', 'ليس لديك صلاحية لطباعة هذا التقرير.',
          isError: true);
      return;
    }

    if (transactions.isEmpty) {
      AppSnackbar.showCustomSnackbar('خطأ', 'لا توجد بيانات للطباعة.',
          isError: true);
      return;
    }

    final invoiceTemplatesController = Get.find<InvoiceTemplatesController>();
    invoiceTemplatesController.selectTemplate(_kCurrentScreenName);

    if (invoiceTemplatesController.companyNameController.text.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'يرجى ضبط قالب التقرير في الإعدادات أولاً.',
          isError: true);
      return;
    }

    final double totalDebit =
    transactions.fold(0.0, (sum, tx) => sum + tx.debit);
    final double totalCredit =
    transactions.fold(0.0, (sum, tx) => sum + tx.credit);
    final double finalBalance =
    transactions.isEmpty ? 0.0 : transactions.last.balance;

    Get.to(() => CostCenterReportPdfView(
      centerName: selectedCostCenter.value!.centerName,
      centerNo: selectedCostCenter.value!.centerNo.toString(),
      fromDate: startDate.value!,
      toDate: endDate.value!,
      transactions: transactions.toList(),
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      finalBalance: finalBalance,
      companyName: invoiceTemplatesController.companyNameController.text,
      companyAddress:
      invoiceTemplatesController.addressDetailsController.text,
      contactInfo: invoiceTemplatesController.contactInfoController.text,
      thanksMessage: invoiceTemplatesController.thanksMessageController.text,
      logoUrl: invoiceTemplatesController.currentLogoUrl.value,
      showLogo: invoiceTemplatesController.showLogo.value,
      userName: userState.safeUserName,
      userBranchName: userState.safeUserBranchName,
      userDepartmentName: userState.safeUserDepartmentName,
    ));
  }
}

/// دالة المعالجة في Isolate منفصل لحركات مركز التكلفة
List<CostCenterTransaction> _parseCostCenterTransactionsInIsolate(String rawJson) {
  final Map<String, dynamic> json = jsonDecode(rawJson) as Map<String, dynamic>;
  final list = json['transactions'] as List?;
  if (list == null || list.isEmpty) return [];

  double runningBalance = 0.0;
  final List<CostCenterTransaction> newTransactions = [];
  for (var record in list) {
    final map = record as Map<String, dynamic>;
    final double debit = (map['debit'] as num?)?.toDouble() ?? 0.0;
    final double credit = (map['credit'] as num?)?.toDouble() ?? 0.0;
    runningBalance += (debit - credit);
    newTransactions.add(
      CostCenterTransaction.fromResponse(map, runningBalance),
    );
  }
  return newTransactions;
}