import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:untitled4/auth/connection_settings_controller.dart';

class ConnectionSettingsScreen extends StatelessWidget {
  final bool isEditOnly;
  const ConnectionSettingsScreen({super.key, this.isEditOnly = false});

  @override
  Widget build(BuildContext context) {
    final ConnectionSettingsController controller = Get.put(ConnectionSettingsController(isEditOnly: isEditOnly));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0C1D36),
              theme.colorScheme.primary,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    Icons.lan_outlined,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 80
                ).animate()
                    .scale(duration: 600.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 20),

                Text(
                  'إعدادات الخادم',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'أدخل عنوان IP السيرفر ',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),

                const SizedBox(height: 40),

                ClipRRect(
                  borderRadius: BorderRadius.circular(24.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                    child: Container(
                      padding: const EdgeInsets.all(32.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: controller.companyNameController,
                            decoration: _buildInputDecoration(
                              labelText: 'اسم الشركة',
                              icon: Icons.business_rounded,
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: controller.serverAddressController,
                            decoration: _buildInputDecoration(
                              labelText: 'عنوان السيرفر (IP)',
                              icon: Icons.dns_rounded,
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 24),

                          Obx(() {
                            if (controller.errorMessage.value.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.5)
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFFF8A80), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        controller.errorMessage.value,
                                        style: const TextStyle(color: Color(0xFFFFCC80), fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          Obx(() {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    offset: const Offset(0, 4),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: controller.isLoading.value ? null : controller.connectAndSaveSettings,
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(WidgetState.disabled)) {
                                      return Colors.white.withValues(alpha: 0.9);
                                    }
                                    return Colors.white;
                                  }),
                                  foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                    return theme.colorScheme.primary;
                                  }),
                                  overlayColor: WidgetStateProperty.all(
                                      theme.colorScheme.primary.withValues(alpha: 0.1)
                                  ),
                                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                                  shape: WidgetStateProperty.all(
                                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  elevation: WidgetStateProperty.resolveWith((states) {
                                    if (states.contains(WidgetState.disabled)) return 0;
                                    return 8;
                                  }),
                                ),
                                child: controller.isLoading.value
                                    ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'جاري فحص الاتصال...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                )
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'حفظ واختبار الاتصال',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3, curve: Curves.easeOutCubic),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String labelText, required IconData icon}) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.9)),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.2),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFF8A80), width: 2),
      ),
    );
  }
}