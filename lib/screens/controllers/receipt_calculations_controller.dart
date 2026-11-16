// lib/screens/controllers/receipt_calculations_controller.dart
import 'package:get/get.dart';
import 'package:untitled4/utils/number_to_words_converter.dart'; // استيراد الدالة الجديدة

class ReceiptCalculationsController extends GetxController {
  // الإجمالي الكلي للسند (يمثل صافي المبلغ المدفوع/المقبوض)
  final RxDouble total = 0.0.obs;

  // في سندات القبض/الصرف، لا يوجد خصم أو ضريبة عادةً بشكل منفصل
  // لذا، NetTotal سيكون هو نفسه Total
  final RxDouble netTotal = 0.0.obs;

  // المبلغ الإجمالي كتابة باللغة العربية
  final RxString amountInWords = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // تهيئة القيم عند بدء التشغيل
    total.value = 0.0;
    netTotal.value = 0.0;
    amountInWords.value = convertNumberToWordsArabic(0.0); // تهيئة أولية
  }

  // دالة لتحديث الإجمالي الكلي
  // هذه الدالة ستُستدعى من ReceiptItemsController كلما تغيرت بنود السند.
  void updateTotal(double newTotal) {
    total.value = newTotal;
    netTotal.value = newTotal; // في سند القبض، الإجمالي هو نفسه الصافي
    amountInWords.value = convertNumberToWordsArabic(newTotal); // تحديث المبلغ كتابة
  }

  // دالة لإعادة تعيين جميع الحسابات إلى الصفر
  void reset() {
    total.value = 0.0;
    netTotal.value = 0.0;
    amountInWords.value = ''; // أو يمكنك تعيينها إلى 'صفر' حسب رغبتك
  }
}


