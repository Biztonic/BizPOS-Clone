import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() {
  // Setup FFI for Windows
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SQFlite Migration Tests', () {
    late Repository repository;
    final testDbName = 'test_biztonic_${DateTime.now().millisecondsSinceEpoch}.db';

    setUp(() async {
      DatabaseHelper.setDbName(testDbName);
      repository = Repository();
      // Ensure DB starts clean
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, testDbName);
      if (File(path).existsSync()) {
        File(path).deleteSync();
      }
    });

    tearDown(() async {
      await DatabaseHelper().close();
      // Cleanup
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
           File(path).deleteSync();
        } catch (_) {}
      }
    });

    test('Database Schema Creation', () async {
      // Accessing repository should trigger DB creation
      final db = await DatabaseHelper().database;
      final tables = await db.query('sqlite_master', where: 'type = ?', whereArgs: ['table']);
      final tableNames = tables.map((row) => row['name'] as String).toList();
      
      expect(tableNames, contains('orders'));
      expect(tableNames, contains('order_items'));
      expect(tableNames, contains('inventory'));
      expect(tableNames, contains('customers'));
    });

    test('Order CRUD Operations', () async {
      final order = OrderModel(
        id: 'order_123',
        storeId: 'store_1',
        items: [],
        total: 100.0,
        date: DateTime.now(),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash',
      );

      await repository.insertOrder(order);
      
      final count = await repository.getOrderCount('store_1');
      expect(count, 1);

      final fetchedOrders = await repository.getOrders('store_1');
      expect(fetchedOrders.first.id, 'order_123');
      expect(fetchedOrders.first.total, 100.0);
      
      await repository.voidOrder('order_123');
      final countAfterDelete = await repository.getOrderCount('store_1');
      expect(countAfterDelete, 0); // Excluded from active counts but remains in DB
      
      final allOrders = await repository.getOrders('store_1');
      expect(allOrders.length, 1);
      expect(allOrders.first.status, 'VOID');
    });

    test('Inventory CRUD Operations', () async {
      final item = InventoryItem(
        id: 'item_1',
        storeId: 'store_1',
        name: 'Burger',
        category: 'Food',
        price: 15.0,
        quantity: 50,
        status: 'In Stock',
        trackStock: true,
      );

      await repository.insertInventory(item);
      
      final count = await repository.getInventoryCount('store_1');
      expect(count, 1);
      
      final items = await repository.getInventory('store_1');
      expect(items.first.name, 'Burger');
      expect(items.first.trackStock, true);
    });
  });
}
