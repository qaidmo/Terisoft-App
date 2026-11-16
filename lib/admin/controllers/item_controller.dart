import 'package:get/get.dart';
import 'package:flutter/material.dart';
// Note: supabase_flutter import removed — no longer used after server migration
import 'package:untitled4/models/sun_item.dart';
import 'package:untitled4/models/sun_currency.dart';
import 'package:untitled4/models/sun_item_group.dart';
import 'package:untitled4/models/cost_center.dart';
import 'package:untitled4/repositories/account_repository.dart'; // <-- Added
import 'package:untitled4/repositories/item_repository.dart'; // <-- Added
import 'package:untitled4/repositories/lookups_repository.dart'; // <-- Added
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/models/sun_main_group.dart';
import '../../user_state.dart';
import '../printing/funds_pdf_view.dart';
import '../printing/pdf_items_report.dart';

// Removed: supabase_manager.dart

class ItemController extends GetxController {
  final ItemRepository _itemRepository = ItemRepository(); // <-- Added
  final LookupsRepository _lookupsRepository = LookupsRepository(); // <-- Added
  final AccountRepository _accountRepository = AccountRepository(); // <-- Added

  final RxList<SunItem> allItems = <SunItem>[].obs;
  final RxList<SunCurrency> currencies = <SunCurrency>[].obs;
  final RxList<SunMainGroup> allMainGroups = <SunMainGroup>[].obs;
  final RxList<SunItemGroup> allGroups = <SunItemGroup>[].obs;
  final RxList<CostCenter> costCenters = <CostCenter>[].obs;
  final RxList<String> units = <String>[].obs;

  final RxList<Map<String, dynamic>> inventoryAccounts =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> cogsAccounts =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> salesRevenueAccounts =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> salesDiscountAccounts =
      <Map<String, dynamic>>[].obs;

  final RxBool isLoading = true.obs;
  final RxBool isEditing = false.obs;
  final RxBool isSaveEnabled = false.obs; // true when form is unlocked for Add or Edit
  final RxnString editingNo = RxnString();
  final RxBool isTaxable = false.obs;
  final RxBool isDiscountable = false.obs;
  final RxBool isCashReserved = false.obs;

  final noController = TextEditingController();
  final nameController = TextEditingController();
  final barcodeController = TextEditingController();
  final unitController = TextEditingController();
  final priceController = TextEditingController();
  final taxRateController = TextEditingController();
  final discountRateController = TextEditingController();
  final costCenterNameController = TextEditingController();
  final RxnInt selectedCostCenterNo = RxnInt();

  final RxnString selectedInventoryAccountId = RxnString();
  final RxnString selectedCogsAccountId = RxnString();
  final RxnString selectedSalesRevenueAccountId = RxnString();
  final RxnString selectedSalesDiscountAccountId = RxnString();

  final groupNameController = TextEditingController();
  final RxnString selectedMainGroupNo = RxnString();
  final RxnString selectedGroupNo = RxnString();
  final RxnInt selectedCurrency = RxnInt();

  @override
  void onInit() {
    super.onInit();
    fetchData();
  }

  @override
  void onClose() {
    noController.dispose();
    nameController.dispose();
    barcodeController.dispose();
    unitController.dispose();
    priceController.dispose();
    costCenterNameController.dispose();
    taxRateController.dispose();
    discountRateController.dispose();
    groupNameController.dispose();
    super.onClose();
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      const inventoryParentNumber = '1241';
      const cogsParentNumber = '3111';
      const revenueParentNumber = '4111';
      const discountParentNumber = '3112';

      Future<List<Map<String, dynamic>>> getChildAccounts(
          String parentNumber) async {
        final parentRes =
        await _accountRepository.getAccountByTrimmedNumber(parentNumber);
        if (parentRes == null || parentRes['id'] == null) return [];
        final parentId = parentRes['id'];
        return await _accountRepository.getTransactionalChildrenOfParent(parentId);
      }

      final responses = await Future.wait([
        _itemRepository.fetchAllItemsWithDetails(),
        _lookupsRepository.fetchAllCurrencies(),
        _lookupsRepository.fetchAllItemGroups(),
        getChildAccounts(inventoryParentNumber),
        getChildAccounts(cogsParentNumber),
        getChildAccounts(revenueParentNumber),
        getChildAccounts(discountParentNumber),
        _lookupsRepository.fetchAllCostCenters(),
        _itemRepository.fetchDistinctUnits(),
        _lookupsRepository.fetchAllMainGroups(),
      ]);

      allItems.assignAll(responses[0] as List<SunItem>);

      currencies.assignAll(responses[1] as List<SunCurrency>);
      allGroups.assignAll((responses[2] as List<Map<String, dynamic>>)
          .map((g) => SunItemGroup.fromJson(g))
          .toList());

      inventoryAccounts
          .assignAll(responses[3] as List<Map<String, dynamic>>);
      cogsAccounts.assignAll(responses[4] as List<Map<String, dynamic>>);
      salesRevenueAccounts
          .assignAll(responses[5] as List<Map<String, dynamic>>);
      salesDiscountAccounts
          .assignAll(responses[6] as List<Map<String, dynamic>>);

      costCenters.assignAll((responses[7] as List<Map<String, dynamic>>)
          .map((cc) => CostCenter.fromJson(cc))
          .toList());

      units.assignAll(responses[8] as List<String>);
      
      allMainGroups.assignAll((responses[9] as List<Map<String, dynamic>>)
          .map((mg) => SunMainGroup.fromJson(mg))
          .toList());
    } catch (e) {
      print("Error in fetchData: $e");
      showMessage('حدث خطأ أثناء جلب البيانات: ${e.toString()}', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> selectGroup(SunItemGroup group) async {
    selectedGroupNo.value = group.groupNo;
    groupNameController.text = group.groupName;
    Get.back();

    if (!isEditing.value) {
      isLoading.value = true;
      noController.clear();
      try {
        final int length = group.groupLength ?? 3;
        final newItemCode = await _itemRepository.getNextItemCode(group.groupNo, length);
        if (newItemCode != null) {
          noController.text = newItemCode;
        } else {
          showMessage('لم يتم العثور على تسلسل لهذه المجموعة.', isError: true);
        }
      } catch (e) {
        showMessage('خطأ أثناء معاينة رقم الصنف: ${e.toString()}', isError: true);
      } finally {
        isLoading.value = false;
      }
    }
  }

  void selectCostCenter(CostCenter center) {
    selectedCostCenterNo.value = center.centerNo;
    costCenterNameController.text = center.centerName;
    Get.back();
  }

  void clearForm() {
    isEditing.value = false;
    isSaveEnabled.value = false; // Lock the form back to read-only
    editingNo.value = null;
    noController.clear();
    nameController.clear();
    barcodeController.clear();
    unitController.clear();
    priceController.clear();
    isTaxable.value = false;
    taxRateController.clear();
    isDiscountable.value = false;
    isCashReserved.value = false;
    discountRateController.clear();
    selectedCurrency.value = null;
    selectedMainGroupNo.value = null;
    selectedGroupNo.value = null;
    groupNameController.clear();
    selectedInventoryAccountId.value = null;
    selectedCogsAccountId.value = null;
    selectedSalesRevenueAccountId.value = null;
    selectedSalesDiscountAccountId.value = null;
    costCenterNameController.clear();
    selectedCostCenterNo.value = null;
  }

  /// Called by the جديد (New) button: clears the form and unlocks it for data entry.
  void startNew() {
    clearForm();
    isEditing.value = false;
    isSaveEnabled.value = true; // Unlock the form
  }

  void editItem(SunItem item) {
    isEditing.value = true;
    isSaveEnabled.value = true; // Unlock the form for editing
    editingNo.value = item.itemNo;
    noController.text = item.itemNo;
    nameController.text = item.itemName;
    barcodeController.text = item.itemBarcode ?? '';
    unitController.text = item.itemUnit;
    priceController.text = item.itemPrice.toStringAsFixed(2);
    isTaxable.value = item.isTaxable;
    taxRateController.text = item.taxRate.toString();
    isDiscountable.value = item.isDiscountable;
    isCashReserved.value = item.isCashReserved;
    discountRateController.text = item.discountRate?.toString() ?? '';
    selectedCurrency.value = item.currencyNo;
    selectedGroupNo.value = item.itemGroupNo;
    groupNameController.text = item.groupName ?? '';
    
    final group = allGroups.firstWhereOrNull((g) => g.groupNo == item.itemGroupNo);
    selectedMainGroupNo.value = group?.mainGroupNo;
    
    selectedInventoryAccountId.value = item.inventoryAccountId;
    selectedCogsAccountId.value = item.cogsAccountId;
    selectedSalesRevenueAccountId.value = item.salesRevenueAccountId;
    selectedSalesDiscountAccountId.value = item.salesDiscountAccountId;
    selectedCostCenterNo.value = item.costCenterNo;
    final costCenter =
    costCenters.firstWhereOrNull((c) => c.centerNo == item.costCenterNo);
    costCenterNameController.text = costCenter?.centerName ?? '';
  }

  Future<void> submitForm(GlobalKey<FormState> formKey) async {
    if (selectedGroupNo.value == null && !isEditing.value) {
      showMessage('يرجى اختيار مجموعة أولاً.', isError: true);
      return;
    }
    if (nameController.text.isEmpty || priceController.text.isEmpty) {
      showMessage('يرجى ملء اسم الصنف والسعر.', isError: true);
      return;
    }
    if (selectedCurrency.value == null) {
      showMessage('يرجى اختيار العملة.', isError: true);
      return;
    }

    isLoading.value = true;
    try {
      final double? finalDiscountRate = isDiscountable.value
          ? (double.tryParse(discountRateController.text) ?? 0.0)
          : null;
      final double finalTaxRate = double.tryParse(taxRateController.text) ?? 0.0;

      if (isEditing.value) {
        // --- EDIT FLOW: local-first, then server ---
        // Build a map with proper SQLite column names (no p_ prefix).
        final itemData = {
          'item_name': nameController.text,
          'item_barcode': barcodeController.text.isEmpty ? null : barcodeController.text,
          'item_unit': unitController.text,
          'item_price': double.parse(priceController.text),
          'item_group_no': selectedGroupNo.value,
          'currency_no': selectedCurrency.value!,
          'inventory_account_id': selectedInventoryAccountId.value,
          'cogs_account_id': selectedCogsAccountId.value,
          'sales_revenue_account_id': selectedSalesRevenueAccountId.value,
          'sales_discount_account_id': selectedSalesDiscountAccountId.value,
          'is_taxable': isTaxable.value ? 1 : 0,
          'tax_rate': finalTaxRate,
          'cost_center_no': selectedCostCenterNo.value,
          'discount_rate': finalDiscountRate,
          'is_discountable': isDiscountable.value ? 1 : 0,
          'is_cash_reserved': isCashReserved.value ? 1 : 0,
        };

        // Step 1: Update local SQLite immediately so UI feels responsive.
        await _itemRepository.updateItem(editingNo.value!, itemData);

        // Step 2: Send update to server (best-effort).
        // If server is offline the local change is still saved.
        try {
          await _itemRepository.updateItemOnServer(editingNo.value!, itemData);
          showMessage('تم تحديث الصنف بنجاح');
        } catch (serverError) {
          // Local save succeeded but server was unreachable.
          String errMsg = serverError.toString();
          if (errMsg.startsWith('Exception: ')) {
            errMsg = errMsg.substring('Exception: '.length);
          }
          showMessage(
            'تم الحفظ محلياً. تعذّر تحديث السيرفر: $errMsg',
            isWarning: true,
          );
        }
      } else {
        // --- CREATE FLOW: server-first, then local ---
        // The server validates the item_no is not a duplicate before we commit locally.
        
        final unitConversionFactor = await _itemRepository.getUnitConversionFactor(unitController.text);
        
        final serverParams = {
          'ItemNo': noController.text,
          'ItemName': nameController.text,
          'ItemBarcode': barcodeController.text.isEmpty ? null : barcodeController.text,
          'ItemUnit': unitController.text,
          'ItemUnitSizeValue': unitConversionFactor,
          'ItemPrice': double.parse(priceController.text),
          'ItemGroupNo': selectedGroupNo.value,
          'CurrencyNo': selectedCurrency.value!,
          'InventoryAccountId': selectedInventoryAccountId.value,
          'CogsAccountId': selectedCogsAccountId.value,
          'SalesRevenueAccountId': selectedSalesRevenueAccountId.value,
          'SalesDiscountAccountId': selectedSalesDiscountAccountId.value,
          'IsTaxable': isTaxable.value,
          'TaxRate': finalTaxRate,
          'IsDiscountable': isDiscountable.value,
          'DiscountRate': finalDiscountRate,
          'IsCashReserved': isCashReserved.value,
          'CostCenterNo': selectedCostCenterNo.value,
          'MainGroupNo': selectedMainGroupNo.value ?? "1",
          'SectionId': Get.find<UserState>().userDepartment?.toString() ?? "1",
        };

        // Step 1: Send to server FIRST — validates for duplicate item_no.
        final response = await _itemRepository.createItemOnServer(serverParams);

        if (response['success'] == true) {
          // Step 2: Server confirmed success — now write to local SQLite.
          // Use proper SQLite column names (no PascalCase, no p_ prefix).
          final sqliteData = {
            'item_no': noController.text,
            'item_name': nameController.text,
            'item_barcode': barcodeController.text.isEmpty ? null : barcodeController.text,
            'item_unit': unitController.text,
            'item_price': double.parse(priceController.text),
            'item_group_no': selectedGroupNo.value,
            'currency_no': selectedCurrency.value!,
            'inventory_account_id': selectedInventoryAccountId.value,
            'cogs_account_id': selectedCogsAccountId.value,
            'sales_revenue_account_id': selectedSalesRevenueAccountId.value,
            'sales_discount_account_id': selectedSalesDiscountAccountId.value,
            'is_taxable': isTaxable.value ? 1 : 0,
            'tax_rate': finalTaxRate,
            'cost_center_no': selectedCostCenterNo.value,
            'discount_rate': finalDiscountRate,
            'is_discountable': isDiscountable.value ? 1 : 0,
            'is_cash_reserved': isCashReserved.value ? 1 : 0,
          };
          await _itemRepository.createNewItem(sqliteData);
          showMessage('تمت إضافة الصنف بنجاح');
        } else {
          // Server rejected the request (e.g. duplicate item_no).
          showMessage(response['message']?.toString() ?? 'رفض السيرفر الطلب', isError: true);
          return; // Do NOT write to SQLite.
        }
      }

      await fetchData();
      clearForm();
    } catch (e) {
      showMessage('حدث خطأ أثناء الحفظ: ${e.toString()}', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteItem(String itemNo) async {
    bool? confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الصنف؟'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      isLoading.value = true;
      try {
        await _itemRepository.deleteItem(itemNo);
        await fetchData();
        clearForm();
        showMessage('تم حذف الصنف بنجاح.');
      } catch (e) {
        showMessage('حدث خطأ أثناء الحذف: ${e.toString()}', isError: true);
      } finally {
        isLoading.value = false;
      }
    }
  }

  void printData() async {
    List<SunItem> dataToPrint = [];
    String reportTitle = '';
    if (isEditing.value && editingNo.value != null) {
      final selectedItem =
      allItems.firstWhereOrNull((item) => item.itemNo == editingNo.value);
      if (selectedItem != null) {
        dataToPrint.add(selectedItem);
        reportTitle = 'طباعة بيانات الصنف: ${selectedItem.itemName}';
      }
    } else if (selectedGroupNo.value != null) {
      dataToPrint = allItems
          .where((item) => item.itemGroupNo == selectedGroupNo.value)
          .toList();
      final groupName = groupNameController.text;
      reportTitle = 'تقرير اصناف المجموعة: $groupName';
    } else {
      dataToPrint = allItems.toList();
      reportTitle = 'تقرير بجميع الأصناف';
    }

    if (dataToPrint.isEmpty) {
      showMessage('لا توجد بيانات للطباعة.', isError: true);
      return;
    }

    Get.dialog(const Center(child: CircularProgressIndicator()),
        barrierDismissible: false);
    try {
      final userState = Get.find<UserState>();
      final currentUserName = userState.safeUserName;
      final pdfData = await PdfItemsReport.generate(
          items: dataToPrint,
          reportTitle: reportTitle,
          userName: currentUserName);
      Get.back();
      Get.to(() => FundsPdfView(pdfData: pdfData, reportTitle: reportTitle));
    } catch (e) {
      Get.back();
      showMessage('حدث خطأ أثناء إنشاء الـ PDF: ${e.toString()}', isError: true);
    }
  }

  void showMessage(String message, {bool isError = false, bool isWarning = false}) {
    // Robustly strip any technical prefixes like "Exception: ", "TimeoutException: ", etc.
    message = message.replaceAll(RegExp(r'[a-zA-Z]*Exception:\s*'), '');
    
    final String title = isError ? 'خطأ' : (isWarning ? 'تنبيه' : 'نجاح');
    AppSnackbar.showCustomSnackbar(title, message, isError: isError, isWarning: isWarning);
  }

  String getCurrencySymbol(int? currencyNo) {
    if (currencyNo == null) return '';
    final currency = currencies.firstWhereOrNull((c) => c.currencyNo == currencyNo);
    return currency?.currencySymbol ?? '';
  }
}