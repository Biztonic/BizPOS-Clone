import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('entitlement_unit_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('entitlements_v1');
    await Hive.openBox('settings');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Unit Tests: Entitlement Policies & Subscription Rules', () {
    final entitlementService = EntitlementService();

    test('1. Basic Plan defaults and order limits', () {
      final basicEntitlement = StoreEntitlement.create(
        storeId: 'STORE_BASIC',
        plan: PlanTier.basic,
        status: PlanStatus.active,
        limits: EntitlementService.defaultPlanLimits[PlanTier.basic]!,
        features: EntitlementService.defaultPlanFeatures[PlanTier.basic]!,
      );
      expect(basicEntitlement.plan, PlanTier.basic);
      expect(basicEntitlement.status, PlanStatus.active);
      expect(basicEntitlement.limits['orders'], 500);
      expect(basicEntitlement.limits['employees'], 5);
      expect(basicEntitlement.features.contains('billing'), isTrue);
      expect(basicEntitlement.addons.contains('kds'), isFalse);
    });

    test('2. Enterprise tier unlocks wildcard capabilities', () {
      final enterpriseEntitlement = StoreEntitlement.create(
        storeId: 'STORE_ENT',
        plan: PlanTier.enterprise,
        status: PlanStatus.active,
        limits: const {'orders': -1, 'inventory': -1},
        features: const {'*'},
      );
      expect(enterpriseEntitlement.plan, PlanTier.enterprise);
      expect(enterpriseEntitlement.limits['orders'], -1); // Unlimited
      expect(enterpriseEntitlement.features.contains('*'), isTrue);
    });

    test(
        '3. SHA-256 tamper hash verification rejects unauthorized modifications',
        () {
      final original = StoreEntitlement.create(
        storeId: 'STORE_TAMPER',
        plan: PlanTier.basic,
        status: PlanStatus.active,
        limits: const {'orders': 500},
        features: const {'billing'},
      );
      expect(original.verifyIntegrity(), isTrue);

      // Mutate plan without updating tamperHash
      final tampered = original.copyWith(
        plan: PlanTier.enterprise,
        limits: const {'orders': -1},
      );
      expect(tampered.verifyIntegrity(), isFalse);
    });

    test('4. Grace period computation (7-day post-expiration tolerance)', () {
      final now = DateTime.now();
      final expiredTwoDaysAgo = now.subtract(const Duration(days: 2));

      final graceEntitlement = StoreEntitlement.create(
        storeId: 'STORE_GRACE',
        plan: PlanTier.standard,
        status: PlanStatus.grace,
        startDate: now.subtract(const Duration(days: 32)),
        endDate: expiredTwoDaysAgo,
        gracePeriodDays: 7,
        limits: const {'orders': 1000},
        features: const {'billing'},
      );

      expect(graceEntitlement.status, PlanStatus.grace);
      expect(graceEntitlement.isUsable, isTrue);
      expect(graceEntitlement.isInGracePeriod, isTrue);

      final expiredTenDaysAgo = now.subtract(const Duration(days: 10));
      final fullyExpiredEntitlement = StoreEntitlement.create(
        storeId: 'STORE_EXPIRED',
        plan: PlanTier.standard,
        status: PlanStatus.expired,
        startDate: now.subtract(const Duration(days: 40)),
        endDate: expiredTenDaysAgo,
        gracePeriodDays: 7,
        limits: const {'orders': 1000},
        features: const {'billing'},
      );

      expect(fullyExpiredEntitlement.status, PlanStatus.expired);
      expect(fullyExpiredEntitlement.isUsable, isFalse);
      expect(fullyExpiredEntitlement.isExpired, isTrue);
    });

    test('5. Addon alias resolution in EntitlementService', () async {
      final customEntitlement = StoreEntitlement.create(
        storeId: 'STORE_ADDONS',
        plan: PlanTier.standard,
        status: PlanStatus.active,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 30)),
        addons: const {'kds_management', 'customer_management'},
        limits: const {'orders': 1000},
        features: const {'billing'},
      );
      await entitlementService.updateEntitlement(customEntitlement);

      // Test alias resolution
      expect(
          entitlementService.isFeatureEnabled('kds', storeId: 'STORE_ADDONS'),
          isTrue);
      expect(
          entitlementService.isFeatureEnabled('kds_management',
              storeId: 'STORE_ADDONS'),
          isTrue);
      expect(
          entitlementService.isFeatureEnabled('crm', storeId: 'STORE_ADDONS'),
          isTrue);
      expect(
          entitlementService.isFeatureEnabled('customer_management',
              storeId: 'STORE_ADDONS'),
          isTrue);
      expect(
          entitlementService.isFeatureEnabled('ecommerce',
              storeId: 'STORE_ADDONS'),
          isFalse);
    });

    test('6. Quota check order limits', () async {
      final limitedEntitlement = StoreEntitlement.create(
        storeId: 'STORE_LIMITED',
        plan: PlanTier.basic,
        status: PlanStatus.active,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 30)),
        limits: const {'orders': 10},
        features: const {'billing'},
      );
      await entitlementService.updateEntitlement(limitedEntitlement);

      // Within limit
      expect(
        entitlementService.canPerformAction(
          'create_order',
          storeId: 'STORE_LIMITED',
          currentCount: 5,
        ),
        isTrue,
      );

      // Limit reached
      expect(
        entitlementService.canPerformAction(
          'create_order',
          storeId: 'STORE_LIMITED',
          currentCount: 10,
        ),
        isFalse,
      );
      expect(
        entitlementService.getBlockReason(
          'create_order',
          storeId: 'STORE_LIMITED',
        ),
        contains('Order limit reached'),
      );
    });
  });
}
