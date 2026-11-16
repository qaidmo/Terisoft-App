// lib/admin/admin_dashboard.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:untitled4/admin/controllers/admin_dashboard_controller.dart';
import 'package:untitled4/admin/widgets/admin_3d_stats_card.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminDashboardController controller = Get.put(AdminDashboardController());

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'لوحة تحكم المدير',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. البطاقة الإحصائية ثلاثية الأبعاد العلوية بكامل العرض
          SliverToBoxAdapter(
            child: Admin3DStatsCard(controller: controller),
          ),

          // عنوان فرعي أنيق قبل شبكة بطاقات الإدارة
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 18, right: 18, top: 6, bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'إدارة البيانات والتهيئة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. شبكة بطاقات الإدارة الـ 12 الملونة بأسلوب MenuCard المتناسق
          SliverPadding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 10,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                mainAxisExtent: 130,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = controller.items[index];
                  return _buildDashboardItem(item, index, controller);
                },
                childCount: controller.items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء بطاقة الخدمة الإدارية بأسلوب MenuCard والزجاجية والظلال الملونة
  Widget _buildDashboardItem(
      DashboardItem item, int index, AdminDashboardController controller) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: item.color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.white.withOpacity(0.85),
            child: InkWell(
              splashColor: item.color.withOpacity(0.15),
              highlightColor: Colors.transparent,
              onTap: () => controller.navigateTo(item.route),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.icon,
                          size: 38,
                          color: item.color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fade(duration: 400.ms, delay: (index * 40).ms)
        .scale(curve: Curves.easeOutBack, delay: (index * 40).ms);
  }
}