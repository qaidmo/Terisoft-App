import 'package:get/get.dart';
import 'package:untitled4/core/database_helper.dart';
import 'package:untitled4/core/exceptions.dart';

class UserState extends GetxController {
  final _id = Rxn<String>();
  final _userNo = Rxn<int>();
  final _userDepartment = Rxn<int>();
  final _userDepartmentName = Rxn<String>();
  final _userType = Rxn<String>();
  final _lastTransactionSequence = 0.obs;
  final _userName = Rxn<String>();
  final _userGroup = ''.obs;
  final _screenPermissions = RxMap<String, Map<String, bool>>({});

  // Branch/store: record (default) values come from the synced user row.
  final _defaultBranch = Rxn<int>();
  final _defaultBranchName = Rxn<String>();
  final _defaultStoreNo = Rxn<int>();
  final _defaultStoreName = Rxn<String>();

  // Branch/store: active values — either the override target or the default.
  final _activeBranch = Rxn<int>();
  final _activeBranchName = Rxn<String>();
  final _activeStoreNo = Rxn<int>();
  final _activeStoreName = Rxn<String>();
  bool _branchOverridden = false;
  bool _canChangeBranch = false;

  final _userBoxNo = Rxn<int>();
  final _userBoxName = Rxn<String>();
  final _userBoxCurrencyNo = Rxn<int>();
  final _userBoxCurrencySymbol = Rxn<String>();

  final _receiptBoxNo = Rxn<int>();
  final _receiptBoxName = Rxn<String>();
  final _receiptBoxCurrencyNo = Rxn<int>();
  final _receiptBoxCurrencySymbol = Rxn<String>();

  final _paymentBoxNo = Rxn<int>();
  final _paymentBoxName = Rxn<String>();
  final _paymentBoxCurrencyNo = Rxn<int>();
  final _paymentBoxCurrencySymbol = Rxn<String>();

  final _financialYearId = Rxn<int>();
  final _financialYearName = Rxn<String>();

  Map<String, Map<String, bool>> get screenPermissions => _screenPermissions.value;
  String? get id => _id.value;
  int? get userNo => _userNo.value;

  /// Active branch — the override target when a branch was selected at login,
  /// otherwise the record's default branch. This is what every call site reads.
  int? get userBranch => _activeBranch.value;
  int? get userDepartment => _userDepartment.value;
  String? get userBranchName => _activeBranchName.value;
  String? get userDepartmentName => _userDepartmentName.value;
  String? get userType => _userType.value;
  int get lastTransactionSequence => _lastTransactionSequence.value;
  String? get userName => _userName.value;
  String get userGroup => _userGroup.value;

  /// Record (default) values straight from the synced user row.
  int? get defaultBranch => _defaultBranch.value;
  String? get defaultBranchName => _defaultBranchName.value;
  int? get defaultStoreNo => _defaultStoreNo.value;
  String? get defaultStoreName => _defaultStoreName.value;
  bool get isBranchOverridden => _branchOverridden;
  bool get canChangeBranch => _canChangeBranch;
  bool get canSwitchBranch => isAdmin || _canChangeBranch;

  int? get userBoxNo => _userBoxNo.value;
  String? get userBoxName => _userBoxName.value;
  int? get userStoreNo => _activeStoreNo.value;
  String? get userStoreName => _activeStoreName.value;
  int? get userBoxCurrencyNo => _userBoxCurrencyNo.value;
  String? get userBoxCurrencySymbol => _userBoxCurrencySymbol.value;

  int? get receiptBoxNo => _receiptBoxNo.value;
  String? get receiptBoxName => _receiptBoxName.value;
  int? get receiptBoxCurrencyNo => _receiptBoxCurrencyNo.value;
  String? get receiptBoxCurrencySymbol => _receiptBoxCurrencySymbol.value;

  int? get paymentBoxNo => _paymentBoxNo.value;
  String? get paymentBoxName => _paymentBoxName.value;
  int? get paymentBoxCurrencyNo => _paymentBoxCurrencyNo.value;
  String? get paymentBoxCurrencySymbol => _paymentBoxCurrencySymbol.value;

  int? get financialYearId => _financialYearId.value;
  String? get financialYearName => _financialYearName.value;

  bool get isAdmin => (userType ?? '').toLowerCase() == 'admin';

  String get safeId => id ?? '';
  int get safeUserNo => userNo ?? 0;
  int get safeUserBranch => userBranch ?? 0;
  int get safeUserDepartment => userDepartment ?? 0;
  String get safeUserBranchName => userBranchName ?? 'غير معروف';
  String get safeUserDepartmentName => userDepartmentName ?? 'غير معروف';
  String get safeUserName => userName ?? 'مستخدم غير معروف';
  bool get hasUserGroup => userGroup.isNotEmpty;

  int get safeUserBoxNo => userBoxNo ?? 0;
  String get safeUserBoxName => userBoxName ?? 'صندوق غير محدد';
  int get safeUserStoreNo => userStoreNo ?? 0;
  String get safeUserStoreName => userStoreName ?? 'مخزن غير محدد';
  int get safeCurrencyNo => userBoxCurrencyNo ?? 0;
  String get safeCurrencySymbol => userBoxCurrencySymbol ?? '-';

  int get safeReceiptBoxNo => receiptBoxNo ?? 0;
  String get safeReceiptBoxName => receiptBoxName ?? 'غير محدد';
  int get safeReceiptCurrencyNo => receiptBoxCurrencyNo ?? 0;
  String get safeReceiptCurrencySymbol => receiptBoxCurrencySymbol ?? '-';

  int get safePaymentBoxNo => paymentBoxNo ?? 0;
  String get safePaymentBoxName => paymentBoxName ?? 'غير محدد';
  int get safePaymentCurrencyNo => paymentBoxCurrencyNo ?? 0;
  String get safePaymentCurrencySymbol => paymentBoxCurrencySymbol ?? '-';

  int get safeFinancialYearId => financialYearId ?? 0;
  String get safeFinancialYearName => financialYearName ?? 'غير محددة';

  void setUser({
    required String userId,
    required int userNumber,
    required int userBranch,
    required int userDepartment,
    required String userBranchName,
    required String userDepartmentName,
    required String userType,
    required int lastTransactionSequence,
    required String userName,
    required String userGroup,
    bool canChangeBranch = false,
    Map<String, Map<String, bool>>? screenPermissions,
    int? userBoxNo,
    String? userBoxName,
    int? userStoreNo,
    String? userStoreName,
    int? userBoxCurrencyNo,
    String? userBoxCurrencySymbol,
    int? receiptBoxNo,
    String? receiptBoxName,
    int? receiptBoxCurrencyNo,
    String? receiptBoxCurrencySymbol,
    int? paymentBoxNo,
    String? paymentBoxName,
    int? paymentBoxCurrencyNo,
    String? paymentBoxCurrencySymbol,
    required int financialYearId,
    required String financialYearName,
  }) {
    _id.value = userId;
    _userNo.value = userNumber;
    _userDepartment.value = userDepartment;
    _userDepartmentName.value = userDepartmentName;
    _userType.value = userType;
    _lastTransactionSequence.value = lastTransactionSequence;
    _userName.value = userName;
    _userGroup.value = userGroup;
    _screenPermissions.value = screenPermissions ?? {};
    _canChangeBranch = canChangeBranch;

    // Record (default) branch/store from the synced user row.
    _defaultBranch.value = userBranch;
    _defaultBranchName.value = userBranchName;
    _defaultStoreNo.value = userStoreNo;
    _defaultStoreName.value = userStoreName;

    // Active starts equal to the default; applyBranchOverride() diverges them.
    _activeBranch.value = userBranch;
    _activeBranchName.value = userBranchName;
    _activeStoreNo.value = userStoreNo;
    _activeStoreName.value = userStoreName;
    _branchOverridden = false;

    _userBoxNo.value = userBoxNo;
    _userBoxName.value = userBoxName;
    _userBoxCurrencyNo.value = userBoxCurrencyNo;
    _userBoxCurrencySymbol.value = userBoxCurrencySymbol;

    _receiptBoxNo.value = receiptBoxNo;
    _receiptBoxName.value = receiptBoxName;
    _receiptBoxCurrencyNo.value = receiptBoxCurrencyNo;
    _receiptBoxCurrencySymbol.value = receiptBoxCurrencySymbol;

    _paymentBoxNo.value = paymentBoxNo;
    _paymentBoxName.value = paymentBoxName;
    _paymentBoxCurrencyNo.value = paymentBoxCurrencyNo;
    _paymentBoxCurrencySymbol.value = paymentBoxCurrencySymbol;

    _financialYearId.value = financialYearId;
    _financialYearName.value = financialYearName;
  }

  void clearUser() {
    _id.value = null;
    _userNo.value = null;
    _userDepartment.value = null;
    _userDepartmentName.value = null;
    _userType.value = null;
    _lastTransactionSequence.value = 0;
    _userName.value = null;
    _userGroup.value = '';
    _screenPermissions.value = {};
    _canChangeBranch = false;

    _defaultBranch.value = null;
    _defaultBranchName.value = null;
    _defaultStoreNo.value = null;
    _defaultStoreName.value = null;
    _activeBranch.value = null;
    _activeBranchName.value = null;
    _activeStoreNo.value = null;
    _activeStoreName.value = null;
    _branchOverridden = false;

    _userBoxNo.value = null;
    _userBoxName.value = null;
    _userBoxCurrencyNo.value = null;
    _userBoxCurrencySymbol.value = null;

    _receiptBoxNo.value = null;
    _receiptBoxName.value = null;
    _receiptBoxCurrencyNo.value = null;
    _receiptBoxCurrencySymbol.value = null;

    _paymentBoxNo.value = null;
    _paymentBoxName.value = null;
    _paymentBoxCurrencyNo.value = null;
    _paymentBoxCurrencySymbol.value = null;

    _financialYearId.value = null;
    _financialYearName.value = null;
  }

  bool get isLoggedIn => _id.value != null;

  bool canAccessScreen(String screenName) {
    if (isAdmin) return true;
    return _screenPermissions.value[screenName]?['access'] ?? false;
  }

  bool canAdd(String screenName) {
    if (isAdmin) return true;
    return _screenPermissions.value[screenName]?['add'] ?? false;
  }

  bool canEdit(String screenName) {
    if (isAdmin) return true;
    return _screenPermissions.value[screenName]?['edit'] ?? false;
  }

  bool canSearch(String screenName) {
    if (isAdmin) return true;
    return _screenPermissions.value[screenName]?['search'] ?? false;
  }

  bool canPrint(String screenName) {
    if (isAdmin) return true;
    return _screenPermissions.value[screenName]?['print'] ?? false;
  }

  bool canChangePrice(String screenName) {
    if (isAdmin) return true;
    return _screenPermissions.value[screenName]?['change_price'] ?? false;
  }

  void updateScreenPermissions(Map<String, Map<String, bool>> newPermissions) {
    _screenPermissions.value = newPermissions;
  }

  // ---------------------------------------------------------------------------
  // Branch override — the ONLY mutator of the active branch/store (D2).
  // Resolves the store that belongs to [branchId] and returns it so the caller
  // can pre-select the store dropdown. Box/currency/permission fields are never
  // touched here (D4).
  // ---------------------------------------------------------------------------
  Future<({int storeNo, String storeName})> applyBranchOverride(int branchId) async {
    if (!canSwitchBranch) {
      throw StateError('هذا المستخدم غير مصرح له بتغيير الفرع');
    }

    final db = await DatabaseHelper.instance.database;

    // 1. Validate the branch exists locally.
    final branchRes = await db.query(
      'sun_branches',
      columns: ['branch_id', 'branch_name'],
      where: 'branch_id = ?',
      whereArgs: [branchId],
    );
    if (branchRes.isEmpty) {
      throw StateError('الفرع المحدد غير موجود');
    }
    final String branchName = branchRes.first['branch_name'].toString();

    // 2. Resolve the store for this branch (D7).
    final stores = await db.query(
      'sun_store',
      columns: ['no_store', 'name_store'],
      where: 'branch_id = ?',
      whereArgs: [branchId],
    );
    if (stores.isEmpty) {
      throw BlockedBranchException('لا يوجد مخزن مرتبط بهذا الفرع');
    }

    int storeNo;
    String storeName;
    if (stores.length == 1) {
      storeNo = int.tryParse(stores.first['no_store'].toString()) ?? 0;
      storeName = stores.first['name_store'].toString();
    } else {
      // Prefer the user's default store if it belongs to this branch.
      final defaultStoreNo = _defaultStoreNo.value;
      final match = defaultStoreNo == null
          ? null
          : stores.firstWhereOrNull(
              (s) => int.tryParse(s['no_store'].toString()) == defaultStoreNo,
            );
      storeNo = int.tryParse((match ?? stores.first)['no_store'].toString()) ?? 0;
      storeName = (match ?? stores.first)['name_store'].toString();
    }

    // 3. Apply the override.
    _activeBranch.value = branchId;
    _activeBranchName.value = branchName;
    _activeStoreNo.value = storeNo;
    _activeStoreName.value = storeName;
    _branchOverridden = branchId != _defaultBranch.value;

    return (storeNo: storeNo, storeName: storeName);
  }
}