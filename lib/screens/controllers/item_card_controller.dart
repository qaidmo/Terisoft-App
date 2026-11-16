// lib/screens/controllers/item_card_controller.dart
// تحكم تقرير بطاقة الصنف - GetX Controller مستقل تماماً

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/repositories/item_card_repository.dart';
import 'package:untitled4/screens/pdf/item_card_pdf_view.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import '../../models/item_card_models.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'dart:convert';

const String _kItemCardScreenName = 'ItemCardScreen';

class ItemCardController extends GetxController {
  final ItemCardRepository _repository = ItemCardRepository();
  final UserState userState = Get.find<UserState>();
  final InvoiceTemplatesController _invoiceTemplatesController =
      Get.find<InvoiceTemplatesController>();

  // ---------------------------------------------------------------------------
  // حالة الفلاتر
  // ---------------------------------------------------------------------------
  final Rx<DateTime> fromDate = DateTime.now().obs;
  final Rx<DateTime> toDate   = DateTime.now().obs;

  // حقل اسم الصنف (إجباري) — يتحكم به TextEditingController
  final TextEditingController itemNameTextController = TextEditingController();
  final RxString itemNameFilter = ''.obs;

  // نوع الحركة — dropdown ثابت
  final RxString selectedReportType = 'all'.obs;
  final RxList<Map<String, String>> reportTypes = <Map<String, String>>[].obs;

  // Dropdowns التابعة (تُحمَّل بعد إدخال اسم الصنف)
  final RxList<UnitInfo> unitsList   = <UnitInfo>[].obs;
  final RxList<String>   batchesList = <String>[].obs;
  final Rxn<UnitInfo>    selectedUnit  = Rxn<UnitInfo>(null);
  final RxnString        selectedBatch = RxnString(null);

  final RxList<Map<String, dynamic>> availableItems = <Map<String, dynamic>>[].obs;

  // ---------------------------------------------------------------------------
  // إعدادات
  // ---------------------------------------------------------------------------
  final RxBool excludeOpeningBalance  = false.obs;
  final RxBool excludePreviousBalance = false.obs;

  // ---------------------------------------------------------------------------
  // حالة النتائج
  // ---------------------------------------------------------------------------
  final RxBool isLoading   = false.obs;
  final RxBool hasSearched = false.obs;
  final RxList<ItemCardRow> reportData = <ItemCardRow>[].obs;

  /// البيانات الخام (بالوحدة الأساسية) — تُستخدم لإعادة التحويل بدون استدعاء API
  final List<ItemCardRow> _rawReportData = [];
  /// المجاميع الخام (بالوحدة الأساسية)
  double _rawTotalQuantityIn  = 0.0;
  double _rawTotalQuantityOut = 0.0;
  double _rawFinalBalance     = 0.0;

  // مجاميع التقرير (المحوّلة حسب الوحدة المختارة)
  final RxDouble totalQuantityIn  = 0.0.obs;
  final RxDouble totalQuantityOut = 0.0.obs;
  final RxDouble finalBalance     = 0.0.obs;
  final RxString totalQuantityInStr  = '0'.obs;
  final RxString totalQuantityOutStr = '0'.obs;
  final RxString finalBalanceStr     = '0'.obs;
  final RxInt    rowCount         = 0.obs;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    _initDates();
    _loadStaticReportTypes();
    _loadAvailableItems();
  }

  @override
  void onClose() {
    itemNameTextController.dispose();
    super.onClose();
  }

  void _initDates() {
    final String? yearName = userState.financialYearName;
    final int currentYear = int.tryParse(yearName ?? '') ?? DateTime.now().year;
    fromDate.value = DateTime(currentYear, 1, 1);
    toDate.value   = DateTime(currentYear, 12, 31, 23, 59, 59);
  }

  void _loadStaticReportTypes() {
    reportTypes.assignAll([
      {'value': 'all',                              'display': 'الكل'},
      {'value': '601,603,605,607,633,801,803',      'display': 'مبيعات'},
      {'value': '421,423',                          'display': 'مشتريات'},
      {'value': '602,604,606,608,634,802,804',      'display': 'مردودات مبيعات'},
      {'value': '422,424',                          'display': 'مردودات مشتريات'},
      {'value': '801,803',                          'display': 'مبيعات مطعم'},
      {'value': '802,804',                          'display': 'مردودات مطعم'},
      {'value': '507',                              'display': 'جرد مخزن'},
    ]);
  }

  Future<void> _loadAvailableItems() async {
    try {
      final db = DatabaseHelper.instance;
      final department = userState.safeUserDepartment.toString();
      final items = await db.rawQuery(
        "SELECT item_no, item_name, item_unit FROM sun_items WHERE section_no = ?",
        [department],
      );
      availableItems.assignAll(items);
    } catch (_) {
      availableItems.clear();
    }
  }

  List<Map<String, dynamic>> filterItems(String query) {
    if (query.isEmpty) {
      return availableItems.toList();
    }
    final lowerQuery = query.toLowerCase();
    return availableItems.where((item) {
      final itemName = item['item_name']?.toString().toLowerCase() ?? '';
      final itemNo = item['item_no']?.toString().toLowerCase() ?? '';
      return itemName.contains(lowerQuery) || itemNo.contains(lowerQuery);
    }).take(50).toList();
  }

  // ---------------------------------------------------------------------------
  // تحميل الوحدات والدفعات بعد إدخال اسم الصنف
  // ---------------------------------------------------------------------------

  /// يُستدعى عند الضغط على زر البحث أو إنهاء الكتابة في حقل اسم الصنف
  Future<void> onItemNameSubmitted() async {
    final String name = itemNameTextController.text.trim();
    itemNameFilter.value = name;

    // إعادة تعيين الـ dropdowns التابعة
    selectedUnit.value  = null;
    selectedBatch.value = null;
    unitsList.clear();
    batchesList.clear();
    _rawReportData.clear();

    if (name.isEmpty) return;

    await _loadUnitsForItem(name);
    await _loadBatchesForItem(name);

    // تعيين الوحدة الأساسية تلقائياً (أول وحدة في القائمة)
    if (unitsList.isNotEmpty) {
      selectedUnit.value = unitsList.first;
    }
  }

  Future<void> _loadUnitsForItem(String itemName) async {
    try {
      final db = DatabaseHelper.instance;

      // البحث عن رقم الصنف أولاً بالاسم (مطابقة جزئية)
      final items = await db.rawQuery(
        "SELECT item_no, item_unit FROM sun_items "
        "WHERE item_name LIKE ? LIMIT 1",
        ['%$itemName%'],
      );
      if (items.isEmpty) return;

      final String itemNo       = items.first['item_no']?.toString() ?? '';
      final String primaryUnit  = items.first['item_unit']?.toString() ?? '';

      // جلب جميع الوحدات مع معامل التحويل من sun_itemsize
      final units = await db.query(
        'sun_itemsize',
        columns: ['unit_name', 'conversion_factor'],
        where: 'item_no = ? AND is_active = 1',
        whereArgs: [itemNo],
        orderBy: 'unit_index ASC',
      );

      // الوحدة الأساسية دائماً أولاً (PackFactor = 1.0 بالتعريف)
      final List<UnitInfo> result = [];
      if (primaryUnit.isNotEmpty) {
        result.add(UnitInfo(name: primaryUnit, packFactor: 1.0));
      }
      for (final u in units) {
        final String uName = u['unit_name']?.toString() ?? '';
        final double factor = (u['conversion_factor'] as num?)?.toDouble() ?? 1.0;
        if (uName.isNotEmpty && uName != primaryUnit) {
          result.add(UnitInfo(name: uName, packFactor: factor));
        }
      }
      unitsList.assignAll(result);
    } catch (_) {
      unitsList.clear();
    }
  }

  Future<void> _loadBatchesForItem(String itemName) async {
    try {
      final db = DatabaseHelper.instance;

      final items = await db.rawQuery(
        "SELECT item_no FROM sun_items "
        "WHERE item_name LIKE ? LIMIT 1",
        ['%$itemName%'],
      );
      if (items.isEmpty) return;

      final String itemNo = items.first['item_no']?.toString() ?? '';

      final batches = await db.rawQuery(
        "SELECT DISTINCT batch_no FROM sun_stock "
        "WHERE item_no = ? AND batch_no != '' "
        "ORDER BY batch_no ASC",
        [itemNo],
      );
      batchesList.assignAll(
        batches.map((b) => b['batch_no']?.toString() ?? '').where((b) => b.isNotEmpty).toList(),
      );
    } catch (_) {
      batchesList.clear();
    }
  }

  // ---------------------------------------------------------------------------
  // جلب البيانات — مع تطبيق نطاق الأمان والأوفلاين
  // ---------------------------------------------------------------------------
  Future<void> fetchReportData() async {
    // --- التحقق من الحقل الإجباري (اسم الصنف) ---
    if (itemNameFilter.value.trim().isEmpty) {
      AppSnackbar.showCustomSnackbar(
        'حقل إجباري',
        'يرجى إدخال اسم الصنف أولاً ثم الضغط على بحث.',
        isError: true,
      );
      return;
    }

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
          '|${itemNameFilter.value.trim()}'
          '|${selectedBatch.value ?? ""}'
          '|${selectedReportType.value}'
          '|eo:${excludeOpeningBalance.value ? 1 : 0}'
          '|ep:${excludePreviousBalance.value ? 1 : 0}';

      try {
        final result = await _repository.getItemCardWithCache(
          startDate:              fromDate.value.toIso8601String(),
          endDate:                toDate.value.toIso8601String(),
          year:                   currentYear,
          branchId:               userState.safeUserBranch,
          itemName:               itemNameFilter.value.trim().isEmpty ? null : itemNameFilter.value.trim(),
          batchNumber:            selectedBatch.value,
          transactionType:        selectedReportType.value,
          excludeOpeningBalance:  excludeOpeningBalance.value,
          excludePreviousBalance: excludePreviousBalance.value,
          userId:                 userState.isAdmin ? null : userState.userNo,
          departmentId:           userState.userDepartment,
        );

        final rawJson = result.$2;

        // تحليل البيانات في خلفية النظام Isolate وعرضها فوراً
        final response = await compute(parseItemCardJson, rawJson);
        _applyResponse(response);

        // حفظ في ملف الكاش الخارجي
        final String entityId = itemNameFilter.value.trim().isEmpty ? 'ALL' : itemNameFilter.value.trim();
        try {
          final String filePath = await ReportCacheFileManager.saveReportPayload(
            reportType: 'ItemCard',
            entityId: entityId,
            parametersHash: paramHash,
            rawJson: rawJson,
          );

          await DatabaseHelper.instance.insertOrUpdate(
            'Offline_ReportsCache',
            {
              'ReportType':        'ItemCard',
              'EntityIdentifier':  entityId,
              'CurrencyId':        '0',
              'ParametersHash':    paramHash,
              'file_path':         filePath,
              'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
            },
            'ParametersHash',
          );
        } catch (cacheErr) {
          debugPrint('Error saving ItemCard cache: $cacheErr');
        }

      } on OfflineFallbackException catch (e) {
        // استرجاع البيانات المحلية من ملف الكاش
        final cacheResult = await DatabaseHelper.instance.query(
          'Offline_ReportsCache',
          where: 'ReportType = ? AND CurrencyId = ? AND ParametersHash = ?',
          whereArgs: ['ItemCard', '0', paramHash],
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
            final response = await compute(parseItemCardJson, rawPayload);
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

  void _applyResponse(ItemCardResponse response) {
    // حفظ البيانات الخام (بالوحدة الأساسية) للتحويل الديناميكي
    _rawReportData.clear();
    _rawReportData.addAll(response.rows);
    _rawTotalQuantityIn  = response.totalQuantityIn;
    _rawTotalQuantityOut = response.totalQuantityOut;
    _rawFinalBalance     = response.finalBalance;
    rowCount.value       = response.rowCount;

    // تطبيق التحويل حسب الوحدة المختارة
    _applyConversion();
  }

  /// يُطبّق التحويل الديناميكي على البيانات الخام بناءً على الوحدة المختارة.
  /// يُستدعى عند: (1) وصول بيانات جديدة، (2) تغيير الوحدة من الـ dropdown.
  void _applyConversion() {
    final UnitInfo? unit = selectedUnit.value;
    final double targetPackFactor = unit?.packFactor ?? 1.0;
    final String targetUnitName   = unit?.name ?? '';

    if (targetPackFactor == 1.0 &&
        (targetUnitName.isEmpty ||
            (_rawReportData.isNotEmpty && _rawReportData.first.itemUnit == targetUnitName))) {
      reportData.assignAll(_rawReportData);
    } else {
      reportData.assignAll(
        _rawReportData.map((row) => row.copyWithConversion(targetPackFactor, targetUnitName)).toList(),
      );
    }
    totalQuantityIn.value  = _rawTotalQuantityIn  / targetPackFactor;
    totalQuantityOut.value = _rawTotalQuantityOut / targetPackFactor;
    finalBalance.value     = _rawFinalBalance     / targetPackFactor;
    totalQuantityInStr.value  = formatNumber(totalQuantityIn.value);
    totalQuantityOutStr.value = formatNumber(totalQuantityOut.value);
    finalBalanceStr.value     = formatNumber(finalBalance.value);
  }

  /// يُستدعى من الـ dropdown عند تغيير الوحدة — تحويل فوري بدون استدعاء API
  void onUnitChanged(UnitInfo? newUnit) {
    selectedUnit.value = newUnit;
    if (_rawReportData.isNotEmpty) {
      _applyConversion();
    }
  }

  void _resetTotals() {
    rowCount.value            = 0;
    totalQuantityIn.value     = 0.0;
    totalQuantityOut.value    = 0.0;
    finalBalance.value        = 0.0;
    totalQuantityInStr.value  = '0';
    totalQuantityOutStr.value = '0';
    finalBalanceStr.value     = '0';
  }

  // ---------------------------------------------------------------------------
  // مسح الفلاتر
  // ---------------------------------------------------------------------------
  void clearFilters() {
    itemNameTextController.clear();
    itemNameFilter.value    = '';
    selectedUnit.value      = null;
    selectedBatch.value     = null;
    unitsList.clear();
    batchesList.clear();
    _rawReportData.clear();
    selectedReportType.value      = 'all';
    excludeOpeningBalance.value   = false;
    excludePreviousBalance.value  = false;
    _initDates();
    reportData.clear();
    _resetTotals();
    hasSearched.value = false;
  }

  // ---------------------------------------------------------------------------
  // صلاحية الطباعة
  // ---------------------------------------------------------------------------
  bool canPrint() => userState.canPrint(_kItemCardScreenName);

  void printReport() {
    if (!canPrint()) {
      AppSnackbar.showCustomSnackbar('صلاحيات', 'ليس لديك صلاحية طباعة هذا التقرير.');
      return;
    }
    if (reportData.isEmpty) {
      AppSnackbar.showCustomSnackbar(
        'خطأ', 'لا توجد بيانات لطباعتها. يرجى عرض التقرير أولاً.',
        isError: true,
      );
      return;
    }
    _invoiceTemplatesController.selectTemplate(_kItemCardScreenName);
    if (_invoiceTemplatesController.companyNameController.text.isEmpty) {
      AppSnackbar.showCustomSnackbar(
        'خطأ', 'يرجى ضبط قالب التقرير في الإعدادات أولاً.',
        isError: true,
      );
      return;
    }

    Get.to(() => ItemCardPdfView(
      reportData:         reportData.toList(),
      fromDate:           fromDate.value,
      toDate:             toDate.value,
      totalQuantityIn:    totalQuantityIn.value,
      totalQuantityOut:   totalQuantityOut.value,
      finalBalance:       finalBalance.value,
      rowCount:           rowCount.value,
      selectedUnitName:   selectedUnit.value?.name ?? '',
      companyName:        _invoiceTemplatesController.companyNameController.text,
      companyAddress:     _invoiceTemplatesController.addressDetailsController.text,
      contactInfo:        _invoiceTemplatesController.contactInfoController.text,
      thanksMessage:      _invoiceTemplatesController.thanksMessageController.text,
      logoUrl:            _invoiceTemplatesController.currentLogoUrl.value,
      showLogo:           _invoiceTemplatesController.showLogo.value,
      userName:           userState.safeUserName,
      userBranchName:     userState.safeUserBranchName,
      userDepartmentName: userState.safeUserDepartmentName,
    ));
  }

  // ---------------------------------------------------------------------------
  // تنسيق الأرقام والتاريخ
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
