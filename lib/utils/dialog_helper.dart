import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DialogHelper {
  static Future<bool> showExitConfirmationDialog() async {
    final bool? result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('تأكيد الخروج', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text('هل أنت متأكد أنك تريد الخروج؟'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
