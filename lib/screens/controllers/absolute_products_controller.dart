import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:untitled4/supabase_manager.dart';
import 'package:untitled4/screens/controllers/absolute_calculations_controller.dart';

class AbsoluteProductsController extends GetxController {
  final SupabaseClient _supabase = SupabaseManager.client;

  final RxList<Map<String, dynamic>> products = <Map<String, dynamic>>[].obs;
  final TextEditingController productSearchController = TextEditingController();

  final RxList<Map<String, dynamic>> _allAvailableProducts = <Map<String, dynamic>>[].obs;

  List<Map<String, dynamic>> get allAvailableProductsList => _allAvailableProducts.toList();

  static const int initialEmptyRows = 4; // الحد الأدنى لعدد الصفوف الظاهرة (ممتلئة أو فارغة)
  static const int maxFixedRows = 6; // الحد الأقصى الثابت للصفوف قبل ظهور شريط التمرير

  late AbsoluteCalculationsController calculationsController;

  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, TextEditingController> _bonusQuantityControllers = {};
  final Map<int, TextEditingController> _discountControllers = {};


  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<AbsoluteCalculationsController>()) {
      calculationsController = Get.find<AbsoluteCalculationsController>();
    } else {
      print('تحذير: AbsoluteCalculationsController لم يتم تسجيله بعد.');
    }

    loadAllAvailableProducts();
    _initializeProductsList(); // تبدأ القائمة بـ initialEmptyRows صفوف فارغة عند التهيئة

    ever(products, (_) => _updateCalculations());
  }

  @override
  void onClose() {
    productSearchController.dispose();
    // تأكد أنك تقوم بالتخلص من الـ Controllers عند إغلاق الكنترولر فقط
    _disposeAllControllers();
    super.onClose();
  }

  // هذه الدالة ستظل مسؤولة عن التخلص من كل الـ Controllers عند إغلاق الكنترولر
  void _disposeAllControllers() {
    _quantityControllers.forEach((key, controller) => controller.dispose());
    _bonusQuantityControllers.forEach((key, controller) => controller.dispose());
    _discountControllers.forEach((key, controller) => controller.dispose());
    _quantityControllers.clear();
    _bonusQuantityControllers.clear();
    _discountControllers.clear();
  }

  TextEditingController getQuantityController(int index) {
    if (!_quantityControllers.containsKey(index)) {
      // هذا يجب أن يكون بمثابة fallback في حال لم يتم تهيئة Controller في _initializeProductsList أو loadProductsForEditing
      _quantityControllers[index] = TextEditingController(text: products[index]['quantity']?.toString() ?? '0');
    }
    return _quantityControllers[index]!;
  }

  TextEditingController getBonusQuantityController(int index) {
    if (!_bonusQuantityControllers.containsKey(index)) {
      _bonusQuantityControllers[index] = TextEditingController(text: products[index]['bonus_quantity']?.toString() ?? '0');
    }
    return _bonusQuantityControllers[index]!;
  }

  TextEditingController getDiscountController(int index) {
    if (!_discountControllers.containsKey(index)) {
      _discountControllers[index] = TextEditingController(text: (products[index]['item_discount'] as double?)?.toStringAsFixed(2) ?? '0.00');
    }
    return _discountControllers[index]!;
  }


  Future<void> loadAllAvailableProducts() async {
    try {
      final response = await _supabase
          .from('sun_items')
          .select('item_no, item_name, item_barcode, item_price');
      if (response != null && response is List) {
        _allAvailableProducts.assignAll(List<Map<String, dynamic>>.from(response));
        print('تم تحميل ${_allAvailableProducts.length} صنف متاح للبحث.');
      }
    } on PostgrestException catch (e) {
      Get.snackbar('خطأ في تحميل الأصناف', 'فشل تحميل بيانات الأصناف: ${e.message}',
          backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    } catch (e) {
      Get.snackbar('خطأ عام', 'حدث خطأ غير متوقع أثناء تحميل الأصناف: ${e.toString()}',
          backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
    }
  }

  List<Map<String, dynamic>> filterProducts(String query) {
    if (query.isEmpty) {
      return _allAvailableProducts.toList();
    }
    final lowerQuery = query.toLowerCase();
    return _allAvailableProducts.where((item) {
      final itemName = item['item_name']?.toString().toLowerCase() ?? '';
      final itemBarcode = item['item_barcode']?.toString().toLowerCase() ?? '';
      final itemNo = item['item_no']?.toString().toLowerCase() ?? '';
      return itemName.contains(lowerQuery) ||
          itemBarcode.contains(lowerQuery) ||
          itemNo.contains(lowerQuery);
    }).toList();
  }

  Future<Map<String, dynamic>?> getProductDetails(String searchTerm) async {
    final lowerSearchTerm = searchTerm.toLowerCase();

    final productByNo = _allAvailableProducts.firstWhereOrNull(
          (p) => p['item_no']?.toString().toLowerCase() == lowerSearchTerm,
    );
    if (productByNo != null) return productByNo;

    final productByBarcode = _allAvailableProducts.firstWhereOrNull(
          (p) => p['item_barcode']?.toString().toLowerCase() == lowerSearchTerm,
    );
    if (productByBarcode != null) return productByBarcode;

    final productByName = _allAvailableProducts.firstWhereOrNull(
          (p) => p['item_name']?.toString().toLowerCase() == lowerSearchTerm,
    );
    if (productByName != null) return productByName;

    return null;
  }

  Map<String, dynamic> createEmptyProductPlaceholder() {
    return {
      'item_no': null,
      'item_name': '',
      'item_price': 0.0,
      'quantity': 0,
      'bonus_quantity': 0,
      'item_discount': 0.0,
      'total_item': 0.0,
      'isEmpty': true,
    };
  }

  // 💡 هذه هي الدالة الأساسية التي تم تعديلها لمعالجة مشكلة "disposed controller"
  void _initializeProductsList() {
    // قم بإنشاء نسخ مؤقتة من الـ Controllers الحالية.
    final Map<int, TextEditingController> oldQuantityControllers = Map.from(_quantityControllers);
    final Map<int, TextEditingController> oldBonusQuantityControllers = Map.from(_bonusQuantityControllers);
    final Map<int, TextEditingController> oldDiscountControllers = Map.from(_discountControllers);

    // امسح الـ Maps الأصلية والـ products دون التخلص منها بعد.
    _quantityControllers.clear();
    _bonusQuantityControllers.clear();
    _discountControllers.clear();
    products.clear();

    // أعد ملء قائمة المنتجات بالصفوف الفارغة المطلوبة.
    for (int i = 0; i < initialEmptyRows; i++) {
      products.add(createEmptyProductPlaceholder());

      // أعد استخدام الـ Controllers القديمة إن وجدت، وإلا أنشئ واحدة جديدة.
      _quantityControllers[i] = oldQuantityControllers[i] ?? TextEditingController();
      _bonusQuantityControllers[i] = oldBonusQuantityControllers[i] ?? TextEditingController();
      _discountControllers[i] = oldDiscountControllers[i] ?? TextEditingController();

      // حدث نص الـ Controller بالقيمة الافتراضية.
      _quantityControllers[i]!.text = '0';
      _bonusQuantityControllers[i]!.text = '0';
      _discountControllers[i]!.text = '0.00';
    }

    // تخلص من أي Controllers قديمة لم يتم إعادة استخدامها في الدورة الحالية.
    _disposeUnusedControllers(oldQuantityControllers, _quantityControllers);
    _disposeUnusedControllers(oldBonusQuantityControllers, _bonusQuantityControllers);
    _disposeUnusedControllers(oldDiscountControllers, _discountControllers);

    products.refresh(); // تحديث الواجهة لتعكس التغييرات
  }

  void addProduct(Map<String, dynamic> productData) {
    final String itemNo = productData['item_no']?.toString() ?? '';

    final int existingProductIndex = products.indexWhere((p) => p['isEmpty'] != true && p['item_no']?.toString() == itemNo);

    if (existingProductIndex != -1) {
      final int currentQuantity = products[existingProductIndex]['quantity'] as int;
      products[existingProductIndex]['quantity'] = currentQuantity + 1;
      getQuantityController(existingProductIndex).text = products[existingProductIndex]['quantity'].toString();
      _calculateItemTotal(existingProductIndex);
      Get.snackbar('تنبيه', 'الصنف موجود مسبقاً، تم زيادة الكمية.',
          backgroundColor: Colors.orange.withOpacity(0.8), colorText: Colors.white);
    } else {
      final int emptySlotIndex = products.indexWhere((p) => p['isEmpty'] == true);

      int targetIndex;
      if (emptySlotIndex != -1) {
        targetIndex = emptySlotIndex;
      } else {
        // إذا لم يكن هناك مكان فارغ، أضف صفًا جديدًا
        products.add(createEmptyProductPlaceholder());
        targetIndex = products.length - 1;
      }

      final double itemPrice = (productData['item_price'] as num?)?.toDouble() ?? 0.0;
      products[targetIndex] = {
        'item_no': productData['item_no'],
        'item_name': productData['item_name']?.toString() ?? '',
        'item_price': itemPrice,
        'quantity': 1,
        'bonus_quantity': 0,
        'item_discount': 0.0,
        'total_item': itemPrice,
        'isEmpty': false,
      };

      // تهيئة Controllers لهذا العنصر الجديد/المعاد استخدامه
      _quantityControllers[targetIndex] = _quantityControllers[targetIndex] ?? TextEditingController();
      _bonusQuantityControllers[targetIndex] = _bonusQuantityControllers[targetIndex] ?? TextEditingController();
      _discountControllers[targetIndex] = _discountControllers[targetIndex] ?? TextEditingController();

      getQuantityController(targetIndex).text = '1';
      getBonusQuantityController(targetIndex).text = '0';
      getDiscountController(targetIndex).text = '0.00';
      _calculateItemTotal(targetIndex);
    }
    products.refresh();
  }

  void updateQuantity(int index, String value) {
    if (index < 0 || index >= products.length || products[index]['isEmpty'] == true) return;

    final quantity = int.tryParse(value) ?? 0;
    if (quantity < 0) {
      Get.snackbar('خطأ', 'الكمية لا يمكن أن تكون سالبة.', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      getQuantityController(index).text = products[index]['quantity'].toString();
      return;
    }

    products[index]['quantity'] = quantity;
    _calculateItemTotal(index);
    products.refresh();
  }

  void updateBonusQuantity(int index, String value) {
    if (index < 0 || index >= products.length || products[index]['isEmpty'] == true) return;

    final bonusQuantity = int.tryParse(value) ?? 0;
    if (bonusQuantity < 0) {
      Get.snackbar('خطأ', 'كمية البونص لا يمكن أن تكون سالبة.', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      getBonusQuantityController(index).text = products[index]['bonus_quantity'].toString();
      return;
    }

    products[index]['bonus_quantity'] = bonusQuantity;
    products.refresh();
  }

  void updateItemDiscount(int index, String value) {
    if (index < 0 || index >= products.length || products[index]['isEmpty'] == true) return;

    final double itemDiscount = double.tryParse(value) ?? 0.0;
    if (itemDiscount < 0) {
      Get.snackbar('خطأ', 'الخصم للصنف لا يمكن أن يكون سالباً.', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      getDiscountController(index).text = products[index]['item_discount'].toStringAsFixed(2);
      return;
    }

    final int quantity = products[index]['quantity'] as int;
    final double price = products[index]['item_price'] as double;
    final double maxValue = quantity * price;

    if (itemDiscount > maxValue) {
      Get.snackbar('خطأ', 'الخصم للصنف لا يمكن أن يتجاوز قيمة السطر (${maxValue.toStringAsFixed(2)}\$).', backgroundColor: Colors.red.withOpacity(0.8), colorText: Colors.white);
      products[index]['item_discount'] = maxValue;
      getDiscountController(index).text = maxValue.toStringAsFixed(2);
    } else {
      products[index]['item_discount'] = itemDiscount;
    }
    _calculateItemTotal(index);
    products.refresh();
  }

  void _calculateItemTotal(int index) {
    final product = products[index];
    final int quantity = product['quantity'] as int;
    final double price = product['item_price'] as double;
    final double discount = product['item_discount'] as double;

    double itemTotal = (quantity * price) - discount;
    if (itemTotal < 0) itemTotal = 0;

    products[index]['total_item'] = itemTotal;
  }

  void removeProduct(int index) {
    if (index < 0 || index >= products.length) return;

    if (products[index]['isEmpty'] == true) {
      Get.snackbar('تنبيه', 'لا يمكن حذف خانة فارغة.',
          backgroundColor: Colors.orange.withOpacity(0.8), colorText: Colors.white);
      return;
    }

    // لا تتخلص من الـ Controllers هنا مباشرة، بل دع _rebuildControllersMap تتولى ذلك.
    // _quantityControllers[index]?.dispose();
    // _bonusQuantityControllers[index]?.dispose();
    // _discountControllers[index]?.dispose();

    products.removeAt(index);


    // دائمًا أضف صفًا فارغًا بعد الحذف إذا كان العدد أقل من الحد الأقصى
    if (products.length < maxFixedRows) {
      products.add(createEmptyProductPlaceholder());
    }

    // قم بإعادة بناء خرائط الـ Controllers بعد تغيير قائمة products
    _rebuildControllersMap();
    products.refresh();
  }

  // 💡 هذه الدالة تم تعديلها لتنظيف الـ Controllers التي لم تعد مستخدمة
  void _rebuildControllersMap() {
    final Map<int, TextEditingController> oldQuantityControllers = Map.from(_quantityControllers);
    final Map<int, TextEditingController> oldBonusQuantityControllers = Map.from(_bonusQuantityControllers);
    final Map<int, TextEditingController> oldDiscountControllers = Map.from(_discountControllers);

    _quantityControllers.clear();
    _bonusQuantityControllers.clear();
    _discountControllers.clear();

    for (int i = 0; i < products.length; i++) {
      // إعادة استخدام الـ Controller القديم إذا كان موجودًا في نفس الفهرس
      _quantityControllers[i] = oldQuantityControllers[i] ?? TextEditingController();
      _bonusQuantityControllers[i] = oldBonusQuantityControllers[i] ?? TextEditingController();
      _discountControllers[i] = oldDiscountControllers[i] ?? TextEditingController();

      // تحديث نص الـ Controller
      _quantityControllers[i]!.text = products[i]['quantity']?.toString() ?? '0';
      _bonusQuantityControllers[i]!.text = products[i]['bonus_quantity']?.toString() ?? '0';
      _discountControllers[i]!.text = (products[i]['item_discount'] as double?)?.toStringAsFixed(2) ?? '0.00';
    }

    // تخلص من الـ Controllers القديمة التي لم يتم إعادة استخدامها
    _disposeUnusedControllers(oldQuantityControllers, _quantityControllers);
    _disposeUnusedControllers(oldBonusQuantityControllers, _bonusQuantityControllers);
    _disposeUnusedControllers(oldDiscountControllers, _discountControllers);
  }

  // دالة مساعدة للتخلص من الـ Controllers غير المستخدمة
  void _disposeUnusedControllers(Map<int, TextEditingController> oldMap, Map<int, TextEditingController> newMap) {
    oldMap.forEach((key, controller) {
      if (!newMap.containsKey(key)) {
        controller.dispose();
      }
    });
  }

  void resetProducts() {
    _initializeProductsList();
    productSearchController.clear();
  }

  void _updateCalculations() {
    double newTotal = products.where((p) => p['isEmpty'] == false).fold(
        0.0,
            (sum, item) => sum + (item['total_item'] as double)
    );

    if (Get.isRegistered<AbsoluteCalculationsController>()) {
      calculationsController.updateTotal(newTotal);
    } else {
      print('تحذير: AbsoluteCalculationsController لم يتم تسجيله بعد عند محاولة تحديث الحسابات.');
    }
  }

  // 💡 هذه هي الدالة الأساسية الأخرى التي تم تعديلها لمعالجة مشكلة "disposed controller"
  void loadProductsForEditing(List<Map<String, dynamic>> loadedItems) {
    // قم بإنشاء نسخ مؤقتة من الـ Controllers الحالية.
    final Map<int, TextEditingController> oldQuantityControllers = Map.from(_quantityControllers);
    final Map<int, TextEditingController> oldBonusQuantityControllers = Map.from(_bonusQuantityControllers);
    final Map<int, TextEditingController> oldDiscountControllers = Map.from(_discountControllers);

    // امسح الـ Maps الأصلية والـ products دون التخلص منها بعد.
    _quantityControllers.clear();
    _bonusQuantityControllers.clear();
    _discountControllers.clear();
    products.clear();

    // 1. إضافة الأصناف المحملة
    for (var i = 0; i < loadedItems.length; i++) {
      var item = loadedItems[i];
      products.add({
        'item_no': item['item_no']?.toString() ?? '',
        'item_name': item['item_name']?.toString() ?? '',
        'quantity': (item['quantity'] as num?)?.toInt() ?? 0,
        'bonus_quantity': (item['bonus_quantity'] as num?)?.toInt() ?? 0,
        'item_price': (item['item_price'] as num?)?.toDouble() ?? 0.0,
        'item_discount': (item['item_discount'] as num?)?.toDouble() ?? 0.0,
        'total_item': (item['total_item'] as num?)?.toDouble() ?? 0.0,
        'isEmpty': false,
      });
      // أعد استخدام الـ Controllers القديمة أو أنشئ جديدة للـ loaded items
      _quantityControllers[i] = oldQuantityControllers[i] ?? TextEditingController();
      _bonusQuantityControllers[i] = oldBonusQuantityControllers[i] ?? TextEditingController();
      _discountControllers[i] = oldDiscountControllers[i] ?? TextEditingController();

      // تحديث نص الـ Controller
      _quantityControllers[i]!.text = products[i]['quantity'].toString();
      _bonusQuantityControllers[i]!.text = products[i]['bonus_quantity'].toString();
      _discountControllers[i]!.text = products[i]['item_discount'].toStringAsFixed(2);
    }

    // 2. حساب عدد الصفوف الفارغة المطلوب وإضافتها
    int currentProductsCount = products.length;
    int rowsToAdd = 0;

    if (currentProductsCount < initialEmptyRows) {
      rowsToAdd = initialEmptyRows - currentProductsCount;
    }

    for (int i = 0; i < rowsToAdd; i++) {
      products.add(createEmptyProductPlaceholder());
      final emptyIndex = products.length - 1;
      // أعد استخدام أو أنشئ Controllers للصفوف الفارغة المضافة
      _quantityControllers[emptyIndex] = oldQuantityControllers[emptyIndex] ?? TextEditingController(text: '0');
      _bonusQuantityControllers[emptyIndex] = oldBonusQuantityControllers[emptyIndex] ?? TextEditingController(text: '0');
      _discountControllers[emptyIndex] = oldDiscountControllers[emptyIndex] ?? TextEditingController(text: '0.00');
    }

    // 3. إعادة ترتيب المنتجات لضمان أن الصفوف الفارغة في الأسفل
    products.sort((a, b) {
      if (a['isEmpty'] == true && b['isEmpty'] == false) return 1;
      if (a['isEmpty'] == false && b['isEmpty'] == true) return -1;
      return 0;
    });

    // 4. تخلص من أي Controllers قديمة لم يتم إعادة استخدامها بعد تحميل الأصناف والترتيب
    _disposeUnusedControllers(oldQuantityControllers, _quantityControllers);
    _disposeUnusedControllers(oldBonusQuantityControllers, _bonusQuantityControllers);
    _disposeUnusedControllers(oldDiscountControllers, _discountControllers);

    products.refresh(); // تحديث الواجهة
  }
}