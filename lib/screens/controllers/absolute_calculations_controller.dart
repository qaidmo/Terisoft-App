// lib/screens/controllers/absolute_calculations_controller.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class AbsoluteCalculationsController extends GetxController {
  final RxDouble total = 0.0.obs;
  final RxDouble discount = 0.0.obs;
  final RxDouble tax = 0.0.obs;
  final RxDouble netTotal = 0.0.obs;

  late final TextEditingController discountController;
  late final TextEditingController taxController; // ✨ إضافة متحكم جديد للضريبة

  // final double _taxRate = 0.15; // ✨ تم حذف نسبة الضريبة الثابتة

  @override
  void onInit() {
    super.onInit();
    discountController = TextEditingController(text: '0.00');
    discountController.addListener(_onDiscountChanged);

    // ✨ تهيئة متحكم الضريبة والاستماع لتغييراته
    taxController = TextEditingController(text: '0.00');
    taxController.addListener(_onTaxChanged);

    _calculateAll();
  }

  @override
  void onClose() {
    discountController.removeListener(_onDiscountChanged);
    discountController.dispose();

    // ✨ التخلص من متحكم الضريبة
    taxController.removeListener(_onTaxChanged);
    taxController.dispose();

    super.onClose();
  }

  void updateTotal(double newTotal) {
    total.value = newTotal;
    _calculateAll();
  }

  void _onDiscountChanged() {
    final String inputText = discountController.text.trim();
    if (inputText.isEmpty) {
      _updateDiscountValue(0.0);
      return;
    }

    final double? parsedDiscount = double.tryParse(inputText);

    if (parsedDiscount != null && parsedDiscount >= 0) {
      double newDiscountValue = parsedDiscount;

      if (newDiscountValue > total.value) {
        newDiscountValue = total.value;
        _updateDiscountControllerText(newDiscountValue);
        Get.snackbar(
          'تنبيه',
          'الخصم لا يمكن أن يتجاوز إجمالي الفاتورة.',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      _updateDiscountValue(newDiscountValue);
    } else {
      print('⚠️ تحذير: إدخال خصم غير صالح: $inputText');
    }
  }

  // ✨ دالة جديدة للتعامل مع تغييرات حقل الضريبة
  void _onTaxChanged() {
    final String inputText = taxController.text.trim();
    final double parsedTax = double.tryParse(inputText) ?? 0.0;
    if (parsedTax >= 0) {
      _updateTaxValue(parsedTax);
    }
  }

  void _updateDiscountValue(double newValue) {
    if (discount.value != newValue) {
      discount.value = newValue;
      _calculateAll();
    }
  }

  // ✨ دالة مساعدة جديدة لتحديث قيمة الضريبة
  void _updateTaxValue(double newValue) {
    if (tax.value != newValue) {
      tax.value = newValue;
      _calculateAll();
    }
  }

  void _updateDiscountControllerText(double newValue) {
    final String formattedValue = newValue.toStringAsFixed(2);
    discountController.removeListener(_onDiscountChanged);
    if (discountController.text != formattedValue) {
      discountController.text = formattedValue;
      discountController.selection = TextSelection.fromPosition(
        TextPosition(offset: discountController.text.length),
      );
    }
    discountController.addListener(_onDiscountChanged);
  }

  // ✨ دالة مساعدة جديدة لتحديث نص متحكم الضريبة
  void _updateTaxControllerText(double newValue) {
    final String formattedValue = newValue.toStringAsFixed(2);
    taxController.removeListener(_onTaxChanged);
    if (taxController.text != formattedValue) {
      taxController.text = formattedValue;
      taxController.selection = TextSelection.fromPosition(
        TextPosition(offset: taxController.text.length),
      );
    }
    taxController.addListener(_onTaxChanged);
  }

  void _calculateAll() {
    double currentDiscount = discount.value;

    double subTotalAfterDiscount = total.value - currentDiscount;
    if (subTotalAfterDiscount < 0) {
      subTotalAfterDiscount = 0;
    }

    // tax.value = subTotalAfterDiscount * _taxRate; // ✨ تم حذف هذه المعادلة

    netTotal.value = subTotalAfterDiscount + tax.value;
  }

  void resetCalculations() {
    total.value = 0.0;
    discount.value = 0.0;
    tax.value = 0.0;
    netTotal.value = 0.0;
    _updateDiscountControllerText(0.0);
    _updateTaxControllerText(0.0); // ✨ إعادة تعيين حقل الضريبة
  }
}