// lib/screens/controllers/calculations_controller.dart
import 'package:get/get.dart';

class CalculationsController extends GetxController {
  final RxDouble total = 0.0.obs;
  final RxDouble discount = 0.0.obs;
  final RxDouble tax = 0.0.obs;
  final RxDouble netTotal = 0.0.obs;


  void updateAll({
    required double total,
    required double tax,
    double? totalItemDiscount,
  }) {
    this.total.value = total;
    this.tax.value = tax;
    discount.value = totalItemDiscount ?? 0.0;
    _calculateNetTotal();
  }


  void _calculateNetTotal() {
    netTotal.value = total.value + tax.value;
  }

  void resetCalculations() {
    total.value = 0.0;
    discount.value = 0.0;
    tax.value = 0.0;
    netTotal.value = 0.0;
  }
}