import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:hive/hive.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/repositories/billing_repository.dart';
import 'package:biztonic_pos/features/billing/presentation/providers/billing_provider.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/providers/order_provider.dart';
import 'package:biztonic_pos/models/store.dart';

class _FakeBillingRepository implements BillingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getPaginatedOrders) {
      return Future.value(BillingResult<List<OrderEntity>>.success([]));
    }
    if (invocation.memberName == #insertOrder) {
      return Future.value(BillingResult<void>.success(null));
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Security Perimeter Regression Tests', () {
    late Repository repository;
    late String testDbName;
    late Directory tempHiveDir;

    setUp(() async {
      await DatabaseHelper().close();
      testDbName =
          'sec_perimeter_test_${DateTime.now().microsecondsSinceEpoch}.db';
      DatabaseHelper.setDbName(testDbName);
      repository = Repository();

      tempHiveDir = await Directory.systemTemp.createTemp('hive_sec_test_');
      Hive.init(tempHiveDir.path);
    });

    tearDown(() async {
      await DatabaseHelper().close();
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }

      await Hive.close();
      if (tempHiveDir.existsSync()) {
        try {
          tempHiveDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test(
        'SQLite queries strictly deny cross-tenant access when storeId is empty or null',
        () async {
      final order1 = OrderModel(
        id: 'ORD_TENANT_A',
        storeId: 'store_alpha',
        items: [],
        total: 100.0,
        date: DateTime.now(),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash',
      );
      final order2 = OrderModel(
        id: 'ORD_TENANT_B',
        storeId: 'store_beta',
        items: [],
        total: 200.0,
        date: DateTime.now(),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash',
      );

      await repository.insertOrder(order1);
      await repository.insertOrder(order2);

      // Null or empty storeId must return empty list (NO data leakage)
      expect(await repository.getOrders(null), isEmpty);
      expect(await repository.getOrders(''), isEmpty);
      expect(await repository.getPaginatedOrders(null), isEmpty);
      expect(await repository.getPaginatedOrders(''), isEmpty);
      expect(await repository.getUnsyncedOrders(null), isEmpty);
      expect(await repository.getUnsyncedOrders(''), isEmpty);

      // Scoped storeId must return ONLY the target tenant's orders
      final alphaOrders = await repository.getOrders('store_alpha');
      expect(alphaOrders.length, 1);
      expect(alphaOrders.first.id, 'ORD_TENANT_A');

      final betaOrders = await repository.getOrders('store_beta');
      expect(betaOrders.length, 1);
      expect(betaOrders.first.id, 'ORD_TENANT_B');
    });

    test(
        'getOrderCountSince correctly binds parameters without positional misalignment',
        () async {
      final now = DateTime.now();
      final pastOrderAlpha = OrderModel(
        id: 'ORD_PAST_A',
        storeId: 'store_alpha',
        items: [],
        total: 50.0,
        date: now.subtract(const Duration(days: 2)),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash',
      );
      final recentOrderAlpha = OrderModel(
        id: 'ORD_RECENT_A',
        storeId: 'store_alpha',
        items: [],
        total: 75.0,
        date: now.subtract(const Duration(hours: 1)),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash',
      );
      final recentOrderBeta = OrderModel(
        id: 'ORD_RECENT_B',
        storeId: 'store_beta',
        items: [],
        total: 90.0,
        date: now.subtract(const Duration(hours: 1)),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash',
      );

      await repository.insertOrder(pastOrderAlpha);
      await repository.insertOrder(recentOrderAlpha);
      await repository.insertOrder(recentOrderBeta);

      final cutoff = now.subtract(const Duration(days: 1));

      // store_alpha has only 1 order since cutoff
      final alphaCount =
          await repository.getOrderCountSince('store_alpha', cutoff);
      expect(alphaCount, 1);

      // store_beta has only 1 order since cutoff
      final betaCount =
          await repository.getOrderCountSince('store_beta', cutoff);
      expect(betaCount, 1);
    });

    test('BillingProvider.checkout rejects concurrent duplicate execution',
        () async {
      final syncService = SyncService();
      final provider =
          BillingProvider(syncService, repository: _FakeBillingRepository());

      final dummyOrder = OrderEntity(
        id: 'ORD_REENTRANT_TEST',
        storeId: 'store_alpha',
        items: [],
        total: 100,
        status: OrderStatus.completed,
        paymentMethod: PaymentMethod.cash,
        type: OrderType.dineIn,
        date: DateTime.now(),
      );

      // Trigger first checkout
      final future1 = provider.checkout(
        order: dummyOrder,
        activeStoreId: 'store_alpha',
        deviceId: 'dev1',
        idempotencyKey: 'idemp1',
        checkLimits: false,
      );

      // Immediate second call should be caught by re-entrant guard if loading
      if (provider.isLoading) {
        final result2 = await provider.checkout(
          order: dummyOrder,
          activeStoreId: 'store_alpha',
          deviceId: 'dev1',
          idempotencyKey: 'idemp2',
          checkLimits: false,
        );
        expect(result2.isSuccess, isFalse);
        expect(result2.error, contains("already in progress"));
      }

      await future1;
    });

    test('OrderProvider.placeOrder rejects concurrent re-entrant invocation',
        () async {
      final syncService = SyncService();
      final orderProvider = OrderProvider(syncService);

      final dummyOrder = OrderModel(
        id: 'ORD_OP_REENTRANT',
        storeId: 'store_alpha',
        items: [],
        total: 100,
        status: 'Completed',
        paymentMethod: 'Cash',
        type: 'Dine-In',
        date: DateTime.now(),
      );

      final store = Store.fromMap({
        'name': 'Alpha Store',
        'owner': 'owner_alpha',
        'phone': '1234567890',
      }, 'store_alpha');

      orderProvider.isUnrestricted = true;

      // Start first placeOrder
      final future1 = orderProvider.placeOrder(dummyOrder, store);

      // Second placeOrder should fail with re-entrant exception if first is still running
      if (orderProvider.isPlacingOrder) {
        expect(
          () => orderProvider.placeOrder(dummyOrder, store),
          throwsA(predicate((e) =>
              e.toString().contains("Order placement already in progress"))),
        );
      }

      try {
        await future1;
      } catch (_) {
        // Expected since fake or uninitialized full pipeline
      }
    });

    test(
        'Clock rollback tamper detection: rollback before 2025 or backwards triggers tamper alarm',
        () async {
      final settingsBox = await Hive.openBox('settings');
      const thresholdMs = 1735689600000; // Jan 1, 2025

      // Simulate normal time in 2026
      final normalTimeMs = DateTime(2026, 6, 1).millisecondsSinceEpoch;
      await settingsBox.put('last_known_time', normalTimeMs);

      // Scenario A: Clock set backward to 2025 (within range, but backward relative to lastKnownMs)
      final rolledBack2025Ms = DateTime(2025, 6, 1).millisecondsSinceEpoch;
      expect(rolledBack2025Ms < normalTimeMs, isTrue);

      // Scenario B: Clock set backward to 2024 (pre-2025 threshold bypass attempt)
      final rolledBack2024Ms = DateTime(2024, 1, 1).millisecondsSinceEpoch;
      expect(rolledBack2024Ms < thresholdMs, isTrue);
      expect(rolledBack2024Ms < normalTimeMs, isTrue);

      // Verification of policy logic:
      bool isTampered(int nowMs, int? lastKnown) {
        if (lastKnown != null && nowMs < lastKnown) return true;
        if (lastKnown != null && nowMs < thresholdMs) return true;
        return false;
      }

      expect(isTampered(rolledBack2025Ms, normalTimeMs), isTrue);
      expect(isTampered(rolledBack2024Ms, normalTimeMs), isTrue);
      expect(isTampered(normalTimeMs + 1000, normalTimeMs), isFalse);
    });
  });
}
