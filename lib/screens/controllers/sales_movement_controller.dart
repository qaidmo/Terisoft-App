import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/screens/pdf/sales_movement_pdf_view.dart';
import 'package:untitled4/user_state.dart';
import '../../models/transaction_history_models.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/utils/ui_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import '../../utils/snackbar_helper.dart';
import '../absolute_cash_sale_return_screen.dart';
import '../absolute_cash_sale_screen.dart';
import '../cash_payment_voucher_screen.dart';
import '../cash_receipt_voucher_screen.dart';
import '../cash_sale_return_screen.dart';
import '../cash_sale_screen.dart';
import '../credit_sale_return_screen.dart';
import '../credit_sale_screen.dart';

const String _kCurrentScreenName = 'SalesMovementScreen';

class SalesMovementController extends GetxController {
  final ReportRepository _reportRepository = ReportRepository();
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final UserState userState = Get.find<UserState>();

  final InvoiceTemplatesController _invoiceTemplatesController =
  Get.find<InvoiceTemplatesController>();

  final Rx<DateTime> fromDate = DateTime.now().obs;
  final Rx<DateTime> toDate = DateTime.now().obs;

  final RxString selectedReportType = 'all'.obs;
  final RxList<Map<String, String>> reportTypes = <Map<String, String>>[].obs;

  final RxList<Map<String, dynamic>> branchesList = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> departmentsList = <Map<String, dynamic>>[].obs;

  final Rxn<int> selectedBranchId = Rxn<int>();
  final Rxn<int> selectedDepartmentId = Rxn<int>();

  final RxBool isLoading = false.obs;
  final RxBool hasSearched = false.obs;
  final RxList<Map<String, dynamic>> reportData = <Map<String, dynamic>>[].obs;
  final RxDouble grandTotal = 0.0.obs;
  final RxInt itemsCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    if (!userState.canAccessScreen(_kCurrentScreenName)) {
      AppSnackbar.showCustomSnackbar(
          'صلاحيات', 'ليس لديك صلاحية الوصول لهذه الشاشة.');
      Future.delayed(Duration.zero, () => Get.back());
      return;
    }

    String? yearName = userState.financialYearName;
    int currentYear = int.tryParse(yearName ?? '') ?? DateTime.now().year;

    fromDate.value = DateTime(currentYear, 1, 1);
    toDate.value = DateTime(currentYear, 12, 31, 23, 59, 59);

    _loadStaticReportTypes();
    _loadBranches();
    _loadDepartments();
  }

  void _loadStaticReportTypes() {
    reportTypes.assignAll([
      {'value': 'all', 'display': 'الكل'},
      {'value': 'ن', 'display': 'بيع نقدي'},
      {'value': 'ج', 'display': 'بيع آجل'},
      {'value': 'م', 'display': 'بيع معلق'},
      {'value': 'رن', 'display': 'مردود بيع نقدي'},
      {'value': 'رج', 'display': 'مردود بيع آجل'},
      {'value': 'رم', 'display': 'مردود بيع معلق'},
      {'value': 'ق', 'display': 'سند قبض'},
      {'value': 'ص', 'display': 'سند صرف'},
    ]);
  }

  String getDisplayTypeName(String char) {
    var item = reportTypes.firstWhere(
            (element) => element['value'] == char,
        orElse: () => {'display': char});
    return item['display'] ?? char;
  }

  Future<void> _loadBranches() async {
    try {
      branchesList.clear();
      if (userState.isAdmin) {
        final response = await _lookupsRepository.fetchAllBranches();
        branchesList.addAll(response);
        selectedBranchId.value = branchesList.isNotEmpty ? branchesList.first['branch_id'] : null;
      } else {
        branchesList.add({
          'branch_id': userState.userBranch,
          'branch_name': userState.safeUserBranchName,
        });
        selectedBranchId.value = userState.userBranch;
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل في تحميل الفروع: $e', isError: true);
    }
  }

  Future<void> _loadDepartments() async {
    try {
      departmentsList.clear();
      if (userState.isAdmin) {
        departmentsList.add({'department_id': null, 'department_name': 'كل الأقسام'});
        final response = await _lookupsRepository.fetchAllDepartments();
        departmentsList.addAll(response);
        selectedDepartmentId.value = null;
      } else {
        departmentsList.add({
          'department_id': userState.userDepartment,
          'department_name': userState.safeUserDepartmentName,
        });
        selectedDepartmentId.value = userState.userDepartment;
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل في تحميل الأقسام: $e', isError: true);
    }
  }

  Future<void> fetchReportData() async {
    isLoading.value = true;
    hasSearched.value = true;
    reportData.clear();
    grandTotal.value = 0.0;
    itemsCount.value = 0;

    if (selectedBranchId.value == null && branchesList.isNotEmpty) {
      var firstRealBranch = branchesList.firstWhere((b) => b['branch_id'] != null, orElse: () => {});
      if (firstRealBranch.isNotEmpty) {
        selectedBranchId.value = firstRealBranch['branch_id'];
      }
    }

    try {
      String? currentYear = userState.financialYearName;
      if (currentYear == null || currentYear.isEmpty) {
        throw Exception('السنة المالية غير محددة');
      }

      if (selectedBranchId.value == null) {
        throw Exception('يجب تحديد الفرع لعرض البيانات');
      }

      try {
        final result = await _reportRepository.getTransactionHistoryWithCache(
          startDate: fromDate.value.toIso8601String(),
          endDate: toDate.value.toIso8601String(),
          year: currentYear,
          branchId: selectedBranchId.value!,
          transactionType: selectedReportType.value,
          userId: userState.isAdmin ? null : userState.userNo,
          departmentId: selectedDepartmentId.value,
        );

        final rawJson = result.$2;

        await _processInIsolate(rawJson, isOfflineSlicing: false);
        // 1. حفظ ملف الكاش المحلي في الخلفية
        try {
          final fileName = ReportCacheFileManager.generateFileName(
            reportType: 'TransactionHistory',
            entityId: '${selectedBranchId.value}_${selectedDepartmentId.value ?? 0}',
            currencyId: '0',
            paramsHash: '${selectedReportType.value}_$currentYear',
          );
          final filePath = await ReportCacheFileManager.saveCacheFile(fileName, rawJson);

          final db = await DatabaseHelper.instance.database;
          await db.insert('Offline_ReportsCache', {
            'ReportType': 'TransactionHistory',
            'EntityIdentifier': '${selectedBranchId.value}_${selectedDepartmentId.value ?? 0}',
            'CurrencyId': '0',
            'ParametersHash': '${selectedReportType.value}_$currentYear',
            'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
            'file_path': filePath,
            'ledger_signature': '',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          debugPrint('Error saving TransactionHistory cache file: $e');
        }

        if (false)
        await _processInIsolate(rawJson, isOfflineSlicing: false);

      } on OfflineFallbackException catch (e) {
        bool handled = false;

        // محاولة القراءة من كاش الملفات أولاً
        try {
          final db = await DatabaseHelper.instance.database;
          final cacheRecords = await db.query(
            'Offline_ReportsCache',
            where: 'ReportType = ? AND EntityIdentifier = ? AND CurrencyId = ? AND ParametersHash = ?',
            whereArgs: ['TransactionHistory', '${selectedBranchId.value}_${selectedDepartmentId.value ?? 0}', '0', '${selectedReportType.value}_$currentYear'],
            orderBy: 'LastSyncTimestamp DESC',
            limit: 1,
          );

          if (cacheRecords.isNotEmpty) {
            final filePath = cacheRecords.first['file_path'] as String?;
            if (filePath != null) {
              final rawJson = await ReportCacheFileManager.readCacheFile(filePath);
              if (rawJson != null && rawJson.isNotEmpty) {
                if (e.reason == 'CONNECTION_LOST') {
                  bool proceed = await UiHelper.showOfflineWarningDialog(cacheRecords.first['LastSyncTimestamp']?.toString() ?? 'البيانات المحلية');
                  if (!proceed) {
                    isLoading.value = false;
                    return;
                  }
                }
                await _processInIsolate(rawJson, isOfflineSlicing: true);
                handled = true;
              }
            }
          }
        } catch (err) {
          debugPrint('File cache read fallback error: $err');
        }

        // محاولة ثانية: قراءة من جدول local_transaction_history القديم إن وُجد
        if (!handled) {
          String queryStart = fromDate.value.toIso8601String().substring(0, 10);
          String queryEnd = toDate.value.toIso8601String().substring(0, 10);
          
          final db = await DatabaseHelper.instance.database;
          final cacheResult = await db.query(
            'local_transaction_history',
            where: 'Date >= ? AND Date <= ?',
            whereArgs: [queryStart, queryEnd],
            orderBy: 'Date DESC, Time DESC'
          );

          if (cacheResult.isNotEmpty) {
            if (e.reason == 'CONNECTION_LOST') {
              bool proceed = await UiHelper.showOfflineWarningDialog('البيانات المحلية');
              if (!proceed) {
                isLoading.value = false;
                return;
              }
            }

            final List<Map<String, dynamic>> offlineItems = [];
            double total = 0.0;
            final numberFormat = NumberFormat("#,##0.00", "en_US");

            for (var row in cacheResult) {
              final netTotal = (row['NetTotal'] as num?)?.toDouble() ?? 0.0;
              final typeId = row['TransactionTypeId']?.toString() ?? '';
              String typeChar = '';
              String source = '';
              switch (typeId) {
                case '601': typeChar = 'ن'; source = 'sales'; break;
                case '603': typeChar = 'ج'; source = 'sales'; break;
                case '633': typeChar = 'م'; source = 'sales'; break;
                case '602': typeChar = 'رن'; source = 'sales'; break;
                case '604': typeChar = 'رج'; source = 'sales'; break;
                case '634': typeChar = 'رم'; source = 'sales'; break;
                case '201': typeChar = 'ق'; source = 'receipt'; break;
                case '202': typeChar = 'ص'; source = 'receipt'; break;
                default:
                  typeChar = typeId;
                  source = 'other';
                  break;
              }

              if (selectedReportType.value == 'all' || typeChar == selectedReportType.value) {
                offlineItems.add({
                  'id': row['TransactionId']?.toString() ?? '',
                  'transaction_number': row['TransactionNumber']?.toString() ?? '',
                  'reference_number': row['ReferenceNumber']?.toString() ?? '',
                  'date': row['Date']?.toString() ?? '',
                  'formatted_date': row['Date']?.toString() ?? '',
                  'time': row['Time']?.toString() ?? '',
                  'customer_name': row['CustomerName']?.toString() ?? '',
                  'net_total': netTotal,
                  'net_total_str': numberFormat.format(netTotal),
                  'user_name': row['UserName']?.toString() ?? 'غير معروف',
                  'invoice_type_char': typeChar,
                  'display_name': row['TransactionTypeName']?.toString() ?? '',
                  'type_id': typeId,
                  'source': source,
                });
                total += netTotal;
              }
            }

            reportData.assignAll(offlineItems);
            grandTotal.value = total;
            itemsCount.value = offlineItems.length;
            handled = true;
          }
        }

        if (!handled) {
          AppSnackbar.showCustomSnackbar('خطأ', 'لا يوجد اتصال بالإنترنت ولا توجد بيانات سابقة محفوظة لهذا التاريخ.', isError: true);
        }
      }
    } catch (e) {
      if (e is! OfflineFallbackException) {
        AppSnackbar.showCustomSnackbar('خطأ', 'فشل في جلب البيانات: ${e.toString()}', isError: true);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _processInIsolate(String rawJson, {required bool isOfflineSlicing}) async {
    final result = await compute(_parseSalesMovementInIsolate, {
      'rawJson': rawJson,
      'isOfflineSlicing': isOfflineSlicing,
      'fromDate': fromDate.value.toIso8601String(),
      'toDate': toDate.value.toIso8601String(),
      'reqType': selectedReportType.value,
    });

    final items = (result['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    reportData.assignAll(items);
    grandTotal.value = (result['grandTotal'] as num?)?.toDouble() ?? 0.0;
    itemsCount.value = (result['itemsCount'] as num?)?.toInt() ?? 0;

    if (items.isEmpty && isOfflineSlicing) {
      AppSnackbar.showCustomSnackbar('معلومات', 'لا توجد حركات في الذاكرة المحلية مطابقة للتاريخ والنوع المحددين.', isError: false);
    }
  }

  String formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    double value = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat("#,###.##", "en_US");
    return formatter.format(value);
  }

  void clearFilters() {
    selectedReportType.value = 'all';

    if (userState.isAdmin) {
      selectedBranchId.value = branchesList.isNotEmpty ? branchesList.first['branch_id'] : null;
      selectedDepartmentId.value = null;
    } else {
      selectedBranchId.value = userState.userBranch;
      selectedDepartmentId.value = userState.userDepartment;
    }

    String? yearName = userState.financialYearName;
    int currentYear = int.tryParse(yearName ?? '') ?? DateTime.now().year;

    fromDate.value = DateTime(currentYear, 1, 1);
    toDate.value = DateTime(currentYear, 12, 31, 23, 59, 59);

    reportData.clear();
    grandTotal.value = 0;
    itemsCount.value = 0;
    hasSearched.value = false;
  }

  DateTime? _parseLegacyDate(String dateStr) {
    try {
      if (dateStr.contains('/')) {
        var parts = dateStr.split('/');
        if (parts.length == 3) {
          int d = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          int y = int.parse(parts[2]);
          return DateTime(y, m, d);
        }
      }
      return DateTime.tryParse(dateStr);
    } catch (_) {
      return null;
    }
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

    String reportTitle;
    if (selectedReportType.value == 'all') {
      reportTitle = 'تقرير الحركات المالية الشامل';
    } else {
      reportTitle = getDisplayTypeName(selectedReportType.value);
    }

    Get.to(() => SalesMovementPdfView(
      reportData: reportData.toList(),
      fromDate: fromDate.value,
      toDate: toDate.value,
      grandTotal: grandTotal.value,
      itemsCount: itemsCount.value,
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

  void _navigateToCashReceipt(Map<String, dynamic> transactionItem) {
    final String transId = transactionItem['id'].toString();
    final String year = userState.financialYearName ?? DateTime.now().year.toString();
    final int branchId = selectedBranchId.value!;

    final Map<String, dynamic> args = {
      'transactionId': transId,
      'isRemote': true,
      'remoteBranchId': branchId,
      'remoteYear': year,
    };

    Get.to(() => ReceiptScreen(receiptId: int.tryParse(transId)), arguments: args);
  }

  void _navigateToCashPayment(Map<String, dynamic> transactionItem) {
    final String transId = transactionItem['id'].toString();
    final String year = userState.financialYearName ?? DateTime.now().year.toString();
    final int branchId = selectedBranchId.value!;

    final Map<String, dynamic> args = {
      'transactionId': transId,
      'isRemote': true,
      'remoteBranchId': branchId,
      'remoteYear': year,
    };

    Get.to(() => CashPaymentVoucherScreen(paymentId: int.tryParse(transId)), arguments: args);
  }

  void navigateToTransactionDetails(Map<String, dynamic> transactionItem) {
    final String typeChar = transactionItem['invoice_type_char'] ?? '';
    final String transactionId = transactionItem['id'].toString();

    final String year = userState.financialYearName ?? DateTime.now().year.toString();
    final int branchId = selectedBranchId.value!;

    final Map<String, dynamic> args = {
      'invoiceId': transactionId,
      'isRemote': true,
      'remoteBranchId': branchId,
      'remoteYear': year,
      'invoiceTypeChar': typeChar,
    };

    switch (typeChar) {
      case 'ن':
        Get.to(() => CashSaleScreen(invoiceId: transactionId), arguments: args);
        break;

      case 'م':
        Get.to(() => AbsoluteCashSaleScreen(invoiceId: transactionId), arguments: args);
        break;

      case 'ج':
        Get.to(() => CreditSaleScreen(invoiceId: transactionId), arguments: args);
        break;

      case 'رن':
        Get.to(() => CashSaleReturnScreen(invoiceId: transactionId), arguments: args);
        break;

      case 'رج':
        Get.to(() => CreditSaleReturnScreen(invoiceId: transactionId), arguments: args);
        break;

      case 'رم':
        Get.to(() => AbsoluteCashSaleReturnScreen(invoiceId: transactionId), arguments: args);
        break;

      case 'ق':
        _navigateToCashReceipt(transactionItem);
        break;

      case 'ص':
        _navigateToCashPayment(transactionItem);
        break;

      default:
        AppSnackbar.showCustomSnackbar('تنبيه', 'نوع الحركة  غير مدعوم: $typeChar', isError: false);
    }
  }

  bool canPrint() {
    return userState.canPrint(_kCurrentScreenName);
  }
}

/// دالة العزل الخلفي: تقوم بفك تشفير JSON، والفلترة، وحساب المجاميع، وتنسيق التواريخ والأرقام في مسار واحد
Map<String, dynamic> _parseSalesMovementInIsolate(Map<String, dynamic> params) {
  final String rawJson = params['rawJson'] as String;
  final bool isOfflineSlicing = params['isOfflineSlicing'] as bool? ?? false;
  final String fromDateStr = params['fromDate'] as String;
  final String toDateStr = params['toDate'] as String;
  final String reqType = params['reqType'] as String;

  final Map<String, dynamic> jsonResponse = jsonDecode(rawJson);
  final List<dynamic> transactionsList = jsonResponse['transactions'] as List<dynamic>? ?? [];

  DateTime? reqStart;
  DateTime? reqEnd;
  if (isOfflineSlicing) {
    reqStart = DateTime.tryParse(fromDateStr);
    final parsedEnd = DateTime.tryParse(toDateStr);
    if (parsedEnd != null) {
      reqEnd = parsedEnd.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
    }
  }

  final List<Map<String, dynamic>> parsedItems = [];
  double calculatedTotal = 0.0;
  final DateFormat outputFormat = DateFormat('yyyy-MM-dd');
  final NumberFormat numberFormat = NumberFormat("#,##0.00", "en_US");

  for (final rawItem in transactionsList) {
    if (rawItem is! Map<String, dynamic>) continue;

    final String txDateStr = rawItem['date']?.toString() ?? '';
    final String typeId = rawItem['transactionTypeId']?.toString() ?? '';
    final double netTotal = (rawItem['netTotal'] as num?)?.toDouble() ?? 0.0;

    String typeChar = '';
    String source = '';
    switch (typeId) {
      case '601': typeChar = 'ن'; source = 'sales'; break;
      case '603': typeChar = 'ج'; source = 'sales'; break;
      case '633': typeChar = 'م'; source = 'sales'; break;
      case '602': typeChar = 'رن'; source = 'sales'; break;
      case '604': typeChar = 'رج'; source = 'sales'; break;
      case '634': typeChar = 'رم'; source = 'sales'; break;
      case '201': typeChar = 'ق'; source = 'receipt'; break;
      case '202': typeChar = 'ص'; source = 'receipt'; break;
      default:
        typeChar = typeId;
        source = 'other';
        break;
    }

    if (isOfflineSlicing && reqStart != null && reqEnd != null) {
      DateTime? txDate;
      try {
        if (txDateStr.contains('/')) {
          final parts = txDateStr.split('/');
          if (parts.length == 3) {
            txDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } else {
          txDate = DateTime.tryParse(txDateStr);
        }
      } catch (_) {}

      if (txDate != null && (txDate.isBefore(reqStart) || txDate.isAfter(reqEnd))) {
        continue;
      }

      if (reqType != 'all' && typeChar != reqType) {
        continue;
      }
    }

    String formattedDate = '-';
    if (txDateStr.isNotEmpty) {
      try {
        if (txDateStr.contains('/')) {
          final parts = txDateStr.split('/');
          if (parts.length == 3) {
            final dt = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            formattedDate = outputFormat.format(dt);
          }
        } else {
          final dt = DateTime.parse(txDateStr);
          formattedDate = outputFormat.format(dt);
        }
      } catch (_) {
        formattedDate = txDateStr;
      }
    }

    parsedItems.add({
      'id': rawItem['transactionId']?.toString() ?? '',
      'transaction_number': rawItem['transactionNumber']?.toString() ?? '',
      'reference_number': rawItem['referenceNumber']?.toString() ?? '',
      'date': txDateStr,
      'formatted_date': formattedDate,
      'time': rawItem['time']?.toString() ?? '',
      'customer_name': rawItem['customerName']?.toString() ?? '',
      'net_total': netTotal,
      'net_total_str': numberFormat.format(netTotal),
      'user_name': rawItem['userName']?.toString() ?? 'غير معروف',
      'invoice_type_char': typeChar,
      'display_name': rawItem['transactionTypeName']?.toString() ?? '',
      'type_id': typeId,
      'source': source,
    });

    calculatedTotal += netTotal;
  }

  final reversedItems = parsedItems.reversed.toList();

  final double finalGrandTotal = isOfflineSlicing
      ? calculatedTotal
      : ((jsonResponse['grandTotal'] as num?)?.toDouble() ?? calculatedTotal);
  final int finalItemsCount = isOfflineSlicing
      ? reversedItems.length
      : ((jsonResponse['itemsCount'] as num?)?.toInt() ?? reversedItems.length);

  return {
    'items': reversedItems,
    'grandTotal': finalGrandTotal,
    'itemsCount': finalItemsCount,
  };
}