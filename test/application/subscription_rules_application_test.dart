import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';

void main() {
  late Directory tempDir;
  late EntitlementService entitlementService;

  const testStoreId = 'STORE_SUB_TEST_01';

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('app_sub_rules_test_');
    Hive.init(tempDir.path);
    await Hive.openBox(EntitlementService.boxName);

    entitlementService = EntitlementService();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group(
      'Application Tests: Subscription Rules & Entitlement Policy Enforcement',
      () {
    test('1. Starting plan enforces order and inventory limits strictly', () {
      final startingEntitlement = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.starting,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.starting]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.starting]!,
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      entitlementService.registerInMemory(startingEntitlement);

      // Starting plan order limit is 50
      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 49),
          isTrue);
      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 50),
          isFalse);
      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 51),
          isFalse);

      // Starting plan inventory limit is 30
      expect(
          entitlementService.canPerformAction('add_inventory',
              storeId: testStoreId, currentCount: 29),
          isTrue);
      expect(
          entitlementService.canPerformAction('add_inventory',
              storeId: testStoreId, currentCount: 30),
          isFalse);

      // Starting plan feature checks: has billing, lacks employees/tables
      expect(
          entitlementService.isFeatureEnabled('billing', storeId: testStoreId),
          isTrue);
      expect(
          entitlementService.isFeatureEnabled('employees',
              storeId: testStoreId),
          isFalse);
      expect(
          entitlementService.isFeatureEnabled('tables', storeId: testStoreId),
          isFalse);
    });

    test(
        '2. Enterprise plan allows unlimited access across all actions and features',
        () {
      final enterpriseEntitlement = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.enterprise,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.enterprise]!,
        features: {'*'},
        endDate: DateTime.now().add(const Duration(days: 365)),
      );
      entitlementService.registerInMemory(enterpriseEntitlement);

      // Extreme counts still allowed
      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 100000),
          isTrue);
      expect(
          entitlementService.canPerformAction('add_inventory',
              storeId: testStoreId, currentCount: 50000),
          isTrue);
      expect(
          entitlementService.canPerformAction('add_employee',
              storeId: testStoreId, currentCount: 1000),
          isTrue);

      // Any feature unlocked
      expect(
          entitlementService.isFeatureEnabled('advanced_analytics',
              storeId: testStoreId),
          isTrue);
      expect(entitlementService.isFeatureEnabled('kds', storeId: testStoreId),
          isTrue);
      expect(
          entitlementService.isFeatureEnabled('custom_integrations',
              storeId: testStoreId),
          isTrue);
    });

    test('3. Suspended or Cancelled subscription blocks all write actions', () {
      final suspendedEntitlement = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.standard,
        status: PlanStatus.suspended,
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
        endDate: DateTime.now().add(const Duration(days: 10)),
      );
      entitlementService.registerInMemory(suspendedEntitlement);

      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 1),
          isFalse);
      expect(
          entitlementService.canPerformAction('add_inventory',
              storeId: testStoreId, currentCount: 1),
          isFalse);

      final cancelledEntitlement = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.standard,
        status: PlanStatus.cancelled,
        limits: EntitlementService.defaultPlanLimits[PlanTier.standard]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.standard]!,
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      entitlementService.registerInMemory(cancelledEntitlement);

      expect(
          entitlementService.canPerformAction('create_order',
              storeId: testStoreId, currentCount: 1),
          isFalse);
    });

    test('4. Addon features (CRM, KDS) enabled via addons list and aliases',
        () {
      final basicWithAddons = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.basic,
        status: PlanStatus.active,
        addons: {'customer_management', 'kds_management'},
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      entitlementService.registerInMemory(basicWithAddons);

      // Verify addon direct check
      expect(
          entitlementService.hasAddon('customer_management',
              storeId: testStoreId),
          isTrue);
      expect(
          entitlementService.hasAddon('kds_management', storeId: testStoreId),
          isTrue);
      expect(
          entitlementService.hasAddon('loyalty_rewards', storeId: testStoreId),
          isFalse);

      // Verify feature aliases
      expect(entitlementService.isFeatureEnabled('crm', storeId: testStoreId),
          isTrue);
      expect(entitlementService.isFeatureEnabled('kds', storeId: testStoreId),
          isTrue);
    });

    test('5. Super Admin role bypasses feature restrictions even on basic plan',
        () {
      final basicEntitlement = StoreEntitlement.create(
        storeId: testStoreId,
        plan: PlanTier.basic,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
        endDate: DateTime.now().add(const Duration(days: 30)),
      );
      entitlementService.registerInMemory(basicEntitlement);

      // Regular Cashier user cannot access advanced reports on basic plan
      expect(
        entitlementService.isFeatureEnabled('advanced_reports',
            storeId: testStoreId, userRole: 'Cashier'),
        isFalse,
      );

      // Super Admin bypasses and accesses advanced reports
      expect(
        entitlementService.isFeatureEnabled('advanced_reports',
            storeId: testStoreId, userRole: 'Super Admin'),
        isTrue,
      );
    });
  });
}
