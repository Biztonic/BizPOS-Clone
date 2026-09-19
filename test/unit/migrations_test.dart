import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biztonic_pos/services/database_helper.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('unit_migrations_test_');
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Unit Tests: Deterministic Schema Migrations & Invariants', () {
    test('1. Fresh installation initializes database directly at schema v26',
        () async {
      final dbPath = p.join(tempDir.path, 'fresh_v26_unit.db');
      DatabaseHelper.setDbName(dbPath);
      final db = await DatabaseHelper().database;

      final versionResult = await db.rawQuery('PRAGMA user_version');
      final version = versionResult.first['user_version'] as int;
      expect(version, 26);

      // Verify all expected tables are present
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      const expectedCoreTables = {
        'orders',
        'order_items',
        'inventory',
        'inventory_movements',
        'business_events',
        'transaction_journal',
        'idempotency_keys',
        'customers',
        'employees',
        'employee_attendance',
        'employee_leaves',
        'employee_payroll',
        'roles',
        'store_settings',
        'floors',
        'tables',
        'suppliers',
        'notes',
        'monthly_order_counter',
        'plan_tokens',
        'outbox_operations',
        'conflict_records',
        'business_days',
        'daily_order_counter',
        'cache_inventory_quantities',
      };

      for (var expected in expectedCoreTables) {
        expect(tableNames.contains(expected), isTrue,
            reason: 'Expected table $expected missing in schema v26');
      }

      await DatabaseHelper().close();
    });

    test('2. Unique indexes are strictly enforced in schema v26', () async {
      final dbPath = p.join(tempDir.path, 'unique_indexes_unit.db');
      DatabaseHelper.setDbName(dbPath);
      final db = await DatabaseHelper().database;

      // Check unique index on employees(storeId, employeeId)
      final empIndexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='uq_employees_store_emp_id'");
      expect(empIndexes.isNotEmpty, isTrue);

      // Check unique index on inventory_movements(storeId, operationId)
      final movIndexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='uq_movements_store_operation'");
      expect(movIndexes.isNotEmpty, isTrue);

      // Check index on orders(storeId, businessDayId)
      final orderIndexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_orders_business_day'");
      expect(orderIndexes.isNotEmpty, isTrue);

      await DatabaseHelper().close();
    });

    test(
        '3. Historical migration from v1 to v26 preserves data and applies columns',
        () async {
      final dbPath = p.join(tempDir.path, 'migration_v1_v26_unit.db');

      // Create v1 database
      var db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE orders (
              id TEXT PRIMARY KEY,
              storeId TEXT,
              total REAL,
              date TEXT,
              status TEXT,
              type TEXT,
              paymentMethod TEXT
            )
          ''');
          await db.execute('''
            INSERT INTO orders (id, storeId, total, date, status, type, paymentMethod)
            VALUES ('ORD_V1_UNIT', 'STORE_V1', 250.0, '2023-01-01', 'Completed', 'Dine-In', 'Cash')
          ''');
        },
      );
      await db.close();

      // Upgrade to v26 using DatabaseHelper
      DatabaseHelper.setDbName(dbPath);
      db = await DatabaseHelper().database;

      final versionResult = await db.rawQuery('PRAGMA user_version');
      expect(versionResult.first['user_version'], 26);

      // Verify v1 order still exists with all its data
      final orders =
          await db.query('orders', where: 'id = ?', whereArgs: ['ORD_V1_UNIT']);
      expect(orders.isNotEmpty, isTrue);
      expect(orders.first['total'], 250.0);
      expect(orders.first['storeId'], 'STORE_V1');

      // Verify new v26 columns were added
      expect(orders.first.containsKey('isDeleted'), isTrue);
      expect(orders.first.containsKey('version'), isTrue);
      expect(orders.first.containsKey('businessDayId'), isTrue);

      await DatabaseHelper().close();
    });
  });
}
