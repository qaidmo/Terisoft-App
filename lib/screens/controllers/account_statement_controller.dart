import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/models/sun_account_model.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/admin/controllers/invoice_templates_controller.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'dart:convert';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/services/offline_fallback_exception.dart';
import 'package:untitled4/services/offline_report_query_service.dart';
import 'package:untitled4/services/report_cache_file_manager.dart';
import 'package:untitled4/utils/ui_helper.dart';
import '../../models/account_statement_models.dart';
import '../cash_payment_voucher_screen.dart';
import '../cash_receipt_voucher_screen.dart';
import '../pdf_statement/statement_pdf_view.dart';

class AccountStatementController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final ReportRepository _reportRepository = ReportRepository();
  final InvoiceTemplatesController _invoiceTemplatesController =
  Get.find<InvoiceTemplatesController>();
  final UserState userState = Get.find<UserState>();

  final Rxn<SunAccount> selectedAccount = Rxn<SunAccount>();
  late TextEditingController accountNameController;
  late Rx<DateTime> fromDate;
  late Rx<DateTime> toDate;
  final Rxn<SunCurrency> selectedCurrency = Rxn<SunCurrency>();
  final RxList<SunCurrency> allowedCurrencies = <SunCurrency>[].obs;

  // Branch state
  final RxList<Map<String, dynamic>> allBranches = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> selectedBranch = Rxn<Map<String, dynamic>>();

  // Department state
  final RxList<Map<String, dynamic>> allDepartments = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> selectedDepartment = Rxn<Map<String, dynamic>>();

  final RxBool isLoading = false.obs;
  final RxList<StatementRowDisplayModel> statementRows =
      <StatementRowDisplayModel>[].obs;
  final RxList<SunAccount> allAccounts = <SunAccount>[].obs;

  final RxDouble openingBalance = 0.0.obs;
  final RxDouble totalDebit = 0.0.obs;
  final RxDouble totalCredit = 0.0.obs;
  final RxDouble closingBalance = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    accountNameController = TextEditingController();
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month, 1).obs;
    toDate = DateTime(now.year, now.month + 1, 0).obs;
    _invoiceTemplatesController.fetchInvoiceTemplates();
    loadAllAccounts();
    _loadBranches();
    _loadDepartments();
  }

  @override
  void onClose() {
    accountNameController.dispose();
    super.onClose();
  }

  Future<void> loadAllAccounts() async {
    try {
      final response = await _lookupsRepository.fetchAllAccounts();
      allAccounts.assignAll(response);
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل في تحميل قائمة الحسابات.',
          isError: true);
    }
  }

  /// Builds the ParametersHash used for the offline cache key.
  /// Format: "B{branchId}_D{departmentId}"
  /// Uses 0 as a sentinel for "no department selected" (all departments).
  String _buildParametersHash(int branchId, int? departmentId) {
    return 'B${branchId}_D${departmentId ?? 0}';
  }

  Future<void> _loadBranches() async {
    try {
      var data = await _lookupsRepository.fetchAllBranches();
      final userBranchId = userState.safeUserBranch;
      
      if (!userState.isAdmin) {
        data = data.where((b) => b['branch_id'].toString() == userBranchId.toString()).toList();
      }
      
      allBranches.assignAll(data);
      // Pre-select the logged-in user's branch
      final match = data.firstWhereOrNull(
          (b) => b['branch_id'].toString() == userBranchId.toString());
      selectedBranch.value = match;
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تحميل الفروع.', isError: true);
    }
  }

  Future<void> _loadDepartments() async {
    try {
      var data = await _lookupsRepository.fetchAllDepartments();
      final userDeptId = userState.safeUserDepartment;

      if (!userState.isAdmin) {
        data = data.where((d) => d['department_id'].toString() == userDeptId.toString()).toList();
      }

      allDepartments.assignAll(data);
      
      if (!userState.isAdmin) {
        selectedDepartment.value = data.firstWhereOrNull(
            (d) => d['department_id'].toString() == userDeptId.toString());
      }
      // Otherwise, Default: no department selected = "All Departments"
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تحميل الأقسام.', isError: true);
    }
  }

  void onBranchSelected(Map<String, dynamic>? branch) {
    selectedBranch.value = branch;
    clearStatement(); // Wipe results when a filter changes
  }

  void onDepartmentSelected(Map<String, dynamic>? dept) {
    selectedDepartment.value = dept;
    clearStatement();
  }

  String getParentAccountName(String? parentId) {
    if (parentId == null) return 'N/A';
    final parent = allAccounts.firstWhereOrNull((acc) => acc.id == parentId);
    return parent?.name ?? 'غير معروف';
  }

  void onAccountSelected(SunAccount account) {
    selectedAccount.value = account;
    accountNameController.text = "${account.accountNumber} - ${account.name}";
    clearStatement();
    _fetchAllowedCurrencies(account.id);
  }

  Future<void> _fetchAllowedCurrencies(String accountId) async {
    // 1. طباعة لمعرفة ما هو الرقم الذي تم إرساله
    print("🚀 جاري جلب العملات للحساب رقم: $accountId");

    allowedCurrencies.clear();
    selectedCurrency.value = null;

    try {
      final response = await _lookupsRepository.fetchCurrenciesForAccount(accountId);

      // 2. طباعة لمعرفة ماذا عاد من السيرفر
      print("✅ تم استلام ${response.length} عملة/عملات من السيرفر.");

      if (response.isEmpty) {
        print("⚠️ تحذير: السيرفر أعاد قائمة فارغة! تأكد من قاعدة البيانات.");
      } else {
        response.forEach((c) => print(" - عملة: ${c.currencyName} (${c.currencyNo})"));
      }

      allowedCurrencies.assignAll(response);

      if (allowedCurrencies.isNotEmpty) {
        // نختار العملة الافتراضية الأولى
        selectedCurrency.value = allowedCurrencies.first;
      }
    } catch (e) {
      // 3. طباعة الخطأ إن وجد
      print("❌ خطأ أثناء جلب العملات: $e");
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل في جلب عملات الحساب.', isError: true);
    }
  }

  String? _lastIsolateLedgerSignature;
  String? _lastLoadedFilterKey;

  void onCurrencySelected(SunCurrency? currency) {
    selectedCurrency.value = currency;
  }

  Future<void> getStatement() async {
    if (selectedAccount.value == null) {
      AppSnackbar.showCustomSnackbar('خطأ', 'يرجى اختيار حساب أولاً.',
          isError: true);
      return;
    }
    if (selectedCurrency.value == null) {
      AppSnackbar.showCustomSnackbar('خطأ', 'يرجى اختيار العملة.', isError: true);
      return;
    }
    isLoading.value = true;

    try {
      // Effective branch: from dropdown if selected, else fall back to user's own branch
      final int effectiveBranchId =
          (selectedBranch.value?['branch_id'] as int?) ?? userState.safeUserBranch;

      // Effective department: null means "All Departments" (no filter)
      final int? effectiveDeptId =
          selectedDepartment.value?['department_id'] as int?;

      // Year (existing logic unchanged)
      String year = userState.safeFinancialYearName;
      if (year == 'غير محددة' || year.isEmpty) {
        year = fromDate.value.year.toString();
      }

      // ParametersHash for cache — same value used in both write and read
      final String parametersHash = _buildParametersHash(effectiveBranchId, effectiveDeptId);
      final String currentFilterKey =
          '${selectedAccount.value!.id}_${selectedCurrency.value!.currencyNo}_${parametersHash}_${fromDate.value.toIso8601String().substring(0, 10)}_${toDate.value.toIso8601String().substring(0, 10)}';

      try {
        final result = await _reportRepository.getAccountStatementWithCache(
          accountId: selectedAccount.value!.id,
          currencyId: selectedCurrency.value!.currencyNo,
          startDate: fromDate.value.toIso8601String(),
          endDate: toDate.value.toIso8601String(),
          year: year,
          branchId: effectiveBranchId,
          departmentId: effectiveDeptId,
        );

        final response = result.$1;
        final rawJson = result.$2;

        // Extract ledgerSignature from rawJson with lightweight targeted parse
        // (avoids full deserialization on the main thread).
        String? ledgerSignature;
        if (response != null) {
          ledgerSignature = response.ledgerSignature;
        } else {
          // Quick extraction from raw JSON without full model parse
          try {
            statementRows.clear();
            await _processOfflineFileInIsolate(rawJson, isOfflineSlicing: false);
            ledgerSignature = _lastIsolateLedgerSignature;
            _lastLoadedFilterKey = currentFilterKey;
          } catch (_) {
            ledgerSignature = null;
          }
        }

        // 1. حفظ ملف الـ JSON المحلي لتفادي حد CursorWindow 2MB
        // 1. حفظ ملف الـ JSON المحلي لتفادي حد CursorWindow 2MB
        try {
          final filePath = await ReportCacheFileManager.saveReportJson(
          reportType: 'AccountStatement',
          entityId: selectedAccount.value!.id,
          currencyId: selectedCurrency.value!.currencyNo.toString(),
          paramsHash: parametersHash,
          rawJson: rawJson,
        );

        // 2. تحديث جدول SQLite بالمسار والبصمة فقط
        await DatabaseHelper.instance.insertOrUpdate(
          'Offline_ReportsCache',
          {
            'ReportType': 'AccountStatement',
            'EntityIdentifier': selectedAccount.value!.id,
            'CurrencyId': selectedCurrency.value!.currencyNo.toString(),
            'ParametersHash': parametersHash,
            'file_path': filePath,
            'ledger_signature': ledgerSignature ?? '',
            'LastSyncTimestamp': DateTime.now().toUtc().toIso8601String(),
          },
          'ReportType'
        );

        // rows already populated in isolate above
        // Cache saved to SQLite
        } catch (cacheErr) {
          print('⚠️ تعذر حفظ كاش كشف الحساب المحلي: $cacheErr');
        }

        // rows already populated in isolate above
        // Single combined isolate: parse JSON + build display models in one pass
        if (response != null) {
          statementRows.clear();
          await _processOfflineFileInIsolate(rawJson, isOfflineSlicing: false);
          _lastLoadedFilterKey = currentFilterKey;
        }
      } on OfflineFallbackException catch (e) {
        // --- NOT_MODIFIED: Data is unchanged on server for the exact same filter & date range.
        if (e.reason == 'NOT_MODIFIED') {
          if (statementRows.isNotEmpty && _lastLoadedFilterKey == currentFilterKey) {
            isLoading.value = false;
            return;
          }
        }

        // 1. محاولة الاستعلام من جداول SQLite المحلية (يدعم أي فترة زمنية يختارها المستخدم)
        final sqlResult = await OfflineReportQueryService.queryAccountStatementAsJson(
          accountId: selectedAccount.value!.id,
          currencyId: selectedCurrency.value!.currencyNo,
          branchId: effectiveBranchId,
          departmentId: effectiveDeptId ?? 0,
          year: year,
          fromDate: fromDate.value,
          toDate: toDate.value,
        );

        if (sqlResult != null) {
          if (e.reason == 'CONNECTION_LOST') {
            bool proceed = await UiHelper.showOfflineWarningDialog(sqlResult.lastSyncTimestamp);
            if (!proceed) {
              isLoading.value = false;
              return;
            }
          }
          await _processOfflineFileInIsolate(sqlResult.rawJson, isOfflineSlicing: false);
          return;
        }

        List<Map<String, dynamic>> cacheResult = const [];
        try {
          cacheResult = await DatabaseHelper.instance.query(
            'Offline_ReportsCache',
            where: 'ReportType = ? AND EntityIdentifier = ? AND CurrencyId = ? AND ParametersHash = ?',
            whereArgs: [
              'AccountStatement',
              selectedAccount.value!.id,
              selectedCurrency.value!.currencyNo.toString(),
              parametersHash,
            ],
            orderBy: 'Id DESC',
          );
        } catch (cacheErr) {
          debugPrint('⚠️ Ignored offline cache query error: $cacheErr');
        }

        if (cacheResult.isNotEmpty) {
          final syncTime = cacheResult.first['LastSyncTimestamp'];
          final preFilePath = cacheResult.first['file_path']?.toString();
          String? rawJson = preFilePath != null ? await ReportCacheFileManager.readReportJson(preFilePath) : null;
          
          if (e.reason == 'CONNECTION_LOST') {
            bool proceed = await UiHelper.showOfflineWarningDialog(syncTime.toString());
            if (!proceed) {
              isLoading.value = false;
              return;
            }
          }

          final filePath = cacheResult.first['file_path']?.toString();
          // rawJson pre-read before dialog
          if (filePath != null && rawJson == null) {
            rawJson = await ReportCacheFileManager.readReportJson(filePath);
          }

          if (rawJson != null && rawJson.isNotEmpty) {
            await _processOfflineFileInIsolate(rawJson);
            return;
          }
        }

        try {
          final fallbackCached = await OfflineReportQueryService.findCachedReportWithFallback(
            reportType: 'AccountStatement',
            currencyId: selectedCurrency.value!.currencyNo.toString(),
            exactParamsHash: parametersHash,
            entityId: selectedAccount.value!.id,
            year: year,
            branchId: effectiveBranchId,
          );
          if (fallbackCached != null && fallbackCached.rawJson.isNotEmpty) {
            if (e.reason == 'CONNECTION_LOST') {
              bool proceed = await UiHelper.showOfflineWarningDialog(fallbackCached.lastSyncTimestamp);
              if (!proceed) {
                isLoading.value = false;
                return;
              }
            }
            await _processOfflineFileInIsolate(fallbackCached.rawJson);
            return;
          }
        } catch (fbErr) {
          debugPrint('⚠️ Ignored fallback cache lookup error: $fbErr');
        }

        AppSnackbar.showCustomSnackbar(
          'خطأ',
          cacheResult.isNotEmpty
              ? 'تعذر قراءة ملف كاش كشف الحساب المحلي.'
              : 'لا يوجد اتصال بالإنترنت ولا توجد بيانات سابقة محفوظة لهذا الحساب.',
          isError: true,
        );
      }
    } catch (e) {
      if (e is! OfflineFallbackException) {
        AppSnackbar.showCustomSnackbar(
            'خطأ', 'فشل في جلب كشف الحساب: ${e.toString()}',
            isError: true);
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// معالجة ملف الكاش المحلي أو استجابة 200 OK في Background Isolate واحد
  /// يقوم بفك تشفير JSON وبناء نماذج العرض في مسار واحد
  Future<void> _processOfflineFileInIsolate(String rawJson, {bool isOfflineSlicing = true}) async {
    final params = StatementProcessingParams(
      rawJson: rawJson,
      fromDate: fromDate.value,
      toDate: toDate.value,
      isOfflineSlicing: isOfflineSlicing,
    );

    final result = await compute(isolateProcessAccountStatement, params);
    _lastIsolateLedgerSignature = result.ledgerSignature;

    openingBalance.value = result.openingBalance;
    totalDebit.value = result.totalDebit;
    totalCredit.value = result.totalCredit;
    closingBalance.value = result.closingBalance;
    statementRows.assignAll(result.rows);

    if (statementRows.isEmpty && openingBalance.value == 0) {
      clearStatement(keepAccountAndCurrency: true);
      AppSnackbar.showCustomSnackbar('معلومات', 'لا توجد حركات أو أرصدة في هذه الفترة المحددة.');
    }
  }

  void clearForm() {
    selectedAccount.value = null;
    accountNameController.clear();
    allowedCurrencies.clear();
    selectedCurrency.value = null;
    final now = DateTime.now();
    fromDate.value = DateTime(now.year, now.month, 1);
    toDate.value = DateTime(now.year, now.month + 1, 0);
    clearStatement();
  }

  void clearFilters() {
    selectedAccount.value = null;
    fromDate.value = DateTime.now().subtract(const Duration(days: 30));
    toDate.value = DateTime.now();
    openingBalance.value = 0.0;
    statementRows.clear();
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

  void clearStatement({bool keepAccountAndCurrency = false}) {
    statementRows.clear();
    openingBalance.value = 0.0;
    totalDebit.value = 0.0;
    totalCredit.value = 0.0;
    closingBalance.value = 0.0;
  }

  void onStatementRowTap(StatementRowDisplayModel row) {
    if (row.type == 'رصيد مرحل') return;

    final String code = row.traLstId.trim();
    final String typeText = row.type.trim();

    final bool isReceiptVoucher = code == '201' || (code.isEmpty && typeText == 'سند قبض');
    final bool isPaymentVoucher = code == '202' || (code.isEmpty && typeText == 'سند صرف');

    final int effectiveBranchId =
        (selectedBranch.value?['branch_id'] as int?) ?? userState.safeUserBranch;
    String year = userState.safeFinancialYearName;
    if (year == 'غير محددة' || year.isEmpty) {
      year = fromDate.value.year.toString();
    }

    if (isReceiptVoucher && row.traId.isNotEmpty) {
      Get.to(
        () => ReceiptScreen(receiptId: int.tryParse(row.traId)),
        arguments: {
          'transactionId': row.traId,
          'isRemote': true,
          'remoteBranchId': effectiveBranchId,
          'remoteYear': year,
        },
      );
      return;
    }

    if (isPaymentVoucher && row.traId.isNotEmpty) {
      Get.to(
        () => CashPaymentVoucherScreen(paymentId: int.tryParse(row.traId)),
        arguments: {
          'transactionId': row.traId,
          'isRemote': true,
          'remoteBranchId': effectiveBranchId,
          'remoteYear': year,
        },
      );
      return;
    }

    // عرض تفاصيل الحركة (حركات الموظفين والسلف 105 / 214 / 215 / 106 والقيود والفواتير)
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                row.typeStr.isNotEmpty ? row.typeStr : 'تفاصيل الحركة',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (code.isNotEmpty) _buildDetailLine('رمز الحركة:', code),
              _buildDetailLine('رقم الحركة:', row.traNoStr),
              _buildDetailLine('التاريخ:', row.dateStr),
              if (row.beneficiaryStr.isNotEmpty)
                _buildDetailLine('المستفيد:', row.beneficiaryStr),
              if (row.debit > 0) _buildDetailLine('مدين:', row.debitStr),
              if (row.credit > 0) _buildDetailLine('دائن:', row.creditStr),
              _buildDetailLine('الرصيد:', row.balanceStr),
              if (row.descriptionStr.isNotEmpty) ...[
                const Divider(),
                const Text(
                  'البيان:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(row.descriptionStr, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> printStatement() async {
    if (statementRows.isEmpty ||
        selectedAccount.value == null ||
        selectedCurrency.value == null) {
      AppSnackbar.showCustomSnackbar(
          'خطأ', 'لا توجد بيانات لطباعتها. يرجى عرض التقرير أولاً.',
          isError: true);
      return;
    }

    await _invoiceTemplatesController.fetchInvoiceTemplates();
    _invoiceTemplatesController.selectTemplate('AccountStatementScreen');

    if (_invoiceTemplatesController.companyNameController.text.trim().isEmpty) {
      await _invoiceTemplatesController.fetchInvoiceTemplates(forceRefresh: true);
      _invoiceTemplatesController.selectTemplate('AccountStatementScreen');
    }

    // في حال كان قالب كشف الحساب محفوظاً باسم شركة فارغ بينما قوالب الفواتير/السندات مضبوطة
    if (_invoiceTemplatesController.companyNameController.text.trim().isEmpty) {
      for (final fallbackScreen in const [
        'CashSaleScreen',
        'ReceiptScreen',
        'CashPaymentVoucherScreen',
      ]) {
        _invoiceTemplatesController.selectTemplate(fallbackScreen);
        if (_invoiceTemplatesController.companyNameController.text.trim().isNotEmpty) {
          break;
        }
      }
    }

    if (_invoiceTemplatesController.companyNameController.text.trim().isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('saved_company_name')?.trim() ?? '';
      _invoiceTemplatesController.companyNameController.text =
          savedName.isNotEmpty ? savedName : userState.safeUserBranchName;
    }

    if (_invoiceTemplatesController.companyNameController.text.trim().isEmpty) {
      AppSnackbar.showCustomSnackbar('خطأ',
          'لا يمكن تحميل إعدادات قالب الطباعة، يرجى التأكد من ضبط القوالب في الإعدادات.',
          isError: true);
      return;
    }

    Get.to(() => StatementPdfView(
      accountName: selectedAccount.value!.name,
      accountNumber: selectedAccount.value!.accountNumber,
      currencyName: selectedCurrency.value!.currencyName,
      fromDate: fromDate.value,
      toDate: toDate.value,
      statementRows: statementRows.map((r) => r.toMap()).toList(),
      openingBalance: openingBalance.value,
      totalDebit: totalDebit.value,
      totalCredit: totalCredit.value,
      closingBalance: closingBalance.value,
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