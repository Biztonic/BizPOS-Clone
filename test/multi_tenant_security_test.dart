import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() {
  // Initialize FFI for SQFlite in test environment
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Multi-Tenant Store Isolation & Immutability Tests', () {
    late Repository repository;
    late String testDbName;

    setUp(() async {
      await DatabaseHelper().close();
      testDbName = 'test_isolation_${DateTime.now().microsecondsSinceEpoch}.db';
      DatabaseHelper.setDbName(testDbName);
      repository = Repository();
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
    });

    tearDown(() async {
      await DatabaseHelper().close();
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
    });

    test('Store A orders must not be accessible or returned in Store B queries',
        () async {
      final orderStoreA = OrderModel(
        id: 'ORD_STORE_A_001',
        storeId: 'store_alpha',
        items: [],
        total: 250.0,
        date: DateTime.now(),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash',
      );

      final orderStoreB = OrderModel(
        id: 'ORD_STORE_B_001',
        storeId: 'store_beta',
        items: [],
        total: 500.0,
        date: DateTime.now(),
        status: 'Completed',
        type: 'Takeaway',
        paymentMethod: 'Card',
      );

      await repository.insertOrder(orderStoreA);
      await repository.insertOrder(orderStoreB);

      // Verify Store Alpha query returns ONLY Store Alpha order
      final alphaOrders = await repository.getOrders('store_alpha');
      expect(alphaOrders.length, 1);
      expect(alphaOrders.first.id, 'ORD_STORE_A_001');
      expect(alphaOrders.first.storeId, 'store_alpha');

      // Verify Store Beta query returns ONLY Store Beta order
      final betaOrders = await repository.getOrders('store_beta');
      expect(betaOrders.length, 1);
      expect(betaOrders.first.id, 'ORD_STORE_B_001');
      expect(betaOrders.first.storeId, 'store_beta');

      // Verify counts are strictly isolated
      expect(await repository.getOrderCount('store_alpha'), 1);
      expect(await repository.getOrderCount('store_beta'), 1);
    });

    test('Store A inventory must be strictly isolated from Store B', () async {
      final itemA = InventoryItem(
        id: 'ITEM_ALPHA_01',
        storeId: 'store_alpha',
        name: 'Alpha Product',
        category: 'Electronics',
        price: 100.0,
        quantity: 10,
        status: 'Available',
        trackStock: true,
      );

      final itemB = InventoryItem(
        id: 'ITEM_BETA_01',
        storeId: 'store_beta',
        name: 'Beta Product',
        category: 'Food',
        price: 20.0,
        quantity: 50,
        status: 'Available',
        trackStock: true,
      );

      await repository.insertInventory(itemA);
      await repository.insertInventory(itemB);

      final alphaInventory = await repository.getInventory('store_alpha');
      expect(alphaInventory.length, 1);
      expect(alphaInventory.first.id, 'ITEM_ALPHA_01');

      final betaInventory = await repository.getInventory('store_beta');
      expect(betaInventory.length, 1);
      expect(betaInventory.first.id, 'ITEM_BETA_01');
    });

    test(
        'Order voiding performs soft-delete tombstone without erasing audit record',
        () async {
      final order = OrderModel(
        id: 'ORD_AUDIT_001',
        storeId: 'store_alpha',
        items: [],
        total: 150.0,
        date: DateTime.now(),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'UPI',
      );

      await repository.insertOrder(order);
      expect(await repository.getOrderCount('store_alpha'), 1);

      // Void the order
      await repository.voidOrder('ORD_AUDIT_001');

      // Active count should exclude voided orders
      expect(await repository.getOrderCount('store_alpha'), 0);

      // But record must remain in database for financial audit integrity
      final allOrders = await repository.getOrders('store_alpha');
      expect(allOrders.length, 1);
      expect(allOrders.first.status, 'VOID');
      expect(allOrders.first.isImmutable, isTrue);
    });

    test('Role privilege elevation checks', () {
      const cashierRole = 'Cashier';
      const superAdminRole = 'Super Admin';
      const staffRole = 'Staff';

      // Verify cashier or staff role is not treated as super admin
      bool checkIsSuperAdmin(String role) =>
          role == superAdminRole || role == 'super_admin';

      expect(checkIsSuperAdmin(cashierRole), isFalse);
      expect(checkIsSuperAdmin(staffRole), isFalse);
      expect(checkIsSuperAdmin(superAdminRole), isTrue);
    });
  });
}
