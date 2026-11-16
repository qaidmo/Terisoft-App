import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

class UiHelper {
  static Future<bool> showOfflineWarningDialog(String lastSyncTime, {String? lockedDateRange}) async {
    bool? result = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actionsPadding: const EdgeInsets.only(bottom: 24, right: 24, left: 24),
        title: const Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: Colors.orangeAccent,
              size: 52,
            ),
            SizedBox(height: 16),
            Text(
              'وضع عدم الاتصال',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'لا يوجد اتصال بالإنترنت. سيتم عرض البيانات المخزنة محلياً لآخر مزامنة في:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              _formatSyncTime(lastSyncTime),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
              textDirection: TextDirection.ltr,
            ),
            if (lockedDateRange != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_clock, size: 20, color: Colors.black54),
                        SizedBox(width: 8),
                        Text(
                          'تنبيه الفلترة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'نظراً لطبيعة هذا التقرير، البيانات المعروضة محصورة فقط في الفترة:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lockedDateRange,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Get.back(result: false),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.black87, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: () => Get.back(result: true),
                  child: const Text('متابعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
      barrierDismissible: false,
    );

    return result ?? false;
  }


  static String _formatSyncTime(String rawTime) {
    final DateTime? dt = DateTime.tryParse(rawTime);
    if (dt == null) return rawTime;
    final DateTime local = dt.toLocal();
    return DateFormat('dd/MM/yyyy — hh:mm a').format(local);
  }
}
