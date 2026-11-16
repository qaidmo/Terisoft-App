import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:untitled4/models/sun_customer.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/account_repository.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/admin/printing/pdf_customers_report.dart';
import 'package:untitled4/admin/printing/funds_pdf_view.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'dart:developer';

class CustomerController extends GetxController {
  final LookupsRepository _lookupsRepository = LookupsRepository();
  final AccountRepository _accountRepository = AccountRepository();

  final RxList<SunCustomer> allCustomers = <SunCustomer>[].obs;
  final RxList<SunCustomer> filteredCustomers = <SunCustomer>[].obs;

  final RxBool isLoading = true.obs;
  final RxBool isSaveEnabled = false.obs;
  final RxBool isEditMode = false.obs;
  final Rxn<SunCustomer> selectedCustomer = Rxn<SunCustomer>();

  final noController = TextEditingController();
  final nameController = TextEditingController();
  final foreignNameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();
  final mainSearchController = TextEditingController();
  final accountNameController = TextEditingController();

  final costDataController = TextEditingController();
  final costNextController = TextEditingController();
  final costRsomController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchData();
    mainSearchController.addListener(() => filterCustomers(mainSearchController.text));
  }

  @override
  void onClose() {
    noController.dispose();
    nameController.dispose();
    foreignNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    emailController.dispose();
    mainSearchController.dispose();
    accountNameController.dispose();
    costDataController.dispose();
    costNextController.dispose();
    costRsomController.dispose();
    super.onClose();
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      final customersRes = await _lookupsRepository.fetchAllCustomers();
      allCustomers.assignAll(customersRes);
      filterCustomers('');
      await clearDisplay(generateId: false);
    } catch (e) {
      _handleDetailedError(e, 'جلب البيانات');
    } finally {
      isLoading.value = false;
    }
  }

  void filterCustomers(String query) {
    final validCustomers = allCustomers.where((c) => c.customerNo != 0).toList();

    if (query.isEmpty) {
      filteredCustomers.assignAll(validCustomers);
    } else {
      final lowerCaseQuery = query.toLowerCase();
      filteredCustomers.assignAll(validCustomers.where((customer) {
        return customer.customerName.toLowerCase().contains(lowerCaseQuery) ||
            customer.customerNo.toString().contains(lowerCaseQuery) ||
            (customer.phoneNumber?.contains(lowerCaseQuery) ?? false);
      }).toList());
    }
  }

  Future<void> clearDisplay({bool generateId = false}) async {
    nameController.clear();
    foreignNameController.clear();
    phoneController.clear();
    addressController.clear();
    emailController.clear();
    accountNameController.clear();
    costDataController.clear();
    costNextController.clear();
    costRsomController.clear();

    isEditMode.value = false;
    selectedCustomer.value = null;

    if (generateId) {
      try {
        final db = await DatabaseHelper.instance.database;
        final result = await db.rawQuery('SELECT MAX(customer_no) as max_no FROM sun_customers');

        int nextId = 1;
        if (result.isNotEmpty && result.first['max_no'] != null) {
          nextId = (result.first['max_no'] as int) + 1;
        }

        noController.text = nextId.toString();
      } catch (e) {
        noController.text = '0';
        log("Error fetching next customer ID: $e");
      }
    } else {
      noController.clear();
    }
  }

  Future<void> prepareNewCustomer() async {
    await clearDisplay(generateId: true);
    isSaveEnabled.value = true;
    isEditMode.value = false;
  }

  void prepareEditCustomer() {
    if (selectedCustomer.value != null) {
      isSaveEnabled.value = true;
      isEditMode.value = true;
    } else {
      showMessage('يرجى اختيار عميل أولاً للتعديل', isError: true);
    }
  }

  void displayCustomer(SunCustomer customer) {
    selectedCustomer.value = customer;
    isSaveEnabled.value = false;
    isEditMode.value = false;

    noController.text = customer.customerNo.toString();
    nameController.text = customer.customerName;
    foreignNameController.text = customer.customerForeignName ?? '';
    phoneController.text = customer.phoneNumber ?? '';
    addressController.text = customer.address ?? '';
    emailController.text = customer.email ?? '';
    accountNameController.text = customer.accountName ?? 'حساب غير محدد';
    costDataController.text = customer.costData ?? '';
    costNextController.text = customer.costNext?.toString() ?? '';
    costRsomController.text = customer.costRsom?.toString() ?? '';
  }

  Future<void> saveCustomer() async {
    if (nameController.text.trim().isEmpty) {
      showMessage('يرجى إدخال اسم العميل', isError: true);
      return;
    }

    isLoading.value = true;

    try {
      final userState = Get.find<UserState>();
      final String currentUserName = userState.safeUserName;

      // Optional utility fields (strictly nullable/non-mandatory)
      final String? costData = costDataController.text.trim().isEmpty ? null : costDataController.text.trim();
      final double? costNext = double.tryParse(costNextController.text.trim());
      final double? costRsom = double.tryParse(costRsomController.text.trim());

      if (isEditMode.value && selectedCustomer.value != null) {
        // === تحديث عميل موجود مسبقاً ===
        final updatedCustomer = selectedCustomer.value!.copyWith(
          customerName: nameController.text.trim(),
          customerForeignName: foreignNameController.text.trim(),
          phoneNumber: phoneController.text.trim(),
          address: addressController.text.trim(),
          email: emailController.text.trim(),
          costData: costData,
          costNext: costNext,
          costRsom: costRsom,
          lastUpdated: DateTime.now().toString(),
        );

        final response = await _accountRepository.updateCustomerOnServer(updatedCustomer, currentUserName);

        if (response['success'] == true) {
          final db = await DatabaseHelper.instance.database;

          try {
            await db.execute('PRAGMA foreign_keys = OFF');
            await db.update(
              'sun_customers',
              updatedCustomer.toMap(),
              where: 'customer_no = ?',
              whereArgs: [updatedCustomer.customerNo],
            );

            showMessage('تم تحديث بيانات العميل بنجاح');
            await fetchData();
            displayCustomer(updatedCustomer);
          } catch (dbError) {
            _handleDetailedError(dbError, 'تحديث البيانات محلياً');
          } finally {
            await db.execute('PRAGMA foreign_keys = ON');
          }
        } else {
          String errorMsg = response['message'] ?? 'فشل السيرفر في تحديث العميل';
          showMessage(errorMsg, isError: true);
        }
      } else {
        // === إنشاء عميل جديد ===
        final tempCustomer = SunCustomer(
          customerNo: 0,
          customerName: nameController.text.trim(),
          customerForeignName: foreignNameController.text.trim(),
          phoneNumber: phoneController.text.trim(),
          address: addressController.text.trim(),
          email: emailController.text.trim(),
          costData: costData,
          costNext: costNext,
          costRsom: costRsom,
          sourceId: null,
          accountId: null,
          lastUpdated: DateTime.now().toString(),
        );

        final response = await _accountRepository.createCustomerOnServer(tempCustomer, currentUserName);

        if (response['success'] == true) {
          final String newSourceId = response['customer_no'].toString();
          final String newAccountId = response['account_id'].toString();
          final int realCustomerNo = int.tryParse(newSourceId) ?? 0;

          final finalCustomer = SunCustomer(
            customerNo: realCustomerNo,
            customerName: tempCustomer.customerName,
            customerForeignName: tempCustomer.customerForeignName,
            phoneNumber: tempCustomer.phoneNumber,
            address: tempCustomer.address,
            email: tempCustomer.email,
            costData: tempCustomer.costData,
            costNext: tempCustomer.costNext,
            costRsom: tempCustomer.costRsom,
            sourceId: newSourceId,
            accountId: newAccountId,
            lastUpdated: DateTime.now().toString(),
          );

          final db = await DatabaseHelper.instance.database;

          try {
            await db.execute('PRAGMA foreign_keys = OFF');
            await db.insert('sun_customers', finalCustomer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

            showMessage('تم إنشاء العميل وحفظه بنجاح برقم $newSourceId');
            await fetchData();
            await clearDisplay(generateId: false);
          } catch (dbError) {
            _handleDetailedError(dbError, 'الحفظ المحلي');
          } finally {
            await db.execute('PRAGMA foreign_keys = ON');
          }

        } else {
          String errorMsg = response['message'] ?? 'فشل السيرفر في معالجة الطلب';
          showMessage(errorMsg, isError: true);
        }
      }
    } catch (e) {
      _handleDetailedError(e, 'عملية الحفظ');
    } finally {
      isLoading.value = false;
    }
  }

  void _handleDetailedError(dynamic error, String context) {
    String errorMessage = 'حدث خطأ غير متوقع أثناء $context';
    String errorString = error.toString();

    if (errorString.contains('SocketException') || errorString.contains('HttpException')) {
      errorMessage = 'تعذر الاتصال بالسيرفر، يرجى التأكد من اتصال الإنترنت أو إعدادات السيرفر';
    } else if (errorString.contains('BadPaddingException') || errorString.contains('BAD_DECRYPT')) {
      errorMessage = 'فشل في قراءة البيانات المشفرة، يرجى إعادة تسجيل الدخول لمزامنة مفاتيح الأمان';
    } else if (errorString.contains('SQLITE_CONSTRAINT_FOREIGNKEY') || errorString.contains('code 787')) {
      errorMessage = 'فشل في ربط العميل بالحساب المالي المختار، يرجى محاولة تحديث البيانات أولاً';
    } else if (errorString.contains('Unique constraint failed')) {
      errorMessage = 'هذا العميل موجود مسبقاً في النظام';
    } else if (errorString.contains('TimeoutException')) {
      errorMessage = 'استغرقت العملية وقتاً طويلاً، يرجى المحاولة مرة أخرى';
    }

    log("❌ خطأ تقني ($context): $error");
    showMessage(errorMessage, isError: true);
  }

  void printData() async {
    List<SunCustomer> dataToPrint = [];
    String reportTitle = '';

    if (mainSearchController.text.isNotEmpty) {
      dataToPrint = filteredCustomers.toList();
      reportTitle = 'طباعة نتائج البحث عن: "${mainSearchController.text}"';
    } else {
      dataToPrint = allCustomers.toList();
      reportTitle = 'تقرير بجميع العملاء';
    }

    if (dataToPrint.isEmpty) {
      showMessage('لا توجد بيانات للطباعة.', isError: true);
      return;
    }

    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final userState = Get.find<UserState>();
      final currentUserName = userState.safeUserName;

      final pdfData = await PdfCustomersReport.generate(
        customers: dataToPrint,
        reportTitle: reportTitle,
        userName: currentUserName,
      );
      Get.back();
      Get.to(() => FundsPdfView(pdfData: pdfData, reportTitle: reportTitle));
    } catch (e) {
      Get.back();
      _handleDetailedError(e, 'إنشاء التقرير');
    }
  }

  void showMessage(String message, {bool isError = false}) {
    final String title = isError ? 'تنبيه' : 'نجاح';
    AppSnackbar.showCustomSnackbar(title, message, isError: isError);
  }
}