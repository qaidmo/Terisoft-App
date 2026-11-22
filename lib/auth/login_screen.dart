// lib/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:untitled4/auth/login_controller.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:untitled4/auth/connection_settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController _controller;

  /// Display controllers for the read-only combined "ID - Name" fields.
  ///
  /// [_branchDisplayController] is used only when the user cannot switch
  /// branches (the [DropdownButtonFormField] for switchable users needs no
  /// text controller). [_deptDisplayController] is always shown.
  late final TextEditingController _branchDisplayController;
  late final TextEditingController _deptDisplayController;

  /// GetX [Worker]s that keep the display controllers in sync. Disposed in
  /// [dispose].
  final List<Worker> _workers = [];

  /// Style constants shared across the login form fields (hoisted here so all
  /// builders share one source of truth).
  static const Color iconColor = Color(0xFF666666);
  static const Color labelColor = Color(0xFF555555);
  static const Color textColor = Colors.black;
  static const Color borderColor = Color(0xFFCCCCCC);
  static const EdgeInsets contentPadding =
      EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0);

  @override
  void initState() {
    super.initState();
    _controller = Get.find<LoginController>();

    _branchDisplayController = TextEditingController(
      text: _formatBranchDisplay(
        _controller.selectedBranchId.value,
        _controller.loggedInBranchName.value,
      ),
    );
    _deptDisplayController = TextEditingController(
      text: _formatDeptDisplay(
        _controller.departmentController.text,
        _controller.loggedInDepartmentName.value,
      ),
    );

    // Keep the display controllers in sync with the reactive observables.
    //
    // loggedInBranchName fires AFTER selectBranch() has already updated
    // selectedBranchId, so reading selectedBranchId.value here is safe and
    // always reflects the current selection.
    _workers.add(ever<String>(_controller.loggedInBranchName, (name) {
      _branchDisplayController.text = _formatBranchDisplay(
        _controller.selectedBranchId.value,
        name,
      );
    }));

    // refreshUserBranchState sets departmentController.text (the raw id) before
    // it sets loggedInDepartmentName, so the id is always available when this
    // worker fires.
    _workers.add(ever<String>(_controller.loggedInDepartmentName, (name) {
      _deptDisplayController.text = _formatDeptDisplay(
        _controller.departmentController.text,
        name,
      );
    }));
  }

  @override
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    _branchDisplayController.dispose();
    _deptDisplayController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Display-string helpers
  // ---------------------------------------------------------------------------

  /// Returns "ID - Name", gracefully degrading when either part is absent.
  String _formatBranchDisplay(int? branchId, String name) {
    if (branchId == null) return name;
    if (name.isEmpty) return branchId.toString();
    return '$branchId - $name';
  }

  /// Returns "ID - Name", gracefully degrading when either part is absent.
  String _formatDeptDisplay(String rawId, String name) {
    final id = rawId.trim();
    if (id.isEmpty) return name;
    if (name.isEmpty) return id;
    return '$id - $name';
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✨ ملاحظة: تم تعديل Get.put إلى Get.find()
    // هذا يفترض أنك قمت بعمل Get.put(LoginController()) في مكان ما قبل هذه الشاشة
    // أو إذا كانت هذه هي الشاشة الأولى، يمكنك إبقاء Get.put() كما كانت.
    // لكن Get.put() هو الأنسب إذا كانت هذه هي المرة الأولى التي يُستدعى فيها.
    final LoginController controller = _controller;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeaderSection(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: SingleChildScrollView(
                        child: Form(
                          key: controller.loginFormKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLoginForm(controller, context),
                              const SizedBox(height: 24),
                              // ✨ تم تعديل هذه الدالة بالكامل
                              _buildLoginButton(controller),
                              const SizedBox(height: 12),
                              _buildFullSyncButton(controller),
                              const SizedBox(height: 2),
                              _buildContactFooter(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Gear icon for editing server URL without triggering full sync
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Color(0xFF555555)),
                  iconSize: 22,
                  tooltip: 'إعدادات الاتصال',
                  onPressed: () {
                    Get.to(() => const ConnectionSettingsScreen(isEditOnly: true));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    // ... (هذه الدالة تبقى كما هي بدون تغيير) ...
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final carouselHeight = screenHeight * 0.3;
    final List<String> promoImages = [
      'assets/images/terai1.png', 'assets/images/terai3.png', 'assets/images/terai2.png',
      'assets/images/terai4.png', 'assets/images/terai5.png', 'assets/images/terai6.png',
      'assets/images/terai7.png', 'assets/images/terai8.png', 'assets/images/terai9.png',
      'assets/images/terai10.png', 'assets/images/terai11.png'
    ];

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(boxShadow: [BoxShadow(color: const Color(0xFF4A90E2).withOpacity(0.4), blurRadius: 20.0, spreadRadius: -5.0)]),
          child: Image.asset('assets/images/header_logo.jpg', width: screenWidth, fit: BoxFit.cover),
        ),
        CarouselSlider.builder(
          itemCount: promoImages.length,
          itemBuilder: (context, index, realIndex) => SizedBox(
            width: screenWidth,
            child: Image.asset(
              promoImages[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 40)),
            ),
          ),
          options: CarouselOptions(
            height: carouselHeight,
            autoPlay: true,
            viewportFraction: 1.0,
            enlargeCenterPage: false,
            autoPlayInterval: const Duration(seconds: 3),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildContactFooter() {
    // ... (هذه الدالة تبقى كما هي بدون تغيير) ...
    Widget contactItem(Widget iconWidget, String label, VoidCallback onTap) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF3A7BDB), Color(0xFF2A5AB5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: iconWidget,
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Column(
      children: [
        Divider(color: Colors.grey.shade300, indent: 20, endIndent: 20),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            contactItem(const Icon(Icons.call, color: Colors.white, size: 26), 'اتصل بنا', () => _launchURL('tel:+967774414409')),
            contactItem(const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white, size: 26), 'وتساب', () => _launchURL('https://wa.me/967774414409')),
            contactItem(const FaIcon(FontAwesomeIcons.facebook, color: Colors.white, size: 26), 'فيس بوك', () => _launchURL('https://www.facebook.com/TeraSoftit')),
            contactItem(const Icon(Icons.public, color: Colors.white, size: 26), 'موقعنا', () => _launchURL('https://terasoftit.net')),
          ],
        ).animate(delay: 500.ms).fadeIn(duration: 600.ms).moveY(begin: 30, end: 0, curve: Curves.easeOut),
      ],
    );
  }

  // ==========================================================
  // START: ✨ تم تعديل هذه الدالة بالكامل لإضافة زر البصمة
  // ==========================================================
  Widget _buildLoginButton(LoginController controller) {
    // 1. حولنا الـ Container الأصلي إلى Row
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 2. هذا هو زر "تسجيل الدخول" الأصلي، لكن وضعناه داخل Expanded
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3A7BDB), Color(0xFF2A5AB5)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: const Color(0xFF1E3F72).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]),
            child: Obx(() => ElevatedButton(
              onPressed: controller.isLoading.value ? null : controller.handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: controller.isLoading.value
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Text('تسجيل الدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.2)),
            )),
          ),
        ),

        // 3. إضافة فاصل صغير
        const SizedBox(width: 12),

        // 4. إضافة زر البصمة، مغلف بـ Obx لإظهاره/إخفائه
        Obx(() {
          // سيظهر الزر فقط إذا كان الجهاز يدعم البصمة *و* المستخدم قام بتفعيل الميزة
          if (controller.isBiometricEnabled.value && controller.canCheckBiometrics.value) {
            // هذا التصميم مأخوذ من الكود المثال الذي أرسلته
            return Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 8)]
              ),
              child: IconButton(
                // ✨ استدعاء دالة الدخول بالبصمة من الكنترولر
                onPressed: controller.handleBiometricLogin,
                icon: const Icon(Icons.fingerprint, color: Color(0xFF2A5AB5)),
                iconSize: 30,
                padding: const EdgeInsets.all(14),
                tooltip: 'الدخول بالبصمة',
              ),
            );
          } else {
            // إذا لم تتحقق الشروط، لا تعرض شيئاً
            return const SizedBox.shrink();
          }
        }),
      ],
    );
  }
  // ==========================================================
  // END: نهاية التعديل
  // ==========================================================

  Widget _buildFullSyncButton(LoginController controller) {
    return InkWell(
      onTap: controller.handleFullSync,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sync_rounded, color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
            Text(
              '\u0625\u0639\u0627\u062f\u0629 \u0645\u0632\u0627\u0645\u0646\u0629 \u0643\u0644\u064a\u0629',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLoginForm(LoginController controller, BuildContext context) {
    final Color focusedBorderColor = Theme.of(context).primaryColor;

    return Column(
      children: [
        const SizedBox(height: 24),
        TextFormField(
          controller: controller.usernameController,
          style: const TextStyle(color: textColor, fontSize: 14),
          onChanged: controller.refreshUserBranchState,
          validator: (value) => value!.isEmpty ? 'يرجى إدخال اسم المستخدم' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            labelText: 'اسم المستخدم',
            labelStyle: const TextStyle(color: labelColor, fontSize: 14),
            prefixIcon: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: controller.showUserSelectionSheet,
              child: const Icon(Icons.person_outline, color: iconColor),
            ),
            contentPadding: contentPadding,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: focusedBorderColor, width: 2)),
          ),
        ),
        const SizedBox(height: 16),
        Obx(() => TextFormField(
          controller: controller.passwordController,
          obscureText: controller.obscurePassword.value,
          style: const TextStyle(color: textColor, fontSize: 14),
          validator: (value) => value!.isEmpty ? 'يرجى إدخال كلمة المرور' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            labelText: 'كلمة المرور',
            labelStyle: const TextStyle(color: labelColor, fontSize: 14),
            prefixIcon: const Icon(Icons.lock_outline, color: iconColor),
            suffixIcon: IconButton(
              icon: Icon(controller.obscurePassword.value ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
              onPressed: controller.togglePasswordVisibility,
            ),
            contentPadding: contentPadding,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: focusedBorderColor, width: 2)),
          ),
        )),
        const SizedBox(height: 16),
        Obx(() {
          if (controller.isLoadingYears.value) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (controller.financialYears.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'لا توجد سنوات مالية متاحة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }
          return DropdownButtonFormField<int>(
            initialValue: controller.selectedFinancialYearId.value,
            items: controller.financialYears.map((year) {
              return DropdownMenuItem<int>(
                value: year['id'] as int,
                child: Text(
                  year['year_name'].toString(),
                  style: const TextStyle(color: textColor, fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (int? newValue) {
              controller.selectedFinancialYearId.value = newValue;
            },
            validator: (value) => value == null ? 'يرجى اختيار السنة المالية' : null,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              labelText: 'السنة المالية',
              labelStyle: const TextStyle(color: labelColor, fontSize: 14),
              prefixIcon: const Icon(Icons.calendar_today_outlined, color: iconColor, size: 20),
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: focusedBorderColor, width: 2)),
            ),
          );
        }),
        const SizedBox(height: 16),
        // Single row: Branch dropdown (left 50%) | Department read-only (right 50%).
        // Equal flex prevents the dropdown arrow from being squeezed. Falls back
        // to a vertical stack on very narrow devices (< 360 dp logical pixels).
        _buildBranchDepartmentRow(controller, context),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Branch / Department row
  // ---------------------------------------------------------------------------

  /// Single responsive row: Branch on the left, Department on the right.
  ///
  /// Both halves receive exactly 50 % of the available width via [Expanded]
  /// with equal flex, ensuring the branch dropdown arrow is never squeezed.
  /// On very narrow devices (< 360 logical dp) the fields stack vertically.
  Widget _buildBranchDepartmentRow(
    LoginController controller,
    BuildContext context,
  ) {
    final bool isNarrow = MediaQuery.of(context).size.width < 360;

    final branchWidget = _buildBranchField(controller, context);
    final deptWidget   = _buildDepartmentField();

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          branchWidget,
          const SizedBox(height: 12),
          deptWidget,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: branchWidget),
        const SizedBox(width: 12),
        Expanded(child: deptWidget),
      ],
    );
  }

  /// Branch field.
  ///
  /// • **Non-switchable users** → read-only [TextFormField] showing "ID - Name"
  ///   via [_branchDisplayController]. Validation guards the reactive
  ///   [selectedBranchId], not the formatted display text.
  ///
  /// • **Switchable users** → [DropdownButtonFormField] showing "ID - Name"
  ///   items. [isExpanded] is `true` so the widget constrains itself to its
  ///   parent's width and never overflows.
  Widget _buildBranchField(LoginController controller, BuildContext context) {
    final Color focusedColor = Theme.of(context).primaryColor;

    return Obx(() {
      // ── Read-only fallback for non-switchable users ──────────────────────
      if (!controller.canSwitchBranch.value) {
        return TextFormField(
          controller: _branchDisplayController,
          readOnly: true,
          style: const TextStyle(color: textColor, fontSize: 14),
          // Validate via the reactive id, not the "ID - Name" display string.
          validator: (_) =>
              controller.selectedBranchId.value == null ? 'مطلوب' : null,
          decoration: _fieldDecoration(
            label: 'الفرع',
            icon: Icons.location_on_outlined,
            fillColor: Colors.grey.shade100,
            // No active focus ring for a read-only field.
            focusedBorderColor: borderColor,
          ),
        );
      }

      // ── Dropdown for branch-switchable users ─────────────────────────────
      final Set<int?> validIds = controller.branches
          .map((b) => int.tryParse(b['branch_id'].toString()))
          .toSet();
      final int? selected =
          validIds.contains(controller.selectedBranchId.value)
              ? controller.selectedBranchId.value
              : null;

      return DropdownButtonFormField<int>(
        value: selected,
        // isExpanded constrains the dropdown to its parent width, preventing
        // the intrinsic-width overflow that caused the +36 px render error.
        isExpanded: true,
        items: controller.branches.map((b) {
          return DropdownMenuItem<int>(
            value: int.tryParse(b['branch_id'].toString()),
            child: Text(
              '${b['branch_id']} - ${b['branch_name']}',
              style: const TextStyle(color: textColor, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }).toList(),
        onChanged: controller.selectBranch,
        validator: (v) => v == null ? 'مطلوب' : null,
        decoration: _fieldDecoration(
          label: 'الفرع',
          icon: Icons.location_on_outlined,
          fillColor: Colors.white,
          focusedBorderColor: focusedColor,
        ),
      );
    });
  }

  /// Department field — always read-only, displays "ID - Name" via
  /// [_deptDisplayController].
  ///
  /// Validation checks the raw integer id held in the controller's internal
  /// [departmentController] (which stores only the id) rather than the
  /// formatted display string.
  Widget _buildDepartmentField() {
    return TextFormField(
      controller: _deptDisplayController,
      readOnly: true,
      style: const TextStyle(color: textColor, fontSize: 14),
      // Validate via the raw id controller, not the "ID - Name" display text.
      validator: (_) =>
          _controller.departmentController.text.trim().isEmpty ? 'مطلوب' : null,
      decoration: _fieldDecoration(
        label: 'القسم',
        icon: Icons.business_center_outlined,
        fillColor: Colors.grey.shade100,
        // No active focus ring for a read-only field.
        focusedBorderColor: borderColor,
      ),
    );
  }

  /// Shared [InputDecoration] factory for the branch and department row fields,
  /// keeping border radius, padding, and colours consistent with the rest of
  /// the login form.
  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    required Color fillColor,
    required Color focusedBorderColor,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: fillColor,
      labelText: label,
      labelStyle: const TextStyle(color: labelColor, fontSize: 14),
      prefixIcon: Icon(icon, color: iconColor, size: 20),
      contentPadding: contentPadding,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focusedBorderColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}