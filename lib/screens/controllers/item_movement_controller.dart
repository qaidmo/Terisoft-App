// lib/screens/controllers/item_movement_controller.dart
// تحكم تقرير حركة الأصناف - GetX Controller مستقل تماماً

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/repositories/item_movement_repository.dart';
import 'package:untitled4/screens/pdf/item_movement_pdf_view.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../models/item_movement_models.dart';
import 'package:flutter/foundation.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'dart:convert';

const String _kScreenName = 'ItemMovementScreen';

class ItemMovementController extends GetxController {
  final ItemMovementRepository _repository = ItemMovementRepository();
  final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController =
      Get.find<InvoiceTemplatesController>();

  // ---------------------------------------------------------------------------
  // حالة الفلاتر
  // ---------------------------------------------------------------------------
  final Rx<DateTime> fromDate = DateTime.now().obs;
  final Rx<DateTime> toDate   = DateTime.now().obs;

  // نوع الحركة — حالياً "الكل" فقط، ستضاف الأنواع لاحقاً
  final RxString selectedReportType = 'all'.obs;
  final RxList<Map<String, String>> reportTypes = <Map<String, String>>[].obs;

  // مجموعة الأصناف
  final RxnString selectedItemGroupId = RxnString(null);
  final RxList<Map<String, String>> itemGroupsList = <Map<String, String>>[].obs;

  // ---------------------------------------------------------------------------
  // حالة النتائج
  // ---------------------------------------------------------------------------
  final RxBool isLoading   = false.obs;
  final RxBool hasSearched = false.obs;
  final RxList<ItemMovementRow> reportData = <ItemMovementRow>[].obs;

  // مجاميع التقرير
  final RxDouble grandTotalAmount = 0.0.obs;
  final RxDouble grandNetAmount   = 0.0.obs;
  final RxDouble grandTotalCost   = 0.0.obs;
  final RxDouble grandMargin      = 0.0.obs;
  final RxInt    rowCount         = 0.obs;

  final RxString grandTotalAmountStr = '0'.obs;
  final RxString grandNetAmountStr   = '0'.obs;
  final RxString grandTotalCostStr   = '0'.obs;
  final RxString grandMarginStr      = '0'.obs;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    _initDates();
    _loadStaticReportTypes();
    _loadItemGroups();
  }

  void _initDates() {
    final String? yearName = userState.financialYearName;
    final int currentYear = int.tryParse(yearName ?? '') ?? DateTime.now().year;
    fromDate.value = DateTime(currentYear, 1, 1);
    toDate.value   = DateTime(currentYear, 12, 31, 23, 59, 59);
  }

  /// أنواع الحركة — حالياً "الكل" فقط
  void _loadStaticReportTypes() {
    reportTypes.assignAll([
      {'value': 'all', 'display': 'الكل'},
    ]);
  }

  /// جلب مجموعات الأصناف من قاعدة البيانات المحلية SQLite
  Future<void> _loadItemGroups() async {
    try {
      final db = DatabaseHelper.instance;
      final rows = await db.query(
        'sun_item_groups',
        columns: ['group_no', 'group_name'],
        orderBy: 'group_name ASC',
      );
      itemGroupsList.assignAll(
        rows.map((r) => {
          'group_no':   r['group_no']?.toString() ?? '',
          'group_name': r['group_name']?.toString() ?? '',
        }).toList(),
      );
    } catch (e) {
      // إذا فشل الجلب نتجاهل الخطأ ويبقى الـ dropdown فارغاً
      itemGroupsList.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // جلب البيانات — مع تطبيق نطاق الأمان
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
          '|type:${selectedReportType.value}'
          '|group:${selectedItemGroupId.value ?? 'ALL'}';

      try {
        final result = await _repository.getItemMovementWithCache(
          startDate:       fromDate.value.toIso8601String(),
          endDate:         toDate.value.toIso8601String(),
          year:            currentYear,
          branchId:        userState.safeUserBranch,
          transactionType: selectedReportType.value,
          userId:          userState.isAdmin ? null : userState.userNo,
          departmentId:    userState.userDepartment,
          itemGroupId:     selectedItemGroupId.value,
        );

        final rawJson  = result.$2;

        await _processRawJsonWithIsolate(rawJson);

        try {
          final filePath = await ReportCacheFileManager.saveReportJson(
            reportType: 'ItemMovement',
            entityId: 'ALL',
            currencyId: '0',
            paramsHash: paramHash,
            rawJson: rawJson,
          );

          await DatabaseHelper.instance.insertOrUpdate(
            'Offline_ReportsCache',
            {
              'ReportType':        'ItemMovement',
              'EntityIdentifier':  'ALL',
              'CurrencyId':        '0',
              'ParametersHash':    paramHash,
              'file_path':         filePath,
              'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
            },
            'ReportType',
          );
        } catch (cacheErr) {
          debugPrint('Error saving ItemMovement cache: $cacheErr');
        }

      } on OfflineFallbackException catch (e) {
        final cacheResult = await DatabaseHelper.instance.query(
          'Offline_ReportsCache',
          where: 'ReportType = ? AND CurrencyId = ? AND ParametersHash = ?',
          whereArgs: ['ItemMovement', '0', paramHash],
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
          isError: true,
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _processRawJsonWithIsolate(String rawJson) async {
    try {
      final response = await compute(_parseItemMovementInIsolate, rawJson);
      _applyResponse(response);
    } catch (e) {
      debugPrint('Error parsing item movement in isolate: $e');
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ أثناء معالجة بيانات التقرير.', isError: true);
    }
  }

  void _applyResponse(ItemMovementResponse response) {
    reportData.assignAll(response.rows);
    rowCount.value            = response.rowCount;
    grandTotalAmount.value    = response.grandTotalAmount;
    grandNetAmount.value      = response.grandNetAmount;
    grandTotalCost.value      = response.grandTotalCost;
    grandMargin.value         = response.grandMargin;

    grandTotalAmountStr.value = response.grandTotalAmountStr;
    grandNetAmountStr.value   = response.grandNetAmountStr;
    grandTotalCostStr.value   = response.grandTotalCostStr;
    grandMarginStr.value      = response.grandMarginStr;
  }

  void _resetTotals() {
    rowCount.value            = 0;
    grandTotalAmount.value    = 0.0;
    grandNetAmount.value      = 0.0;
    grandTotalCost.value      = 0.0;
    grandMargin.value         = 0.0;

    grandTotalAmountStr.value = '0';
    grandNetAmountStr.value   = '0';
    grandTotalCostStr.value   = '0';
    grandMarginStr.value      = '0';
  }

  // ---------------------------------------------------------------------------
  // مسح الفلاتر
  // ---------------------------------------------------------------------------
  void clearFilters() {
    selectedReportType.value  = 'all';
    selectedItemGroupId.value = null;
    _initDates();
    reportData.clear();
    _resetTotals();
    hasSearched.value = false;
  }

  // ---------------------------------------------------------------------------
  // صلاحية الطباعة
  // ---------------------------------------------------------------------------
  bool canPrint() => userState.canPrint(_kScreenName);

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
    _invoiceTemplatesController.selectTemplate(_kScreenName);
    if (_invoiceTemplatesController.companyNameController.text.isEmpty) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'يرجى ضبط قالب التقرير في الإعدادات أولاً.',
          isError: true);
      return;
    }
    Get.to(() => ItemMovementPdfView(
          reportData: reportData.toList(),
          fromDate: fromDate.value,
          toDate: toDate.value,
          grandTotalAmount: grandTotalAmount.value,
          grandNetAmount: grandNetAmount.value,
          grandTotalCost: grandTotalCost.value,
          grandMargin: grandMargin.value,
          rowCount: rowCount.value,
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
    final double d = (value is double) ? value : (double.tryParse(value.toString()) ?? 0.0);
    return NumberFormat('#,###.##', 'en_US').format(d);
  }

  String formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
      }
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) return DateFormat('yyyy-MM-dd').format(parsed);
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }
}

/// دالة المعالجة في Isolate منفصل لتقرير حركة الأصناف
ItemMovementResponse _parseItemMovementInIsolate(String rawJson) {
  final Map<String, dynamic> json = jsonDecode(rawJson) as Map<String, dynamic>;
  return ItemMovementResponse.fromJson(json);
}
