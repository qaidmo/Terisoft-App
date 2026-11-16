import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/models/sun_box.dart';
import 'package:untitled4/utils/snackbar_helper.dart';

class SalesPaymentResult {
  final bool isNetwork;
  final bool isCredit;
  final Map<String, dynamic>? selectedNetworkBox;
  final double networkPaidAmount;

  SalesPaymentResult({
    required this.isNetwork,
    this.isCredit = false,
    this.selectedNetworkBox,
    this.networkPaidAmount = 0.0,
  });
}

class SalesPaymentDialogHelper {
  static String _formatAmount(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  static Future<SalesPaymentResult?> processPayment({
    required double totalRequired,
    required LookupsRepository lookupsRepository,
  }) async {
    // Step 1: Select Payment Method
    final bool? isNetwork = await _showPaymentMethodSelection();
    if (isNetwork == null) return null; // Cancelled

    if (!isNetwork) {
      return SalesPaymentResult(isNetwork: false);
    }

    // Step 2: Select Network Box
    final selectedBox = await _showNetworkBoxSelectionDialog(lookupsRepository);
    if (selectedBox == null) return null; // Cancelled

    // Step 3: Enter Network Amount
    final double? networkPaidAmount = await _showNetworkAmountDialog(totalRequired);
    if (networkPaidAmount == null) return null; // Cancelled

    return SalesPaymentResult(
      isNetwork: true,
      selectedNetworkBox: selectedBox,
      networkPaidAmount: networkPaidAmount,
    );
  }

  static Future<SalesPaymentResult?> processUtilityPayment({
    required double totalRequired,
    required LookupsRepository lookupsRepository,
  }) async {
    // 3 options: cash, network, credit
    final String? method = await _showUtilityPaymentMethodSelection();
    if (method == null) return null; // Cancelled

    if (method == 'cash') {
      return SalesPaymentResult(isNetwork: false, isCredit: false);
    } else if (method == 'credit') {
      return SalesPaymentResult(isNetwork: false, isCredit: true);
    } else {
      // Network
      final selectedBox = await _showNetworkBoxSelectionDialog(lookupsRepository);
      if (selectedBox == null) return null;

      final double? networkPaidAmount = await _showNetworkAmountDialog(totalRequired);
      if (networkPaidAmount == null) return null;

      return SalesPaymentResult(
        isNetwork: true,
        isCredit: false,
        selectedNetworkBox: selectedBox,
        networkPaidAmount: networkPaidAmount,
      );
    }
  }

  static Future<String?> _showUtilityPaymentMethodSelection() async {
    return await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'طريقة سداد فاتورة الخدمات',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => Get.back(result: 'cash'),
              icon: const Icon(Icons.money, size: 24, color: Colors.white),
              label: const Text('نقداً (كاش)', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Get.back(result: 'network'),
              icon: const Icon(Icons.credit_card, size: 24, color: Colors.white),
              label: const Text('شبكة (بطاقة / بنك)', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Get.back(result: 'credit'),
              icon: const Icon(Icons.receipt_long, size: 24, color: Colors.white),
              label: const Text('آجل (على الحساب)', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
  }

  static Future<bool?> _showPaymentMethodSelection() async {
    return await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('طريقة الدفع', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.all(20),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Get.back(result: false),
                icon: const Icon(Icons.money, size: 28, color: Colors.white),
                label: const Text('نقدي', style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Get.back(result: true),
                icon: const Icon(Icons.credit_card, size: 28, color: Colors.white),
                label: const Text('شبكة', style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: true,
    );
  }

  static Future<Map<String, dynamic>?> _showNetworkBoxSelectionDialog(LookupsRepository lookupsRepository) async {
    return await Get.dialog<Map<String, dynamic>>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر حساب الشبكة / البنك',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: FutureBuilder<List<SunBox>>(
                  future: lookupsRepository.fetchNetworkBoxes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('لا توجد حسابات شبكة متاحة'));
                    }

                    final boxes = snapshot.data!;
                    return GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: boxes.length,
                      itemBuilder: (context, index) {
                        final box = boxes[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () {
                              Get.back(result: {
                                'id': box.boxNo.toString(),
                                'name': box.boxName,
                                'account_id': box.accountId,
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                    radius: 25,
                                    child: const Icon(Icons.account_balance_wallet, color: Colors.blueAccent),
                                  ),
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text(
                                      box.boxName ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Get.back(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('إلغاء العملية', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  static Future<double?> _showNetworkAmountDialog(double totalRequired) async {
    final TextEditingController amountController = TextEditingController(text: _formatAmount(totalRequired));
    final RxDouble remainingAmount = 0.0.obs;

    amountController.addListener(() {
      final entered = double.tryParse(amountController.text) ?? 0.0;
      remainingAmount.value = totalRequired - entered;
    });

    return await Get.dialog<double>(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'إتمام الدفع الشبكي',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ الإجمالي:', style: TextStyle(fontSize: 16, color: Colors.black87)),
                    Text(
                      _formatAmount(totalRequired),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع شبكة',
                  labelStyle: const TextStyle(fontSize: 16),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  prefixIcon: const Icon(Icons.credit_card),
                ),
              ),
              const SizedBox(height: 10),
              Obx(() {
                bool isFullPayment = remainingAmount.value <= 0;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isFullPayment ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isFullPayment ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFullPayment ? Icons.check_circle : Icons.info,
                        size: 18,
                        color: isFullPayment ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isFullPayment
                            ? 'تم سداد كامل المبلغ'
                            : 'المتبقي (نقداً): ${_formatAmount(remainingAmount.value)}',
                        style: TextStyle(
                            color: isFullPayment ? Colors.green[700] : Colors.orange[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 15
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('إلغاء', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final entered = double.tryParse(amountController.text) ?? 0.0;
                        if (entered > totalRequired) {
                          AppSnackbar.showCustomSnackbar('خطأ', 'المبلغ المدفوع لا يمكن أن يتجاوز الإجمالي.', isError: true);
                          return;
                        }
                        if (entered <= 0) {
                          AppSnackbar.showCustomSnackbar('خطأ', 'يجب إدخال مبلغ صحيح.', isError: true);
                          return;
                        }

                        Get.back(result: entered);
                        await Future.delayed(const Duration(milliseconds: 300));
                        if (remainingAmount.value > 0) {
                          AppSnackbar.showCustomSnackbar('تنبيه', 'سيتم قيد المتبقي ${remainingAmount.value.toStringAsFixed(2)} على الصندوق النقدي.');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text('تأكيد الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
