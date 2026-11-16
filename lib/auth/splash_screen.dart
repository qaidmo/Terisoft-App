import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../core/database_helper.dart';

// تعريف حالات التوجيه الممكنة
enum NavigationTarget { settings, sync, login }

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showGradient = false;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _showGradient = true;
        });
      }
    });

    _initializeAndCheckSettings();
  }

  Future<void> _initializeAndCheckSettings() async {
    // ننتظر وقتاً كافياً للأنيميشن (مثلاً 3 ثواني)
    final minDisplayTime = Future.delayed(const Duration(seconds: 3));

    // ✅ 3. تشغيل منطق الفحص الجديد
    final logicTask = _checkNewSystemStatus();

    final results = await Future.wait([minDisplayTime, logicTask]);

    // استلام النتيجة وتحديد الوجهة
    final NavigationTarget target = results[1] as NavigationTarget;

    // ✅ 4. التوجيه الذكي بناءً على الحالة
    switch (target) {
      case NavigationTarget.login:
      // الحالة الطبيعية: البيانات موجودة
        Get.offAllNamed('/login');
        break;
      case NavigationTarget.sync:
      // تم الاتصال لكن البيانات لم تُحمل بعد
      // تأكد من أن اسم الراوت هنا يطابق ما وضعته في main.dart
        Get.offAllNamed('/sync-data');
        break;
      case NavigationTarget.settings:
      // أول مرة يفتح التطبيق أو تم مسح البيانات
        Get.offAllNamed('/connection-settings');
        break;
    }
  }

  // ✅ 5. دالة الفحص الجديدة كلياً
  Future<NavigationTarget> _checkNewSystemStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // أ. فحص المفتاح الجديد الخاص بال API
      final serverAddress = prefs.getString('server_address');

      if (serverAddress == null || serverAddress.isEmpty) {
        // لم يتم إعداد الاتصال بعد
        return NavigationTarget.settings;
      }

      // ب. فحص قاعدة البيانات المحلية (هل تمت المزامنة؟)
      // بما أن CoreServicesBinding تعمل، الـ DatabaseHelper جاهز
      final db = await DatabaseHelper.instance.database;

      // نفحص جدول المستخدمين كمؤشر. إذا كان فارغاً، نحتاج لمزامنة.
      // نستخدم limit 1 للسرعة
      final List<Map<String, dynamic>> users = await db.query('sun_users', limit: 1);

      if (users.isEmpty) {
        // العنوان موجود، لكن لا توجد بيانات -> اذهب للمزامنة
        return NavigationTarget.sync;
      }

      // ج. كل شيء تمام -> اذهب لتسجيل الدخول
      return NavigationTarget.login;

    } catch (e) {
      debugPrint("Error during startup check: $e");
      // في حال حدوث أي خطأ غير متوقع، نعيده للإعدادات كخيار آمن
      return NavigationTarget.settings;
    }
  }

  // ============================================================
  // كود الواجهة (UI) يبقى كما هو تماماً دون تغيير
  // ============================================================
  @override
  Widget build(BuildContext context) {
    const Color nativeBackgroundColor = Color(0xFF0C1D36);
    return Scaffold(
      backgroundColor: nativeBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 1000),
            opacity: _showGradient ? 1.0 : 0.0,
            curve: Curves.easeOut,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0C1D36), Color(0xFF1A3A5F), Color(0xFF2D5A8A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5BC0FF).withOpacity(0.5),
                        blurRadius: 25.0,
                        spreadRadius: 2.0,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/logo.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    duration: 1200.ms,
                    curve: Curves.easeOutBack
                )
                    .fadeIn(duration: 800.ms),

                const SizedBox(height: 40),

                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  builder: (context, value, child) {
                    return ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: const [Color(0xFF5BC0FF), Colors.white, Color(0xFFA4C8F5)],
                          transform: GradientRotation(value * 2 * 3.14159),
                        ).createShader(bounds);
                      },
                      child: child,
                    );
                  },
                  child: const Text(
                    'Terasoft',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      letterSpacing: 2,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 1200.ms)
                    .slideY(begin: 0.5, end: 0, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ],
      ),
    );
  }
}