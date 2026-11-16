// lib/screens/controllers/inventory_calculations_controller.dart

import 'package:get/get.dart';

class InventoryCalculationsController extends GetxController {
  // القيم المالية
  final RxDouble totalActualValue = 0.0.obs; // الاجمالي (قيمة الجرد)
  final RxDouble totalSystemValue = 0.0.obs; // قيمة الرصيد
  final RxDouble netDiffValue = 0.0.obs;     // فارق القيمة
  final RxDouble totalSurplusValue = 0.0.obs; // قيمة الفائض
  final RxDouble totalDeficitValue = 0.0.obs; // قيمة العجز

  // الكميات (للعمود الأيسر)
  final RxDouble totalItemsCount = 0.0.obs;  // عدد القطع (الفعلي)
  final RxDouble totalSystemQty = 0.0.obs;   // عدد الرصيد (الدفتري)
  final RxDouble totalDiffQty = 0.0.obs;     // فارق الكمية

  void updateCalculations({
    required double sysQty,
    required double actQty,
    required double sysVal,
    required double actVal,
    required double surplus,
    required double deficit,
    // ✅ نستقبل القيم الجديدة
    required double totalDiffQtyInput,
  }) {
    totalSystemQty.value = sysQty;
    totalItemsCount.value = actQty;
    totalDiffQty.value = totalDiffQtyInput; // تخزين فارق الكمية

    totalSystemValue.value = sysVal;
    totalActualValue.value = actVal;

    totalSurplusValue.value = surplus;
    totalDeficitValue.value = deficit;

    // فارق القيمة هو (الجرد - الرصيد)
    netDiffValue.value = actVal - sysVal;
  }

  void reset() {
    totalActualValue.value = 0.0;
    totalSystemValue.value = 0.0;
    netDiffValue.value = 0.0;
    totalSurplusValue.value = 0.0;
    totalDeficitValue.value = 0.0;
    totalItemsCount.value = 0.0;
    totalSystemQty.value = 0.0;
    totalDiffQty.value = 0.0;
  }
}