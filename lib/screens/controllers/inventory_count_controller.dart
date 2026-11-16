import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/repositories/sales_repository.dart';
import 'package:untitled4/models/full_sales_invoice.dart';
import 'package:untitled4/screens/controllers/inventory_header_controller.dart';
import 'package:untitled4/screens/controllers/input_section_controller.dart';
import 'package:untitled4/screens/controllers/inventory_products_controller.dart';
import 'package:untitled4/screens/controllers/inventory_calculations_controller.dart';
import '../../services/lookups_service.dart.dart';
import '../../utils/trial_period_manager.dart';
import '../inventory_history_screen.dart';

class InventoryCountController extends GetxController {
  final UserState userState = Get.find<UserState>();
  final SalesRepository _salesRepository = SalesRepository();
  final LookupsService _lookupsService = Get.find<LookupsService>();

  late final String _tag;
  final RxBool isLoading = false.obs;
  final RxnString currentInventoryId = RxnString();

  late final InventoryHeaderController headerController;
  late final InputSectionController inputController;
  late final InventoryProductsController productsController;
  late final InventoryCalculationsController calculationsController;

  final RxBool showExpiryDate = true.obs;
  final RxBool showBatchNumber = true.obs;

  InventoryCountController({String? initialInventoryId, required String controllerTag}) {
    _tag = controllerTag;
    if (initialInventoryId != null) {
      currentInventoryId.value = initialInventoryId;
    }
    headerController = Get.put(InventoryHeaderController(), tag: _tag);
    inputController = Get.put(InputSectionController(), tag: _tag);
    calculationsController = Get.put(InventoryCalculationsController(), tag: _tag);
    productsController = Get.put(InventoryProductsController(controllerTag: _tag), tag: _tag);
  }

  @override
  void onInit() {
    super.onInit();
    _loadTableSettings();
    _initializeData();

    ever(inputController.selectedStore, (_) {
      if (!isLoading.value && productsController.products.where((p) => p['isEmpty'] != true).isNotEmpty) {
      }
    });
  }

  Future<void> _loadTableSettings() async {
    final prefs = await SharedPreferences.getInstance();
    showExpiryDate.value = prefs.getBool('inv_showExpiryDate') ?? true;
    showBatchNumber.value = prefs.getBool('inv_showBatchNumber') ?? true;
  }

  Future<void> toggleTableSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    switch (key) {
      case 'expiry':
        showExpiryDate.value = value;
        await prefs.setBool('inv_showExpiryDate', value);
        break;
      case 'batch':
        showBatchNumber.value = value;
        await prefs.setBool('inv_showBatchNumber', value);
        break;
    }
  }

  Future<void> _initializeData() async {
    isLoading.value = true;
    try {
      if (_lookupsService.productsList.isEmpty) {
        await _lookupsService.loadAllLookupData();
      }

      if (currentInventoryId.value == null) {
        await Future.wait([
          inputController.loadInitialData(),
          headerController.generateNextTransactionNumber(),
        ]);
      } else {
        await _loadInventoryForEditing(currentInventoryId.value!);
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تحميل البيانات الأولية', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadInventoryForEditing(String id) async {
    try {
      final FullSalesInvoice fullInvoice = await _salesRepository.loadInvoice(id);
      final saleData = fullInvoice.sale;

      await inputController.loadInitialData();

      final int? loadedStoreNo = saleData.storeNo;
      if (loadedStoreNo != null) {
        await inputController.fetchAndAddMissingStore(loadedStoreNo);
        final storeName = inputController.stores.firstWhereOrNull((s) => s.noStore == loadedStoreNo)?.nameStore;
        inputController.selectedStore.value = storeName ?? '';
      }
      inputController.updateSelectedCurrency(saleData.currency);

      currentInventoryId.value = saleData.id;
      headerController.transactionNumber.value = saleData.transactionNumber;
      headerController.closingDate.value = saleData.date;
      if (saleData.startDate != null) {
        headerController.startDate.value = saleData.startDate!;
      }

      double calculatedSysQty = 0.0;
      double calculatedActQty = 0.0;
      double calculatedDiffQty = 0.0;
      double calculatedSysVal = 0.0;
      double calculatedActVal = 0.0;
      double calculatedDeficit = 0.0;
      double calculatedSurplus = 0.0;

      for (var item in fullInvoice.items) {
        double sQty = item.stockBalance ?? 0.0;
        double aQty = item.quantity.toDouble();
        double cost = item.costPrice ?? item.itemPrice;

        calculatedSysQty += sQty;
        calculatedActQty += aQty;

        double diff = item.diffQuantity ?? (aQty - sQty);
        calculatedDiffQty += diff;

        calculatedSysVal += (sQty * cost);
        calculatedActVal += item.total;
        calculatedDeficit += item.deficitValue ?? 0.0;
        calculatedSurplus += item.surplusValue ?? 0.0;
      }

      calculationsController.updateCalculations(
        sysQty: calculatedSysQty,
        actQty: calculatedActQty,
        sysVal: calculatedSysVal,
        actVal: calculatedActVal,
        surplus: calculatedSurplus,
        deficit: calculatedDeficit,
        totalDiffQtyInput: calculatedDiffQty,
      );

      await productsController.loadInvoiceProductsForInventory(fullInvoice.items);

    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تحميل المحضر المطلوب', isError: true);
      _resetForm();
    }
  }

  Future<void> navigateToSearch() async {
    final result = await Get.to(() => const InventoryHistoryScreen());
    if (result != null && result is String) {
      _resetForm();
      isLoading.value = true;
      await _loadInventoryForEditing(result);
      isLoading.value = false;
    }
  }

  Future<void> saveInventory() async {
    if (inputController.selectedStoreNo == null) {
      AppSnackbar.showCustomSnackbar('خطأ', 'يرجى اختيار المخزن', isError: true);
      return;
    }
    if (productsController.products.isEmpty) {
      AppSnackbar.showCustomSnackbar('خطأ', 'لا يوجد أصناف', isError: true);
      return;
    }

    isLoading.value = true;
    try {
      final headerData = _prepareHeaderData();
      final itemsData = _prepareItemsData();

      if (currentInventoryId.value == null) {
        // التحقق من الفترة التجريبية قبل الحفظ
        final checkResult = await TrialPeriodManager.checkOnSave(invoiceTypeChar: 'م ض');
        if (checkResult != TrialSaveCheckResult.allow) {
          isLoading.value = false;
          return;
        }

        final result = await _salesRepository.saveCompleteSale(
          saleHeader: headerData,
          saleItems: itemsData,
          ledgerPostings: [],
        );

        final String newId = result['id'].toString();
        final String transNo = result['transaction_number'].toString();

        currentInventoryId.value = newId;
        headerController.transactionNumber.value = transNo;

        AppSnackbar.showCustomSnackbar('نجاح', 'تم حفظ المحضر رقم $transNo', isError: false);

        await TrialPeriodManager.handlePostSave(invoiceTypeChar: 'م ض', screenTitle: 'محضر جرد');

        _resetForm();
      } else {
        final String idToUpdate = currentInventoryId.value!;

        await _salesRepository.updateCompleteSale(
          invoiceId: int.parse(idToUpdate),
          saleHeader: headerData,
          saleItems: itemsData,
          ledgerPostings: [],
        );

        AppSnackbar.showCustomSnackbar('نجاح', 'تم تعديل المحضر', isError: false);
      }
      
      _triggerBackgroundSync();
      
    } catch (e) {
      print("Inventory Save Error: $e");
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ أثناء حفظ البيانات', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  void _triggerBackgroundSync() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final String? savedAddress = prefs.getString('server_address');

        if (savedAddress != null && savedAddress.isNotEmpty) {
          final String fullApiUrl = 'http://$savedAddress/api/Transaction/sync-inventory';

          await _salesRepository.syncSalesToRemote(
              fullApiUrl,
              "",
              invoiceTypeChar: 'م ض'
          );
          await _salesRepository.deleteOldSyncedSales();
        }
      } catch (e) {
        print("Background sync error: $e");
      }
    });
  }

  Map<String, dynamic> _prepareHeaderData() {
    return {
      'transaction_number': currentInventoryId.value == null
          ? ''
          : headerController.transactionNumber.value,
      'date': headerController.closingDate.value.toUtc().toIso8601String(),
      'start_date': headerController.startDate.value.toUtc().toIso8601String(),
      'invoice_type_char': 'م ض',
      'store_no': inputController.selectedStoreNo,
      'branch_id': userState.userBranch,
      'user_id': userState.userNo,
      'currency': inputController.selectedCurrency.value,
      'sun_year': userState.safeFinancialYearName,
      'total': calculationsController.totalActualValue.value,
      'net_total': calculationsController.netDiffValue.value,
      'system_total_value': calculationsController.totalSystemValue.value,
      'tax': 0, 'discount': 0, 'account_no': '', 'is_synced': 0,
      'source_last_updated_at': DateTime.now().toString(),
    };
  }

  List<Map<String, dynamic>> _prepareItemsData() {
    return productsController.products.where((item) => item['isEmpty'] != true).map((item) {
      final double qty = (item['actual_qty'] as num?)?.toDouble() ?? 0.0;
      final double cost = (item['cost_price'] as num?)?.toDouble() ?? 0.0;
      final double totalVal = qty * cost;

      return {
        'item_no': item['item_no'],
        'item_unit': item['item_unit'] ?? '',
        'pack_factor': item['pack_factor'] ?? 1.0,
        'expiry_date': item['expiry_date'],
        'batch_no': item['batch_no'] ?? '',
        'quantity': qty,
        'stock_balance': item['system_qty'] ?? 0.0,
        'cost_price': cost,
        'diff_quantity': item['diff_qty'] ?? 0.0,
        'deficit_value': item['deficit_value'] ?? 0.0,
        'surplus_value': item['surplus_value'] ?? 0.0,
        'item_price': cost,
        'total': totalVal,
        'created_at': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  void _resetForm() {
    currentInventoryId.value = null;
    productsController.clearAll();
    calculationsController.reset();
    headerController.resetHeader();
    headerController.generateNextTransactionNumber();
  }

  @override
  void onClose() {
    Get.delete<InventoryHeaderController>(tag: _tag, force: true);
    Get.delete<InputSectionController>(tag: _tag, force: true);
    Get.delete<InventoryCalculationsController>(tag: _tag, force: true);
    Get.delete<InventoryProductsController>(tag: _tag, force: true);
    super.onClose();
  }
}