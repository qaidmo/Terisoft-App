import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sun_app_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onConfigure: _onConfigure,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE sun_users ADD COLUMN can_change_branch INTEGER NOT NULL DEFAULT 0;',
      );
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE sun_customers ADD COLUMN cost_data TEXT;');
      await db.execute('ALTER TABLE sun_customers ADD COLUMN cost_next REAL;');
      await db.execute('ALTER TABLE sun_customers ADD COLUMN cost_rsom REAL;');
      await db.execute('ALTER TABLE sales ADD COLUMN tra_srv REAL DEFAULT 0;');
      await db.execute('ALTER TABLE sale_items ADD COLUMN trad_tra_tax REAL DEFAULT 0;');
    }
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // --- [ دوال العمليات الأساسية CRUD & Sync ] ---

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await instance.database;
    return await db.insert(table, data);
  }

  Future<int> insertOrUpdate(String table, Map<String, dynamic> data, String pkColumn) async {
    final db = await instance.database;
    return await db.insert(
      table,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> queryAll(String table, {String? orderBy}) async {
    final db = await instance.database;
    return await db.query(table, orderBy: orderBy);
  }

  Future<List<Map<String, dynamic>>> query(
      String table, {
        String? where,
        List<dynamic>? whereArgs,
        List<String>? columns,
        String? orderBy,
      }) async {
    final db = await instance.database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      columns: columns,
      orderBy: orderBy,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await instance.database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> update(String table, Map<String, dynamic> data, String where, List<dynamic> whereArgs) async {
    final db = await instance.database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    final db = await instance.database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> clearTable(String table) async {
    final db = await instance.database;
    await db.delete(table);
  }

  // --- [ Sync Tracking Methods ] ---
  
  Future<String?> getLastSyncTime(String tableName) async {
    final db = await instance.database;
    final result = await db.query(
      'sync_tracking',
      columns: ['last_sync_time'],
      where: 'table_name = ?',
      whereArgs: [tableName],
    );
    if (result.isNotEmpty) {
      return result.first['last_sync_time'] as String?;
    }
    return null;
  }

  Future<void> updateSyncTime(String tableName, String syncTime) async {
    if (syncTime.isEmpty) return;
    final db = await instance.database;
    await db.insert(
      'sync_tracking',
      {'table_name': tableName, 'last_sync_time': syncTime},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- [ إنشاء الجداول ] ---

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sun_currencies (
        currency_no INTEGER PRIMARY KEY,
        currency_name TEXT NOT NULL,
        currency_fkah TEXT NOT NULL,
        currency_symbol TEXT NOT NULL,
        currency_rate REAL NOT NULL,
        currency_highest REAL NOT NULL,
        currency_lowest REAL NOT NULL,
        source_id TEXT UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_account_types (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        name_en TEXT,
        source_id TEXT UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_years (
        id INTEGER PRIMARY KEY, 
        year_name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        created_at TEXT,
        source_id TEXT UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_branches (
        branch_id INTEGER PRIMARY KEY,
        branch_name TEXT NOT NULL,
        created_at TEXT,
        source_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_pumps (
        m_no TEXT PRIMARY KEY,
        m_name TEXT,
        m_right REAL,
        date_m_right TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_departments (
        department_id INTEGER PRIMARY KEY,
        department_name TEXT NOT NULL,
        created_at TEXT,
        source_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE cost_centers (
        center_no INTEGER PRIMARY KEY AUTOINCREMENT,
        center_name TEXT NOT NULL,
        source_id TEXT UNIQUE,
        last_updated TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_main_groups (
        main_group_no TEXT PRIMARY KEY,
        main_group_name TEXT NOT NULL,
        source_id TEXT UNIQUE,
        created_at TEXT,
        last_updated TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_account_major_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_en TEXT,
        main_type_id INTEGER NOT NULL,
        source_id TEXT UNIQUE,
        last_updated TEXT,
        FOREIGN KEY (main_type_id) REFERENCES sun_account_types (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_account_classifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        name_en TEXT,
        major_type_id INTEGER NOT NULL,
        default_parent_account_id TEXT,
        source_id TEXT UNIQUE,
        FOREIGN KEY (major_type_id) REFERENCES sun_account_major_types (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_account (
        id TEXT PRIMARY KEY,
        created_at TEXT,
        account_number TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        parent_id TEXT,
        account_type_id INTEGER NOT NULL,
        nature TEXT NOT NULL,
        is_transactional INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        name_en TEXT,
        classification_id INTEGER,
        default_currency_id INTEGER,
        source_id TEXT UNIQUE,
        FOREIGN KEY (parent_id) REFERENCES sun_account (id),
        FOREIGN KEY (account_type_id) REFERENCES sun_account_types (id),
        FOREIGN KEY (default_currency_id) REFERENCES sun_currencies (currency_no),
        FOREIGN KEY (classification_id) REFERENCES sun_account_classifications (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_account_currencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id TEXT NOT NULL,
        currency_id INTEGER NOT NULL,
        FOREIGN KEY (account_id) REFERENCES sun_account (id) ON DELETE CASCADE,
        FOREIGN KEY (currency_id) REFERENCES sun_currencies (currency_no) ON DELETE CASCADE,
        UNIQUE(account_id, currency_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_boxes (
        box_no INTEGER PRIMARY KEY AUTOINCREMENT,
        box_name TEXT NOT NULL,
        account_id TEXT,
        source_id TEXT UNIQUE,
        control_account_id TEXT,
        FOREIGN KEY (account_id) REFERENCES sun_account (id),
        FOREIGN KEY (control_account_id) REFERENCES sun_account (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_box_currencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        box_no INTEGER NOT NULL,
        currency_id INTEGER NOT NULL,
        created_at TEXT,
        FOREIGN KEY (box_no) REFERENCES sun_boxes (box_no) ON DELETE CASCADE,
        FOREIGN KEY (currency_id) REFERENCES sun_currencies (currency_no) ON DELETE CASCADE,
        UNIQUE(box_no, currency_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_store (
        no_store INTEGER PRIMARY KEY,
        name_store TEXT NOT NULL,
        branch_id INTEGER,
        inventory_account_id TEXT,
        source_id TEXT UNIQUE,
        FOREIGN KEY (inventory_account_id) REFERENCES sun_account (id),
        FOREIGN KEY (branch_id) REFERENCES sun_branches (branch_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_no INTEGER NOT NULL UNIQUE,
        user_group TEXT NOT NULL UNIQUE,
        user_name TEXT NOT NULL,
        user_branch INTEGER NOT NULL,
        user_type TEXT NOT NULL,
        created_at TEXT,
        password_hash TEXT,
        transaction_sequence INTEGER DEFAULT 0,
        user_department INTEGER NOT NULL,
        user_status TEXT NOT NULL DEFAULT 'active',
        box_no INTEGER,
        no_store INTEGER,
        receipt_box_no INTEGER,
        payment_box_no INTEGER,
        can_change_branch INTEGER NOT NULL DEFAULT 0,
        source_id TEXT UNIQUE,
        modified_at TEXT,
        last_updated TEXT,
        FOREIGN KEY (box_no) REFERENCES sun_boxes (box_no),
        FOREIGN KEY (no_store) REFERENCES sun_store (no_store),
        FOREIGN KEY (user_department) REFERENCES sun_departments (department_id),
        FOREIGN KEY (user_branch) REFERENCES sun_branches (branch_id) ON DELETE SET NULL,
        FOREIGN KEY (receipt_box_no) REFERENCES sun_boxes (box_no),
        FOREIGN KEY (payment_box_no) REFERENCES sun_boxes (box_no)
        
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_customers (
        customer_no INTEGER PRIMARY KEY,
        customer_name TEXT NOT NULL,
        customer_foreign_name TEXT,
        phone_number TEXT,
        address TEXT,
        email TEXT,
        account_id TEXT,
        created_at TEXT,
        source_id TEXT UNIQUE,
        control_account_id TEXT,
        cost_data TEXT,
        cost_next REAL,
        cost_rsom REAL,
        last_updated TEXT,
        FOREIGN KEY (account_id) REFERENCES sun_account (id) ON DELETE SET NULL,
        FOREIGN KEY (control_account_id) REFERENCES sun_account (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sun_suppliers (
        supplier_no INTEGER PRIMARY KEY,
        supplier_name TEXT NOT NULL,
        supplier_foreign_name TEXT,
        phone_number TEXT,
        address TEXT,
        email TEXT,
        account_id TEXT,
        control_account_id TEXT,
        created_at TEXT,
        source_id TEXT UNIQUE,
        last_updated TEXT,
        FOREIGN KEY (account_id) REFERENCES sun_account (id) ON DELETE SET NULL,
        FOREIGN KEY (control_account_id) REFERENCES sun_account (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_customer_currencies (
        customer_no INTEGER NOT NULL,
        currency_no INTEGER NOT NULL,
        PRIMARY KEY (customer_no, currency_no),
        FOREIGN KEY (currency_no) REFERENCES sun_currencies (currency_no) ON DELETE CASCADE,
        FOREIGN KEY (customer_no) REFERENCES sun_customers (customer_no) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_salespeople (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        salesperson_no INTEGER NOT NULL UNIQUE,
        salesperson_name TEXT NOT NULL,
        phone_number TEXT,
        percentage REAL DEFAULT 0.00,
        commissions_disabled INTEGER NOT NULL DEFAULT 0,
        account_id TEXT,
        expense_account_id TEXT,
        created_at TEXT NOT NULL,
        source_id TEXT UNIQUE,
        last_updated TEXT,
        FOREIGN KEY (account_id) REFERENCES sun_account (id) ON DELETE SET NULL,
        FOREIGN KEY (expense_account_id) REFERENCES sun_account (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_collectors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        collector_no INTEGER NOT NULL UNIQUE,
        collector_name TEXT NOT NULL,
        phone_number TEXT,
        account_id TEXT,
        branch_id INTEGER,
        source_id TEXT UNIQUE,
        last_updated TEXT,
        FOREIGN KEY (account_id) REFERENCES sun_account (id) ON DELETE SET NULL,
        FOREIGN KEY (branch_id) REFERENCES sun_branches (branch_id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_item_groups (
        group_no TEXT PRIMARY KEY,
        group_name TEXT NOT NULL,
        created_at TEXT,
        last_item_sequence INTEGER DEFAULT 0,
        main_group_no TEXT,
        group_length INTEGER DEFAULT 3,
        source_id TEXT UNIQUE,
        last_updated TEXT,
        FOREIGN KEY (main_group_no) REFERENCES sun_main_groups (main_group_no)
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_items (
        item_no TEXT PRIMARY KEY,
        item_name TEXT NOT NULL,
        item_barcode TEXT,
        item_unit TEXT NOT NULL,
        item_price REAL NOT NULL,
        average_cost TEXT DEFAULT '0',
        section_no INTEGER, 
        item_group TEXT,
        cost_center TEXT,
        currency_no INTEGER NOT NULL,
        item_group_no TEXT,
        inventory_account_id TEXT,
        cogs_account_id TEXT,
        sales_revenue_account_id TEXT,
        sales_discount_account_id TEXT,
        is_taxable INTEGER DEFAULT 0,
        tax_rate REAL DEFAULT 0.00,
        cost_center_no INTEGER,
        discount_rate REAL,
        is_discountable INTEGER NOT NULL DEFAULT 0,
        is_cash_reserved INTEGER NOT NULL DEFAULT 0,
        categoryId TEXT,
        imageBase TEXT,
        last_updated TEXT,
        
        FOREIGN KEY (item_group_no) REFERENCES sun_item_groups (group_no) ON DELETE SET NULL,
        FOREIGN KEY (inventory_account_id) REFERENCES sun_account (id),
        FOREIGN KEY (cogs_account_id) REFERENCES sun_account (id),
        FOREIGN KEY (sales_revenue_account_id) REFERENCES sun_account (id),
        FOREIGN KEY (sales_discount_account_id) REFERENCES sun_account (id),
        FOREIGN KEY (cost_center_no) REFERENCES cost_centers (center_no) ON DELETE SET NULL,
        FOREIGN KEY (currency_no) REFERENCES sun_currencies (currency_no),
        FOREIGN KEY (section_no) REFERENCES sun_departments (department_id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_itemsize (
        unit_id TEXT PRIMARY KEY,
        item_no TEXT NOT NULL,
        unit_name TEXT NOT NULL,
        unit_index INTEGER NOT NULL,
        conversion_factor REAL DEFAULT 1.0,
        sale_price REAL DEFAULT 0.0,
        barcode TEXT,
        is_active INTEGER DEFAULT 1,
        last_updated TEXT,
        FOREIGN KEY (item_no) REFERENCES sun_items (item_no) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
  CREATE TABLE sun_stock (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_no TEXT NOT NULL,
    store_no INTEGER NOT NULL,
    branch_id INTEGER NOT NULL,
    batch_no TEXT NOT NULL DEFAULT '',
    expiry_date TEXT NOT NULL DEFAULT '',
    item_name TEXT,
    quantity REAL DEFAULT 0,
    last_updated_str TEXT,
    updated_at TEXT,
    cost_price REAL DEFAULT 0,
    
    UNIQUE(item_no, store_no, expiry_date, branch_id, batch_no),
    FOREIGN KEY (branch_id) REFERENCES sun_branches (branch_id) ON DELETE CASCADE,
    FOREIGN KEY (item_no) REFERENCES sun_items (item_no) ON DELETE CASCADE,
    FOREIGN KEY (store_no) REFERENCES sun_store (no_store) ON DELETE CASCADE
  )
''');

    await db.execute('''
      CREATE TABLE user_invoice_sequences (
        user_no INTEGER NOT NULL,
        invoice_type_char TEXT NOT NULL,
        last_sequence INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_no, invoice_type_char),
        FOREIGN KEY (user_no) REFERENCES sun_users (user_no) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
  CREATE TABLE sun_receipt (
    id INTEGER PRIMARY KEY AUTOINCREMENT, 
    guid TEXT UNIQUE,
    created_at TEXT NOT NULL,
    transaction_number TEXT NOT NULL,
    date TEXT NOT NULL,
    cash_box TEXT NOT NULL,
    currency TEXT NOT NULL,
    account_name TEXT NOT NULL,
    cost_center TEXT,
    description TEXT,
    total_amount REAL NOT NULL,
    amount_in_words TEXT,
    user_id INTEGER NOT NULL,
    invoice_type_char TEXT NOT NULL,
    invoice_type TEXT NOT NULL,
    collector_name TEXT,
    cost_center_no INTEGER,
    is_synced INTEGER NOT NULL DEFAULT 0,
    sun_year INTEGER,
    branch_id INTEGER,
    department_id INTEGER,
    collector_no INTEGER,
    source_last_updated_at TEXT,
    updated_at TEXT,
    UNIQUE(transaction_number, invoice_type_char),
    FOREIGN KEY (user_id) REFERENCES sun_users (user_no),
    FOREIGN KEY (collector_no) REFERENCES sun_collectors (collector_no),
    FOREIGN KEY (cost_center_no) REFERENCES cost_centers (center_no) ON DELETE SET NULL
  )
''');

    await db.execute('''
  CREATE TABLE receipt_payment_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    receipt_payment_id INTEGER NOT NULL,
    account_no TEXT NOT NULL,
    account_name TEXT NOT NULL,
    amount REAL NOT NULL,
    item_currency TEXT NOT NULL,
    exchange_rate REAL NOT NULL,
    equivalent_amount REAL NOT NULL,
    FOREIGN KEY (receipt_payment_id) REFERENCES sun_receipt (id) ON DELETE CASCADE
  )
''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        guid TEXT UNIQUE,
        transaction_number TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        currency TEXT NOT NULL,
        currency_id INTEGER,
        currency_rate REAL,
        customer_name TEXT,
        collector TEXT,
        sales_rep TEXT,
        total REAL NOT NULL,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        net_total REAL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        user_id INTEGER,
        invoice_type_char TEXT NOT NULL DEFAULT 'ن',
        invoice_type TEXT,
        account_no TEXT NOT NULL DEFAULT '',
        original_invoice_ref TEXT,
        box_no INTEGER,
        store_no INTEGER,
        collector_id INTEGER,
        agent_id INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        sun_year INTEGER,
        branch_id INTEGER,
        department_id INTEGER,
        source_last_updated_at TEXT,
        start_date TEXT,
        system_total_value REAL,
        tra_srv REAL DEFAULT 0,
        UNIQUE(transaction_number, invoice_type_char),
        FOREIGN KEY (collector_id) REFERENCES sun_collectors (id) ON DELETE SET NULL,
        FOREIGN KEY (box_no) REFERENCES sun_boxes (box_no) ON DELETE SET NULL,
        FOREIGN KEY (agent_id) REFERENCES sun_salespeople (id) ON DELETE SET NULL,
        FOREIGN KEY (store_no) REFERENCES sun_store (no_store) ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES sun_users (user_no)
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER,
        quantity REAL NOT NULL,
        total REAL NOT NULL,
        item_price REAL NOT NULL,
        cost_price REAL,
        item_discount REAL,
        item_no TEXT,
        item_unit TEXT DEFAULT '',
        pack_factor REAL DEFAULT 1.0,
        expiry_date TEXT,
        batch_no TEXT DEFAULT '',
        stock_balance REAL DEFAULT 0,
        created_at TEXT,
        bonus_quantity INTEGER,
        diff_quantity REAL,
        deficit_value REAL,
        surplus_value REAL,
        item_currency_id INTEGER DEFAULT 1,
        item_currency_rate REAL DEFAULT 1.0,
        pump_name TEXT,
        previous_reading REAL,
        current_reading REAL,
        trad_tra_tax REAL DEFAULT 0,
        FOREIGN KEY (item_no) REFERENCES sun_items (item_no),
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_general_ledger_postings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT,
        account_id TEXT NOT NULL,
        description TEXT,
        original_amount REAL NOT NULL,
        currency_id INTEGER NOT NULL,
        exchange_rate REAL NOT NULL,
        debit REAL DEFAULT 0,
        credit REAL DEFAULT 0,
        transaction_date TEXT NOT NULL,
        transaction_id INTEGER,
        transaction_type TEXT,
        transaction_ref TEXT,
        beneficiary_name TEXT,
        cost_center_no INTEGER,
        entity_name TEXT,
        FOREIGN KEY (cost_center_no) REFERENCES cost_centers (center_no) ON DELETE SET NULL,
        FOREIGN KEY (account_id) REFERENCES sun_account (id) ON DELETE RESTRICT,
        FOREIGN KEY (currency_id) REFERENCES sun_currencies (currency_no) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_display_name TEXT NOT NULL UNIQUE,
        screen_name_identifier TEXT NOT NULL UNIQUE,
        settings_json TEXT NOT NULL DEFAULT '{}', 
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        last_updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sun_permissions (
        permission_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_no INTEGER,
        screen_name TEXT NOT NULL,
        can_access INTEGER DEFAULT 0,
        can_add INTEGER DEFAULT 0,
        can_edit INTEGER DEFAULT 0,
        can_search INTEGER DEFAULT 0,
        can_print INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        can_change_price INTEGER DEFAULT 0,
        UNIQUE(user_no, screen_name),
        FOREIGN KEY (user_no) REFERENCES sun_users (user_no) ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_tracking (
        table_name TEXT PRIMARY KEY,
        last_sync_time TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE restaurant_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT NOT NULL UNIQUE,
        orderNumber TEXT,
        tableNumber TEXT,
        transactionDate TEXT NOT NULL,
        yearId TEXT NOT NULL,
        userId TEXT NOT NULL,
        userName TEXT,
        branchId TEXT,
        sectionId TEXT,
        storeId TEXT,
        storeName TEXT,
        currencyId TEXT,
        currencyName TEXT,
        currencyValue REAL DEFAULT 1.0,
        discount REAL DEFAULT 0.0,
        tax REAL DEFAULT 0.0,
        total REAL DEFAULT 0.0,
        netTotal REAL DEFAULT 0.0,
        orderTypeId TEXT DEFAULT '0',
        netTotalInWords TEXT,
        traLstId TEXT NOT NULL,
        traTitle TEXT,
        customerName TEXT,
        isNetworkPayment INTEGER DEFAULT 0,
        paidAmount REAL DEFAULT 0.0,
        boxId TEXT,
        boxName TEXT,
        boxNo TEXT,
        boxParentName TEXT,
        notes TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE restaurant_invoice_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        unit TEXT,
        quantity REAL NOT NULL DEFAULT 1.0,
        price REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL DEFAULT 0.0,
        notes TEXT,
        categoryName TEXT,
        discount REAL DEFAULT 0.0,
        tax REAL DEFAULT 0.0,
        FOREIGN KEY (invoiceNumber) REFERENCES restaurant_invoices (invoiceNumber) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_prints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tra_no TEXT NOT NULL,
        invoice_data TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Offline_ReportsCache (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        ReportType TEXT NOT NULL,
        EntityIdentifier TEXT NOT NULL,
        CurrencyId TEXT NOT NULL DEFAULT '',
        ParametersHash TEXT NOT NULL DEFAULT '',
        file_path TEXT NOT NULL,
        ledger_signature TEXT,
        LastSyncTimestamp TEXT NOT NULL,
        UNIQUE(ReportType, EntityIdentifier, CurrencyId, ParametersHash)
      )
    ''');

    await db.execute('''
      CREATE TABLE local_transaction_history (
        TransactionId TEXT PRIMARY KEY,
        TransactionNumber TEXT,
        ReferenceNumber TEXT,
        Date TEXT,
        Time TEXT,
        CustomerName TEXT,
        NetTotal REAL,
        UserName TEXT,
        TransactionTypeId TEXT,
        TransactionTypeName TEXT
      )
    ''');
  }
}