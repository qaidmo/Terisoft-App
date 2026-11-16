import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:untitled4/user_state.dart';
import 'package:untitled4/models/menu_item.dart';
import '../../utils/snackbar_helper.dart';

class ReportCategory {
  final String title;
  final IconData icon;
  final List<MenuItem> items;
  final bool isUnderDevelopment;

  const ReportCategory({
    required this.title,
    required this.icon,
    this.items = const [],
    this.isUnderDevelopment = false,
  });
}

class ReportsController extends GetxController {
  final UserState userState = Get.find<UserState>();

  final List<ReportCategory> categories = const [
    ReportCategory(
      title: 'التقارير العامة',
      icon: Icons.description_outlined,
      items: [
        MenuItem(
          title: 'سجل الحركات',
          icon: Icons.trending_up,
          screenNameKey: 'SalesMovementScreen',
        ),
        MenuItem(
          title: 'حركة المبيعات',
          icon: Icons.receipt_long_outlined,
          screenNameKey: 'SalesMovementNewScreen',
        ),
        MenuItem(
          title: 'حركة العملاء',
          icon: Icons.people_alt,
          screenNameKey: 'ClientsMovementScreen',
        ),
        MenuItem(
          title: 'حركة الموردين',
          icon: Icons.handshake_outlined,
          screenNameKey: 'SupplierMovementScreen',
        ),
      ],
    ),
    ReportCategory(
      title: 'تقارير الحسابات',
      icon: Icons.account_balance_wallet_outlined,
      items: [
        MenuItem(
          title: 'كشف حساب',
          icon: Icons.account_balance,
          screenNameKey: 'AccountStatementScreen',
        ),
        MenuItem(
          title: 'تقارير مراكز التكلفة',
          icon: Icons.account_tree_outlined,
          screenNameKey: 'CostCenterScreen',
        ),
        MenuItem(
          title: 'أرصدة الحسابات',
          icon: Icons.balance_outlined,
          screenNameKey: 'AccountBalancesScreen',
        ),
      ],
    ),
    ReportCategory(
      title: 'تقارير الأصناف والمخزون',
      icon: Icons.inventory_2_outlined,
      items: [
        MenuItem(
          title: 'حركة الأصناف',
          icon: Icons.swap_horiz_outlined,
          screenNameKey: 'ItemMovementScreen',
        ),
         MenuItem(
          title: 'أرصدة الأصناف',
          icon: Icons.inventory_outlined,
          screenNameKey: 'ItemBalancesScreen',
        ),
        MenuItem(
          title: 'بطاقة صنف',
          icon: Icons.credit_card_outlined,
          screenNameKey: 'ItemCardScreen',
        ),
        MenuItem(
          title: 'هامش الربح',
          icon: Icons.trending_up_rounded,
          screenNameKey: 'ProfitMarginScreen',
        ),
      ],
    ),
    ReportCategory(
      title: 'تقارير الأصول',
      icon: Icons.domain_outlined,
      isUnderDevelopment: true,
    ),
    ReportCategory(
      title: 'تقارير إحصائية',
      icon: Icons.bar_chart_outlined,
      isUnderDevelopment: true,
    ),
  ];

  void onCategoryTap(ReportCategory category) {
    if (category.isUnderDevelopment) {
      Get.defaultDialog(
        title: "تنبيه",
        titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        middleText: "هذا القسم قيد التطوير حالياً",
        middleTextStyle: const TextStyle(fontSize: 16),
        confirmTextColor: Colors.white,
        buttonColor: const Color.fromARGB(255, 1, 90, 163),
        radius: 10,
        textConfirm: "حسناً",
        onConfirm: () => Get.back(),
      );
    }
  }

  void onReportItemTap(MenuItem item) {

    bool isAdmin = userState.userType == 'admin';
    bool canAccess = userState.canAccessScreen(item.screenNameKey!) || isAdmin;

    if (canAccess) {
      Get.toNamed('/${item.screenNameKey}');
    } else {
      AppSnackbar.showCustomSnackbar(
          'صلاحيات',
          'ليس لديك صلاحية الوصول إلى "${item.title}".', isError: true
      );
    }
  }

  bool canAccessScreen(String? screenNameKey) {
    if (screenNameKey == null) return false;
    bool isAdmin = userState.userType == 'admin';
    return userState.canAccessScreen(screenNameKey) || isAdmin;
  }
}