import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Server-Authoritative Entitlements, Quotas & Anti-Tampering Test Suite',
      () {
    final testDbName =
        'test_auth_entitlement_${DateTime.now().millisecondsSinceEpoch}.db';
    late Directory tempDir;
    late Repository repo;
    late Database db;
    late EntitlementService service;

    const testStoreId = 'STORE_SECURE_AUTH_01';

    setUp(() async {
      DatabaseHelper.setDbName(testDbName);
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, testDbName);
      if (File(path).existsSync()) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }

      tempDir = Directory.systemTemp.createTempSync('hive_auth_entitlement_');
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

    test('1. Modified client cannot upgrade itself by editing local Hive cache',
        () async {
      // Establish legitimate Basic tier
      final legitimate = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.basic,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
        addons: {},
        purchasedAddons: {},
      );
      await service.updateEntitlement(legitimate);

      expect(service.currentPlan(testStoreId), equals(PlanTier.basic));
      expect(service.canPerformAction('multi_store', storeId: testStoreId),
          isFalse);

      // Attack scenario: Client modifies local Hive storage to claim Enterprise tier
      final box = Hive.box(EntitlementService.boxName);
      final rawData = Map<String, dynamic>.from(box.get(testStoreId) as Map);
      rawData['plan'] = 'Enterprise';
      rawData['features'] = ['*'];
      rawData['limits'] = {'orders': -1, 'inventory': -1};
      // Note: tamperHash is NOT valid for this forged payload
      await box.put(testStoreId, rawData);

      // Force reload from corrupted cache
      final evaluated = service.getEntitlement(testStoreId);

      // Verification: Tamper detected -> Reverts to safe baseline (Basic plan)
      expect(evaluated.plan, equals(PlanTier.basic));
      expect(evaluated.features.contains('*'), isFalse);
      expect(service.canPerformAction('multi_store', storeId: testStoreId),
          isFalse);
    });

    test(
        '2. Expired subscription past grace cannot access mutations, but offline grace functions normally',
        () async {
      const graceStoreId = 'STORE_GRACE_LIFECYCLE';
      final now = DateTime.now();

      // Case A: Within Grace Period (Expired 2 days ago, 7 day grace)
      final graceEntitlement = StoreEntitlement.create(
        storeId: graceStoreId,
        plan: PlanTier.standard,
        status: PlanStatus.active,
        startDate: now.subtract(const Duration(days: 32)),
        endDate: now.subtract(const Duration(days: 2)),
        gracePeriodDays: 7,
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
      );
      await service.updateEntitlement(graceEntitlement);

      final graceEval = service.getEntitlement(graceStoreId);
      expect(graceEval.status, equals(PlanStatus.grace));
      expect(graceEval.isUsable, isTrue);
      expect(graceEval.isInGracePeriod, isTrue);
      // Legitimate offline POS billing is NOT interrupted
      expect(service.canPerformAction('create_order', storeId: graceStoreId),
          isTrue);

      // Case B: Past Grace Period (Expired 10 days ago, 7 day grace)
      final expiredEntitlement = StoreEntitlement.create(
        storeId: graceStoreId,
        plan: PlanTier.standard,
        status: PlanStatus.active,
        startDate: now.subtract(const Duration(days: 40)),
        endDate: now.subtract(const Duration(days: 10)),
        gracePeriodDays: 7,
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
      );
      await service.updateEntitlement(expiredEntitlement);

      final expiredEval = service.getEntitlement(graceStoreId);
      expect(expiredEval.status, equals(PlanStatus.expired));
      expect(expiredEval.isUsable, isFalse);
      expect(service.canPerformAction('create_order', storeId: graceStoreId),
          isFalse);
      expect(service.canPerformAction('sync_cloud', storeId: graceStoreId),
          isFalse);
      expect(
        service.getBlockReason('create_order', storeId: graceStoreId),
        contains('Subscription has expired'),
      );
    });

    test(
        '3. Addon entitlement cannot be forged locally without server purchase',
        () async {
      const addonStoreId = 'STORE_ADDON_TAMPER';
      final legitimate = StoreEntitlement.create(
        storeId: addonStoreId,
        plan: PlanTier.basic,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
        addons: {'customer_management'},
        purchasedAddons: {'customer_management'}, // Only crm is purchased
      );
      await service.updateEntitlement(legitimate);

      // Allowed purchased addon
      expect(service.hasAddon('customer_management', storeId: addonStoreId),
          isTrue);
      // Unpurchased addon is rejected
      expect(
          service.hasAddon('kds_management', storeId: addonStoreId), isFalse);

      // Attack: Attempt to sync unpurchased addons from local store object
      await service.syncFromStore(
        storeId: addonStoreId,
        planName: 'Basic',
        status: 'ACTIVE',
        addons: [
          'customer_management',
          'kds_management',
          'franchise_management'
        ],
      );

      final afterSync = service.getEntitlement(addonStoreId);
      // Unpurchased addons filtered out by defensive sync
      expect(afterSync.addons.contains('kds_management'), isFalse);
      expect(afterSync.addons.contains('franchise_management'), isFalse);
      expect(afterSync.addons.contains('customer_management'), isTrue);
    });

    test('4. Quota enforcement: Order limit cannot be bypassed', () async {
      const quotaStoreId = 'STORE_ORDER_QUOTA';
      final entitlement = StoreEntitlement.create(
        storeId: quotaStoreId,
        plan: PlanTier.starting,
        status: PlanStatus.active,
        limits: {
          'orders': 50,
          'dailyOrders': 2,
          'monthlyOrders': 50,
        },
        features: EntitlementService.defaultPlanFeatures[PlanTier.starting]!,
      );
      await service.updateEntitlement(entitlement);

      final now = DateTime.now();
      final dateStr = now.toIso8601String();

      // Seed 2 orders today
      for (int i = 0; i < 2; i++) {
        await db.insert('orders', {
          'id': 'ord_q_$i',
          'storeId': quotaStoreId,
          'date': dateStr,
          'total': 150.0,
          'subtotal': 140.0,
          'status': 'COMPLETED',
          'syncStatus': 'CONFIRMED',
        });
      }

      // Check order limit throws PlanLimitExceededException
      expect(
        () => service.checkOrderLimit(quotaStoreId),
        throwsA(isA<PlanLimitExceededException>()),
      );
    });

    test(
        '5. Quota enforcement: Catalog, Customer, and Employee limits cannot be bypassed',
        () async {
      const catalogStoreId = 'STORE_CATALOG_QUOTA';
      final entitlement = StoreEntitlement.create(
        storeId: catalogStoreId,
        plan: PlanTier.starting,
        status: PlanStatus.active,
        limits: {
          'inventory': 5,
          'customers': 3,
          'employees': 2,
        },
        features: EntitlementService.defaultPlanFeatures[PlanTier.starting]!,
      );
      await service.updateEntitlement(entitlement);

      // Inventory check
      expect(
        () => service.checkInventoryQuota(catalogStoreId, currentCount: 5),
        throwsA(isA<PlanLimitExceededException>()),
      );
      expect(
        () => service.checkInventoryQuota(catalogStoreId, currentCount: 4),
        returnsNormally,
      );

      // Customer check
      expect(
        () => service.checkCustomerQuota(catalogStoreId, currentCount: 3),
        throwsA(isA<PlanLimitExceededException>()),
      );
      expect(
        () => service.checkCustomerQuota(catalogStoreId, currentCount: 2),
        returnsNormally,
      );

      // Employee check
      expect(
        () => service.checkEmployeeQuota(catalogStoreId, currentCount: 2),
        throwsA(isA<PlanLimitExceededException>()),
      );
      expect(
        () => service.checkEmployeeQuota(catalogStoreId, currentCount: 1),
        returnsNormally,
      );
    });

    test(
        '6. Offline resilience: Temporary network outage does NOT downgrade plan or drop queued sales',
        () async {
      const offlineStoreId = 'STORE_OFFLINE_RESILIENCE';
      final now = DateTime.now();

      // Store is in active state with 30 days remaining
      final activeEntitlement = StoreEntitlement.create(
        storeId: offlineStoreId,
        plan: PlanTier.standard,
        status: PlanStatus.active,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        gracePeriodDays: 7,
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
      );
      await service.updateEntitlement(activeEntitlement);

      // Simulate network disconnection: local cache maintains full usability
      expect(service.isSubscribed(offlineStoreId), isTrue);
      expect(service.canPerformAction('create_order', storeId: offlineStoreId),
          isTrue);

      // Queue an offline order in outbox
      final outboxStore = OutboxStore(
        getQueueBox: () => Hive.box(OutboxStore.primaryQueueBox),
        getFailedQueueBox: () => Hive.box(OutboxStore.deadLetterBox),
        getRepository: () => repo,
      );

      final op = OutboxOperation(
        operationId: 'op_offline_resilience_01',
        storeId: offlineStoreId,
        userId: 'CASHIER_OFFLINE',
        deviceId: 'TERMINAL_01',
        collection: 'orders',
        entityId: 'ORD_OFFLINE_01',
        operation: 'create',
        payload: {
          'id': 'ORD_OFFLINE_01',
          'storeId': offlineStoreId,
          'total': 500.0,
          'offlinePermitted': true,
        },
        createdAt: now.millisecondsSinceEpoch,
        state: OutboxState.pending,
      );
      await outboxStore.enqueue(op);

      // Verify outbox retains operation in pending state ready for reconnect
      final readyOps =
          await outboxStore.getReadyOperations(storeId: offlineStoreId);
      expect(readyOps.length, equals(1));
      expect(readyOps.first.entityId, equals('ORD_OFFLINE_01'));
      expect(readyOps.first.payload['offlinePermitted'], isTrue);
    });

    test(
        '7. Store Owner on Basic and Standard plans receives full canonical sidebar menu entitlements',
        () async {
      const basicStoreId = 'STORE_NEW_BASIC_OWNER';
      await service.syncFromStore(
        storeId: basicStoreId,
        planName: 'Basic',
        status: 'ACTIVE',
        addons: [],
        purchasedAddons: [],
        fromServer: true,
      );

      for (final coreKey in [
        'dashboard',
        'pos',
        'inventory',
        'reports',
        'sales',
        'settings',
        'biz_store',
        'customer_management',
        'crm',
      ]) {
        expect(
          service.isFeatureEnabled(coreKey,
              storeId: basicStoreId, userRole: 'Store Owner'),
          isTrue,
          reason: 'Basic plan Store Owner must have $coreKey enabled',
        );
      }

      const standardStoreId = 'STORE_EXISTING_STANDARD_OWNER';
      await service.syncFromStore(
        storeId: standardStoreId,
        planName: 'Standard',
        status: 'ACTIVE',
        addons: ['kds_management', 'table_reservation', 'employee_management'],
        purchasedAddons: [
          'kds_management',
          'table_reservation',
          'employee_management'
        ],
        fromServer: true,
      );

      expect(service.currentPlan(standardStoreId), equals(PlanTier.standard));
      for (final stdKey in [
        'dashboard',
        'pos',
        'inventory',
        'reports',
        'sales',
        'settings',
        'biz_store',
        'customer_management',
        'employee_management',
        'table_reservation',
        'supplier_management',
        'kds_management',
        'data_center',
      ]) {
        expect(
          service.isFeatureEnabled(stdKey,
              storeId: standardStoreId, userRole: 'Store Owner'),
          isTrue,
          reason: 'Standard plan Store Owner must have $stdKey enabled',
        );
      }
    });
  });
}
