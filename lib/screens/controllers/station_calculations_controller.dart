// lib/screens/controllers/station_calculations_controller.dart
import 'package:get/get.dart';

class StationsCollectionCalculationsController extends GetxController {
  final RxDouble total = 0.0.obs;
  final RxDouble totalCharges = 0.0.obs;
  final RxDouble consumptionTotal = 0.0.obs;

  void updateAll({
    required double total,
    required double tax,
    double? totalItemDiscount,
    double? totalCharges,
    double? consumptionTotal,
  }) {
    this.total.value = total;
    if (totalCharges != null) this.totalCharges.value = totalCharges;
    if (consumptionTotal != null) this.consumptionTotal.value = consumptionTotal;
  }

  void resetCalculations() {
    total.value = 0.0;
    totalCharges.value = 0.0;
    consumptionTotal.value = 0.0;
  }
}
