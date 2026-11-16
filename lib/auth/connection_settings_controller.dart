import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database_helper.dart';

class ConnectionSettingsController extends GetxController {
  final bool isEditOnly;

  ConnectionSettingsController({this.isEditOnly = false});

  final companyNameController = TextEditingController();
  final serverAddressController = TextEditingController();

  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final successMessage = ''.obs;

  static const String serverPort = "5000";

  @override
  void onInit() {
    super.onInit();
    if (isEditOnly) {
      _loadExistingSettings();
    }
  }

  Future<void> _loadExistingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    companyNameController.text = prefs.getString('saved_company_name') ?? '';
    final savedAddress = prefs.getString('server_address') ?? '';
    // Strip the port suffix so the user sees only the raw IP for editing
    serverAddressController.text = savedAddress.replaceAll(':$serverPort', '');
  }

  Future<void> connectAndSaveSettings() async {
    final name = companyNameController.text.trim();
    final rawAddress = serverAddressController.text.trim();

    if (name.isEmpty || rawAddress.isEmpty) {
      errorMessage.value = 'يرجى إدخال اسم الشركة وعنوان الـ IP.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    successMessage.value = '';

    try {
      await DatabaseHelper.instance.database;

      String cleanIp = rawAddress
          .replaceAll('http://', '')
          .replaceAll('https://', '')
          .replaceAll('/', '')
          .split(':')[0];

      String finalAddress = '$cleanIp:$serverPort';
      String testUrl = 'http://$finalAddress/api/CoreData/check-connection';

      log("Testing URL: $testUrl");

      final response = await http.get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_company_name', name);
        await prefs.setString('server_address', finalAddress);

        if (isEditOnly) {
          successMessage.value = 'تم تحديث عنوان السيرفر بنجاح!';
          Future.delayed(const Duration(seconds: 1), () {
            Get.back();
          });
        } else {
          successMessage.value = 'تم الاتصال بالسيرفر بنجاح! جاري التوجيه...';
          Future.delayed(const Duration(seconds: 1), () {
            Get.offAllNamed('/sync-data');
          });
        }
      } else {
        errorMessage.value = 'فشل الاتصال: السيرفر رد بكود (${response.statusCode})';
      }
    } on TimeoutException {
      errorMessage.value = 'انتهى وقت الاتصال بالسيرفر. السيرفر مشغول';
    } catch (e) {
      log("Connection Error: $e");
      errorMessage.value = 'تعذر الوصول للسيرفر. تأكد من أن الـ IP صحيح والسيرفر يعمل.';
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    companyNameController.dispose();
    serverAddressController.dispose();
    super.onClose();
  }
}