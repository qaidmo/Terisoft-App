// lib/utils/snackbar_helper.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSnackbar {
  static void showCustomSnackbar(String title, String message, {bool isError = false, bool isWarning = false}) {
    Color backgroundColor;
    IconData iconData;
    
    if (isError) {
      backgroundColor = Colors.red.shade600;
      iconData = Icons.error_outline;
    } else if (isWarning) {
      backgroundColor = Colors.orange.shade600;
      iconData = Icons.warning_amber_outlined;
    } else {
      backgroundColor = Colors.green.shade600;
      iconData = Icons.check_circle_outline;
    }

    Get.snackbar(
      '',
      '',

      titleText: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        textAlign: TextAlign.right,
      ),
      messageText: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        textAlign: TextAlign.right,
      ),
      backgroundColor: backgroundColor,

      duration: const Duration(seconds: 1),
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal, // هذا السطر يسمح بالسحب الأفقي

      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      icon: Icon(
        iconData,
        color: Colors.white,
      ),
    );
  }
}