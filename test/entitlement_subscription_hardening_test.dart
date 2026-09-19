import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
import 'package:biztonic_pos/sync/policy/plan_sync_policy.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Authoritative Entitlement & Subscription Hardening Tests', () {
    final testDbName =
        'test_entitlement_${DateTime.now().millisecondsSinceEpoch}.db';
    late Directory tempDir;
    late Repository repo;
    late Database db;
    late EntitlementService service;

    const testStoreId = 'STORE_ENTITLEMENT_ALPHA';

    setUp(() async {
      DatabaseHelper.setDbName(testDbName);
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }

      tempDir = Directory.systemTemp.createTempSync('hive_entitlement_test_');
      Hive.init(tempDir.path);

      await Hive.openBox(EntitlementService.boxName);
      await Hive.openBox(OutboxStore.primaryQueueBox);
      await Hive.openBox(OutboxStore.deadLetterBox);
      await Hive.openBox('cache_stores');

      repo = Repository();
      db = await DatabaseHelper().database;
      service = EntitlementService(repository: repo);
    });

    tearDown(() async {
      await Hive.close();
      await DatabaseHelper().close();
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('1. Basic Plan enforces strict quotas and restricts advanced addons',
        () async {
      final entitlement = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.basic,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
        addons: {},
      );
      await service.updateEntitlement(entitlement);

      expect(service.currentPlan(testStoreId), equals(PlanTier.basic));
      expect(service.planName(testStoreId), equals('Basic'));
      expect(service.isSubscribed(testStoreId), isTrue);

      // Quota checking via canPerformAction
      expect(
        service.canPerformAction('create_order',
            storeId: testStoreId, currentCount: 10),
        isTrue,
      );
      expect(
        service.canPerformAction('create_order',
            storeId: testStoreId, currentCount: 500),
        isFalse,
      );

      // Addons restricted
      expect(service.hasAddon('data_center', storeId: testStoreId), isFalse);
      expect(
          service.hasAddon('table_reservation', storeId: testStoreId), isFalse);
      expect(service.isFeatureEnabled('multi_store', storeId: testStoreId),
          isFalse);

      // Block reasons
      final reason =
          service.getBlockReason('create_order', storeId: testStoreId);
      expect(reason, contains('Order limit reached'));
    });

    test(
        '2. Higher Plan (Standard / Enterprise) unlocks unlimited orders and features',
        () async {
      // Standard Tier
      final standardEntitlement = StoreEntitlement.create(
        storeId: 'STORE_STANDARD',
        plan: PlanTier.standard,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
        addons: {'data_center'},
      );
      await service.updateEntitlement(standardEntitlement);

      expect(
        service.canPerformAction('create_order',
            storeId: 'STORE_STANDARD', currentCount: 99999),
        isTrue,
      );
      expect(service.isFeatureEnabled('reports', storeId: 'STORE_STANDARD'),
          isTrue);
      expect(service.isFeatureEnabled('tables', storeId: 'STORE_STANDARD'),
          isTrue);
      expect(
          service.hasAddon('data_center', storeId: 'STORE_STANDARD'), isTrue);

      // Enterprise Tier (Wildcard unlock)
      final enterpriseEntitlement = StoreEntitlement.create(
        storeId: 'STORE_ENTERPRISE',
        plan: PlanTier.enterprise,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.enterprise]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.enterprise]!,
        addons: {},
      );
      await service.updateEntitlement(enterpriseEntitlement);

      expect(
          service.isFeatureEnabled('any_custom_feature',
              storeId: 'STORE_ENTERPRISE'),
          isTrue);
      expect(service.hasAddon('kds_management', storeId: 'STORE_ENTERPRISE'),
          isTrue);
      expect(
        service.canPerformAction('create_order',
            storeId: 'STORE_ENTERPRISE', currentCount: 1000000),
        isTrue,
      );
    });

    test('3. Expired plan past grace period blocks mutations and features',
        () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 15));
      final expiredEntitlement = StoreEntitlement.create(
        storeId: 'STORE_EXPIRED',
        plan: PlanTier.standard,
        status: PlanStatus.active, // initially active in doc
        startDate: DateTime.now().subtract(const Duration(days: 45)),
        endDate: pastDate,
        gracePeriodDays: 7, // 15 > 7, grace exceeded
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
      );
      await service.updateEntitlement(expiredEntitlement);

      final evaluated = service.getEntitlement('STORE_EXPIRED');
      expect(evaluated.status, equals(PlanStatus.expired));
      expect(evaluated.isUsable, isFalse);
      expect(service.isSubscribed('STORE_EXPIRED'), isFalse);

      // Actions blocked
      expect(
        service.canPerformAction('create_order', storeId: 'STORE_EXPIRED'),
        isFalse,
      );
      expect(
        service.isFeatureEnabled('reports', storeId: 'STORE_EXPIRED'),
        isFalse,
      );
      expect(
        service.getBlockReason('create_order', storeId: 'STORE_EXPIRED'),
        contains('Subscription has expired'),
      );
    });

    test('4. Grace period allows sales and features with warning status',
        () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 3));
      final graceEntitlement = StoreEntitlement.create(
        storeId: 'STORE_GRACE',
        plan: PlanTier.standard,
        status: PlanStatus.active,
        startDate: DateTime.now().subtract(const Duration(days: 33)),
        endDate: pastDate,
        gracePeriodDays: 7, // 3 < 7, still within grace!
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
      );
      await service.updateEntitlement(graceEntitlement);

      final evaluated = service.getEntitlement('STORE_GRACE');
      expect(evaluated.status, equals(PlanStatus.grace));
      expect(evaluated.isUsable, isTrue);
      expect(service.isSubscribed('STORE_GRACE'), isTrue);

      // Operations permitted during grace
      expect(
        service.canPerformAction('create_order', storeId: 'STORE_GRACE'),
        isTrue,
      );
      expect(
        service.isFeatureEnabled('reports', storeId: 'STORE_GRACE'),
        isTrue,
      );
    });

    test('5. Suspended store freezes order creation, writes, and sync pull',
        () async {
      final suspendedEntitlement = StoreEntitlement.create(
        storeId: 'STORE_SUSPENDED',
        plan: PlanTier.standard,
        status: PlanStatus.suspended,
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
      );
      await service.updateEntitlement(suspendedEntitlement);

      expect(
          service.planStatus('STORE_SUSPENDED'), equals(PlanStatus.suspended));
      expect(
        service.canPerformAction('create_order', storeId: 'STORE_SUSPENDED'),
        isFalse,
      );
      expect(
        service.canPerformAction('add_inventory', storeId: 'STORE_SUSPENDED'),
        isFalse,
      );
      expect(
        service.getBlockReason('create_order', storeId: 'STORE_SUSPENDED'),
        contains('Store account is suspended'),
      );

      // PlanSyncPolicy blocks inbound pull for suspended store
      final policy = PlanSyncPolicy();
      final shouldPull = await policy.shouldPullInbound(
        storeId: 'STORE_SUSPENDED',
        userRole: 'Store Owner',
        syncFrequency: 'LIVE',
        lastSyncTime: null,
        forceManual: false,
      );
      expect(shouldPull, isFalse);

      // Throws on checkOrderLimit
      expect(
        () => service.checkOrderLimit('STORE_SUSPENDED'),
        throwsA(isA<PlanLimitExceededException>()),
      );
    });

    test('6. Addon enabled unlocks feature and alias mapping', () async {
      final entitlement = StoreEntitlement.create(
        storeId: 'STORE_ADDON',
        plan: PlanTier.basic,
        status: PlanStatus.active,
        addons: {'customer_management', 'kds_management', 'data_center'},
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
      );
      await service.updateEntitlement(entitlement);

      expect(service.hasAddon('data_center', storeId: 'STORE_ADDON'), isTrue);
      expect(
          service.hasAddon('kds_management', storeId: 'STORE_ADDON'), isTrue);

      // Check aliases: 'crm' -> 'customer_management', 'kds' -> 'kds_management'
      expect(service.isFeatureEnabled('crm', storeId: 'STORE_ADDON'), isTrue);
      expect(service.isFeatureEnabled('kds', storeId: 'STORE_ADDON'), isTrue);
      expect(service.canPerformAction('sync_cloud', storeId: 'STORE_ADDON'),
          isTrue);
    });

    test(
        '7. Addon disabled blocks access and provides descriptive block reason',
        () async {
      final entitlement = StoreEntitlement.create(
        storeId: 'STORE_NO_ADDON',
        plan: PlanTier.basic,
        status: PlanStatus.active,
        addons: {}, // No addons
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
      );
      await service.updateEntitlement(entitlement);

      expect(
          service.hasAddon('data_center', storeId: 'STORE_NO_ADDON'), isFalse);
      expect(service.canPerformAction('sync_cloud', storeId: 'STORE_NO_ADDON'),
          isFalse);
      expect(
        service.getBlockReason('sync_cloud', storeId: 'STORE_NO_ADDON'),
        contains("requires 'Data Center' addon or Standard plan"),
      );
    });

    test(
        '8. Quota reached throws PlanLimitExceededException and fires PlanLimitReachedEvent',
        () async {
      final entitlement = StoreEntitlement.create(
        storeId: 'STORE_QUOTA',
        plan: PlanTier.basic,
        status: PlanStatus.active,
        addons: {},
        limits: {
          'orders': 100,
          'dailyOrders': 3, // Low limit for test
          'monthlyOrders': 1000,
        },
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
      );
      await service.updateEntitlement(entitlement);

      // Insert 3 orders today into SQLite
      final now = DateTime.now();
      final dateStr = now.toIso8601String();
      for (int i = 0; i < 3; i++) {
        await db.insert('orders', {
          'id': 'ord_quota_$i',
          'storeId': 'STORE_QUOTA',
          'date': dateStr,
          'total': 100.0,
          'subtotal': 90.0,
          'status': 'COMPLETED',
          'syncStatus': 'CONFIRMED',
        });
      }

      PlanLimitReachedEvent? capturedEvent;
      final sub = EventBus.instance.on<PlanLimitReachedEvent>((evt) {
        capturedEvent = evt;
      });

      expect(
        () => service.checkOrderLimit('STORE_QUOTA'),
        throwsA(isA<PlanLimitExceededException>()),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.storeId, equals('STORE_QUOTA'));
      expect(capturedEvent!.maxAllowed, equals(3));
      expect(capturedEvent!.currentCount, equals(3));

      sub.cancel();
    });

    test(
        '9. Malicious client tampering with local Hive cache is detected and reverted to basic',
        () async {
      const storeId = 'STORE_TAMPER';
      final legitimate = StoreEntitlement.create(
        storeId: storeId,
        plan: PlanTier.basic,
        status: PlanStatus.active,
        addons: {},
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
      );
      await service.updateEntitlement(legitimate);

      // Verify legitimate entitlement
      expect(service.currentPlan(storeId), equals(PlanTier.basic));

      // Simulate malicious client or rooted device modifying raw Hive storage
      // to grant Enterprise tier without valid cryptographic hash
      final box = Hive.box(EntitlementService.boxName);
      final rawMap = Map<String, dynamic>.from(box.get(storeId) as Map);
      rawMap['plan'] = 'Enterprise';
      rawMap['features'] = ['*'];
      rawMap['limits'] = {'orders': -1};
      // Note: tamperHash is NOT updated to match Enterprise!
      await box.put(storeId, rawMap);

      // Clear memory cache to force reload from corrupted Hive box
      final reloadedEntitlement = service.getEntitlement(storeId);

      // Anti-Bypass check: integrity failure triggers safe fallback to basic
      expect(reloadedEntitlement.plan, equals(PlanTier.basic));
      expect(reloadedEntitlement.features.contains('*'), isFalse);
    });

    test('10. Offline entitlement cache survives and recovers across restarts',
        () async {
      const storeId = 'STORE_OFFLINE_CACHE';
      final original = StoreEntitlement.create(
        storeId: storeId,
        plan: PlanTier.standard,
        status: PlanStatus.active,
        addons: {'customer_management'},
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
        version: 5,
      );
      await service.updateEntitlement(original);

      // Simulate app kill / restart: close Hive and reopen
      await Hive.box(EntitlementService.boxName).close();
      await Hive.openBox(EntitlementService.boxName);

      // Create new instance simulating cold boot
      final newService = EntitlementService(repository: repo);
      final recovered = newService.getEntitlement(storeId);

      expect(recovered.storeId, equals(storeId));
      expect(recovered.plan, equals(PlanTier.standard));
      expect(recovered.addons.contains('customer_management'), isTrue);
      expect(recovered.version, equals(5));
      expect(recovered.verifyIntegrity(), isTrue);
    });

    test(
        '11. Reconnect after expiration preserves existing offline sales and financial ledgers',
        () async {
      const storeId = 'STORE_OFFLINE_SALES';

      // 1. Store was active when sale occurred offline
      final outboxStore = OutboxStore(
        getQueueBox: () => Hive.box(OutboxStore.primaryQueueBox),
        getFailedQueueBox: () => Hive.box(OutboxStore.deadLetterBox),
        getRepository: () => repo,
      );

      const orderId = 'ord_offline_sales_99';
      final now = DateTime.now();

      // Insert valid sale into SQLite
      await db.insert('orders', {
        'id': orderId,
        'storeId': storeId,
        'date': now.toIso8601String(),
        'total': 250.0,
        'subtotal': 225.0,
        'status': 'COMPLETED',
        'syncStatus': 'PENDING',
      });

      // Seed inventory catalog item to satisfy foreign key
      await db.insert('inventory', {
        'id': 'ITEM_MILK_01',
        'storeId': storeId,
        'name': 'Fresh Milk 1L',
        'category': 'Dairy',
        'price': 60.0,
        'quantity': 10,
        'status': 'Active',
      });

      // Insert corresponding stock deduction movement
      await db.insert('inventory_movements', {
        'id': 'mvt_offline_99',
        'storeId': storeId,
        'itemId': 'ITEM_MILK_01',
        'orderId': orderId,
        'type': 'SALE',
        'delta': -2,
        'cost': 50.0,
        'reason': 'Customer offline purchase',
        'deviceId': 'DEV_01',
        'createdAt': now.toIso8601String(),
        'syncStatus': 'PENDING',
      });

      // Enqueue to durable outbox
      final op = OutboxOperation(
        operationId: 'op_offline_sale_99',
        storeId: storeId,
        userId: 'USER_DEV',
        deviceId: 'DEV_01',
        collection: 'orders',
        entityId: orderId,
        operation: 'create',
        payload: {
          'id': orderId,
          'storeId': storeId,
          'total': 250.0,
          'offlinePermitted': true,
        },
        createdAt: now.millisecondsSinceEpoch,
        state: OutboxState.pending,
      );
      await outboxStore.enqueue(op);

      // 2. Later, when reconnecting online, subscription is expired
      final expired = StoreEntitlement.create(
        storeId: storeId,
        plan: PlanTier.basic,
        status: PlanStatus.expired,
        endDate: now.subtract(const Duration(days: 30)),
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
      );
      await service.updateEntitlement(expired);

      // 3. Verify ledger invariance:
      // Existing offline sales and movements are NEVER discarded or dropped!
      final orderRes =
          await db.query('orders', where: 'id = ?', whereArgs: [orderId]);
      expect(orderRes.isNotEmpty, isTrue);
      expect(orderRes.first['status'], equals('COMPLETED'));

      final mvtRes = await db.query('inventory_movements',
          where: 'id = ?', whereArgs: ['mvt_offline_99']);
      expect(mvtRes.isNotEmpty, isTrue);
      expect(mvtRes.first['delta'], equals(-2));

      // Outbox queue retains the operation for delivery with offlinePermitted flag
      final pendingOps = await outboxStore.getReadyOperations(storeId: storeId);
      expect(pendingOps.length, equals(1));
      expect(pendingOps.first.entityId, equals(orderId));
      expect(pendingOps.first.payload['offlinePermitted'], isTrue);
    });
  });
}
