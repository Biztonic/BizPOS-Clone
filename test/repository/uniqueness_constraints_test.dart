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
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('repo_uniqueness_test_');
    final dbPath = p.join(tempDir.path, 'repo_uniqueness.db');
    DatabaseHelper.setDbName(dbPath);
  });

  tearDown(() async {
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Repository Tests: Database Uniqueness Constraints & Data Invariants',
      () {
    test('1. uq_employees_store_emp_id enforces unique employeeId per store',
        () async {
      final db = await DatabaseHelper().database;

      // First employee: store A, employeeId 1001 -> Success
      await db.insert('employees', {
        'id': 'EMP_A_1001',
        'storeId': 'STORE_A',
        'name': 'John Doe',
        'email': 'john@store-a.com',
        'role': 'Cashier',
        'employeeId': '1001',
      });

      // Second employee: store B, employeeId 1001 -> Success (different store)
      await db.insert('employees', {
        'id': 'EMP_B_1001',
        'storeId': 'STORE_B',
        'name': 'Jane Doe',
        'email': 'jane@store-b.com',
        'role': 'Cashier',
        'employeeId': '1001',
      });

      // Third employee: store A, employeeId 1001 -> VIOLATION
      expect(
        () async => await db.insert('employees', {
          'id': 'EMP_A_1001_DUPLICATE',
          'storeId': 'STORE_A',
          'name': 'Duplicate User',
          'email': 'dup@store-a.com',
          'role': 'Cashier',
          'employeeId': '1001',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test(
        '2. uq_movements_store_operation enforces unique operationId per store',
        () async {
      final db = await DatabaseHelper().database;

      // Seed item
      await db.insert('inventory', {
        'id': 'ITEM_UQ_01',
        'storeId': 'STORE_A',
        'name': 'Item UQ',
        'price': 100.0,
        'quantity': 10,
        'category': 'General',
        'status': 'ACTIVE',
      });

      // Movement 1: op_sale_001 in STORE_A -> Success
      await db.insert('inventory_movements', {
        'id': 'MOV_UQ_1',
        'itemId': 'ITEM_UQ_01',
        'storeId': 'STORE_A',
        'delta': 10,
        'type': 'PURCHASE',
        'operationId': 'op_sale_001',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Movement 2: op_sale_001 in STORE_A again -> VIOLATION
      expect(
        () async => await db.insert('inventory_movements', {
          'id': 'MOV_UQ_2',
          'itemId': 'ITEM_UQ_01',
          'storeId': 'STORE_A',
          'delta': -1,
          'type': 'SALE',
          'operationId': 'op_sale_001',
          'createdAt': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('3. idempotency_keys primary key enforces unique key deduplication',
        () async {
      final db = await DatabaseHelper().database;

      await db.insert('idempotency_keys', {
        'key': 'IDEMP_GLOBAL_001',
        'entityType': 'ORDER',
        'entityId': 'ORD_101',
        'createdAt': DateTime.now().toIso8601String(),
      });

      expect(
        () async => await db.insert('idempotency_keys', {
          'key': 'IDEMP_GLOBAL_001',
          'entityType': 'ORDER',
          'entityId': 'ORD_102',
          'createdAt': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('4. orders table enforces primary key uniqueness', () async {
      final db = await DatabaseHelper().database;

      await db.insert('orders', {
        'id': 'ORD_UNIQUE_PK',
        'storeId': 'STORE_A',
        'subtotal': 100.0,
        'total': 100.0,
        'status': 'Completed',
        'date': DateTime.now().toIso8601String(),
      });

      expect(
        () async => await db.insert('orders', {
          'id': 'ORD_UNIQUE_PK',
          'storeId': 'STORE_A',
          'subtotal': 200.0,
          'total': 200.0,
          'status': 'Completed',
          'date': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
