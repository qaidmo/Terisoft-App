import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/account_repository.dart';
import '../repositories/item_repository.dart';
import '../repositories/store_repository.dart';
import '../repositories/lookups_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/box_repository.dart';
import '../repositories/sales_repository.dart';
import '../repositories/receipt_repository.dart';
import '../repositories/restaurant_repository.dart';
import '../core/database_helper.dart';
import '../core/preferences_service.dart';
import 'package:path_provider/path_provider.dart';

class SyncService extends GetxController {
  final AccountRepository accountRepo;
  final ItemRepository itemRepo;
  final StoreRepository storeRepo;
  final LookupsRepository lookupsRepo;
  final AuthRepository authRepo;
  final BoxRepository boxRepo;
  final SalesRepository salesRepo;
  final ReceiptRepository receiptRepo;
  final RestaurantRepository restaurantRepo;
  final PreferencesService preferencesService;

  RxBool isSyncing = false.obs;
  RxDouble progressValue = 0.0.obs;
  RxString currentTask = "".obs;

  Timer? _syncTimer;
  Timer? _inventoryTimer;

  final int totalSteps = 27;
  int completedSteps = 0;

  SyncService({
    required this.accountRepo,
    required this.itemRepo,
    required this.storeRepo,
    required this.lookupsRepo,
    required this.authRepo,
    required this.boxRepo,
    required this.salesRepo,
    required this.receiptRepo,
    required this.restaurantRepo,
    required this.preferencesService,
  });

  @override
  void onClose() {
    _syncTimer?.cancel();
    _inventoryTimer?.cancel();
    super.onClose();
  }

  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (isSyncing.value) return;

      final bool isConnected = await authRepo.checkDatabaseConnection();
      if (!isConnected) return;

      try {
        final serverAddress = await _getServerAddress();
        if (serverAddress != null && serverAddress.isNotEmpty) {
          final lastSync = await preferencesService.getLastSyncDate();
          final bool isFirstSync = (lastSync == null || lastSync.isEmpty);

          await syncAllMasterData(isSilent: !isFirstSync);
        }
      } catch (e) {
        log(e.toString());
      }
    });
  }

  void startPeriodicInventorySync() {
    _inventoryTimer?.cancel();
    _inventoryTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (isSyncing.value) return;

      try {
        final serverAddress = await _getServerAddress();
        if (serverAddress != null && serverAddress.isNotEmpty) {
          await itemRepo.syncInventory();
        }
      } catch (e) {
        log(e.toString());
      }
    });
  }

  Future<String?> _getServerAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_address');
  }

  Future<void> syncAllMasterData({bool isSilent = false}) async {
    if (isSyncing.value) return;

    isSyncing.value = true;

    if (!isSilent) {
      progressValue.value = 0.0;
      completedSteps = 0;
    }

    final db = await DatabaseHelper.instance.database;

    try {
      await db.execute('PRAGMA foreign_keys = OFF');

      await _trySync(() => lookupsRepo.syncAccountTypes(), "أنواع الحسابات");
      await _trySync(() => lookupsRepo.syncAccountMajorTypes(), "الأنواع الرئيسية");
      await _trySync(() => lookupsRepo.syncAccountClassifications(), "تصنيفات الحسابات");

      await _trySync(() => accountRepo.syncCurrencies(), "العملات");
      await _trySync(() => lookupsRepo.syncFinancialYears(), "السنوات المالية");
      await _trySync(() => lookupsRepo.syncCostCenters(), "مراكز التكلفة");

      await _trySync(() => accountRepo.syncAccounts(), "دليل الحسابات");
      await _trySync(() => accountRepo.syncAccountCurrencies(), "روابط عملات الحسابات");

      await _trySync(() => lookupsRepo.syncBranches(), "الفروع");
      await _trySync(() => lookupsRepo.syncDepartments(), "الأقسام");
      await _trySync(() => lookupsRepo.syncPumps(), "العدادات");

      await _trySync(() => boxRepo.syncBoxes(), "الصناديق");
      await _trySync(() => boxRepo.syncBoxCurrencies(), "عملات الصناديق");

      await _trySync(() => storeRepo.syncStores(), "المستودعات");

      await _trySync(() => authRepo.syncUsers(), "المستخدمين");
      await _trySync(() => authRepo.syncPermissions(), "صلاحيات المستخدمين");

      await _trySync(() => _initializeLocalSequences(), "تهيئة تسلسل الفواتير محلياً");
      await _trySync(() => _syncCompanyIdentity(), "تحديث بيانات الشركة");

      await _trySync(() => accountRepo.syncCustomers(), "العملاء");
      await _trySync(() => accountRepo.syncSuppliers(), "الموردين");
      await _trySync(() => accountRepo.syncCustomerCurrencies(), "عملات العملاء");

      await _trySync(() => itemRepo.syncMainGroups(), "المجموعات الرئيسية");
      await _trySync(() => itemRepo.syncItemGroups(), "مجموعات الأصناف");

      await _trySync(() => itemRepo.syncItems(), "بيانات الأصناف");
      await _trySync(() => itemRepo.syncItemUnits(), "وحدات القياس");
      await _trySync(() => itemRepo.syncInventory(), "الأرصدة المخزنية");

      await _trySync(() => lookupsRepo.syncSalespersons(), "المناديب");
      await _trySync(() => lookupsRepo.syncCollectors(), "المحصلين");

      if (!isSilent) {
        currentTask.value = "تمت المزامنة بنجاح";
        progressValue.value = 1.0;
        await preferencesService.saveLastSyncDate("Done"); // Keep one token for isFirstSync check
      }

      if (!isSilent) {
        await Future.delayed(const Duration(seconds: 1));
        Get.offAllNamed('/login');
      }

    } catch (e) {
      if (!isSilent) currentTask.value = "فشل في المزامنة";
      log(e.toString());
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
      isSyncing.value = false;
    }
  }

  Future<void> syncPendingSales(String apiUrl, String token) async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    currentTask.value = "جاري التحقق من الفواتير...";
    progressValue.value = 0.0;
    try {
      await salesRepo.syncSalesToRemote(apiUrl, token);
      await salesRepo.deleteOldSyncedSales();
      currentTask.value = "تمت عملية المزامنة";
      progressValue.value = 1.0;
    } catch (e) {
      log(e.toString());
      currentTask.value = "فشل في مزامنة الفواتير";
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      isSyncing.value = false;
      currentTask.value = "";
    }
  }

  Future<void> syncPendingReceipts(String apiUrl, String token) async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    currentTask.value = "جاري التحقق من السندات...";
    progressValue.value = 0.0;
    try {
      await receiptRepo.syncReceiptsToRemote(apiUrl, token);
      await receiptRepo.deleteOldSyncedReceipts();
      currentTask.value = "تمت عملية مزامنة السندات";
      progressValue.value = 1.0;
    } catch (e) {
      log(e.toString());
      currentTask.value = "فشل في مزامنة السندات";
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      isSyncing.value = false;
      currentTask.value = "";
    }
  }

  Future<void> syncPendingInventoryRecords(String apiUrl, String token) async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    currentTask.value = "جاري مزامنة محاضر الجرد...";
    progressValue.value = 0.0;
    try {
      String inventoryUrl = apiUrl.replaceAll(RegExp(r'sync-sales|sync-invoice'), 'sync-inventory');
      await salesRepo.syncSalesToRemote(inventoryUrl, token, invoiceTypeChar: 'م ض');
      // No need to call deleteOldSyncedSales specifically unless filtered, but we can call it.
      // deleteOldSyncedSales deletes everything marked is_synced=1, which is safe.
      await salesRepo.deleteOldSyncedSales();
      currentTask.value = "تمت مزامنة محاضر الجرد بنجاح";
      progressValue.value = 1.0;
    } catch (e) {
      log(e.toString());
      currentTask.value = "فشل في مزامنة محاضر الجرد";
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      isSyncing.value = false;
      currentTask.value = "";
    }
  }

  Future<void> syncPendingUtilityInvoices(String apiUrl, String token) async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    currentTask.value = "جاري مزامنة فواتير الخدمات (كهرباء/ماء)...";
    progressValue.value = 0.0;
    try {
      String utilityUrl = apiUrl.replaceAll(RegExp(r'sync-sales|sync-invoice'), 'sync-utility-invoice');
      await salesRepo.syncUtilitySalesToRemote(utilityUrl, token);
      await salesRepo.deleteOldSyncedSales();
      currentTask.value = "تمت مزامنة فواتير الخدمات بنجاح";
      progressValue.value = 1.0;
    } catch (e) {
      log("Error syncing utility invoices: $e");
      currentTask.value = "فشل في مزامنة فواتير الخدمات";
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      isSyncing.value = false;
      currentTask.value = "";
    }
  }

  Future<void> syncPendingRestaurantInvoices(String apiUrl, String token) async {
    if (isSyncing.value) return;
    isSyncing.value = true;
    print('🔄 [Restaurant Sync] Starting sync process...');
    currentTask.value = "جاري التحقق من فواتير المطعم...";
    progressValue.value = 0.0;
    try {
      int successCount = await restaurantRepo.syncRestaurantInvoicesToRemote(apiUrl, token);
      if (successCount > 0) {
         currentTask.value = "تمت مزامنة $successCount فاتورة مطعم";
      } else {
         currentTask.value = "لا توجد فواتير مطعم للمزامنة";
      }
      progressValue.value = 1.0;
    } catch (e) {
      log(e.toString());
      currentTask.value = "فشل في مزامنة فواتير المطعم";
    } finally {
      print('🏁 [Restaurant Sync] Sync process finished.');
      await Future.delayed(const Duration(seconds: 2));
      isSyncing.value = false;
      currentTask.value = "";
    }
  }

  Future<void> _initializeLocalSequences() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> users = await db.query('sun_users');
    final List<String> invoiceTypes = ['ن', 'ج', 'م', 'ق', 'ص', 'رن', 'رج', 'رم', 'م ض', 'ت', '801', '803'];
    await db.transaction((txn) async {
      for (var user in users) {
        for (var type in invoiceTypes) {
          await txn.rawInsert('''
            INSERT OR IGNORE INTO user_invoice_sequences (user_no, invoice_type_char, last_sequence)
            VALUES (?, ?, ?)
          ''', [user['user_no'], type, 0]);
        }
      }
    });
  }

  Future<void> _syncCompanyIdentity() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> users = await db.query('sun_users', limit: 1);
    if (users.isEmpty) return;
    final String departmentId = users.first['user_department']?.toString() ?? '1';
    final Map<String, dynamic>? data = await lookupsRepo.fetchDepartmentDetails(departmentId);
    if (data == null) return;
    String? localLogoPath;
    try {
      final String? base64String = data['logoBase64'] ?? data['LogoBase64'];
      if (base64String != null && base64String.isNotEmpty) {
        final Uint8List bytes = base64Decode(base64String);
        final directory = await getApplicationDocumentsDirectory();
        final String path = '${directory.path}/company_synced_logo.png';
        final File file = File(path);
        await file.writeAsBytes(bytes);
        localLogoPath = path;
      }
    } catch (e) {
      log("Error processing logo: $e");
    }
    final List<String> allScreenIdentifiers = [
      'CashPaymentVoucherScreen', 'CashSaleScreen', 'SalesMovementScreen',
      'ReceiptScreen', 'AbsoluteCashSaleScreen', 'CreditSaleReturnScreen',
      'CreditSaleScreen', 'AccountStatementScreen', 'ClientsMovementScreen',
      'CashSaleReturnScreen', 'CostCenterScreen', 'AbsoluteCashSaleReturnScreen',
      'RestaurantPosScreen',
      'SalesMovementNewScreen',
      'SupplierMovementScreen',
      'ItemBalancesScreen',
      'ItemMovementScreen',
      'ProfitMarginScreen',
      'ItemCardScreen',
    ];
    final batch = db.batch();
    final String now = DateTime.now().toIso8601String();
    for (String identifier in allScreenIdentifiers) {
      final List<Map<String, dynamic>> existing = await db.query('invoice_templates', where: 'screen_name_identifier = ?', whereArgs: [identifier]);
      Map<String, dynamic> settings = {};
      if (existing.isNotEmpty) {
        try { settings = jsonDecode(existing.first['settings_json']); } catch (_) {}
      }
      if (data['companyName'] != null) settings['header_company_name'] = data['companyName'];
      if (data['address'] != null) settings['footer_address_details'] = data['address'];
      if (localLogoPath != null) {
        settings['logo_url'] = localLogoPath;
        settings['show_logo'] = true;
      }
      if (existing.isNotEmpty) {
        batch.update('invoice_templates', {'settings_json': jsonEncode(settings), 'last_updated_at': now}, where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        settings['footer_thanks_message'] = 'شكراً لزيارتكم';
        batch.insert('invoice_templates', {
          'template_display_name': identifier,
          'screen_name_identifier': identifier,
          'settings_json': jsonEncode(settings),
          'is_active': 1,
          'created_at': now,
          'last_updated_at': now,
        });
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> _trySync(Future<void> Function() syncFunc, String taskName) async {
    try {
      currentTask.value = "جاري مزامنة $taskName...";
      await syncFunc();
      completedSteps++;
      progressValue.value = completedSteps / totalSteps;
    } catch (e) {
      log(e.toString());
      completedSteps++;
      progressValue.value = completedSteps / totalSteps;
    }
  }

  String _formatDateForServer(DateTime date) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String y = date.year.toString();
    String m = twoDigits(date.month);
    String d = twoDigits(date.day);
    String h = twoDigits(date.hour);
    String min = twoDigits(date.minute);
    String sec = twoDigits(date.second);
    return "$y$m$d$h$min$sec";
  }
}