import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/repositories/sales_repository.dart';
import 'package:untitled4/utils/snackbar_helper.dart';
import 'package:untitled4/screens/controllers/input_section_controller.dart';
import 'package:untitled4/models/sale_item.dart';
import 'inventory_calculations_controller.dart';
import '../../services/lookups_service.dart.dart';

class InventoryProductsController extends GetxController {
  final SalesRepository _repository = SalesRepository();
  final LookupsService _lookupsService = Get.find<LookupsService>();
  final UserState _userState = Get.find<UserState>();

  late final InventoryCalculationsController _calcsController;
  late final InputSectionController _inputController;

  final String _tag;

  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;

  static const int initialEmptyRows = 4;

  final Map<int, TextEditingController> _actualQtyControllers = {};
  final Map<int, TextEditingController> _costControllers = {};

  Timer? _debounce;

  final AudioPlayer _audioPlayer = AudioPlayer();
  late final Uint8List _beepBytes;

  RxBool isCameraVisible = false.obs;
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: [BarcodeFormat.all],
  );

  DateTime? _lastScanTime;

  InventoryProductsController({required String controllerTag}) : _tag = controllerTag;

  @override
  void onInit() {
    super.onInit();
    try {
      _calcsController = Get.find<InventoryCalculationsController>(tag: _tag);
      _inputController = Get.find<InputSectionController>(tag: _tag);
    } catch (e) {
      print("Dependency Error: $e");
    }

    _initializeEmptyProducts();

    debounce(products, (_) => _calculateTotals(), time: const Duration(milliseconds: 50));

    _beepBytes = _generateBeep(durationMs: 150);
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

  @override
  void onClose() {
    _debounce?.cancel();
    _disposeAllControllers();
    cameraController.dispose();
    _audioPlayer.dispose();
    super.onClose();
  }

  void _disposeAllControllers() {
    _actualQtyControllers.forEach((_, c) => c.dispose());
    _actualQtyControllers.clear();
    _costControllers.forEach((_, c) => c.dispose());
    _costControllers.clear();
  }

  void _initializeEmptyProducts() {
    products.clear();
    for (int i = 0; i < initialEmptyRows; i++) {
      products.add(_createEmptyRow());
    }
  }

  Map<String, dynamic> _createEmptyRow() {
    return {
      'isEmpty': true,
      'item_no': '',
      'item_name': '',
      'item_unit': '',
      'actual_qty': 0,
      'system_qty': 0.0,
      'cost_price': 0.0,
      'diff_qty': 0.0,
      'system_value': 0.0,
      'deficit_value': 0.0,
      'surplus_value': 0.0,
      'total': 0.0,
    };
  }

  TextEditingController getActualQtyController(int index) {
    if (products[index]['isEmpty'] == true) {
      return TextEditingController();
    }
    return _actualQtyControllers.putIfAbsent(index, () =>
        TextEditingController(text: products[index]['actual_qty']?.toString() ?? '0'));
  }

  TextEditingController getCostController(int index) {
    if (products[index]['isEmpty'] == true) {
      return TextEditingController();
    }
    return _costControllers.putIfAbsent(index, () =>
        TextEditingController(text: products[index]['cost_price']?.toString() ?? '0.0'));
  }

  void updateCost(int index, String value) {
    if (index >= products.length || products[index]['isEmpty'] == true) return;
    double? newCost = double.tryParse(value);
    if (newCost != null) {
      products[index]['cost_price'] = newCost;
      _recalculateRow(index);
    }
  }

  List<Map<String, dynamic>> filterProducts(String query) {
    var filteredList = _lookupsService.productsList;
    final int? userDepartment = _userState.userDepartment;
    
    if (userDepartment != null) {
      filteredList = filteredList.where((item) {
        return item['section_no']?.toString() == userDepartment.toString();
      }).toList();
    }

    if (query.isEmpty) return filteredList.take(10).toList();
    final lowerQuery = query.toLowerCase();
    return filteredList.where((item) {
      return (item['item_name']?.toString().toLowerCase().contains(lowerQuery) ?? false) ||
          (item['item_no']?.toString().contains(lowerQuery) ?? false) ||
          (item['item_barcode']?.toString().contains(lowerQuery) ?? false);
    }).take(10).toList();
  }

  double _getTotalStockQty(List<dynamic> stockList, double packFactor) {
    if (stockList.isEmpty) return 0.0;
    double rawTotalQty = stockList.fold(0.0, (sum, batch) => sum + ((batch['quantity'] as num?)?.toDouble() ?? 0.0));
    return rawTotalQty / (packFactor > 0 ? packFactor : 1.0);
  }

  Future<void> loadInvoiceProductsForInventory(List<SaleItem> invoiceItems) async {
    try {
      _disposeAllControllers();
      products.clear();

      final int storeNo = _inputController.selectedStoreNo ?? 0;
      final int branchId = _userState.userBranch ?? 1;

      List<Future<Map<String, dynamic>>> futures = invoiceItems.map((item) {
        return _repository.fetchItemDetailsWithStock(item.itemNo ?? '', storeNo, branchId);
      }).toList();

      final List<Map<String, dynamic>> allItemsDetails = await Future.wait(futures);

      for (int i = 0; i < invoiceItems.length; i++) {
        final SaleItem savedItem = invoiceItems[i];
        final Map<String, dynamic> liveDetails = allItemsDetails[i];

        final List<dynamic> stockList = liveDetails['stock'] ?? [];
        final double packFactor = savedItem.packFactor;

        double sysQty = savedItem.stockBalance ?? 0.0;
        double cost = savedItem.costPrice ?? savedItem.itemPrice;

        final newItem = {
          'isEmpty': false,
          'item_no': savedItem.itemNo,
          'item_name': savedItem.itemName,
          'item_unit': savedItem.itemUnit,
          'pack_factor': packFactor,
          'units_list': liveDetails['units'] ?? [],
          'stock_list': stockList,
          'expiry_date': savedItem.expiryDate,
          'batch_no': savedItem.batchNumber,
          'actual_qty': savedItem.quantity,
          'system_qty': sysQty,
          'cost_price': cost,
          'base_cost_price': cost,
          'diff_qty': savedItem.diffQuantity ?? 0.0,
          'deficit_value': savedItem.deficitValue ?? 0.0,
          'surplus_value': savedItem.surplusValue ?? 0.0,
          'system_value': sysQty * cost,
          'total': savedItem.total,
        };

        products.add(newItem);
      }

      while (products.length < initialEmptyRows) {
        products.add(_createEmptyRow());
      }

      products.refresh();
      _calculateTotals();

    } catch (e) {
      print("Load Items Error: $e");
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل تحميل تفاصيل الأصناف', isError: true);
    }
  }

  Future<void> addProduct(Map<String, dynamic> productLookups) async {
    final int? storeNo = _inputController.selectedStoreNo;

    if (storeNo == null) {
      AppSnackbar.showCustomSnackbar('تنبيه', 'يجب اختيار المخزن أولاً', isError: true);
      return;
    }

    final int emptyIndex = products.indexWhere((p) => p['isEmpty'] == true);
    final int targetIndex = (emptyIndex != -1) ? emptyIndex : products.length;

    try {
      final String itemNo = productLookups['item_no'].toString();
      final int branchId = _userState.userBranch ?? 1;

      final details = await _repository.fetchItemDetailsWithStock(itemNo, storeNo, branchId);
      final List<dynamic> stockList = details['stock'] ?? [];
      final List<dynamic> units = details['units'] ?? [];

      double initialPackFactor = 1.0;
      String initialUnitName = productLookups['item_unit'] ?? '';

      if (units.isNotEmpty) {
        initialUnitName = units.first['unit_name'];
        initialPackFactor = (units.first['conversion_factor'] as num).toDouble();
      } else {
        initialUnitName = productLookups['item_unit'] ?? '';
      }

      double initialCost = 0.0;
      String initialExpiry = '';
      String initialBatch = '';

      if (stockList.isNotEmpty) {
        var firstBatch = stockList.first;
        double baseCost = (firstBatch['cost_price'] as num?)?.toDouble() ?? 0.0;
        initialCost = baseCost * initialPackFactor;
        initialExpiry = firstBatch['expiry_date'] ?? '';
        initialBatch = firstBatch['batch_no'] ?? '';
      }

      double specificSystemQty = _getTotalStockQty(stockList, initialPackFactor);

      final newItem = {
        'isEmpty': false,
        'item_no': itemNo,
        'item_name': productLookups['item_name'],
        'item_unit': initialUnitName,
        'pack_factor': initialPackFactor,
        'units_list': units,
        'stock_list': stockList,
        'expiry_date': initialExpiry,
        'batch_no': initialBatch,
        'cost_price': initialCost,
        'base_cost_price': (stockList.isNotEmpty) ? (stockList.first['cost_price'] as num).toDouble() : 0.0,
        'system_qty': specificSystemQty,
        'actual_qty': 0,
        'diff_qty': 0.0,
        'system_value': 0.0,
        'deficit_value': 0.0,
        'surplus_value': 0.0,
        'total': 0.0,
      };

      if (emptyIndex != -1) {
        products[emptyIndex] = newItem;
      } else {
        products.add(newItem);
      }

      _recalculateRow(targetIndex);

    } catch (e) {
      print('Add Product Error: $e');
      AppSnackbar.showCustomSnackbar('خطأ', 'فشل جلب تفاصيل الصنف', isError: true);
    }
  }

  void updateActualQty(int index, String value) {
    if (index >= products.length || products[index]['isEmpty'] == true) return;
    int actual = int.tryParse(value) ?? 0;
    products[index]['actual_qty'] = actual;
    _recalculateRow(index);
  }

  void changeItemUnit(int index, String? newUnitName) {
    if (newUnitName == null || products[index]['isEmpty'] == true) return;

    final List<dynamic> units = products[index]['units_list'] ?? [];
    final selectedUnitObj = units.firstWhereOrNull((u) => u['unit_name'] == newUnitName);

    if (selectedUnitObj != null) {
      final double newPackFactor = (selectedUnitObj['conversion_factor'] as num).toDouble();
      products[index]['item_unit'] = newUnitName;
      products[index]['pack_factor'] = newPackFactor;

      final double baseCost = (products[index]['base_cost_price'] as num).toDouble();
      products[index]['cost_price'] = baseCost * newPackFactor;

      final List<dynamic> stockList = products[index]['stock_list'] ?? [];
      products[index]['system_qty'] = _getTotalStockQty(stockList, newPackFactor);

      _recalculateRow(index);
    }
  }

  void changeExpiryDate(int index, String? newDate, {String specificBatchNo = ''}) {
    if (newDate == null || products[index]['isEmpty'] == true) return;

    final item = products[index];
    final List<dynamic> stockList = item['stock_list'] ?? [];
    final selectedBatch = stockList.firstWhereOrNull((s) => 
      s['expiry_date'] == newDate && (s['batch_no']?.toString() ?? '') == specificBatchNo
    );

    if (selectedBatch != null) {
      final double packFactor = (item['pack_factor'] as num).toDouble();
      final double baseCost = (selectedBatch['cost_price'] as num).toDouble();
      final double baseQty = (selectedBatch['quantity'] as num).toDouble();

      products[index]['expiry_date'] = newDate;
      products[index]['batch_no'] = selectedBatch['batch_no'] ?? '';
      products[index]['cost_price'] = baseCost * packFactor;
      products[index]['base_cost_price'] = baseCost;
      products[index]['system_qty'] = _getTotalStockQty(stockList, packFactor);

      _recalculateRow(index);
    }
  }

  void _recalculateRow(int index) {
    if (products[index]['isEmpty'] == true) return;

    final item = products[index];
    final double sys = (item['system_qty'] as num).toDouble();
    final double act = (item['actual_qty'] as num).toDouble();
    final double cost = (item['cost_price'] as num).toDouble();

    final double diff = act - sys;
    final double sysVal = sys * cost;
    final double totalVal = act * cost;
    final double diffVal = diff * cost;

    products[index]['diff_qty'] = diff;
    products[index]['system_value'] = sysVal;
    products[index]['total'] = totalVal;

    if (diff < 0) {
      products[index]['deficit_value'] = diffVal.abs();
      products[index]['surplus_value'] = 0.0;
    } else if (diff > 0) {
      products[index]['surplus_value'] = diffVal;
      products[index]['deficit_value'] = 0.0;
    } else {
      products[index]['deficit_value'] = 0.0;
      products[index]['surplus_value'] = 0.0;
    }

    products.refresh();
  }

  void _calculateTotals() {
    double sumSysQty = 0;
    double sumActQty = 0;
    double sumDiffQty = 0;
    double sumSysVal = 0;
    double sumActVal = 0;
    double sumSurplus = 0;
    double sumDeficit = 0;

    for (var item in products) {
      if (item['isEmpty'] == true) continue;

      final double sQty = (item['system_qty'] as num?)?.toDouble() ?? 0.0;
      final double aQty = (item['actual_qty'] as num?)?.toDouble() ?? 0.0;
      final double cost = (item['cost_price'] as num?)?.toDouble() ?? 0.0;

      sumSysQty += sQty;
      sumActQty += aQty;
      sumDiffQty += (aQty - sQty);

      final double itemSysVal = sQty * cost;
      item['system_value'] = itemSysVal;
      sumSysVal += itemSysVal;

      final double itemTotal = aQty * cost;
      sumActVal += itemTotal;

      sumSurplus += (item['surplus_value'] as num?)?.toDouble() ?? 0.0;
      sumDeficit += (item['deficit_value'] as num?)?.toDouble() ?? 0.0;
    }

    if (Get.isRegistered<InventoryCalculationsController>(tag: _tag)) {
      _calcsController.updateCalculations(
        sysQty: sumSysQty,
        actQty: sumActQty,
        sysVal: sumSysVal,
        actVal: sumActVal,
        surplus: sumSurplus,
        deficit: sumDeficit,
        totalDiffQtyInput: sumDiffQty,
      );
    }
  }

  void removeProduct(int index) {
    if (index >= 0 && index < products.length) {
      products.removeAt(index);
      if (products.length < initialEmptyRows) {
        products.add(_createEmptyRow());
      }
      _disposeAllControllers();
      products.refresh();
    }
  }

  void clearAll() {
    _disposeAllControllers();
    _initializeEmptyProducts();
    if (Get.isRegistered<InventoryCalculationsController>(tag: _tag)) {
      _calcsController.reset();
    }
  }

  void toggleCamera() {
    isCameraVisible.value = !isCameraVisible.value;
    if (isCameraVisible.value) {
      cameraController.start();
    } else {
      cameraController.stop();
    }
  }

  void onBarcodeDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final String code = barcode.rawValue!;

        final now = DateTime.now();
        if (_lastScanTime != null && now.difference(_lastScanTime!) < const Duration(seconds: 5)) {
          return;
        }
        _lastScanTime = now;

        HapticFeedback.mediumImpact();
        try {
          _audioPlayer.play(BytesSource(_beepBytes), volume: 1.0);
        } catch (e) {
          print("Audio Error: $e");
        }

        final foundProduct = _lookupsService.productsList.firstWhereOrNull((p) {
          return (p['item_barcode']?.toString() == code) || (p['item_no']?.toString() == code);
        });

        if (foundProduct != null) {
          addProduct(foundProduct);
          AppSnackbar.showCustomSnackbar('تمت القراءة', 'تم إضافة: ${foundProduct['item_name']}', isError: false);
        } else {
          AppSnackbar.showCustomSnackbar('غير موجود', 'لم يتم العثور على صنف: $code', isError: true);
        }

        return;
      }
    }
  }
}