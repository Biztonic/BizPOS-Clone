// import 'dart:io'; // Removed for web compatibility
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:sqflite/sqflite.dart'; // Standard Sqflite
import 'package:path/path.dart';
import 'db_path.dart'; // Conditional Import
// Conditional Import for Shim
import 'db_shim.dart' if (dart.library.html) 'db_shim_web.dart';
import '../core/diagnostics/diagnostics_models.dart';
import '../core/diagnostics/diagnostics_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  // final SecurityService _security = SecurityService(); // Encryption Disabled

  DatabaseHelper._internal();

  static String? _currentUid;

  /// Closes the current database and sets the active user partition
  static Future<void> switchUser(String? uid) async {
    if (_currentUid == uid) return;

    if (_database != null) {
      if (_database!.isOpen) await _database!.close();
      _database = null;
    }

    _currentUid = uid;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static const int _version = 28;
  static int get version => _version;
  static String? _testDbName;
  @visibleForTesting
  static void setDbName(String? name) => _testDbName = name;

  Future<Database> _initDatabase() async {
    // Determine partitioned db name
    String baseName =
        _currentUid != null ? 'biztonic_$_currentUid.db' : 'biztonic.db';
    String webName = _currentUid != null
        ? 'biztonic_pos_$_currentUid.db'
        : 'biztonic_pos.db';

    // WEB INIT
    if (kIsWeb) {
      initWebDatabaseFactory(); // Uses Shim

      try {
        final db = await openDatabase(webName,
            version: _version, onCreate: _onCreate, onUpgrade: _onUpgrade);

        return db;
      } catch (e) {
        rethrow;
      }
    }

    // NATIVE INIT
    String path = await getDatabasePath(_testDbName ?? baseName);

    // Standard Open (No Encryption)
    return await openDatabase(
      path,
      version: _version,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Add support for cascading deletes
    try {
      await db.execute('PRAGMA foreign_keys = ON');
    } catch (e) {/* Error ignored */}

    // Enable Write-Ahead Logging (WAL) for concurrency
    // Use rawQuery because PRAGMA journal_mode returns a result row ('wal')
    // which causes execute() to throw "Queries can be performed using..." exception on some Android versions.
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL');
    } catch (e) {/* Error ignored */}

    // Tune synchronous mode for WAL (NORMAL is safe against application crashes and maximizes write throughput)
    try {
      await db.execute('PRAGMA synchronous = NORMAL');
    } catch (e) {/* Error ignored */}

    // Increase page cache size to ~8MB (negative number means KiB)
    try {
      await db.execute('PRAGMA cache_size = -8000');
    } catch (e) {/* Error ignored */}

    // Keep temp tables and indices in memory
    try {
      await db.execute('PRAGMA temp_store = MEMORY');
    } catch (e) {/* Error ignored */}

    // Increase busy timeout
    try {
      await db.execute('PRAGMA busy_timeout = 3000');
    } catch (e) {/* Error ignored */}
  }

  // MIGRATION HANDLER
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await DiagnosticsService().trace<void>(
      subsystem: DiagnosticSubsystem.migration,
      operationId: 'db_migration_${oldVersion}_to_$newVersion',
      actionName: 'SQLite Schema Migration v$oldVersion -> v$newVersion',
      metadata: {'oldVersion': oldVersion, 'newVersion': newVersion},
      customErrorClassifier: (_) => DiagnosticErrorCategory.migrationError,
      operation: () async {
        await _executeUpgradeSteps(db, oldVersion, newVersion);
      },
    );
  }

  Future<void> _executeUpgradeSteps(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db
            .execute("ALTER TABLE order_items ADD COLUMN seatIndex INTEGER");
      } catch (e) {/* Error ignored */}
    }

    if (oldVersion < 3) {
      try {
        // Orders
        await db.execute("ALTER TABLE orders ADD COLUMN updatedAt TEXT");
        await db.execute("ALTER TABLE orders ADD COLUMN deletedAt TEXT");
        await db.execute(
            "ALTER TABLE orders ADD COLUMN syncStatus TEXT DEFAULT 'PENDING'");
        await db.execute("ALTER TABLE orders ADD COLUMN deviceId TEXT");
        await db.execute("ALTER TABLE orders ADD COLUMN lastSyncedAt TEXT");

        // Inventory
        await db.execute("ALTER TABLE inventory ADD COLUMN updatedAt TEXT");
        await db.execute("ALTER TABLE inventory ADD COLUMN deletedAt TEXT");
        await db.execute(
            "ALTER TABLE inventory ADD COLUMN syncStatus TEXT DEFAULT 'PENDING'");
        await db.execute("ALTER TABLE inventory ADD COLUMN deviceId TEXT");
        await db.execute("ALTER TABLE inventory ADD COLUMN lastSyncedAt TEXT");

        // Customers
        await db.execute("ALTER TABLE customers ADD COLUMN updatedAt TEXT");
        await db.execute("ALTER TABLE customers ADD COLUMN deletedAt TEXT");
        await db.execute(
            "ALTER TABLE customers ADD COLUMN syncStatus TEXT DEFAULT 'PENDING'");
        await db.execute("ALTER TABLE customers ADD COLUMN deviceId TEXT");
        await db.execute("ALTER TABLE customers ADD COLUMN lastSyncedAt TEXT");
      } catch (e) {/* Error ignored */}
    }

    if (oldVersion < 4) {
      try {
        // Employees Table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS employees (
            id TEXT PRIMARY KEY,
            storeId TEXT,
            name TEXT,
            email TEXT,
            role TEXT,
            employeeId TEXT,
            pin TEXT,
            createdAt TEXT,
            updatedAt TEXT,
            deletedAt TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            deviceId TEXT,
            lastSyncedAt TEXT
          )
        ''');

        // Roles Table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS roles (
            id TEXT PRIMARY KEY,
            storeId TEXT,
            name TEXT,
            permissions TEXT,
            isSystem INTEGER DEFAULT 0,
            description TEXT,
            storeAccessMode TEXT DEFAULT 'single',
            createdAt TEXT,
            updatedAt TEXT,
            deletedAt TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            lastSyncedAt TEXT
          )
        ''');
      } catch (e) {/* Error ignored */}
    }

    if (oldVersion < 5) {
      try {
        // Inventory Movements Table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS inventory_movements (
            id TEXT PRIMARY KEY,
            itemId TEXT NOT NULL,
            storeId TEXT NOT NULL,
            type TEXT NOT NULL,
            delta INTEGER NOT NULL,
            orderId TEXT,
            reason TEXT,
            referenceNumber TEXT,
            cost REAL,
            deviceId TEXT,
            createdAt TEXT NOT NULL,
            syncStatus TEXT DEFAULT 'PENDING',
            syncedAt TEXT,
            FOREIGN KEY(itemId) REFERENCES inventory(id) ON DELETE CASCADE
          )
        ''');

        // Create indexes
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_movements_item ON inventory_movements(itemId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_movements_store ON inventory_movements(storeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_movements_sync ON inventory_movements(syncStatus)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_movements_created ON inventory_movements(createdAt)');

        // Migrate existing inventory quantities to movements
        final inventoryItems =
            await db.query('inventory', where: 'quantity > 0');
        for (var item in inventoryItems) {
          final movementId = 'MOV-MIGR-V5-${item['id']}';
          await db.insert(
            'inventory_movements',
            {
              'id': movementId,
              'itemId': item['id'],
              'storeId': item['storeId'],
              'type': 'INITIAL_STOCK',
              'delta': item['quantity'],
              'reason': 'Migration from v4 to v5',
              'deviceId': 'MIGRATION',
              'createdAt': DateTime.now().toIso8601String(),
              'syncStatus': 'SYNCED',
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      } catch (e) {/* Error ignored */}
    }

    if (oldVersion < 6) {
      try {
        // Add version column to tables if not exists
        await db
            .execute('ALTER TABLE orders ADD COLUMN version INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE inventory ADD COLUMN version INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE customers ADD COLUMN version INTEGER DEFAULT 1');
      } catch (e) {
        // Columns might already exist (e.g. if re-running migration), ignore specific error or log it
      }
    }

    if (oldVersion < 7) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cache_inventory_quantities (
            itemId TEXT PRIMARY KEY,
            storeId TEXT,
            quantity INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_cache_qty_store ON cache_inventory_quantities(storeId)');
      } catch (e) {/* Error ignored */}
    }
    if (oldVersion < 8) {
      try {
        await db.execute('''
            CREATE TABLE IF NOT EXISTS business_events (
              id TEXT PRIMARY KEY,
              storeId TEXT,
              entityType TEXT,
              entityId TEXT,
              eventType TEXT,
              amount REAL,
              quantity INTEGER,
              createdAt TEXT,
              deviceId TEXT,
              synced INTEGER DEFAULT 0,
              syncedAt TEXT
            )
          ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_events_store ON business_events(storeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_events_sync ON business_events(synced)');

        await db.execute('''
            CREATE TABLE IF NOT EXISTS monthly_order_counter (
              storeId TEXT,
              yearMonth TEXT,
              count INTEGER,
              PRIMARY KEY (storeId, yearMonth)
            )
          ''');

        await db.execute('''
             CREATE TABLE IF NOT EXISTS plan_tokens (
               storeId TEXT PRIMARY KEY,
               token TEXT,
               signature TEXT,
               validUntil TEXT
             )
          ''');
      } catch (e) {/* Error ignored */}
    }
    if (oldVersion < 9) {
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN businessDayId TEXT");
      } catch (e) {/* Error ignored */}
    }
    if (oldVersion < 10) {
      try {
        await db.execute(
            "ALTER TABLE orders ADD COLUMN taxRateSnapshot REAL DEFAULT 0.0");
        await db.execute(
            "ALTER TABLE orders ADD COLUMN discountSnapshot REAL DEFAULT 0.0");
      } catch (e) {/* Error ignored */}
    }
    if (oldVersion < 11) {
      try {
        await db.execute("ALTER TABLE orders ADD COLUMN voidedAt TEXT");
        await db.execute("ALTER TABLE orders ADD COLUMN voidedBy TEXT");
        await db.execute("ALTER TABLE orders ADD COLUMN voidReason TEXT");
        await db.execute("ALTER TABLE employees ADD COLUMN pinHash TEXT");
      } catch (e) {/* Error ignored */}
    }
    if (oldVersion < 12) {
      try {
        await db.execute("ALTER TABLE order_items ADD COLUMN category TEXT");
      } catch (e) {/* Error ignored */}
    }
    if (oldVersion < 13) {
      try {
        // Migration V13: Custom Low Stock Threshold
        // Default to 10 to maintain existing behavior
        await db.execute(
            "ALTER TABLE inventory ADD COLUMN lowStockThreshold INTEGER DEFAULT 10");
      } catch (e) {/* Error ignored */}
    }
    if (oldVersion < 14) {
      try {
        // Employee Enhancements
        await db.execute("ALTER TABLE employees ADD COLUMN permissions TEXT");
        await db.execute(
            "ALTER TABLE employees ADD COLUMN hourlyRate REAL DEFAULT 0.0");
        await db.execute(
            "ALTER TABLE employees ADD COLUMN monthlySalary REAL DEFAULT 0.0");

        // Attendance Table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS employee_attendance (
            id TEXT PRIMARY KEY,
            employeeId TEXT NOT NULL,
            storeId TEXT NOT NULL,
            checkIn TEXT NOT NULL,
            checkOut TEXT,
            location TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            updatedAt TEXT,
            FOREIGN KEY(employeeId) REFERENCES employees(id) ON DELETE CASCADE
          )
        ''');

        // Leaves Table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS employee_leaves (
            id TEXT PRIMARY KEY,
            employeeId TEXT NOT NULL,
            storeId TEXT NOT NULL,
            startDate TEXT NOT NULL,
            endDate TEXT NOT NULL,
            type TEXT NOT NULL,
            reason TEXT,
            status TEXT DEFAULT 'PENDING',
            syncStatus TEXT DEFAULT 'PENDING',
            updatedAt TEXT,
            FOREIGN KEY(employeeId) REFERENCES employees(id) ON DELETE CASCADE
          )
        ''');

        // Payroll Table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS employee_payroll (
            id TEXT PRIMARY KEY,
            employeeId TEXT NOT NULL,
            storeId TEXT NOT NULL,
            periodStart TEXT NOT NULL,
            periodEnd TEXT NOT NULL,
            baseAmount REAL DEFAULT 0.0,
            bonus REAL DEFAULT 0.0,
            deductions REAL DEFAULT 0.0,
            totalAmount REAL DEFAULT 0.0,
            status TEXT DEFAULT 'PENDING',
            syncStatus TEXT DEFAULT 'PENDING',
            updatedAt TEXT,
            FOREIGN KEY(employeeId) REFERENCES employees(id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_attr_emp ON employee_attendance(employeeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_leaves_emp ON employee_leaves(employeeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_payroll_emp ON employee_payroll(employeeId)');
      } catch (e) {/* Error ignored */}
    }

    if (oldVersion < 15) {
      try {
        // Migration V15: Missing Inventory Columns
        await db.execute("ALTER TABLE inventory ADD COLUMN dietaryType TEXT");
        await db.execute("ALTER TABLE inventory ADD COLUMN packagingType TEXT");
        await db
            .execute("ALTER TABLE inventory ADD COLUMN variantCategory TEXT");
        await db.execute(
            "ALTER TABLE inventory ADD COLUMN featured INTEGER DEFAULT 0");
      } catch (e) {/* Error ignored */}
    }

    if (oldVersion < 16) {
      try {
        // Migration V16: Offline JSON Blob Support for Configuration Entities
        await db.execute('''
          CREATE TABLE IF NOT EXISTS store_settings (
            storeId TEXT PRIMARY KEY,
            data TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            updatedAt TEXT,
            deletedAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS floors (
            id TEXT PRIMARY KEY,
            storeId TEXT,
            data TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            updatedAt TEXT,
            deletedAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS tables (
            id TEXT PRIMARY KEY,
            storeId TEXT,
            data TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            updatedAt TEXT,
            deletedAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS suppliers (
            id TEXT PRIMARY KEY,
            storeId TEXT,
            data TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            updatedAt TEXT,
            deletedAt TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS notes (
            id TEXT PRIMARY KEY,
            storeId TEXT,
            data TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            updatedAt TEXT,
            deletedAt TEXT
          )
        ''');

        // Note: No foreign keys for flexible offline sync caching
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_floors_store ON floors(storeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_tables_store ON tables(storeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_suppliers_store ON suppliers(storeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_notes_store ON notes(storeId)');
      } catch (e) {/* Error ignored */}
    }

    if (oldVersion < 17) {
      try {
        await db.execute(
            "ALTER TABLE order_items ADD COLUMN cost REAL DEFAULT 0.0");
      } catch (e) {/* Error ignored */}
    }

    if (oldVersion < 18) {
      try {
        await db.execute("ALTER TABLE inventory ADD COLUMN localImage TEXT");
      } catch (e) {/* Error ignored */}
    }

    // Migration V19: Local-First Sync State Machine
    // Adds `isDeleted` flag for explicit soft deletes (never physically delete unless CONFIRMED + isDeleted)
    // Adds missing `version` columns for conflict resolution
    if (oldVersion < 19) {
      try {
        // isDeleted columns (core entities)
        for (var table in ['orders', 'inventory', 'customers', 'employees']) {
          try {
            await db.execute(
                'ALTER TABLE $table ADD COLUMN isDeleted INTEGER DEFAULT 0');
          } catch (_) {}
        }
        // isDeleted columns (config entities)
        for (var table in [
          'floors',
          'tables',
          'suppliers',
          'notes',
          'store_settings'
        ]) {
          try {
            await db.execute(
                'ALTER TABLE $table ADD COLUMN isDeleted INTEGER DEFAULT 0');
          } catch (_) {}
        }
        // isDeleted columns (HR entities)
        for (var table in [
          'employee_attendance',
          'employee_leaves',
          'employee_payroll'
        ]) {
          try {
            await db.execute(
                'ALTER TABLE $table ADD COLUMN isDeleted INTEGER DEFAULT 0');
          } catch (_) {}
        }
        // isDeleted for inventory_movements
        try {
          await db.execute(
              'ALTER TABLE inventory_movements ADD COLUMN isDeleted INTEGER DEFAULT 0');
        } catch (_) {}

        // version columns for tables that were missing it
        for (var table in [
          'employees',
          'floors',
          'tables',
          'suppliers',
          'notes',
          'store_settings'
        ]) {
          try {
            await db.execute(
                'ALTER TABLE $table ADD COLUMN version INTEGER DEFAULT 1');
          } catch (_) {}
        }

        // lastSyncedAt for tables that were missing it
        for (var table in [
          'floors',
          'tables',
          'suppliers',
          'notes',
          'store_settings'
        ]) {
          try {
            await db.execute('ALTER TABLE $table ADD COLUMN lastSyncedAt TEXT');
          } catch (_) {}
        }

        // Migrate existing soft-deleted records: set isDeleted = 1 where deletedAt IS NOT NULL
        for (var table in [
          'orders',
          'inventory',
          'customers',
          'employees',
          'floors',
          'tables',
          'suppliers',
          'notes'
        ]) {
          try {
            await db.execute(
                "UPDATE $table SET isDeleted = 1 WHERE deletedAt IS NOT NULL");
          } catch (_) {}
        }

        // Create indexes for the new sync status queries
        try {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_orders_sync ON orders(syncStatus)');
        } catch (_) {}
        try {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_inventory_sync ON inventory(syncStatus)');
        } catch (_) {}
        try {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_customers_sync ON customers(syncStatus)');
        } catch (_) {}
        try {
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_employees_sync ON employees(syncStatus)');
        } catch (_) {}
      } catch (e) {/* Error ignored */}
    }

    // Migration V20: Performance Indexing for Core Tables
    if (oldVersion < 20) {
      try {
        // Orders Indexes
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_orders_store ON orders(storeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_orders_date ON orders(date)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(orderId)');

        // Core Entity Store Indexes
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_inventory_store ON inventory(storeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_customers_store ON customers(storeId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_employees_store ON employees(storeId)');

        // Sync Status Indexes (Ensuring they exist for all)
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_orders_sync ON orders(syncStatus)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_inventory_sync ON inventory(syncStatus)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_customers_sync ON customers(syncStatus)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_employees_sync ON employees(syncStatus)');
      } catch (e) {/* Error ignored */}
    }

    // Migration V21: Tax & Subtotal Columns for Orders
    if (oldVersion < 21) {
      try {
        await db
            .execute('ALTER TABLE orders ADD COLUMN subtotal REAL DEFAULT 0.0');
        await db.execute('ALTER TABLE orders ADD COLUMN cgst REAL DEFAULT 0.0');
        await db.execute('ALTER TABLE orders ADD COLUMN sgst REAL DEFAULT 0.0');
        await db.execute(
            'ALTER TABLE order_items ADD COLUMN cgst REAL DEFAULT 0.0');
        await db.execute(
            'ALTER TABLE order_items ADD COLUMN sgst REAL DEFAULT 0.0');
      } catch (e) {/* Error ignored */}
    }

    // Migration V22: Core Module Tables (Floors, Tables, Suppliers, Notes, Settings)
    // Ensures tables that were added to _onCreate in earlier versions are also created for existing users
    if (oldVersion < 22) {
      try {
        final tablesInfo = ['floors', 'tables', 'suppliers', 'notes'];
        for (var t in tablesInfo) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS $t (
              id TEXT PRIMARY KEY,
              storeId TEXT,
              data TEXT,
              syncStatus TEXT DEFAULT 'PENDING',
              updatedAt TEXT,
              deletedAt TEXT,
              version INTEGER DEFAULT 1,
              isDeleted INTEGER DEFAULT 0,
              lastSyncedAt TEXT
            )
          ''');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_${t}_store ON $t(storeId)');
        }

        await db.execute('''
          CREATE TABLE IF NOT EXISTS store_settings (
            storeId TEXT PRIMARY KEY,
            data TEXT,
            syncStatus TEXT DEFAULT 'PENDING',
            updatedAt TEXT,
            deletedAt TEXT,
            version INTEGER DEFAULT 1,
            isDeleted INTEGER DEFAULT 0,
            lastSyncedAt TEXT
          )
        ''');
      } catch (e) {/* Error ignored */}
    }

    // Migration V23: Tier 1 Platform Hardening (Idempotency & Transaction Journal)
    if (oldVersion < 23) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS idempotency_keys (
            key TEXT PRIMARY KEY,
            entityType TEXT,
            entityId TEXT,
            deviceId TEXT,
            createdAt TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_idem_created ON idempotency_keys(createdAt)');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS transaction_journal (
            id TEXT PRIMARY KEY,
            storeId TEXT,
            status TEXT,
            operations TEXT,
            createdAt TEXT,
            completedAt TEXT,
            error TEXT
          )
        ''');
      } catch (e) {/* Error ignored */}
    }

    // Migration V24: Authoritative Inventory Movement Ledger Integrity
    if (oldVersion < 24) {
      try {
        await db.execute(
            'ALTER TABLE inventory_movements ADD COLUMN operationId TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE inventory_movements ADD COLUMN unitCost REAL');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE inventory_movements ADD COLUMN version INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_movements_operation ON inventory_movements(storeId, operationId)');
      } catch (_) {}
    }

    // Migration V25: Durable Outbox & Conflict Tracking
    if (oldVersion < 25) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS outbox_operations (
            operationId TEXT PRIMARY KEY,
            storeId TEXT,
            userId TEXT,
            deviceId TEXT,
            collection TEXT,
            entityId TEXT,
            operation TEXT,
            payload TEXT,
            baseVersion INTEGER DEFAULT 1,
            newVersion INTEGER DEFAULT 1,
            createdAt INTEGER,
            attemptCount INTEGER DEFAULT 0,
            nextRetryAt INTEGER,
            state TEXT DEFAULT 'PENDING',
            lastError TEXT,
            auditMetadata TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_outbox_state ON outbox_operations(state, nextRetryAt)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_outbox_store ON outbox_operations(storeId)');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS conflict_records (
            id TEXT PRIMARY KEY,
            storeId TEXT,
            collection TEXT,
            entityId TEXT,
            conflictType TEXT,
            localData TEXT,
            cloudData TEXT,
            resolution TEXT,
            resolvedBy TEXT,
            createdAt TEXT,
            resolvedAt TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_conflict_store ON conflict_records(storeId)');

        // Ensure deletedBy column on soft-deletable tables
        for (var table in [
          'orders',
          'inventory',
          'customers',
          'employees',
          'floors',
          'tables',
          'suppliers',
          'notes',
          'store_settings'
        ]) {
          try {
            await db.execute('ALTER TABLE $table ADD COLUMN deletedBy TEXT');
          } catch (_) {}
        }
      } catch (e) {/* Error ignored */}
    }

    // Migration V26: Production-Grade Hardening (Uniqueness Constraints, Deduplication & Session Integrity)
    if (oldVersion < 26) {
      try {
        // 1. Deduplicate legacy employees by (storeId, employeeId) before creating unique index
        try {
          final dupEmployees = await db.rawQuery('''
            SELECT storeId, employeeId, COUNT(*) as count 
            FROM employees 
            WHERE employeeId IS NOT NULL AND employeeId != '' AND (isDeleted = 0 OR isDeleted IS NULL)
            GROUP BY storeId, employeeId 
            HAVING count > 1
          ''');

          for (var dup in dupEmployees) {
            final storeId = dup['storeId'];
            final employeeId = dup['employeeId'];
            final rows = await db.query(
              'employees',
              where: 'storeId = ? AND employeeId = ?',
              whereArgs: [storeId, employeeId],
              orderBy: 'updatedAt DESC, rowid DESC',
            );
            if (rows.length > 1) {
              for (int i = 1; i < rows.length; i++) {
                final dupId = rows[i]['id'] as String;
                await db.update(
                  'employees',
                  {
                    'isDeleted': 1,
                    'deletedAt': DateTime.now().toIso8601String(),
                    'employeeId': '${employeeId}_dup_${i}_${rows[i]['id']}',
                  },
                  where: 'id = ?',
                  whereArgs: [dupId],
                );
              }
            }
          }
        } catch (_) {}

        // 2. Create authoritative unique index on employees(storeId, employeeId)
        try {
          await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS uq_employees_store_emp_id 
            ON employees(storeId, employeeId) 
            WHERE employeeId IS NOT NULL AND employeeId != '' AND isDeleted = 0
          ''');
        } catch (_) {}

        // 3. Deduplicate legacy inventory_movements by (storeId, operationId) before creating unique index
        try {
          final dupMovements = await db.rawQuery('''
            SELECT storeId, operationId, COUNT(*) as count 
            FROM inventory_movements 
            WHERE operationId IS NOT NULL AND operationId != ''
            GROUP BY storeId, operationId 
            HAVING count > 1
          ''');

          for (var dup in dupMovements) {
            final storeId = dup['storeId'];
            final opId = dup['operationId'];
            final rows = await db.query(
              'inventory_movements',
              where: 'storeId = ? AND operationId = ?',
              whereArgs: [storeId, opId],
              orderBy: 'createdAt ASC, rowid ASC',
            );
            if (rows.length > 1) {
              for (int i = 1; i < rows.length; i++) {
                final dupRowId = rows[i]['id'] as String;
                await db.delete(
                  'inventory_movements',
                  where: 'id = ?',
                  whereArgs: [dupRowId],
                );
              }
            }
          }
        } catch (_) {}

        // 4. Create authoritative unique index on inventory_movements(storeId, operationId)
        try {
          await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS uq_movements_store_operation 
            ON inventory_movements(storeId, operationId) 
            WHERE operationId IS NOT NULL AND operationId != ''
          ''');
        } catch (_) {}

        // 5. Create business_days table (Enforcing store + business date uniqueness)
        await db.execute('''
          CREATE TABLE IF NOT EXISTS business_days (
            id TEXT PRIMARY KEY,
            storeId TEXT NOT NULL,
            businessDate TEXT NOT NULL,
            status TEXT DEFAULT 'OPEN',
            openedAt TEXT,
            closedAt TEXT,
            totalSales REAL DEFAULT 0.0,
            orderCount INTEGER DEFAULT 0,
            UNIQUE(storeId, businessDate)
          )
        ''');

        // 6. Create daily_order_counter table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_order_counter (
            storeId TEXT NOT NULL,
            businessDate TEXT NOT NULL,
            count INTEGER DEFAULT 0,
            PRIMARY KEY (storeId, businessDate)
          )
        ''');

        // 7. Indexes for performance & query isolation
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_orders_business_day ON orders(storeId, businessDayId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_journal_status ON transaction_journal(status)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_journal_store ON transaction_journal(storeId)');

        // 8. Ensure version and soft-delete columns on all core tables
        for (var table in [
          'orders',
          'inventory',
          'customers',
          'employees',
          'roles',
          'floors',
          'tables',
          'suppliers',
          'notes',
          'store_settings'
        ]) {
          try {
            await db.execute(
                'ALTER TABLE $table ADD COLUMN version INTEGER DEFAULT 1');
          } catch (_) {}
          try {
            await db.execute(
                'ALTER TABLE $table ADD COLUMN isDeleted INTEGER DEFAULT 0');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE $table ADD COLUMN deletedBy TEXT');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE $table ADD COLUMN lastSyncedAt TEXT');
          } catch (_) {}
        }
      } catch (e) {/* Error ignored */}
    }

    // Migration V27: Enterprise POS Scale & Performance Optimization (Covering & Composite Indexes)
    if (oldVersion < 27) {
      try {
        // 1. Keyset pagination on orders (storeId, isDeleted, date DESC, id DESC)
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_orders_store_date_id ON orders(storeId, isDeleted, date DESC, id DESC)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_orders_store_status ON orders(storeId, status, isDeleted)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_orders_store_sync ON orders(storeId, syncStatus)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(storeId, customerPhone, isDeleted)');

        // 2. High-speed inventory lookup & barcode scanning
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_inventory_store_cat ON inventory(storeId, isDeleted, category)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_inventory_store_sku ON inventory(storeId, sku)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_inventory_store_name ON inventory(storeId, name)');

        // 3. Customer lookup by phone/mobile/name
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_customers_store_phone ON customers(storeId, isDeleted, phone)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_customers_store_mobile ON customers(storeId, isDeleted, mobile)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_customers_store_name ON customers(storeId, isDeleted, name)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_customers_store_id ON customers(storeId, isDeleted, id ASC)');

        // 4. Inventory movements & refund validation speedup
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_movements_store_item_created ON inventory_movements(storeId, itemId, createdAt DESC)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_movements_refund_check ON inventory_movements(storeId, orderId, itemId, type, isDeleted)');

        // 5. Outbox & Business Events composite dispatch indexes
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_outbox_store_state_retry ON outbox_operations(storeId, state, nextRetryAt)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_events_store_created ON business_events(storeId, createdAt DESC)');
      } catch (e) {/* Error ignored */}
    }

    // Migration V28: Customer Udhari & Credit Limit Columns
    if (oldVersion < 28) {
      try {
        await db.execute(
            'ALTER TABLE customers ADD COLUMN udhariBalance REAL DEFAULT 0.0');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE customers ADD COLUMN creditLimit REAL DEFAULT 0.0');
      } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Orders Table
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        total REAL,
        discount REAL,
        date TEXT,
        status TEXT,
        type TEXT,
        paymentMethod TEXT,
        customerName TEXT,
        customerPhone TEXT,
        tableId TEXT,
        tableName TEXT,
        synced INTEGER DEFAULT 0,
        updatedAt TEXT,
        deletedAt TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        deviceId TEXT,
        lastSyncedAt TEXT,
        version INTEGER DEFAULT 1,
        isDeleted INTEGER DEFAULT 0,
        businessDayId TEXT,
        taxRateSnapshot REAL DEFAULT 0.0,
        discountSnapshot REAL DEFAULT 0.0,
        subtotal REAL DEFAULT 0.0,
        cgst REAL DEFAULT 0.0,
        sgst REAL DEFAULT 0.0,
        voidedAt TEXT,
        voidedBy TEXT,
        voidReason TEXT
      )
    ''');

    // 1.5 Cache Table for Quantities (Ephemeral, derived from Movements)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_inventory_quantities (
        itemId TEXT PRIMARY KEY,
        storeId TEXT,
        quantity INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cache_qty_store ON cache_inventory_quantities(storeId)');

    // 2. Order Items Table
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId TEXT,
        itemId TEXT,
        name TEXT,
        price REAL,
        quantity INTEGER,
        note TEXT,
        seatIndex INTEGER, -- Added in v2
        category TEXT, -- Added in v12
        cost REAL, -- Added in v17
        cgst REAL DEFAULT 0.0, -- Added in v21
        sgst REAL DEFAULT 0.0, -- Added in v21
        FOREIGN KEY(orderId) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    // 3. Inventory / Products Table
    await db.execute('''
      CREATE TABLE inventory (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        name TEXT,
        category TEXT,
        price REAL,
        quantity INTEGER,
        status TEXT,
        image TEXT,
        sku TEXT,
        cost REAL,
        unit TEXT,
        expiryDate TEXT,
        trackStock INTEGER, -- Boolean stored as 0/1
        centralItemId TEXT,
        storeType TEXT,
        dietaryType TEXT,
        packagingType TEXT,
        variantCategory TEXT,
        featured INTEGER DEFAULT 0,
        updatedAt TEXT,
        deletedAt TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        deviceId TEXT,
        lastSyncedAt TEXT,
        version INTEGER DEFAULT 1,
        isDeleted INTEGER DEFAULT 0,
        deletedBy TEXT,
        lowStockThreshold INTEGER DEFAULT 10,
        localImage TEXT
      )
    ''');

    // 4. Customers Table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        name TEXT,
        email TEXT,
        mobile TEXT,
        phone TEXT,
        whatsapp TEXT,
        taxNumber TEXT,
        billingAddress TEXT,
        shippingAddress TEXT,
        avatar TEXT,
        joinDate TEXT,
        totalSpent REAL,
        loyaltyPoints INTEGER,
        tier TEXT,
        visitCount INTEGER,
        lastVisit TEXT,
        updatedAt TEXT,
        deletedAt TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        deviceId TEXT,
        lastSyncedAt TEXT,
        version INTEGER DEFAULT 1,
        udhariBalance REAL DEFAULT 0.0,
        creditLimit REAL DEFAULT 0.0,
        isDeleted INTEGER DEFAULT 0,
        deletedBy TEXT
      )
    ''');

    // 5. Employees Table
    await db.execute('''
      CREATE TABLE employees (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        name TEXT,
        email TEXT,
        role TEXT,
        employeeId TEXT,
        pinHash TEXT,
        permissions TEXT,
        hourlyRate REAL DEFAULT 0.0,
        monthlySalary REAL DEFAULT 0.0,
        createdAt TEXT,
        updatedAt TEXT,
        deletedAt TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        deviceId TEXT,
        lastSyncedAt TEXT,
        version INTEGER DEFAULT 1,
        isDeleted INTEGER DEFAULT 0
      )
    ''');

    // 5.5 Attendance Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_attendance (
        id TEXT PRIMARY KEY,
        employeeId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        checkIn TEXT NOT NULL,
        checkOut TEXT,
        location TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        updatedAt TEXT,
        FOREIGN KEY(employeeId) REFERENCES employees(id) ON DELETE CASCADE
      )
    ''');

    // 5.6 Leaves Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_leaves (
        id TEXT PRIMARY KEY,
        employeeId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        type TEXT NOT NULL,
        reason TEXT,
        status TEXT DEFAULT 'PENDING',
        syncStatus TEXT DEFAULT 'PENDING',
        updatedAt TEXT,
        FOREIGN KEY(employeeId) REFERENCES employees(id) ON DELETE CASCADE
      )
    ''');

    // 5.7 Payroll Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_payroll (
        id TEXT PRIMARY KEY,
        employeeId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        periodStart TEXT NOT NULL,
        periodEnd TEXT NOT NULL,
        baseAmount REAL DEFAULT 0.0,
        bonus REAL DEFAULT 0.0,
        deductions REAL DEFAULT 0.0,
        totalAmount REAL DEFAULT 0.0,
        status TEXT DEFAULT 'PENDING',
        syncStatus TEXT DEFAULT 'PENDING',
        updatedAt TEXT,
        FOREIGN KEY(employeeId) REFERENCES employees(id) ON DELETE CASCADE
      )
    ''');

    // 6. Roles Table
    await db.execute('''
      CREATE TABLE roles (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        name TEXT,
        permissions TEXT,
        isSystem INTEGER DEFAULT 0,
        description TEXT,
        storeAccessMode TEXT DEFAULT 'single',
        createdAt TEXT,
        updatedAt TEXT,
        deletedAt TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        lastSyncedAt TEXT
      )
    ''');

    // 7. Inventory Movements Table (Event Sourcing)
    await db.execute('''
      CREATE TABLE inventory_movements (
        id TEXT PRIMARY KEY,
        itemId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        type TEXT NOT NULL,
        delta INTEGER NOT NULL,
        orderId TEXT,
        reason TEXT,
        referenceNumber TEXT,
        cost REAL,
        unitCost REAL,
        deviceId TEXT,
        operationId TEXT,
        createdAt TEXT NOT NULL,
        version INTEGER DEFAULT 1,
        syncStatus TEXT DEFAULT 'PENDING',
        syncedAt TEXT,
        isDeleted INTEGER DEFAULT 0,
        FOREIGN KEY(itemId) REFERENCES inventory(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_orders_store ON orders(storeId)');
    await db.execute('CREATE INDEX idx_orders_date ON orders(date)');
    await db.execute('CREATE INDEX idx_orders_sync ON orders(syncStatus)');
    await db
        .execute('CREATE INDEX idx_order_items_order ON order_items(orderId)');

    await db.execute('CREATE INDEX idx_inventory_store ON inventory(storeId)');
    await db
        .execute('CREATE INDEX idx_inventory_sync ON inventory(syncStatus)');

    await db.execute('CREATE INDEX idx_customers_store ON customers(storeId)');
    await db
        .execute('CREATE INDEX idx_customers_sync ON customers(syncStatus)');

    await db.execute('CREATE INDEX idx_employees_store ON employees(storeId)');
    await db
        .execute('CREATE INDEX idx_employees_sync ON employees(syncStatus)');

    await db.execute(
        'CREATE INDEX idx_movements_item ON inventory_movements(itemId)');
    await db.execute(
        'CREATE INDEX idx_movements_store ON inventory_movements(storeId)');
    await db.execute(
        'CREATE INDEX idx_movements_sync ON inventory_movements(syncStatus)');
    await db.execute(
        'CREATE INDEX idx_movements_created ON inventory_movements(createdAt)');
    await db.execute(
        'CREATE INDEX idx_movements_operation ON inventory_movements(storeId, operationId)');
    await db.execute(
        'CREATE INDEX idx_attr_emp ON employee_attendance(employeeId)');
    await db
        .execute('CREATE INDEX idx_leaves_emp ON employee_leaves(employeeId)');
    await db.execute(
        'CREATE INDEX idx_payroll_emp ON employee_payroll(employeeId)');

    // 8. Business Ledger (Enterprise)
    await db.execute('''
      CREATE TABLE business_events (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        entityType TEXT,
        entityId TEXT,
        eventType TEXT,
        amount REAL,
        quantity INTEGER,
        createdAt TEXT,
        deviceId TEXT,
        synced INTEGER DEFAULT 0,
        syncedAt TEXT
      )
    ''');
    await db
        .execute('CREATE INDEX idx_events_store ON business_events(storeId)');
    await db.execute('CREATE INDEX idx_events_sync ON business_events(synced)');

    // 9. Monthly Order Counter (Token Enforcement)
    await db.execute('''
      CREATE TABLE monthly_order_counter (
        storeId TEXT,
        yearMonth TEXT,
        count INTEGER,
        PRIMARY KEY (storeId, yearMonth)
      )
    ''');

    // 10. Plan Tokens (Security)
    await db.execute('''
       CREATE TABLE plan_tokens (
         storeId TEXT PRIMARY KEY,
         token TEXT,
         signature TEXT,
         validUntil TEXT
       )
    ''');

    // 11. Offline Config Entities (JSON Blobs)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS store_settings (
        storeId TEXT PRIMARY KEY,
        data TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        updatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        isDeleted INTEGER DEFAULT 0,
        lastSyncedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS floors (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        data TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        updatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        isDeleted INTEGER DEFAULT 0,
        lastSyncedAt TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_floors_store ON floors(storeId)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tables (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        data TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        updatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        isDeleted INTEGER DEFAULT 0,
        lastSyncedAt TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tables_store ON tables(storeId)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        data TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        updatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        isDeleted INTEGER DEFAULT 0,
        lastSyncedAt TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_suppliers_store ON suppliers(storeId)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        data TEXT,
        syncStatus TEXT DEFAULT 'PENDING',
        updatedAt TEXT,
        deletedAt TEXT,
        version INTEGER DEFAULT 1,
        isDeleted INTEGER DEFAULT 0,
        lastSyncedAt TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_store ON notes(storeId)');

    // 12. Idempotency & Transactions (Tier 1 Platform Hardening)
    await db.execute('''
      CREATE TABLE idempotency_keys (
        key TEXT PRIMARY KEY,
        entityType TEXT,
        entityId TEXT,
        deviceId TEXT,
        createdAt TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_idem_created ON idempotency_keys(createdAt)');

    await db.execute('''
      CREATE TABLE transaction_journal (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        status TEXT,
        operations TEXT,
        createdAt TEXT,
        completedAt TEXT,
        error TEXT
      )
    ''');

    // 13. Durable Outbox & Conflict Tracking
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox_operations (
        operationId TEXT PRIMARY KEY,
        storeId TEXT,
        userId TEXT,
        deviceId TEXT,
        collection TEXT,
        entityId TEXT,
        operation TEXT,
        payload TEXT,
        baseVersion INTEGER DEFAULT 1,
        newVersion INTEGER DEFAULT 1,
        createdAt INTEGER,
        attemptCount INTEGER DEFAULT 0,
        nextRetryAt INTEGER,
        state TEXT DEFAULT 'PENDING',
        lastError TEXT,
        auditMetadata TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_outbox_state ON outbox_operations(state, nextRetryAt)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_outbox_store ON outbox_operations(storeId)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS conflict_records (
        id TEXT PRIMARY KEY,
        storeId TEXT,
        collection TEXT,
        entityId TEXT,
        conflictType TEXT,
        localData TEXT,
        cloudData TEXT,
        resolution TEXT,
        resolvedBy TEXT,
        createdAt TEXT,
        resolvedAt TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_conflict_store ON conflict_records(storeId)');

    // 14. Business Days & Daily Counters (Session & Operational Hardening)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_days (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        businessDate TEXT NOT NULL,
        status TEXT DEFAULT 'OPEN',
        openedAt TEXT,
        closedAt TEXT,
        totalSales REAL DEFAULT 0.0,
        orderCount INTEGER DEFAULT 0,
        UNIQUE(storeId, businessDate)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_order_counter (
        storeId TEXT NOT NULL,
        businessDate TEXT NOT NULL,
        count INTEGER DEFAULT 0,
        PRIMARY KEY (storeId, businessDate)
      )
    ''');

    // 15. Authoritative Business-Critical Unique Indexes & Query Indexes
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_employees_store_emp_id 
      ON employees(storeId, employeeId) 
      WHERE employeeId IS NOT NULL AND employeeId != '' AND isDeleted = 0
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS uq_movements_store_operation 
      ON inventory_movements(storeId, operationId) 
      WHERE operationId IS NOT NULL AND operationId != ''
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_business_day ON orders(storeId, businessDayId)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_journal_status ON transaction_journal(status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_journal_store ON transaction_journal(storeId)');

    // High-performance composite indexes for enterprise POS scale
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_store_date_id ON orders(storeId, isDeleted, date DESC, id DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_store_status ON orders(storeId, status, isDeleted)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_store_sync ON orders(storeId, syncStatus)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(storeId, customerPhone, isDeleted)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_store_cat ON inventory(storeId, isDeleted, category)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_store_sku ON inventory(storeId, sku)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_inventory_store_name ON inventory(storeId, name)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_store_phone ON customers(storeId, isDeleted, phone)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_store_mobile ON customers(storeId, isDeleted, mobile)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_store_name ON customers(storeId, isDeleted, name)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_customers_store_id ON customers(storeId, isDeleted, id ASC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_movements_store_item_created ON inventory_movements(storeId, itemId, createdAt DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_movements_refund_check ON inventory_movements(storeId, orderId, itemId, type, isDeleted)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_outbox_store_state_retry ON outbox_operations(storeId, state, nextRetryAt)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_events_store_created ON business_events(storeId, createdAt DESC)');
  }

  // --- Helper Methods ---

  /// Generic count method for O(1) record counting
  Future<int> count(String table,
      {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table ${where != null ? 'WHERE $where' : ''}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Clear All Tables (For Full Sync)
  Future<void> clearAll() async {
    final db = await database;
    final tables = [
      'order_items',
      'orders',
      'inventory',
      'customers',
      'employees',
      'roles',
      'store_settings',
      'floors',
      'tables',
      'suppliers',
      'notes',
      'inventory_movements',
      'cache_inventory_quantities',
      'business_events',
      'employee_attendance',
      'employee_leaves',
      'employee_payroll',
      'business_days',
      'daily_order_counter',
      'expense_categories',
      'expenses',
      'payment_methods',
      'activity_logs',
      'idempotency_keys',
      'transaction_journal',
      'outbox_operations',
      'conflict_records'
    ];

    for (var table in tables) {
      try {
        await db.delete(table);
      } catch (e) {
        debugPrint("Could not clear table $table: $e");
      }
    }
  }

  @visibleForTesting
  Future<void> close() async {
    if (_database != null) {
      if (_database!.isOpen) {
        await _database!.close();
      }
      _database = null;
    }
    _testDbName = null;
  }

  // FORCE RESET (Panic Button)
  Future<void> nukeDatabase() async {
    try {
      await close();

      String path;
      if (kIsWeb) {
        path = 'biztonic_pos.db';
      } else {
        path = join(await getDatabasesPath(), _testDbName ?? 'biztonic.db');
      }

      await deleteDatabase(path);
    } catch (e) {
      rethrow;
    }
  }
}
