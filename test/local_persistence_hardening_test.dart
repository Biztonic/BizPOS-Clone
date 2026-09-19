import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/recovery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp
        .createTempSync('biztonic_local_persistence_test_')
        .path;
  });

  tearDown(() async {
    await DatabaseHelper().close();
    try {
      Directory(tempDir).deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Local Persistence Hardening Tests', () {
    test(
        '1. Fresh Database Creation (v26): All 25 Tables, Indexes, and Constraints',
        () async {
      final dbPath = p.join(tempDir, 'fresh_v26.db');
      DatabaseHelper.setDbName(dbPath);

      final db = await DatabaseHelper().database;
      expect(await db.getVersion(), 26);

      // Verify all tables exist
      final tablesRes = await db.query(
        'sqlite_master',
        where: "type = 'table' AND name NOT LIKE 'sqlite_%'",
      );
      final tableNames = tablesRes.map((r) => r['name'] as String).toSet();

      final requiredTables = [
        'orders',
        'order_items',
        'inventory',
        'cache_inventory_quantities',
        'customers',
        'employees',
        'employee_attendance',
        'employee_leaves',
        'employee_payroll',
        'roles',
        'inventory_movements',
        'business_events',
        'monthly_order_counter',
        'plan_tokens',
        'store_settings',
        'floors',
        'tables',
        'suppliers',
        'notes',
        'idempotency_keys',
        'transaction_journal',
        'outbox_operations',
        'conflict_records',
        'business_days',
        'daily_order_counter',
      ];

      for (var table in requiredTables) {
        expect(tableNames, contains(table),
            reason: 'Table $table must exist in fresh v26 schema');
      }

      // Verify unique indexes
      final indexesRes = await db.query(
        'sqlite_master',
        where: "type = 'index'",
      );
      final indexNames = indexesRes.map((r) => r['name'] as String).toSet();

      expect(indexNames, contains('uq_employees_store_emp_id'),
          reason: 'Unique index on employees(storeId, employeeId) must exist');
      expect(indexNames, contains('uq_movements_store_operation'),
          reason:
              'Unique index on inventory_movements(storeId, operationId) must exist');
      expect(indexNames, contains('idx_orders_business_day'));
      expect(indexNames, contains('idx_journal_status'));
      expect(indexNames, contains('idx_journal_store'));
    });

    test(
        '2. Deterministic Historical Migration: v1 -> v26 with Data Preservation',
        () async {
      final dbPath = p.join(tempDir, 'migr_v1_to_v26.db');

      // 1. Build initial v1 database
      final v1Db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
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
              synced INTEGER DEFAULT 0
            )
          ''');

          await db.execute('''
            CREATE TABLE order_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              orderId TEXT,
              itemId TEXT,
              name TEXT,
              price REAL,
              quantity INTEGER,
              note TEXT
            )
          ''');

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
              trackStock INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE customers (
              id TEXT PRIMARY KEY,
              storeId TEXT,
              name TEXT,
              email TEXT,
              mobile TEXT,
              phone TEXT,
              totalSpent REAL,
              loyaltyPoints INTEGER
            )
          ''');
        },
      );

      // Seed v1 Data
      await v1Db.insert('orders', {
        'id': 'ORD_HIST_001',
        'storeId': 'STORE_V1',
        'total': 250.0,
        'discount': 10.0,
        'date': '2025-01-01T10:00:00.000',
        'status': 'Completed',
        'type': 'Dine-In',
        'paymentMethod': 'Cash',
        'customerName': 'Historic Customer',
      });

      await v1Db.insert('order_items', {
        'orderId': 'ORD_HIST_001',
        'itemId': 'ITEM_HIST_001',
        'name': 'Heritage Burger',
        'price': 125.0,
        'quantity': 2,
      });

      await v1Db.insert('inventory', {
        'id': 'ITEM_HIST_001',
        'storeId': 'STORE_V1',
        'name': 'Heritage Burger',
        'category': 'Food',
        'price': 125.0,
        'quantity': 42,
        'status': 'In Stock',
        'trackStock': 1,
      });

      await v1Db.insert('customers', {
        'id': 'CUST_HIST_001',
        'storeId': 'STORE_V1',
        'name': 'Alice Historic',
        'totalSpent': 250.0,
        'loyaltyPoints': 25,
      });

      await v1Db.close();

      // 2. Open via DatabaseHelper to trigger migration pipeline v1 -> v26
      DatabaseHelper.setDbName(dbPath);
      final upgradedDb = await DatabaseHelper().database;
      expect(await upgradedDb.getVersion(), 26);

      // Verify existing data preserved
      final orders = await upgradedDb
          .query('orders', where: 'id = ?', whereArgs: ['ORD_HIST_001']);
      expect(orders.length, 1);
      expect(orders.first['total'], 250.0);
      expect(orders.first['version'], 1);
      expect(orders.first['isDeleted'], 0);
      expect(orders.first['syncStatus'], 'PENDING');

      final items = await upgradedDb.query('order_items',
          where: 'orderId = ?', whereArgs: ['ORD_HIST_001']);
      expect(items.length, 1);
      expect(items.first['name'], 'Heritage Burger');

      final inventory = await upgradedDb
          .query('inventory', where: 'id = ?', whereArgs: ['ITEM_HIST_001']);
      expect(inventory.length, 1);
      expect(inventory.first['quantity'], 42);

      // Verify deterministic v5 movement migration ran
      final movements = await upgradedDb.query('inventory_movements',
          where: 'id = ?', whereArgs: ['MOV-MIGR-V5-ITEM_HIST_001']);
      expect(movements.length, 1);
      expect(movements.first['delta'], 42);
      expect(movements.first['type'], 'INITIAL_STOCK');

      // Verify new v26 tables exist and are ready
      expect(await upgradedDb.query('business_days'), isEmpty);
      expect(await upgradedDb.query('daily_order_counter'), isEmpty);
    });

    test('3. Historical Intermediate Migrations: v8 -> v26 and v19 -> v26',
        () async {
      final dbPath = p.join(tempDir, 'migr_v19_to_v26.db');

      // Create v19 schema database
      final v19Db = await openDatabase(
        dbPath,
        version: 19,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE orders (
              id TEXT PRIMARY KEY,
              storeId TEXT,
              total REAL,
              date TEXT,
              status TEXT,
              version INTEGER DEFAULT 1,
              isDeleted INTEGER DEFAULT 0,
              deletedAt TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE inventory (
              id TEXT PRIMARY KEY,
              storeId TEXT,
              name TEXT,
              quantity INTEGER,
              version INTEGER DEFAULT 1,
              isDeleted INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE employees (
              id TEXT PRIMARY KEY,
              storeId TEXT,
              name TEXT,
              employeeId TEXT,
              version INTEGER DEFAULT 1,
              isDeleted INTEGER DEFAULT 0
            )
          ''');
        },
      );

      await v19Db.insert('orders', {
        'id': 'ORD_V19',
        'storeId': 'STORE_V19',
        'total': 99.0,
        'date': '2025-06-01',
        'status': 'Completed',
        'isDeleted': 1,
        'deletedAt': '2025-06-02',
      });
      await v19Db.close();

      DatabaseHelper.setDbName(dbPath);
      final upgradedDb = await DatabaseHelper().database;
      expect(await upgradedDb.getVersion(), 26);

      final row = await upgradedDb
          .query('orders', where: 'id = ?', whereArgs: ['ORD_V19']);
      expect(row.first['isDeleted'], 1);
      // v25/v26 added deletedBy column
      expect(row.first.containsKey('deletedBy'), true);
    });

    test(
        '4. Resumable Migration & Idempotent Crash Recovery on Partial Upgrade',
        () async {
      final dbPath = p.join(tempDir, 'resumable_crash.db');

      // 1. Create a database at v25 but with partial v26 tables already applied
      final db = await openDatabase(
        dbPath,
        version: 25,
        onCreate: (db, version) async {
          await db.execute(
              'CREATE TABLE orders (id TEXT PRIMARY KEY, storeId TEXT, total REAL)');
          await db.execute(
              'CREATE TABLE employees (id TEXT PRIMARY KEY, storeId TEXT, employeeId TEXT, isDeleted INTEGER DEFAULT 0)');
          await db.execute(
              'CREATE TABLE inventory_movements (id TEXT PRIMARY KEY, itemId TEXT, storeId TEXT, type TEXT, delta INTEGER, operationId TEXT, createdAt TEXT)');
          // Partial creation of v26 table before simulated crash
          await db.execute(
              'CREATE TABLE IF NOT EXISTS daily_order_counter (storeId TEXT NOT NULL, businessDate TEXT NOT NULL, count INTEGER DEFAULT 0, PRIMARY KEY (storeId, businessDate))');
        },
      );
      await db.close();

      // 2. Resume migration to v26 via DatabaseHelper
      DatabaseHelper.setDbName(dbPath);
      final resumedDb = await DatabaseHelper().database;
      expect(await resumedDb.getVersion(), 26);

      // Verify both partial and remaining tables exist cleanly without errors
      expect(await resumedDb.query('daily_order_counter'), isEmpty);
      expect(await resumedDb.query('business_days'), isEmpty);
    });

    test(
        '5. Deduplication of Legacy Duplicate Records Before Unique Constraints Enforcement',
        () async {
      final dbPath = p.join(tempDir, 'dedup_legacy.db');

      // Create v25 database containing duplicate employees and duplicate movements
      final db = await openDatabase(
        dbPath,
        version: 25,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE employees (
              id TEXT PRIMARY KEY,
              storeId TEXT,
              name TEXT,
              employeeId TEXT,
              updatedAt TEXT,
              isDeleted INTEGER DEFAULT 0,
              deletedAt TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE inventory_movements (
              id TEXT PRIMARY KEY,
              itemId TEXT,
              storeId TEXT,
              type TEXT,
              delta INTEGER,
              operationId TEXT,
              createdAt TEXT
            )
          ''');
        },
      );

      // Seed duplicate employees sharing (storeId, employeeId)
      await db.insert('employees', {
        'id': 'EMP_OLD',
        'storeId': 'STORE_A',
        'name': 'John Doe Senior',
        'employeeId': 'EMP001',
        'updatedAt': '2025-01-01T10:00:00.000',
        'isDeleted': 0,
      });
      await db.insert('employees', {
        'id': 'EMP_NEW',
        'storeId': 'STORE_A',
        'name': 'John Doe Junior',
        'employeeId': 'EMP001',
        'updatedAt': '2025-02-01T10:00:00.000',
        'isDeleted': 0,
      });

      // Seed duplicate movements sharing (storeId, operationId)
      await db.insert('inventory_movements', {
        'id': 'MOV_EARLY',
        'itemId': 'ITEM_1',
        'storeId': 'STORE_A',
        'type': 'SALE',
        'delta': -1,
        'operationId': 'OP_DUPLICATE_777',
        'createdAt': '2025-01-01T12:00:00.000',
      });
      await db.insert('inventory_movements', {
        'id': 'MOV_LATER',
        'itemId': 'ITEM_1',
        'storeId': 'STORE_A',
        'type': 'SALE',
        'delta': -1,
        'operationId': 'OP_DUPLICATE_777',
        'createdAt': '2025-01-01T12:00:05.000',
      });

      await db.close();

      // Trigger v26 upgrade
      DatabaseHelper.setDbName(dbPath);
      final upgradedDb = await DatabaseHelper().database;
      expect(await upgradedDb.getVersion(), 26);

      // 1. Verify employee deduplication: exactly ONE active employee with EMP001 exists
      final activeEmployees = await upgradedDb.query(
        'employees',
        where: 'storeId = ? AND employeeId = ? AND isDeleted = 0',
        whereArgs: ['STORE_A', 'EMP001'],
      );
      expect(activeEmployees.length, 1);
      expect(activeEmployees.first['id'], 'EMP_NEW'); // Kept newest

      // Verify the duplicate was soft-deleted and re-keyed
      final deletedEmployees = await upgradedDb.query(
        'employees',
        where: 'id = ?',
        whereArgs: ['EMP_OLD'],
      );
      expect(deletedEmployees.first['isDeleted'], 1);
      expect(deletedEmployees.first['employeeId'], startsWith('EMP001_dup_'));

      // 2. Verify movement deduplication: duplicate movement removed
      final movements = await upgradedDb.query(
        'inventory_movements',
        where: 'storeId = ? AND operationId = ?',
        whereArgs: ['STORE_A', 'OP_DUPLICATE_777'],
      );
      expect(movements.length, 1);
      expect(movements.first['id'], 'MOV_EARLY'); // Kept earliest

      // 3. Verify Unique Constraints are enforced now
      expect(
        () async => await upgradedDb.insert('employees', {
          'id': 'EMP_ILLEGAL_DUP',
          'storeId': 'STORE_A',
          'name': 'Duplicate Staff',
          'employeeId': 'EMP001',
          'isDeleted': 0,
        }),
        throwsA(isA<DatabaseException>()),
        reason:
            'Inserting duplicate active employeeId within store must violate unique constraint',
      );

      expect(
        () async => await upgradedDb.insert('inventory_movements', {
          'id': 'MOV_ILLEGAL_DUP',
          'itemId': 'ITEM_1',
          'storeId': 'STORE_A',
          'type': 'SALE',
          'delta': -1,
          'operationId': 'OP_DUPLICATE_777',
          'createdAt': '2025-03-01T12:00:00.000',
        }),
        throwsA(isA<DatabaseException>()),
        reason:
            'Inserting duplicate movement operationId within store must violate unique constraint',
      );
    });

    test('6. Corrupt Optional Fields & Payloads Handled Without App Crash',
        () async {
      final dbPath = p.join(tempDir, 'corrupt_journal.db');
      DatabaseHelper.setDbName(dbPath);
      final db = await DatabaseHelper().database;

      // Seed corrupt operations JSON
      await db.insert('transaction_journal', {
        'id': 'TX_CORRUPT_001',
        'storeId': 'STORE_1',
        'status': 'PENDING',
        'operations': '{ malformed json :: invalid',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Seed empty operations
      await db.insert('transaction_journal', {
        'id': 'TX_EMPTY_002',
        'storeId': 'STORE_1',
        'status': 'PENDING',
        'operations': '',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final recovery = RecoveryService();
      final reports = await recovery.scanAndRecoverReports();

      expect(reports.length, 2);
      expect(reports[0].status, TransactionResolutionStatus.failed);
      expect(reports[0].error, contains('Corrupted JSON'));
      expect(reports[1].status, TransactionResolutionStatus.failed);
      expect(reports[1].error, contains('Empty operations payload'));

      // Verify journal marked as FAILED
      final rows = await db.query('transaction_journal');
      for (var row in rows) {
        expect(row['status'], 'FAILED');
      }
    });

    test(
        '7. Recovery Case 1: Committed Transaction -> Marked COMPLETED with Zero Writes',
        () async {
      final dbPath = p.join(tempDir, 'recovery_committed.db');
      DatabaseHelper.setDbName(dbPath);
      final db = await DatabaseHelper().database;

      const txId = 'TX_COMMITTED_100';
      const orderId = 'ORD_COMMITTED_100';
      const storeId = 'STORE_100';
      const eventId = 'EVT_COMMITTED_100';
      const movementId = 'MOV_COMMITTED_100';

      // 1. Seed complete order & effects in database (already committed)
      await db.insert('orders', {
        'id': orderId,
        'storeId': storeId,
        'total': 150.0,
        'date': '2026-09-19T20:00:00.000',
        'status': 'Completed',
      });

      await db.insert('order_items', {
        'orderId': orderId,
        'itemId': 'ITEM_PIZZA',
        'name': 'Margherita',
        'price': 150.0,
        'quantity': 1,
      });

      await db.insert('business_events', {
        'id': eventId,
        'storeId': storeId,
        'entityType': 'ORDER',
        'entityId': orderId,
        'eventType': 'CREATE',
        'amount': 150.0,
        'createdAt': '2026-09-19T20:00:00.000',
      });

      await db.insert('inventory', {
        'id': 'ITEM_PIZZA',
        'storeId': storeId,
        'name': 'Margherita',
        'price': 150.0,
        'quantity': 19,
      });

      await db.insert('inventory_movements', {
        'id': movementId,
        'itemId': 'ITEM_PIZZA',
        'storeId': storeId,
        'type': 'SALE',
        'delta': -1,
        'operationId': 'OP_PIZZA_100',
        'createdAt': '2026-09-19T20:00:00.000',
      });

      await db.insert('monthly_order_counter', {
        'storeId': storeId,
        'yearMonth': '2026-09',
        'count': 5,
      });

      // 2. Seed pending journal entry
      final payload = jsonEncode({
        'order': {'id': orderId, 'storeId': storeId, 'total': 150.0},
        'orderItems': [
          {
            'orderId': orderId,
            'itemId': 'ITEM_PIZZA',
            'name': 'Margherita',
            'price': 150.0,
            'quantity': 1
          }
        ],
        'event': {
          'id': eventId,
          'storeId': storeId,
          'entityId': orderId,
          'eventType': 'CREATE',
          'amount': 150.0
        },
        'movements': [
          {
            'id': movementId,
            'itemId': 'ITEM_PIZZA',
            'storeId': storeId,
            'type': 'SALE',
            'delta': -1,
            'operationId': 'OP_PIZZA_100'
          }
        ],
        'yearMonth': '2026-09',
      });

      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': storeId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': '2026-09-19T20:00:00.000',
      });

      // 3. Execute recovery
      final recovery = RecoveryService();
      final reports = await recovery.scanAndRecoverReports();

      expect(reports.length, 1);
      final report = reports.first;
      expect(report.status, TransactionResolutionStatus.committed);
      expect(report.orderExisted, true);
      expect(report.itemsFound, 1);
      expect(report.eventExisted, true);
      expect(report.movementsFound, 1);
      expect(report.counterIncremented, false);

      // Verify journal updated to COMPLETED
      final journal = await db
          .query('transaction_journal', where: 'id = ?', whereArgs: [txId]);
      expect(journal.first['status'], 'COMPLETED');

      // Verify counter was NOT incremented again
      final counter = await db.query('monthly_order_counter',
          where: 'storeId = ?', whereArgs: [storeId]);
      expect(counter.first['count'], 5); // Remained 5
    });

    test(
        '8. Recovery Case 2: Rolled Back Transaction -> Marked ROLLED_BACK with Zero Writes',
        () async {
      final dbPath = p.join(tempDir, 'recovery_rolled_back.db');
      DatabaseHelper.setDbName(dbPath);
      final db = await DatabaseHelper().database;

      const txId = 'TX_ROLLED_BACK_200';
      const orderId = 'ORD_RB_200';
      const storeId = 'STORE_200';

      final payload = jsonEncode({
        'order': {'id': orderId, 'storeId': storeId, 'total': 200.0},
        'orderItems': [
          {
            'orderId': orderId,
            'itemId': 'ITEM_A',
            'name': 'Item A',
            'price': 100.0,
            'quantity': 2
          }
        ],
        'event': {
          'id': 'EVT_200',
          'storeId': storeId,
          'entityId': orderId,
          'eventType': 'CREATE'
        },
        'movements': [
          {
            'id': 'MOV_200',
            'itemId': 'ITEM_A',
            'storeId': storeId,
            'type': 'SALE',
            'delta': -2,
            'operationId': 'OP_200'
          }
        ],
        'yearMonth': '2026-09',
      });

      // Write journal only (transaction failed completely and rolled back)
      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': storeId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': '2026-09-19T20:05:00.000',
      });

      final recovery = RecoveryService();
      final reports = await recovery.scanAndRecoverReports();

      expect(reports.length, 1);
      final report = reports.first;
      expect(report.status, TransactionResolutionStatus.rolledBack);
      expect(report.orderExisted, false);
      expect(report.itemsFound, 0);
      expect(report.eventExisted, false);
      expect(report.movementsFound, 0);

      // Verify journal updated to ROLLED_BACK
      final journal = await db
          .query('transaction_journal', where: 'id = ?', whereArgs: [txId]);
      expect(journal.first['status'], 'ROLLED_BACK');

      // Zero rows were inserted into orders or movements
      expect(await db.query('orders', where: 'id = ?', whereArgs: [orderId]),
          isEmpty);
      expect(await db.query('order_items'), isEmpty);
      expect(await db.query('inventory_movements'), isEmpty);
      expect(await db.query('monthly_order_counter'), isEmpty);
    });

    test(
        '9. Recovery Case 3: Partially Applied Transaction -> Idempotently Completed Without Duplication',
        () async {
      final dbPath = p.join(tempDir, 'recovery_partial.db');
      DatabaseHelper.setDbName(dbPath);
      final db = await DatabaseHelper().database;

      const txId = 'TX_PARTIAL_300';
      const orderId = 'ORD_PARTIAL_300';
      const storeId = 'STORE_300';
      const eventId = 'EVT_PARTIAL_300';
      const movementId1 = 'MOV_P_301';
      const movementId2 = 'MOV_P_302';

      // Seed inventory catalog
      await db.insert('inventory', {
        'id': 'ITEM_BURGER',
        'storeId': storeId,
        'name': 'Double Cheeseburger',
        'price': 100.0,
        'quantity': 50,
      });
      await db.insert('inventory', {
        'id': 'ITEM_FRIES',
        'storeId': storeId,
        'name': 'French Fries',
        'price': 50.0,
        'quantity': 30,
      });

      // Partial Crash State:
      // Order and Item 1 were committed.
      // But Item 2 was missing, Event was missing, and Movements were not inserted.
      await db.insert('orders', {
        'id': orderId,
        'storeId': storeId,
        'total': 150.0,
        'date': '2026-09-19T20:10:00.000',
        'status': 'Completed',
      });

      await db.insert('order_items', {
        'orderId': orderId,
        'itemId': 'ITEM_BURGER',
        'name': 'Double Cheeseburger',
        'price': 100.0,
        'quantity': 1,
      });

      await db.insert('monthly_order_counter', {
        'storeId': storeId,
        'yearMonth': '2026-09',
        'count': 10,
      });

      final payload = jsonEncode({
        'order': {
          'id': orderId,
          'storeId': storeId,
          'total': 150.0,
          'date': '2026-09-19T20:10:00.000',
          'status': 'Completed'
        },
        'orderItems': [
          {
            'orderId': orderId,
            'itemId': 'ITEM_BURGER',
            'name': 'Double Cheeseburger',
            'price': 100.0,
            'quantity': 1
          },
          {
            'orderId': orderId,
            'itemId': 'ITEM_FRIES',
            'name': 'French Fries',
            'price': 50.0,
            'quantity': 1
          },
        ],
        'event': {
          'id': eventId,
          'storeId': storeId,
          'entityId': orderId,
          'eventType': 'CREATE',
          'amount': 150.0
        },
        'movements': [
          {
            'id': movementId1,
            'itemId': 'ITEM_BURGER',
            'storeId': storeId,
            'type': 'SALE',
            'delta': -1,
            'operationId': 'OP_BURGER_301',
            'createdAt': '2026-09-19T20:10:00.000'
          },
          {
            'id': movementId2,
            'itemId': 'ITEM_FRIES',
            'storeId': storeId,
            'type': 'SALE',
            'delta': -1,
            'operationId': 'OP_FRIES_302',
            'createdAt': '2026-09-19T20:10:00.000'
          },
        ],
        'yearMonth': '2026-09',
      });

      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': storeId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': '2026-09-19T20:10:00.000',
      });

      // Execute recovery
      final recovery = RecoveryService();
      final reports =
          await recovery.scanAndRecoverReports(autoReconcilePartials: true);

      expect(reports.length, 1);
      final report = reports.first;
      expect(
          report.status, TransactionResolutionStatus.partiallyAppliedRecovered);
      expect(report.orderExisted, true);
      expect(report.counterIncremented, false,
          reason:
              'Order already existed so monthly counter must not be incremented twice');

      // Verify exactly 2 order items now exist
      final items = await db
          .query('order_items', where: 'orderId = ?', whereArgs: [orderId]);
      expect(items.length, 2);

      // Verify business event inserted
      final events = await db
          .query('business_events', where: 'id = ?', whereArgs: [eventId]);
      expect(events.length, 1);

      // Verify movements inserted
      final movements = await db.query('inventory_movements',
          where: 'storeId = ?', whereArgs: [storeId]);
      expect(movements.length, 2);

      // Verify monthly counter remains 10 (NEVER duplicate counter!)
      final counter = await db.query('monthly_order_counter',
          where: 'storeId = ?', whereArgs: [storeId]);
      expect(counter.first['count'], 10);

      // Verify journal marked COMPLETED
      final journal = await db
          .query('transaction_journal', where: 'id = ?', whereArgs: [txId]);
      expect(journal.first['status'], 'COMPLETED');
    });

    test(
        '10. Recovery Case 4: Missing Order with Partial Movements -> Reconciles Order and Increments Counter Exactly Once',
        () async {
      final dbPath = p.join(tempDir, 'recovery_missing_order.db');
      DatabaseHelper.setDbName(dbPath);
      final db = await DatabaseHelper().database;

      const txId = 'TX_MISSING_ORDER_400';
      const orderId = 'ORD_MO_400';
      const storeId = 'STORE_400';
      const movementId = 'MOV_MO_401';

      await db.insert('inventory', {
        'id': 'ITEM_COKE',
        'storeId': storeId,
        'name': 'Coca Cola',
        'price': 40.0,
        'quantity': 100,
      });

      // Simulate partial state: Movement was inserted before crash, but Order and Item were NOT inserted
      await db.insert('inventory_movements', {
        'id': movementId,
        'itemId': 'ITEM_COKE',
        'storeId': storeId,
        'type': 'SALE',
        'delta': -1,
        'operationId': 'OP_COKE_401',
        'createdAt': '2026-09-19T20:15:00.000',
      });

      await db.insert('monthly_order_counter', {
        'storeId': storeId,
        'yearMonth': '2026-09',
        'count': 3,
      });

      final payload = jsonEncode({
        'order': {
          'id': orderId,
          'storeId': storeId,
          'total': 40.0,
          'date': '2026-09-19T20:15:00.000',
          'status': 'Completed'
        },
        'orderItems': [
          {
            'orderId': orderId,
            'itemId': 'ITEM_COKE',
            'name': 'Coca Cola',
            'price': 40.0,
            'quantity': 1
          }
        ],
        'event': {
          'id': 'EVT_400',
          'storeId': storeId,
          'entityId': orderId,
          'eventType': 'CREATE',
          'amount': 40.0
        },
        'movements': [
          {
            'id': movementId,
            'itemId': 'ITEM_COKE',
            'storeId': storeId,
            'type': 'SALE',
            'delta': -1,
            'operationId': 'OP_COKE_401',
            'createdAt': '2026-09-19T20:15:00.000'
          }
        ],
        'yearMonth': '2026-09',
      });

      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': storeId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': '2026-09-19T20:15:00.000',
      });

      final recovery = RecoveryService();
      final reports =
          await recovery.scanAndRecoverReports(autoReconcilePartials: true);

      expect(reports.length, 1);
      final report = reports.first;
      expect(
          report.status, TransactionResolutionStatus.partiallyAppliedRecovered);
      expect(report.orderExisted, false);
      expect(report.counterIncremented, true,
          reason: 'Order was missing, so counter must be incremented once');

      // Verify order exists now
      final order =
          await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(order.length, 1);

      // Verify movement was NOT duplicated (still exactly 1 row)
      final movements = await db.query('inventory_movements',
          where: 'storeId = ?', whereArgs: [storeId]);
      expect(movements.length, 1);

      // Verify monthly counter was incremented from 3 to 4 (exactly once)
      final counter = await db.query('monthly_order_counter',
          where: 'storeId = ?', whereArgs: [storeId]);
      expect(counter.first['count'], 4);
    });

    test('11. Transaction Reconciliation Reports Provide Complete Audit Trail',
        () async {
      final dbPath = p.join(tempDir, 'reconciliation_report_test.db');
      DatabaseHelper.setDbName(dbPath);
      final db = await DatabaseHelper().database;

      const txId = 'TX_AUDIT_500';
      const storeId = 'STORE_500';
      const orderId = 'ORD_AUDIT_500';

      final payload = jsonEncode({
        'order': {'id': orderId, 'storeId': storeId, 'total': 80.0},
        'orderItems': [
          {
            'orderId': orderId,
            'itemId': 'ITEM_TEA',
            'name': 'Masala Chai',
            'price': 40.0,
            'quantity': 2
          }
        ],
        'event': {
          'id': 'EVT_500',
          'storeId': storeId,
          'entityId': orderId,
          'eventType': 'CREATE'
        },
        'movements': [],
        'yearMonth': '2026-09',
      });

      // Seed partial state: order exists, but items and events are missing
      await db.insert('orders', {
        'id': orderId,
        'storeId': storeId,
        'total': 80.0,
        'date': '2026-09-19T20:20:00.000',
        'status': 'Completed',
      });

      await db.insert('transaction_journal', {
        'id': txId,
        'storeId': storeId,
        'status': 'PENDING',
        'operations': payload,
        'createdAt': '2026-09-19T20:20:00.000',
      });

      final recovery = RecoveryService();
      final report = await recovery.reconcileTransaction(txId);

      expect(report.txId, txId);
      expect(report.storeId, storeId);
      expect(
          report.status, TransactionResolutionStatus.partiallyAppliedRecovered);
      expect(report.actionsTaken, isNotEmpty);
      expect(report.evaluatedAt, isNotNull);

      final map = report.toMap();
      expect(map['txId'], txId);
      expect(map['status'], 'PARTIALLY_APPLIED_RECOVERED');
      expect(map['actionsTaken'], isA<List<String>>());
    });
  });
}
