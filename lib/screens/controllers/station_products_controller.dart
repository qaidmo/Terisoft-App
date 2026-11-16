import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:untitled4/screens/controllers/station_calculations_controller.dart';
import 'package:untitled4/screens/controllers/station_input_section_controller.dart';
import 'package:untitled4/screens/controllers/station_collection_controller.dart';
import 'package:untitled4/repositories/sales_repository.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/user_state.dart';
import '../../i_price_change_permission.dart';
import '../../services/lookups_service.dart.dart';

class StationsCollectionProductsController extends GetxController {
  final LookupsService _lookupsService = Get.find<LookupsService>();
  final SalesRepository _salesRepository = SalesRepository();
  final UserState _userState = Get.find<UserState>();

  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  late final TextEditingController productSearchController;

  static const int initialEmptyRows = 4;

  late final StationsCollectionCalculationsController _calculationsController;
  late final StationsCollectionInputSectionController _inputController;

  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, TextEditingController> _bonusQuantityControllers = {};
  final Map<int, TextEditingController> _discountControllers = {};
  final Map<int, TextEditingController> _priceControllers = {};
  final Map<int, TextEditingController> _batchNumberControllers = {};
  final Map<int, TextEditingController> _prevReadingControllers = {};
  final Map<int, TextEditingController> _currReadingControllers = {};

  final String _tag;
  Timer? _debounce;
  bool isReturnMode = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  late final Uint8List _beepBytes;
  RxBool isCameraVisible = false.obs;
  CameraController? cameraController;
  final TextRecognizer textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isProcessingFrame = false;
  DateTime? _lastScanTime;
  
  double? _lastRecognizedNumber;
  int _consecutiveRecognitions = 0;

  StationsCollectionProductsController({required String controllerTag}) : _tag = controllerTag;

  bool get isPriceChangeAllowed {
    try {
      final IPriceChangePermission mainController = Get.find<IPriceChangePermission>(tag: _tag);
      return mainController.canUserChangePrice.value;
    } catch (e) {
      return false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    try {
      _calculationsController = Get.find<StationsCollectionCalculationsController>(tag: _tag);
      _inputController = Get.find<StationsCollectionInputSectionController>(tag: _tag);
    } catch(e) {
      print("Error finding dependencies: $e");
    }

    productSearchController = TextEditingController();
    _initializeEmptyProducts();

    debounce(products, (_) => _updateCalculations(), time: const Duration(milliseconds: 50));

    _beepBytes = _generateBeep(durationMs: 150);
  }

  @override
  void onClose() {
    _debounce?.cancel();
    productSearchController.dispose();
    _disposeAllControllers();
    cameraController?.dispose();
    textRecognizer.close();
    _audioPlayer.dispose();
    super.onClose();
  }

  void _disposeAllControllers() {
    _quantityControllers.forEach((_, c) => c.dispose());
    _bonusQuantityControllers.forEach((_, c) => c.dispose());
    _discountControllers.forEach((_, c) => c.dispose());
    _priceControllers.forEach((_, c) => c.dispose());
    _batchNumberControllers.forEach((_, c) => c.dispose());
    _prevReadingControllers.forEach((_, c) => c.dispose());
    _currReadingControllers.forEach((_, c) => c.dispose());

    _quantityControllers.clear();
    _bonusQuantityControllers.clear();
    _discountControllers.clear();
    _priceControllers.clear();
    _batchNumberControllers.clear();
    _prevReadingControllers.clear();
    _currReadingControllers.clear();
  }

  TextEditingController getBatchNumberController(int index) {
    return _batchNumberControllers.putIfAbsent(index, () =>
        TextEditingController(text: products[index]['batch_no']?.toString() ?? ''));
  }

  TextEditingController getQuantityController(int index) {
    return _quantityControllers.putIfAbsent(index, () =>
        TextEditingController(text: products[index]['quantity']?.toString() ?? '0'));
  }

  TextEditingController getBonusQuantityController(int index) {
    return _bonusQuantityControllers.putIfAbsent(index, () =>
        TextEditingController(text: products[index]['bonus_quantity']?.toString() ?? '0'));
  }

  TextEditingController getPriceController(int index) {
    double val = (products[index]['item_price'] as num?)?.toDouble() ?? 0.0;
    String text = (val % 1 == 0) ? val.toInt().toString() : val.toStringAsFixed(2);
    var controller = _priceControllers.putIfAbsent(index, () => TextEditingController(text: text));
    if (double.tryParse(controller.text) != val) {
      controller.text = text;
    }
    return controller;
  }

  TextEditingController getDiscountController(int index) {
    return _discountControllers.putIfAbsent(index, () =>
        TextEditingController(text: (products[index]['item_discount'] as double?)?.toStringAsFixed(2) ?? '0.00'));
  }

  TextEditingController getPrevReadingController(int index) {
    return _prevReadingControllers.putIfAbsent(
        index, () => TextEditingController(text: _formatSmart(double.tryParse(products[index]['previous_reading']?.toString() ?? ''))));
  }

  TextEditingController getCurrReadingController(int index) {
    return _currReadingControllers.putIfAbsent(
        index, () => TextEditingController(text: _formatSmart(double.tryParse(products[index]['current_reading']?.toString() ?? ''))));
  }

  List<Map<String, dynamic>> filterProducts(String query) {
    Iterable<Map<String, dynamic>> source = _lookupsService.productsList;

    final int userDepartmentId = _userState.safeUserDepartment;

    source = source.where((item) {
      final rawSection = item['section_no'];
      final int itemSectionNo = int.tryParse(rawSection?.toString() ?? '0') ?? 0;
      return itemSectionNo == userDepartmentId;
    });

    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      source = source.where((item) {
        final itemName = item['item_name']?.toString().toLowerCase() ?? '';
        final itemBarcode = item['item_barcode']?.toString().toLowerCase() ?? '';
        final itemNo = item['item_no']?.toString().toLowerCase() ?? '';
        return itemName.contains(lowerQuery) ||
            itemBarcode.contains(lowerQuery) ||
            itemNo.contains(lowerQuery);
      });
    }

    if (!isReturnMode) {
      source = source.where((item) {
        final double stock = (item['total_stock'] as num?)?.toDouble() ?? 0.0;
        return stock > 0;
      });
    }

    return source.take(10).toList();
  }

  double getCalculatedStockForDisplay(int index) {
    if (index >= products.length || products[index]['isEmpty'] == true) return 0.0;
    return (products[index]['stock_balance'] as num?)?.toDouble() ?? 0.0;
  }

  bool shouldShowStockAlert(int index) {
    return getCalculatedStockForDisplay(index) <= 0;
  }

  void _initializeEmptyProducts() {
    _disposeAllControllers();
    products.clear();
    for (int i = 0; i < initialEmptyRows; i++) {
      products.add(_createEmptyRow());
    }
  }

  Map<String, dynamic> _createEmptyRow() {
    return {
      'item_no': null,
      'item_name': '',
      'item_unit': '',
      'item_price': 0.0,
      'quantity': 0.0,
      'bonus_quantity': 0,
      'item_discount': 0.0,
      'total_item': 0.0,
      'is_taxable': false,
      'tax_rate': 0.0,
      'isEmpty': true,
      'cost_center_no': null,
      'is_discountable': false,
      'discount_rate': 0.0,
      'pack_factor': 1.0,
      'expiry_date': null,
      'units_list': [],
      'stock_list': [],
      'batch_no': '',
      'stock_balance': 0.0,
      'previous_reading': '',
      'current_reading': '',
      'trad_tra_tax': 0.0,
    };
  }

  double _getSpecificBatchQty(List<dynamic> stockList, String? targetExpiry, double packFactor, {String? targetBatchNo}) {
    if (stockList.isEmpty || targetExpiry == null || targetExpiry.isEmpty) return 0.0;

    final batch = stockList.firstWhereOrNull((b) =>
    b['expiry_date'] == targetExpiry &&
        (targetBatchNo == null || targetBatchNo.isEmpty || (b['batch_no']?.toString() ?? '') == targetBatchNo));

    if (batch != null) {
      double rawQty = (batch['quantity'] as num).toDouble();
      return rawQty / (packFactor > 0 ? packFactor : 1.0);
    }
    return 0.0;
  }

  Future<void> addProduct(Map<String, dynamic> productData) async {
    try {
      final stationsController = Get.find<StationsCollectionController>(tag: _tag);
      if (stationsController.isPumpModeActive.value) {
        int populatedItems = products.where((p) => p['isEmpty'] == false).length;
        if (populatedItems >= 1) {
          AppSnackbar.showCustomSnackbar('تنبيه', 'نظام البنزين يسمح بإضافة منتج واحد وطرمبة واحدة فقط للفاتورة', isError: true);
          return;
        }
      }
    } catch (_) {}

    final String itemNo = productData['item_no']?.toString() ?? '';

    final int existingProductIndex = products.indexWhere((p) => p['isEmpty'] != true && p['item_no']?.toString() == itemNo);

    if (existingProductIndex != -1) {
      final double currentQuantity = (products[existingProductIndex]['quantity'] as num).toDouble();
      final double newQuantity = currentQuantity + 1;

      if (!isReturnMode) {
        final double stockBalance = (products[existingProductIndex]['stock_balance'] as num?)?.toDouble() ?? 0.0;
        if (newQuantity > stockBalance) {
          AppSnackbar.showCustomSnackbar('رصيد غير كافٍ', 'الكمية المطلوبة أكبر من المتوفر ($stockBalance).', isError: true);
          return;
        }
      }

      updateQuantity(existingProductIndex, newQuantity.toString());
      getQuantityController(existingProductIndex).text = _formatSmart(newQuantity);
      AppSnackbar.showCustomSnackbar('تنبيه', 'تمت زيادة الكمية.', isError: false);
      return;
    }

    final int emptySlotIndex = products.indexWhere((p) => p['isEmpty'] == true);
    int targetIndex = (emptySlotIndex != -1) ? emptySlotIndex : products.length;

    try {
      final int storeNo = _inputController.selectedStoreNo ?? 0;
      final int branchId = _userState.userBranch ?? 1;

      if (storeNo == 0) {
        AppSnackbar.showCustomSnackbar('خطأ', 'يرجى اختيار المخزن أولاً', isError: true);
        return;
      }

      final details = await _salesRepository.fetchItemDetailsWithStock(itemNo, storeNo, branchId);
      final List<dynamic> units = details['units'] ?? [];
      final List<dynamic> stockList = details['stock'] ?? [];

      double initialPackFactor = 1.0;
      String initialUnitName = productData['item_unit']?.toString() ?? '';
      String? sectionNo;
      String baseAvgCostStr = '0';

      Map<String, dynamic>? selectedUnitData;

      if (units.isNotEmpty) {
        if (initialUnitName.isNotEmpty) {
          selectedUnitData = units.firstWhereOrNull((u) => u['unit_name'] == initialUnitName);
        }

        selectedUnitData ??= units.first;

        if (selectedUnitData != null) {
          initialUnitName = selectedUnitData['unit_name'];
          initialPackFactor = (selectedUnitData['conversion_factor'] as num).toDouble();

          if (selectedUnitData['item'] != null) {
            baseAvgCostStr = selectedUnitData['item']['average_cost']?.toString() ?? '0';
            sectionNo = selectedUnitData['item']['section_no']?.toString();
          }
        }
      }

      double baseAvgCostVal = double.tryParse(baseAvgCostStr) ?? 0.0;
      double initialCostPrice = baseAvgCostVal * initialPackFactor;

      String initialExpiry = '';
      String initialBatch = '';

      if (stockList.isNotEmpty) {
        var firstBatch = stockList.first;
        initialExpiry = firstBatch['expiry_date'] ?? '';
        initialBatch = firstBatch['batch_no'] ?? '';
      }

      double availableStock = _getSpecificBatchQty(stockList, initialExpiry, initialPackFactor);

      if (availableStock <= 0 && !isReturnMode) {
        AppSnackbar.showCustomSnackbar('رصيد غير كافٍ', 'رصيد هذا الصنف (0) في المخزن المحدد.', isError: true);
        return;
      }

      int? itemCurrencyNo;
      if (units.isNotEmpty && units.first['item'] != null) {
        itemCurrencyNo = units.first['item']['currency_no'];
      }

      double conversionFactor = 1.0;
      if (itemCurrencyNo != null) {
        final itemCurrencyObj = _lookupsService.currenciesList.firstWhereOrNull((c) => c.currencyNo == itemCurrencyNo);
        final String transactionCurrencyName = _inputController.selectedCurrency.value;
        final transactionCurrencyObj = _lookupsService.currenciesList.firstWhereOrNull((c) => c.currencyName == transactionCurrencyName);

        if (itemCurrencyObj != null && transactionCurrencyObj != null) {
          conversionFactor = itemCurrencyObj.currencyRate / transactionCurrencyObj.currencyRate;
        }
      }

      double initialPrice = (productData['item_price'] as num?)?.toDouble() ?? 0.0;

      if (selectedUnitData != null) {
        double rawPrice = (selectedUnitData['sale_price'] as num).toDouble();
        initialPrice = rawPrice;
      } else if (units.isNotEmpty) {
        double rawPrice = (units.first['sale_price'] as num).toDouble();
        initialPrice = rawPrice;
      }

      initialPrice = initialPrice * conversionFactor;

      final bool isDiscountable = (productData['is_discountable'] == 1 || productData['is_discountable'] == true);

      final double discountRate = (productData['discount_rate'] as num?)?.toDouble() ?? 0.0;
      double initialDiscount = 0.0;
      if (isDiscountable && discountRate > 0) {
        initialDiscount = initialPrice * (discountRate / 100.0);
      }

      final bool isTaxable = (productData['is_taxable'] == 1 || productData['is_taxable'] == true);

      String existingPumpName = '';
      String existingPrevReading = '';
      String existingCurrReading = '';
      double existingTradTraTax = 0.0;
      double initialQuantity = 1.0;

      if (targetIndex < products.length) {
        existingPumpName = products[targetIndex]['pump_name']?.toString() ?? '';
        existingPrevReading = products[targetIndex]['previous_reading']?.toString() ?? '';
        existingCurrReading = products[targetIndex]['current_reading']?.toString() ?? '';
        existingTradTraTax = (products[targetIndex]['trad_tra_tax'] as num?)?.toDouble() ?? 0.0;
        
        double q = (products[targetIndex]['quantity'] as num?)?.toDouble() ?? 0.0;
        if (q > 0) initialQuantity = q;
      }

      // Handle Utility Mode inheritance when Customer was selected first or fee was set
      bool isUtilityMode = false;
      try {
        final stationsController = Get.find<StationsCollectionController>(tag: _tag);
        isUtilityMode = stationsController.isUtilityModeActive.value;
      } catch (_) {}

      if (isUtilityMode) {
        final cust = _inputController.selectedCustomer.value;
        if (cust != null) {
          if (existingPrevReading.isEmpty && cust.costNext != null && cust.costNext! >= 0) {
            existingPrevReading = _formatSmart(cust.costNext);
          }
          if (existingTradTraTax == 0.0) {
            final parsedFee = double.tryParse(_inputController.subscriptionFeeController.text) ?? (cust.costRsom ?? 0.0);
            if (parsedFee > 0) {
              existingTradTraTax = parsedFee;
            }
          }
        }

        // Always respect the current value in subscriptionFeeController if cashier modified it before selecting the item
        final manualFee = double.tryParse(_inputController.subscriptionFeeController.text);
        if (manualFee != null && manualFee > 0) {
          existingTradTraTax = manualFee;
        }
      }

      final newProductMap = {
        'item_no': productData['item_no'],
        'item_name': productData['item_name']?.toString() ?? '',
        'sales_revenue_account_id': productData['sales_revenue_account_id'],
        'cogs_account_id': productData['cogs_account_id'],
        'item_unit': initialUnitName,
        'item_price': initialPrice,
        'quantity': initialQuantity,
        'bonus_quantity': 0,
        'item_discount': initialDiscount,
        'total_item': initialPrice - initialDiscount,
        'is_taxable': isTaxable,
        'tax_rate': (productData['tax_rate'] as num?)?.toDouble() ?? 0.0,
        'isEmpty': false,
        'cost_center_no': productData['cost_center_no'],
        'is_discountable': isDiscountable,
        'discount_rate': discountRate,
        'pack_factor': initialPackFactor,
        'expiry_date': initialExpiry,
        'batch_no': initialBatch,
        'cost_price': initialCostPrice,
        'original_avg_cost': baseAvgCostStr,
        'section_no': sectionNo,
        'units_list': units,
        'stock_list': stockList,
        'stock_balance': availableStock,
        'item_currency_no': itemCurrencyNo,
        'pump_name': existingPumpName,
        'previous_reading': existingPrevReading,
        'current_reading': existingCurrReading,
        'trad_tra_tax': existingTradTraTax,
      };

      if (emptySlotIndex != -1) {
        products[targetIndex] = newProductMap;
      } else {
        products.add(newProductMap);
      }

      _calculateItemTotal(targetIndex);
      _updateControllersForIndex(targetIndex, newProductMap);

      if (isUtilityMode || existingPrevReading.isNotEmpty || existingCurrReading.isNotEmpty) {
        _recalculateQuantityFromReadings(targetIndex);
      }

      _updateCalculations();

      productSearchController.clear();

    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل إضافة الصنف: $e', isError: true);
    }
  }

  void _updateControllersForIndex(int index, Map<String, dynamic> data) {
    getQuantityController(index).text = _formatSmart((data['quantity'] as num?)?.toDouble());
    getBonusQuantityController(index).text = data['bonus_quantity'].toString();

    double price = (data['item_price'] as num).toDouble();
    TextEditingController priceCtrl = getPriceController(index);
    priceCtrl.text = (price % 1 == 0) ? price.toInt().toString() : price.toStringAsFixed(2);

    getDiscountController(index).text = (data['item_discount'] as double).toStringAsFixed(2);
    getBatchNumberController(index).text = data['batch_no']?.toString() ?? '';
    getPrevReadingController(index).text = _formatSmart(double.tryParse(data['previous_reading']?.toString() ?? ''));
    getCurrReadingController(index).text = _formatSmart(double.tryParse(data['current_reading']?.toString() ?? ''));
  }

  void changeItemUnit(int index, String? newUnitName) {
    if (newUnitName == null || products[index]['isEmpty'] == true) return;

    final List<dynamic> units = products[index]['units_list'] ?? [];
    final selectedUnitObj = units.firstWhereOrNull((u) => u['unit_name'] == newUnitName);

    if (selectedUnitObj != null) {
      products[index]['item_unit'] = newUnitName;
      final double newPackFactor = (selectedUnitObj['conversion_factor'] as num).toDouble();
      products[index]['pack_factor'] = newPackFactor;

      double newPrice = (selectedUnitObj['sale_price'] as num).toDouble();
      final int? itemCurrencyNo = products[index]['item_currency_no'];
      if (itemCurrencyNo != null) {
        final itemCurrencyObj = _lookupsService.currenciesList.firstWhereOrNull((c) => c.currencyNo == itemCurrencyNo);
        final String transactionCurrencyName = _inputController.selectedCurrency.value;
        final transactionCurrencyObj = _lookupsService.currenciesList.firstWhereOrNull((c) => c.currencyName == transactionCurrencyName);
        if (itemCurrencyObj != null && transactionCurrencyObj != null) {
          newPrice = newPrice * (itemCurrencyObj.currencyRate / transactionCurrencyObj.currencyRate);
        }
      }
      products[index]['item_price'] = newPrice;

      String baseAvgCostStr = products[index]['original_avg_cost']?.toString() ?? '0';
      double baseAvgCostVal = double.tryParse(baseAvgCostStr) ?? 0.0;
      products[index]['cost_price'] = baseAvgCostVal * newPackFactor;

      final List<dynamic> stockList = products[index]['stock_list'] ?? [];
      final String? currentExpiry = products[index]['expiry_date'];
      products[index]['stock_balance'] = _getSpecificBatchQty(stockList, currentExpiry, newPackFactor);

      _updateControllersForIndex(index, products[index]);
      _calculateItemTotal(index);
      products.refresh();
    }
  }

  void changeExpiryDate(int index, String? newDate, {String? specificBatchNo}) {
    if (newDate == null || products[index]['isEmpty'] == true) return;

    products[index]['expiry_date'] = newDate;

    String batchToSet = '';

    if (specificBatchNo != null) {
      batchToSet = specificBatchNo;
    } else {
      final List<dynamic> stockList = products[index]['stock_list'] ?? [];
      final matchingBatch = stockList.firstWhereOrNull((s) => s['expiry_date'] == newDate);

      if (matchingBatch != null) {
        batchToSet = matchingBatch['batch_no']?.toString() ?? '';
      }
    }

    products[index]['batch_no'] = batchToSet;

    final List<dynamic> stockList = products[index]['stock_list'] ?? [];
    final double packFactor = (products[index]['pack_factor'] as num).toDouble();

    products[index]['stock_balance'] = _getSpecificBatchQty(stockList, newDate, packFactor, targetBatchNo: batchToSet);

    products.refresh();
    _updateControllersForIndex(index, products[index]);
  }

  void updateBatchNumber(int index, String value) {
    if (index < 0 || index >= products.length) return;
    products[index]['batch_no'] = value;
  }

  void updateQuantity(int index, String value) {
    if (index < 0 || index >= products.length || products[index]['isEmpty'] == true) return;

    final quantity = double.tryParse(value) ?? 0.0;

    if (!isReturnMode) {
      final double stockBalance = (products[index]['stock_balance'] as num?)?.toDouble() ?? 0.0;
      if (quantity > stockBalance) {
        AppSnackbar.showCustomSnackbar('رصيد غير كافٍ', 'الكمية المطلوبة أكبر من المتوفر ($stockBalance)', isError: true);
        getQuantityController(index).text = _formatSmart((products[index]['quantity'] as num).toDouble());
        return;
      }
    }

    products[index]['quantity'] = quantity;

    final bool isDiscountable = products[index]['is_discountable'] ?? false;
    final double discountRate = (products[index]['discount_rate'] as num?)?.toDouble() ?? 0.0;
    final double price = (products[index]['item_price'] as num).toDouble();

    if (isDiscountable && discountRate > 0) {
      final double newDiscountValue = (quantity * price) * (discountRate / 100.0);
      products[index]['item_discount'] = newDiscountValue;
      getDiscountController(index).text = newDiscountValue.toStringAsFixed(2);
    }

    _calculateItemTotal(index);
  }

  void updatePrice(int index, String value) {
    if (index < 0 || index >= products.length || products[index]['isEmpty'] == true) return;
    final price = double.tryParse(value) ?? 0.0;
    products[index]['item_price'] = price;
    _calculateItemTotal(index);
  }

  void updateBonusQuantity(int index, String value) {
    if (index < 0 || index >= products.length) return;
    products[index]['bonus_quantity'] = int.tryParse(value) ?? 0;
  }

  void _calculateItemTotal(int index) {
    final product = products[index];
    final double quantity = (product['quantity'] as num).toDouble();
    final double price = (product['item_price'] as num).toDouble();
    final double discount = double.tryParse(getDiscountController(index).text) ?? 0.0;
    final double fee = (product['trad_tra_tax'] as num?)?.toDouble() ?? 0.0;

    products[index]['item_discount'] = discount;

    // Line total = (Quantity * Price) + Subscription Fee - Discount
    double itemTotal = (quantity * price) + fee - discount;
    if (itemTotal < 0) itemTotal = 0;

    products[index]['total_item'] = itemTotal;
    products.refresh();
  }

  void removeProduct(int index) {
    if (index < 0 || index >= products.length) return;
    products.removeAt(index);
    if (products.length < initialEmptyRows) {
      products.add(_createEmptyRow());
    }
    _disposeAllControllers();
    for (int i = 0; i < products.length; i++) {
      _updateControllersForIndex(i, products[i]);
    }
    products.refresh();
  }

  void resetProducts() {
    _initializeEmptyProducts();
    productSearchController.clear();
  }

  void _updateCalculations() {
    double total = 0.0;
    double totalTax = 0.0;
    double totalItemDiscount = 0.0;
    double totalCharges = 0.0;
    double consumptionTotal = 0.0;

    for (var item in products) {
      if (item['isEmpty'] == false) {
        final double itemTotal = (item['total_item'] as num?)?.toDouble() ?? 0.0;
        final double fee = (item['trad_tra_tax'] as num?)?.toDouble() ?? 0.0;
        final double qty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final double price = (item['item_price'] as num?)?.toDouble() ?? 0.0;
        final double disc = (item['item_discount'] as num?)?.toDouble() ?? 0.0;

        total += itemTotal;
        totalCharges += fee;
        consumptionTotal += (qty * price) - disc;
        totalItemDiscount += disc;

        final bool isTaxable = item['is_taxable'] as bool? ?? false;
        final double taxRate = (item['tax_rate'] as num?)?.toDouble() ?? 0.0;
        if (isTaxable && taxRate > 0) {
          totalTax += itemTotal * (taxRate / 100.0);
        }
      }
    }

    if (Get.isRegistered<StationsCollectionCalculationsController>(tag: _tag)) {
      _calculationsController.updateAll(
        total: total,
        tax: totalTax,
        totalItemDiscount: totalItemDiscount,
        totalCharges: totalCharges,
        consumptionTotal: consumptionTotal,
      );
    }
  }

  void convertPricesToNewCurrency(double oldRate, double newRate) {
    if (products.isEmpty || newRate == 0) return;

    for (int i = 0; i < products.length; i++) {
      if (products[i]['isEmpty'] == true) continue;

      double currentPrice = (products[i]['item_price'] as num?)?.toDouble() ?? 0.0;
      double conversionFactor = oldRate / newRate;
      double newPrice = currentPrice * conversionFactor;

      products[i]['item_price'] = newPrice;
      if (_priceControllers.containsKey(i)) {
        _priceControllers[i]!.text = (newPrice % 1 == 0)
            ? newPrice.toInt().toString()
            : newPrice.toStringAsFixed(2);
      }

      double currentDiscount = (products[i]['item_discount'] as num?)?.toDouble() ?? 0.0;
      double newDiscount = currentDiscount * conversionFactor;
      products[i]['item_discount'] = newDiscount;
      if (_discountControllers.containsKey(i)) {
        _discountControllers[i]!.text = newDiscount.toStringAsFixed(2);
      }

      _calculateItemTotal(i);
    }
    _updateCalculations();
    products.refresh();
  }

  Future<void> loadInvoiceProducts(List<Map<String, dynamic>> invoiceItems) async {
    try {
      _disposeAllControllers();
      products.clear();

      final int storeNo = _inputController.selectedStoreNo ?? 0;
      final int branchId = _userState.userBranch ?? 1;

      final List<Map<String, dynamic>> batchProducts = [];
      final List<Future<Map<String, dynamic>>> futures = [];

      for (var item in invoiceItems) {
        final String itemNo = item['item_no']?.toString() ?? '';
        futures.add(_salesRepository.fetchItemDetailsWithStock(itemNo, storeNo, branchId));
      }

      final List<Map<String, dynamic>> allItemsDetails = await Future.wait(futures);

      for (var i = 0; i < invoiceItems.length; i++) {
        var item = invoiceItems[i];
        var details = allItemsDetails[i];

        List<dynamic> stockList = details['stock'] ?? [];
        List<dynamic> units = details['units'] ?? [];
        String expiry = item['expiry_date'] ?? '';
        String batchNo = item['batch_no']?.toString() ?? '';
        double packFactor = (item['pack_factor'] as num?)?.toDouble() ?? 1.0;

        String baseAvgCostStr = '0';
        String? sectionNo;

        if (units.isNotEmpty && units.first['item'] != null) {
          baseAvgCostStr = units.first['item']['average_cost']?.toString() ?? '0';
          sectionNo = units.first['item']['section_no']?.toString();
        }

        double stockBalance = 0.0;
        final matchingStockBatch = stockList.firstWhereOrNull((s) =>
        (s['expiry_date'] ?? '') == expiry &&
            (batchNo.isEmpty || (s['batch_no']?.toString() ?? '') == batchNo)
        );

        if (matchingStockBatch != null) {
          double baseQty = (matchingStockBatch['quantity'] as num?)?.toDouble() ?? 0.0;
          stockBalance = baseQty / (packFactor > 0 ? packFactor : 1.0);
        }

        double loadedCostPrice = (item['cost_price'] as num?)?.toDouble() ?? 0.0;

        if (loadedCostPrice == 0.0) {
          double baseVal = double.tryParse(baseAvgCostStr) ?? 0.0;
          loadedCostPrice = baseVal * packFactor;
        }

        final dynamic rawIsTaxable = item['is_taxable'];
        final dynamic rawIsDiscountable = item['is_discountable'];

        batchProducts.add({
          'item_no': item['item_no']?.toString() ?? '',
          'item_name': item['item_name']?.toString() ?? '',
          'sales_revenue_account_id': item['sales_revenue_account_id'] ?? details['item']?['sales_revenue_account_id'],
          'cogs_account_id': item['cogs_account_id'] ?? details['item']?['cogs_account_id'],
          'item_unit': item['item_unit']?.toString() ?? '',
          'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
          'bonus_quantity': (item['bonus_quantity'] as num?)?.toInt() ?? 0,
          'item_price': (item['item_price'] as num?)?.toDouble() ?? 0.0,
          'item_discount': (item['item_discount'] as num?)?.toDouble() ?? 0.0,
          'total_item': (item['total_item'] as num?)?.toDouble() ?? 0.0,
          'is_taxable': (rawIsTaxable == 1 || rawIsTaxable == true),
          'tax_rate': (item['tax_rate'] as num?)?.toDouble() ?? 0.0,
          'isEmpty': false,
          'cost_center_no': item['cost_center_no'],
          'is_discountable': (rawIsDiscountable == 1 || rawIsDiscountable == true),
          'discount_rate': (item['discount_rate'] as num?)?.toDouble() ?? 0.0,
          'pack_factor': packFactor,
          'expiry_date': expiry,
          'units_list': units,
          'stock_list': stockList,
          'batch_no': batchNo,
          'cost_price': loadedCostPrice,
          'original_avg_cost': baseAvgCostStr,
          'section_no': sectionNo,
          'stock_balance': stockBalance,
          'pump_name': item['pump_name']?.toString() ?? '',
          'previous_reading': item['previous_reading']?.toString() ?? '',
          'current_reading': item['current_reading']?.toString() ?? '',
        });
      }

      while (batchProducts.length < initialEmptyRows) {
        batchProducts.add(_createEmptyRow());
      }

      products.assignAll(batchProducts);

      for (int i = 0; i < products.length; i++) {
        _updateControllersForIndex(i, products[i]);
      }
    } catch (e) {
      AppSnackbar.showCustomSnackbar('خطأ', 'حدث خطأ أثناء تحميل تفاصيل الأصناف.', isError: true);
    }
  }

  Uint8List _generateBeep({int durationMs = 150, int sampleRate = 8000}) {
    int numSamples = (durationMs * sampleRate) ~/ 1000;
    int headerSize = 44;
    int fileSize = headerSize + numSamples;

    var buffer = Uint8List(fileSize);
    var view = ByteData.view(buffer.buffer);

    view.setUint32(0, 0x52494646, Endian.big);
    view.setUint32(4, fileSize - 8, Endian.little);
    view.setUint32(8, 0x57415645, Endian.big);
    view.setUint32(12, 0x666d7420, Endian.big);
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, 1, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, sampleRate, Endian.little);
    view.setUint16(32, 1, Endian.little);
    view.setUint16(34, 8, Endian.little);

    view.setUint32(36, 0x64617461, Endian.big);
    view.setUint32(40, numSamples, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      double t = i / sampleRate;
      double value = 127 + 127 * sin(2 * pi * 1000 * t);
      buffer[headerSize + i] = value.toInt();
    }
    return buffer;
  }

  List<CameraDescription> _cameras = [];

  Future<void> toggleCamera() async {
    if (isCameraVisible.value) {
      isCameraVisible.value = false;
      try {
        if (cameraController != null) {
          await cameraController!.stopImageStream();
          await cameraController!.dispose();
          cameraController = null;
        }
      } catch (e) {
        debugPrint("Camera Stop Error: $e");
      }
    } else {
      try {
        _cameras = await availableCameras();
        if (_cameras.isEmpty) {
          AppSnackbar.showCustomSnackbar('خطأ', 'لم يتم العثور على كاميرا', isError: true);
          return;
        }
        
        final backCamera = _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back, 
            orElse: () => _cameras.first);
            
        cameraController = CameraController(
          backCamera,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
        );

        await cameraController!.initialize();
        _lastRecognizedNumber = null;
        _consecutiveRecognitions = 0;
        await cameraController!.startImageStream((image) => _processCameraImage(image, backCamera));
        
        isCameraVisible.value = true;
      } catch (e) {
        debugPrint("Camera Start Error: $e");
        isCameraVisible.value = false;
      }
    }
  }

  void _processCameraImage(CameraImage image, CameraDescription camera) async {
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;

    try {
      final now = DateTime.now();
      if (_lastScanTime != null && now.difference(_lastScanTime!) < const Duration(seconds: 2)) {
        _isProcessingFrame = false;
        return;
      }

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg,
          format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );

      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      _extractAndInjectNumber(recognizedText);
    } catch (e) {
      debugPrint("OCR Error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _extractAndInjectNumber(RecognizedText recognizedText) {
    List<double> foundNumbers = [];
    final regExp = RegExp(r'\d+(\.\d+)?');

    for (TextBlock block in recognizedText.blocks) {
      final lines = block.text.split('\n');
      for (String line in lines) {
        String sanitizedText = line.replaceAll(' ', '').replaceAll(',', '.');
        final matches = regExp.allMatches(sanitizedText);
        for (var match in matches) {
          final numStr = match.group(0);
          if (numStr != null) {
            final val = double.tryParse(numStr);
            if (val != null && val >= 1000) {
              foundNumbers.add(val);
            }
          }
        }
      }
    }

    if (foundNumbers.isNotEmpty) {
      final largestNumber = foundNumbers.reduce(max);
      
      if (_lastRecognizedNumber == largestNumber) {
        _consecutiveRecognitions++;
      } else {
        _lastRecognizedNumber = largestNumber;
        _consecutiveRecognitions = 1;
      }
      
      if (_consecutiveRecognitions >= 3) {
        int targetIndex = products.indexWhere((p) {
          final val = double.tryParse(p['current_reading']?.toString() ?? '');
          return p['isEmpty'] == false && (val == null || val == 0.0);
        });
        
        if (targetIndex == -1) targetIndex = 0;

        if (targetIndex < products.length) {
          _lastScanTime = DateTime.now();
          HapticFeedback.mediumImpact();
          try {
            _audioPlayer.play(BytesSource(_beepBytes), volume: 1.0);
          } catch (_) {}

          updateCurrentReading(targetIndex, largestNumber.toString());
          
          toggleCamera();
        }
      }
    }
  }

  String _formatSmart(double? value) {
    if (value == null) return '';
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2).replaceAll(RegExp(r"0*$"), "").replaceAll(RegExp(r"\.$"), "");
  }

  void updatePreviousReadingAndPumpName(String? pumpName, double? previousReading) {
    if (products.isEmpty) return;
    
    products[0]['pump_name'] = pumpName;
    
    final formattedReading = _formatSmart(previousReading);
    products[0]['previous_reading'] = formattedReading;
    
    // Update the UI controller
    getPrevReadingController(0).text = formattedReading;
    
    products.refresh();
    
    _recalculateQuantityFromReadings(0);
  }

  void updateCurrentReading(int index, String value) {
    if (index < 0 || index >= products.length || products[index]['isEmpty'] == true) return;
    
    products[index]['current_reading'] = value;
    getCurrReadingController(index).text = value;
    _recalculateQuantityFromReadings(index);
  }

  void _recalculateQuantityFromReadings(int index) {
    if (index < 0 || index >= products.length || products[index]['isEmpty'] == true) return;

    final prevStr = products[index]['previous_reading']?.toString() ?? '0';
    final currStr = products[index]['current_reading']?.toString() ?? '0';

    final prev = double.tryParse(prevStr) ?? 0.0;
    final curr = double.tryParse(currStr) ?? 0.0;

    double qty = 0.0;
    if (curr > 0 && curr >= prev) {
      qty = curr - prev;
    }

    products[index]['quantity'] = qty;
    final formattedQty = _formatSmart(qty);
    getQuantityController(index).text = formattedQty;

    // Trigger price calculation logic inside updateQuantity natively
    updateQuantity(index, formattedQty);
  }

  void updatePrevReading(int index, String value) {
    if (index < 0 || index >= products.length || products[index]['isEmpty'] == true) return;
    products[index]['previous_reading'] = value;
    getPrevReadingController(index).text = value;
    _recalculateQuantityFromReadings(index);
  }

  void applyCustomerReadingsAndFee(double? reading, double? fee) {
    if (products.isEmpty) return;
    
    // Set previous reading on first row (supports reading >= 0 for new meters starting at 0)
    if (reading != null && reading >= 0) {
      final formattedReading = _formatSmart(reading);
      products[0]['previous_reading'] = formattedReading;
      getPrevReadingController(0).text = formattedReading;
    }
    
    // Set fee on first row
    if (fee != null) {
      products[0]['trad_tra_tax'] = fee;
      if (products[0]['isEmpty'] != true) {
        _calculateItemTotal(0);
      }
    }
    
    products.refresh();
    if (products[0]['isEmpty'] != true) {
      _recalculateQuantityFromReadings(0);
    }
    _updateCalculations();
  }

  void updateSubscriptionFee(double fee, {int index = 0}) {
    if (products.isEmpty || index < 0 || index >= products.length) return;
    products[index]['trad_tra_tax'] = fee;
    if (products[index]['isEmpty'] != true) {
      _calculateItemTotal(index);
    }
    products.refresh();
    _updateCalculations();
  }
}
