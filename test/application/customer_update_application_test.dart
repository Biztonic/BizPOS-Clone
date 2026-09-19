import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/features/crm/data/customer_repository.dart';
import 'package:biztonic_pos/models/customer.dart';

void main() {
  late Directory tempDir;
  late CustomerRepository repository;

  const testStoreId = 'STORE_HYDERABAD_01';
  const otherStoreId = 'STORE_CHENNAI_01';

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('app_customer_test_');
    final dbPath = p.join(tempDir.path, 'app_customer.db');
    DatabaseHelper.setDbName(dbPath);

    Hive.init(tempDir.path);
    await Hive.openBox('cache_customers');

    repository = CustomerRepository(dbHelper: DatabaseHelper());
  });

  tearDown(() async {
    await Hive.close();
    await DatabaseHelper().close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Application Tests: Customer Lifecycle & Loyalty Management', () {
    test('1. Insert and retrieve customer profile with CRM attributes',
        () async {
      final customer = Customer(
        id: 'CUST_RAHUL_001',
        storeId: testStoreId,
        name: 'Rahul Sharma',
        email: 'rahul.sharma@example.com',
        phone: '+919876543210',
        joinDate: DateTime(2025, 1, 15),
        totalSpent: 4500.0,
        loyaltyPoints: 120,
        tier: 'Gold',
        visitCount: 6,
      );

      await repository.insertCustomer(customer);

      final fetched = await repository.getCustomer('CUST_RAHUL_001');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Rahul Sharma');
      expect(fetched.email, 'rahul.sharma@example.com');
      expect(fetched.loyaltyPoints, 120);
      expect(fetched.tier, 'Gold');
      expect(fetched.storeId, testStoreId);
    });

    test(
        '2. Loyalty point adjustment and visit count update persists accurately',
        () async {
      final initialCustomer = Customer(
        id: 'CUST_PRIYA_002',
        storeId: testStoreId,
        name: 'Priya Patel',
        email: 'priya.patel@example.com',
        joinDate: DateTime(2025, 2, 1),
        totalSpent: 1000.0,
        loyaltyPoints: 50,
        tier: 'Silver',
        visitCount: 2,
      );
      await repository.insertCustomer(initialCustomer);

      // Simulate a purchase adding 35 points and 1 visit
      final visitTime = DateTime.now();
      final updated = initialCustomer.copyWith(
        loyaltyPoints: initialCustomer.loyaltyPoints + 35,
        totalSpent: initialCustomer.totalSpent + 700.0,
        visitCount: initialCustomer.visitCount + 1,
        lastVisit: visitTime,
        updatedAt: visitTime,
        version: initialCustomer.version + 1,
      );
      await repository.insertCustomer(updated);

      final reloaded = await repository.getCustomer('CUST_PRIYA_002');
      expect(reloaded, isNotNull);
      expect(reloaded!.loyaltyPoints, 85);
      expect(reloaded.totalSpent, 1700.0);
      expect(reloaded.visitCount, 3);
      expect(reloaded.version, 2);
    });

    test('3. Soft-deleted customer is excluded from active store queries',
        () async {
      final customer = Customer(
        id: 'CUST_TO_DELETE_003',
        storeId: testStoreId,
        name: 'Deleted Customer',
        email: 'deleted@example.com',
        joinDate: DateTime(2025, 3, 1),
        totalSpent: 0.0,
        loyaltyPoints: 0,
        tier: 'New',
      );
      await repository.insertCustomer(customer);

      // Verify active
      var activeList = await repository.getCustomers(testStoreId);
      expect(activeList.any((c) => c.id == 'CUST_TO_DELETE_003'), isTrue);

      // Soft delete: update deletedAt
      final softDeleted = customer.copyWith(
        deletedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.insertCustomer(softDeleted);

      // Verify excluded from active list
      activeList = await repository.getCustomers(testStoreId);
      expect(activeList.any((c) => c.id == 'CUST_TO_DELETE_003'), isFalse);

      // Verify still physically present in SQLite table for audit/sync history
      final db = await DatabaseHelper().database;
      final raw = await db.query('customers',
          where: 'id = ?', whereArgs: ['CUST_TO_DELETE_003']);
      expect(raw.isNotEmpty, isTrue);
      expect(raw.first['deletedAt'], isNotNull);
    });

    test(
        '4. Multi-tenant customer query isolation prevents cross-store data leakage',
        () async {
      final custA = Customer(
        id: 'CUST_STORE_A',
        storeId: testStoreId,
        name: 'Store A Customer',
        email: 'a@store.com',
        joinDate: DateTime.now(),
        totalSpent: 100.0,
        loyaltyPoints: 10,
        tier: 'Bronze',
      );
      final custB = Customer(
        id: 'CUST_STORE_B',
        storeId: otherStoreId,
        name: 'Store B Customer',
        email: 'b@store.com',
        joinDate: DateTime.now(),
        totalSpent: 200.0,
        loyaltyPoints: 20,
        tier: 'Silver',
      );

      await repository.insertCustomer(custA);
      await repository.insertCustomer(custB);

      final storeACustomers = await repository.getCustomers(testStoreId);
      final storeBCustomers = await repository.getCustomers(otherStoreId);

      expect(storeACustomers.any((c) => c.id == 'CUST_STORE_A'), isTrue);
      expect(storeACustomers.any((c) => c.id == 'CUST_STORE_B'), isFalse);

      expect(storeBCustomers.any((c) => c.id == 'CUST_STORE_B'), isTrue);
      expect(storeBCustomers.any((c) => c.id == 'CUST_STORE_A'), isFalse);
    });
  });
}
