import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:untitled4/repositories/box_repository.dart';
import 'package:untitled4/repositories/receipt_repository.dart';
import 'package:untitled4/repositories/report_repository.dart';
import 'package:untitled4/repositories/sales_repository.dart';
import 'package:untitled4/repositories/restaurant_repository.dart';
import 'package:untitled4/services/api_service.dart';
import 'package:untitled4/services/sync_service.dart';
import 'package:untitled4/core//database_helper.dart';
import 'package:untitled4/repositories/account_repository.dart';
import 'package:untitled4/repositories/item_repository.dart';
import 'package:untitled4/repositories/store_repository.dart';
import 'package:untitled4/repositories/lookups_repository.dart';
import 'package:untitled4/repositories/auth_repository.dart';
import 'package:untitled4/admin/Permissions_Screen.dart';
import 'package:untitled4/admin/account_screen.dart';
import 'package:untitled4/admin/agents_screen.dart';
import 'package:untitled4/admin/boxes_screen.dart';
import 'package:untitled4/admin/collectors_screen.dart';
import 'package:untitled4/auth/login_controller.dart';
import 'package:untitled4/screens/controllers/home_controller.dart';
import 'package:untitled4/screens/cost_center_report_screen.dart';
import 'package:untitled4/admin/cost_centers_screen.dart';
import 'package:untitled4/admin/currencies_screen.dart';
import 'package:untitled4/admin/customers_screen.dart';
import 'package:untitled4/admin/item_groups_screen.dart';
import 'package:untitled4/admin/item_screen.dart';
import 'package:untitled4/admin/store_screen.dart';
import 'package:untitled4/auth/splash_screen.dart';
import 'package:untitled4/auth/login_screen.dart';
import 'package:untitled4/admin/admin_dashboard.dart';
import 'package:untitled4/screens/absolute_cash_sale_return_screen.dart';
import 'package:untitled4/screens/credit_sale_return_screen.dart';
import 'package:untitled4/screens/absolute_cash_sale_screen.dart';
import 'package:untitled4/screens/account_statement_screen.dart';
import 'package:untitled4/screens/cash_payment_voucher_screen.dart';
import 'package:untitled4/screens/cash_receipt_voucher_screen.dart';
import 'package:untitled4/screens/cash_sale_return_screen.dart';
import 'package:untitled4/screens/cash_sale_screen.dart';
import 'package:untitled4/screens/clients_movement_screen.dart';
import 'package:untitled4/screens/credit_sale_screen.dart';
import 'package:untitled4/screens/home_screen.dart';
import 'package:untitled4/screens/inventory_count_screen.dart';
import 'package:untitled4/screens/station_collection_screen.dart';
import 'package:untitled4/screens/previous_invoices_screen.dart';
import 'package:untitled4/screens/reports_screen.dart';
import 'package:untitled4/screens/sales_movement_screen.dart';
import 'package:untitled4/screens/sales_movement_new_screen.dart';
import 'package:untitled4/screens/item_movement_screen.dart';
import 'package:untitled4/screens/profit_margin_screen.dart';
import 'package:untitled4/screens/item_balances_screen.dart';
import 'package:untitled4/screens/supplier_movement_screen.dart';
import 'package:untitled4/screens/account_balances_screen.dart';
import 'package:untitled4/screens/item_card_screen.dart';
import 'package:untitled4/views/screens/restaurant_pos_screen.dart';
import 'package:untitled4/services/lookups_service.dart.dart';
import 'package:untitled4/services/sync_view.dart';
import 'package:untitled4/user_state.dart';
import 'admin/branches_page.dart';
import 'admin/controllers/account_controller.dart';
import 'admin/controllers/invoice_templates_controller.dart';
import 'admin/departments_page.dart';
import 'admin/invoice_templates_page.dart';
import 'auth/connection_settings_screen.dart';
import 'core/preferences_service.dart';

class CoreServicesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ApiService(), fenix: true);
    Get.lazyPut(() => DatabaseHelper.instance, fenix: true);
    Get.lazyPut(() => PreferencesService(), fenix: true);

    Get.lazyPut(() => AccountRepository(), fenix: true);
    Get.lazyPut(() => ItemRepository(), fenix: true);
    Get.lazyPut(() => StoreRepository(), fenix: true);
    Get.lazyPut(() => LookupsRepository(), fenix: true);
    Get.lazyPut(() => AuthRepository(), fenix: true);
    Get.lazyPut(() => BoxRepository(), fenix: true);
    Get.lazyPut(() => SalesRepository(), fenix: true);
    Get.lazyPut(() => ReceiptRepository(), fenix: true);
    Get.lazyPut(() => ReportRepository(), fenix: true);
    Get.lazyPut(() => RestaurantRepository(), fenix: true);

    Get.lazyPut(() => SyncService(
      accountRepo: Get.find<AccountRepository>(),
      itemRepo: Get.find<ItemRepository>(),
      storeRepo: Get.find<StoreRepository>(),
      lookupsRepo: Get.find<LookupsRepository>(),
      authRepo: Get.find<AuthRepository>(),
      boxRepo: Get.find<BoxRepository>(),
      salesRepo: Get.find<SalesRepository>(),
      receiptRepo: Get.find<ReceiptRepository>(),
      restaurantRepo: Get.find<RestaurantRepository>(),
      preferencesService: Get.find<PreferencesService>(),
    ), fenix: true);

    Get.lazyPut(() => InvoiceTemplatesController(), fenix: true);
    Get.lazyPut(() => LookupsService(), fenix: true);
  }
}

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await dotenv.load(fileName: ".env");

  Get.put(UserState(), permanent: true);

  const String initialRoute = '/splash';

  runApp(const MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تيرا سوفت',
      defaultTransition: Transition.rightToLeftWithFade,
      transitionDuration: const Duration(milliseconds: 350),
      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Cairo',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            color: Colors.white70,
          ),
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF2962D3),
          secondary: const Color(0xFFF1F1F1),
        ),
      ),

      initialBinding: CoreServicesBinding(),
      onInit: () {
        final syncService = Get.find<SyncService>();
        syncService.startPeriodicSync();
      },
      initialRoute: initialRoute,
      getPages: [
        GetPage(
          name: '/connection-settings',
          page: () => const ConnectionSettingsScreen(),
        ),

        GetPage(
          name: '/sync-data',
          page: () => const SyncView(),
          binding: CoreServicesBinding(),
        ),

        GetPage(
          name: '/splash',
          page: () => const SplashScreen(),
          binding: CoreServicesBinding(),
        ),

        GetPage(
          name: '/login',
          page: () => const LoginScreen(),
          bindings: [
            CoreServicesBinding(),
            BindingsBuilder(() => Get.lazyPut(() => LoginController())),
          ],
          transition: Transition.fadeIn,
          transitionDuration: const Duration(milliseconds: 500),
        ),

        GetPage(
          name: '/admin',
          page: () => const AdminDashboard(),
          transition: Transition.downToUp,
          transitionDuration: const Duration(milliseconds: 400),
        ),

        GetPage(
            name: '/home',
            page: () => const HomeScreen(),
            bindings: [
              CoreServicesBinding(),
              BindingsBuilder(() {
                Get.lazyPut(() => HomeController());
              })
            ]),

        GetPage(name: '/boxes', page: () => const BoxesScreen()),
        GetPage(name: '/store', page: () => const StoreScreen()),
        GetPage(name: '/currencies', page: () => const CurrenciesScreen()),
        GetPage(name: '/item', page: () => ItemsScreen()),
        GetPage(name: '/collectors', page: () => const CollectorsScreen()),
        GetPage(name: '/agents', page: () => const AgentsScreen()),
        GetPage(name: '/permissions', page: () => PermissionsScreen()),
        GetPage(name: '/clients', page: () => const CustomersScreen()),
        GetPage(name: '/branches', page: () => const BranchesPage()),
        GetPage(name: '/departments', page: () => const DepartmentsPage()),
        GetPage(name: '/cost', page: () => const CostCentersScreen()),
        GetPage(
            name: '/admin_invoice_templates',
            page: () => InvoiceTemplatesPage()),
        GetPage(
            name: '/item_groups_screen',
            page: () => const ItemGroupsScreen()),
        GetPage(
          name: '/account_screen',
          page: () => const AccountScreen(),
          binding: BindingsBuilder.put(() => AccountController()),
        ),
        GetPage(name: '/RestaurantPosScreen', page: () => const RestaurantPosScreen()),
        GetPage(name: '/StationCollectionScreen', page: () => const StationsCollectionScreen()),
        GetPage(name: '/CashSaleScreen', page: () => const CashSaleScreen()),
        GetPage(
            name: '/CreditSaleScreen', page: () => const CreditSaleScreen()),
        GetPage(
            name: '/AbsoluteCashSaleScreen',
            page: () => const AbsoluteCashSaleScreen()),
        GetPage(
            name: '/CashPaymentVoucherScreen',
            page: () => const CashPaymentVoucherScreen()),
        GetPage(
            name: '/CashSaleReturnScreen',
            page: () => const CashSaleReturnScreen()),
        GetPage(
            name: '/CreditSaleReturnScreen',
            page: () => const CreditSaleReturnScreen()),
        GetPage(
            name: '/AbsoluteCashSaleReturnScreen',
            page: () => const AbsoluteCashSaleReturnScreen()),
        GetPage(name: '/ReceiptScreen', page: () => const ReceiptScreen()),
        GetPage(name: '/ReportsScreen', page: () => const ReportsScreen()),
        GetPage(
            name: '/AccountStatementScreen',
            page: () => const AccountStatementScreen()),
        GetPage(
            name: '/SalesMovementScreen',
            page: () => const SalesMovementScreen()),
        GetPage(
            name: '/ClientsMovementScreen',
            page: () => const ClientsMovementScreen()),
        GetPage(
            name: '/PreviousInvoicesScreen',
            page: () => const PreviousInvoicesScreen()),
        GetPage(
            name: '/CostCenterScreen',
            page: () => const CostCenterReportScreen()),

        GetPage(
            name: '/InventoryCountScreen',
            page: () => const InventoryCountScreen()
        ),

        // تقرير حركة المبيعات الجديد — مستقل تماماً
        GetPage(
            name: '/SalesMovementNewScreen',
            page: () => const SalesMovementNewScreen()),

        // تقرير حركة الأصناف — مستقل تماماً
        GetPage(
            name: '/ItemMovementScreen',
            page: () => const ItemMovementScreen()),

        // تقرير هامش الربح — مستقل تماماً
        GetPage(
            name: '/ProfitMarginScreen',
            page: () => const ProfitMarginScreen()),

        // تقرير أرصدة الأصناف — مستقل تماماً
        GetPage(
            name: '/ItemBalancesScreen',
            page: () => const ItemBalancesScreen()),

        // تقرير حركة الموردين — مستقل تماماً
        GetPage(
            name: '/SupplierMovementScreen',
            page: () => const SupplierMovementScreen()),

        // تقرير بطاقة الصنف — مستقل تماماً
        GetPage(
            name: '/ItemCardScreen',
            page: () => const ItemCardScreen()),

        // تقرير أرصدة الحسابات — مستقل تماماً
        GetPage(
            name: '/AccountBalancesScreen',
            page: () => const AccountBalancesScreen()),
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
    );
  }
}