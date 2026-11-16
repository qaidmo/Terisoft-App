import 'dart:io';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  static const MethodChannel _channel = MethodChannel('com.terasoft/whatsapp');

  /// Formats the phone number for WhatsApp by removing non-digits,
  /// handling leading zeros, and prefixing with '967' if no country code is present.
  static String formatForWhatsApp(String phone) {
    // Remove everything except numbers
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    
    if (clean.isEmpty) return clean;

    // Remove leading zeros
    while (clean.startsWith('0')) {
      clean = clean.substring(1);
    }

    // Default country code 967
    // If it already starts with 967 or 966, leave it as is
    if (clean.startsWith('967') || clean.startsWith('966')) {
      return clean;
    }

    // Prepend 967 default
    return '967$clean';
  }

  /// Sends the PDF file using the custom MethodChannel.
  /// Falls back to url_launcher if the native intent fails.
  static Future<bool> sendPdf({
    required File pdfFile,
    required String phoneNumber,
    required Function(String) showMessage,
    String packageName = 'com.whatsapp',
    String? caption,
  }) async {
    final String formattedPhone = formatForWhatsApp(phoneNumber);

    if (formattedPhone.isEmpty) {
      showMessage('رقم الهاتف غير صالح.');
      return false;
    }

    try {
      // 1. Attempt the flawless 1-click native intent
      final result = await _channel.invokeMethod('sendPdfToWhatsApp', {
        'path': pdfFile.path,
        'phone': formattedPhone,
        'packageName': packageName,
        'caption': caption,
      });
      return result == true;
    } catch (e) {
      // 2. The intent failed or was blocked by a new WhatsApp version
      print("Direct attachment failed: $e");
      
      // 3. Fallback: Open the chat via official URL scheme
      final String textParam = caption != null ? "?text=${Uri.encodeComponent(caption)}" : "";
      final Uri fallbackUrl = Uri.parse("https://wa.me/$formattedPhone$textParam");
      try {
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
          // 4. Notify the user to attach it manually
          showMessage('تم فتح المحادثة. يرجى إرفاق الفاتورة يدوياً من التنزيلات أو الملفات المؤقتة.');
          return true;
        } else {
          showMessage('تطبيق واتساب غير مثبت أو الرابط غير صالح.');
          return false;
        }
      } catch (e) {
        showMessage('فشل في فتح واتساب: $e');
        return false;
      }
    }
  }
}
