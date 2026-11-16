import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:untitled4/admin/controllers/admin_dashboard_controller.dart';

/// بطاقة إحصائية مدمجة وثلاثية الأبعاد مصممة بعناية فائقة لتوفير مؤشرات فورية دون إشغال مساحة عمودية كبيرة
class Admin3DStatsCard extends StatelessWidget {
  final AdminDashboardController controller;

  const Admin3DStatsCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,##0.00', 'en_US');
    final intFormatter = NumberFormat('#,##0', 'en_US');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // استخدام Border.all متجانس بالكامل لتفادي استثناء paint() عند وجود borderRadius
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.2,
        ),
        boxShadow: [
          // ظل عمق ثلاثي الأبعاد سفلي واقعي
          BoxShadow(
            color: const Color(0xFF040E1B).withOpacity(0.55),
            offset: const Offset(0, 8),
            blurRadius: 20,
            spreadRadius: -2,
          ),
          // هالة إضاءة زرقاء خافتة لتعزيز الحضور البصري
          BoxShadow(
            color: const Color(0xFF1970B7).withOpacity(0.22),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF091C34), // أزرق كحلي ليلي عميق
            Color(0xFF0F3256), // أزرق ملكي
            Color(0xFF164B7E), // ياقوتي متألق
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // انعكاس زجاجي ناعم في الزاوية العلوية
            Positioned(
              top: -40,
              left: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. شريط الرأس المدمج: العنوان ومؤشر الاتصال مع كبسولة الفترات في صف واحد
                  _buildHeaderRow(),

                  const SizedBox(height: 10),

                  // 2. شبكة المؤشرات المالية المدمجة (صافي المبيعات، المخزون، المقبوضات، المدفوعات)
                  Obx(() {
                    if (controller.isStatsLoading.value) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF64B5F6),
                          ),
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        bool isWide = constraints.maxWidth > 550;

                        if (isWide) {
                          // عرض واسع (أجهزة لوحية وشاشات أفقية): صف واحد بـ 4 بطاقات
                          return Row(
                            children: [
                              Expanded(
                                child: _build3DMetricTile(
                                  title: 'صافي المبيعات',
                                  value: currencyFormatter.format(controller.netSales.value),
                                  subtitle: '${intFormatter.format(controller.invoicesCount.value)} فاتورة',
                                  icon: Icons.trending_up_rounded,
                                  accentColor: const Color(0xFF00E676),
                                  isHighlighted: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _build3DMetricTile(
                                  title: 'قيمة المخزون',
                                  value: currencyFormatter.format(controller.stockValue.value),
                                  subtitle: 'الأرصدة الحالية',
                                  icon: Icons.inventory_2_rounded,
                                  accentColor: const Color(0xFFBA68C8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _build3DMetricTile(
                                  title: 'سندات القبض (ق)',
                                  value: currencyFormatter.format(controller.receiptsTotal.value),
                                  icon: Icons.call_received_rounded,
                                  accentColor: const Color(0xFF40C4FF),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _build3DMetricTile(
                                  title: 'سندات الصرف (ص)',
                                  value: currencyFormatter.format(controller.paymentsTotal.value),
                                  icon: Icons.call_made_rounded,
                                  accentColor: const Color(0xFFFFB74D),
                                ),
                              ),
                            ],
                          );
                        }

                        // عرض الهواتف العادية: صفان مدمجان ومضغوطان رأسياً
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _build3DMetricTile(
                                    title: 'صافي المبيعات',
                                    value: currencyFormatter.format(controller.netSales.value),
                                    subtitle: '${intFormatter.format(controller.invoicesCount.value)} فاتورة',
                                    icon: Icons.trending_up_rounded,
                                    accentColor: const Color(0xFF00E676),
                                    isHighlighted: true,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: _build3DMetricTile(
                                    title: 'قيمة المخزون',
                                    value: currencyFormatter.format(controller.stockValue.value),
                                    subtitle: 'الأرصدة الحالية',
                                    icon: Icons.inventory_2_rounded,
                                    accentColor: const Color(0xFFBA68C8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _build3DMetricTile(
                                    title: 'سندات القبض (ق)',
                                    value: currencyFormatter.format(controller.receiptsTotal.value),
                                    icon: Icons.call_received_rounded,
                                    accentColor: const Color(0xFF40C4FF),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _build3DMetricTile(
                                    title: 'سندات الصرف (ص)',
                                    value: currencyFormatter.format(controller.paymentsTotal.value),
                                    icon: Icons.call_made_rounded,
                                    accentColor: const Color(0xFFFFB74D),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    );
                  }),

                  const SizedBox(height: 8),

                  // 3. الشريط السفلي الموحد: المزامنة والعدادات الإجمالية في سطر أنيق واحد
                  _buildUnifiedFooter(intFormatter),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fade(duration: 400.ms)
        .slideY(begin: -0.04, end: 0, curve: Curves.easeOutCubic);
  }

  // رأس البطاقة: مدمج يضم العنوان ونقطة الاتصال وزر التحديث ومبدل الفترات
  Widget _buildHeaderRow() {
    return Row(
      children: [
        // أيقونة الرأس
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.analytics_rounded,
            color: Color(0xFF64B5F6),
            size: 16,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'مؤشرات الأداء',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 6),
        // نقطة الاتصال المتوهجة وزر التحديث
        Obx(() => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: controller.isServerOnline.value
                        ? const Color(0xFF00E676)
                        : const Color(0xFFFFB300),
                    boxShadow: [
                      BoxShadow(
                        color: (controller.isServerOnline.value
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFFB300))
                            .withOpacity(0.7),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: controller.isStatsLoading.value
                      ? null
                      : controller.loadDashboardStats,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: controller.isStatsLoading.value
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Colors.white70,
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                  ),
                ),
              ],
            )),
        const Spacer(),
        // كبسولة اختيار الفترات المدمجة
        _buildCompactPeriodPill(),
      ],
    );
  }

  // كبسولة اختيار الفترة المدمجة (اليوم | الشهر | السنة)
  Widget _buildCompactPeriodPill() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Obx(() {
        int current = controller.selectedPeriod.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPeriodOption(title: 'اليوم', index: 0, isSelected: current == 0),
            _buildPeriodOption(title: 'الشهر', index: 1, isSelected: current == 1),
            _buildPeriodOption(title: 'السنة', index: 2, isSelected: current == 2),
          ],
        );
      }),
    );
  }

  Widget _buildPeriodOption({
    required String title,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => controller.onPeriodChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF29B6F6), Color(0xFF0288D1)],
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0288D1).withOpacity(0.4),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // بلاطة المقياس المدمجة مع حدود متجانسة بالكامل وظل عمق
  Widget _build3DMetricTile({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color accentColor,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.white.withOpacity(0.12)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        // استخدام Border.all متجانس لتفادي أي استثناء في الرسم
        border: Border.all(
          color: isHighlighted
              ? Colors.white.withOpacity(0.24)
              : Colors.white.withOpacity(0.10),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(icon, color: accentColor, size: 15),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: isHighlighted ? const Color(0xFF69F0AE) : Colors.white,
                fontSize: isHighlighted ? 15.5 : 13.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // الشريط السفلي الموحد (المزامنة + عدادات الأصناف والعملاء في شريط واحد مدمج)
  Widget _buildUnifiedFooter(NumberFormat formatter) {
    return Obx(() {
      int pending = controller.pendingSyncCount.value;
      bool isSynced = pending == 0;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.24),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            // شارة المزامنة المدمجة
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSynced ? Icons.check_circle_rounded : Icons.sync_problem_rounded,
                  color: isSynced ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  isSynced ? 'متزامن' : '$pending معلق',
                  style: TextStyle(
                    color: isSynced ? const Color(0xFF00E676) : const Color(0xFFFFD54F),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            _buildVerticalDivider(),
            // العدادات الأربعة مع التوزيع المتكافئ والحماية التامة من التجاوز
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCounterItem('عملاء', controller.totalCustomers.value, Icons.group, formatter),
                    _buildVerticalDivider(),
                    _buildCounterItem('أصناف', controller.totalItems.value, Icons.category, formatter),
                    _buildVerticalDivider(),
                    _buildCounterItem('صناديق', controller.totalBoxes.value, Icons.account_balance, formatter),
                    _buildVerticalDivider(),
                    _buildCounterItem('مخازن', controller.totalStores.value, Icons.inventory, formatter),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCounterItem(
      String label, int count, IconData icon, NumberFormat formatter) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white54, size: 12),
        const SizedBox(width: 3),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
        Text(
          formatter.format(count),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 12,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: Colors.white.withOpacity(0.15),
    );
  }
}
