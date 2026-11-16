import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:untitled4/screens/controllers/home_controller.dart';
import 'package:untitled4/widgets/menu_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find<HomeController>();

    return WillPopScope(
      onWillPop: controller.showExitConfirmationDialog,
      child: Scaffold(
        appBar: AppBar(
          title: Obx(() {
            return Text(controller.companyName.value);
          }),
          centerTitle: true,
          // leading is removed — Flutter auto-shows the hamburger icon for the Drawer
          actions: [
            Obx(() {
              if (controller.userState.isAdmin) {
                return IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'إعدادات المدير',
                  onPressed: controller.onSettingsTap,
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.account_circle_outlined, size: 28),
                  tooltip: 'ملفي الشخصي',
                  onPressed: controller.onProfileIconTap,
                );
              }
            }),
          ],
        ),
        drawer: _buildDrawer(context, controller),
        body: GridView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 130,
          ),
          itemCount: controller.menuItems.length,
          itemBuilder: (context, index) {
            final menuItem = controller.menuItems[index];

            return Obx(() {
              bool canAccess = controller.canAccessScreen(menuItem.screenNameKey);

              Widget cardWidget = Opacity(
                opacity: canAccess ? 1.0 : 0.4,
                child: AbsorbPointer(
                  absorbing: !canAccess,
                  child: MenuCard(
                    item: menuItem,
                    onTap: () => controller.onMenuItemTap(menuItem),
                  ),
                ),
              );

              return cardWidget
                  .animate()
                  .fade(duration: 400.ms, delay: (index * 50).ms)
                  .scale(curve: Curves.easeOutBack, delay: (index * 50).ms);
            });
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Drawer — Side menu with settings, navigation tree, License & Fingerprint
  // ---------------------------------------------------------------------------
  Widget _buildDrawer(BuildContext context, HomeController controller) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ---- Header ----
            Obx(() => UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color.fromARGB(255, 2, 119, 212), Color.fromARGB(255, 1, 90, 163)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Color.fromARGB(255, 1, 90, 163)),
              ),
              accountName: Text(
                controller.userState.safeUserName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: Text(
                controller.companyName.value,
                style: const TextStyle(fontSize: 13),
              ),
            )),

            // ---- Settings Section ----
            // License Lock
            Obx(() => ListTile(
              leading: Icon(
                controller.isLicensed.value ? Icons.verified_user : Icons.lock_outline,
                color: controller.isLicensed.value ? Colors.green : Colors.amber,
              ),
              title: Text(
                'ترخيص التطبيق',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              trailing: controller.isLicensed.value
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                  : null,
              onTap: () {
                Get.back(); // Close drawer
                controller.onLicenseIconTap();
              },
            )),

            // Fingerprint Switch
            Obx(() => SwitchListTile(
              secondary: const Icon(Icons.fingerprint, color: Color.fromARGB(255, 1, 90, 163)),
              title: const Text('تفعيل الدخول بالبصمة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              value: controller.isBiometricEnabled.value,
              activeColor: const Color.fromARGB(255, 1, 90, 163),
              onChanged: controller.canCheckBiometrics.value
                  ? (val) {
                      Get.back(); // Close drawer
                      if (val) {
                        controller.showFingerprintActivationDialog();
                      } else {
                        controller.disableFingerprint();
                      }
                    }
                  : null,
            )),

            const Divider(height: 1),

            // ---- Navigation Tree ----
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'الشاشات المتاحة',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: controller.menuItems.length,
                itemBuilder: (context, index) {
                  final item = controller.menuItems[index];
                  final canAccess = controller.canAccessScreen(item.screenNameKey);
                  return ListTile(
                    leading: Icon(item.icon,
                        color: canAccess ? item.color : Colors.grey.shade400, size: 22),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: canAccess ? Colors.black87 : Colors.grey.shade400,
                      ),
                    ),
                    onTap: canAccess
                        ? () {
                            Get.back(); // Close drawer
                            controller.onMenuItemTap(item);
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}