import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/core/config/plan_config.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_model.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/services/offline_service.dart';
import 'package:biztonic_pos/models/store.dart';
import 'package:biztonic_pos/models/user_profile.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    OfflineService.isTesting = true;
    tempDir = await Directory.systemTemp.createTemp('multi_store_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  group('PlanConfig & Entitlement Limits - Multi-Store Rules', () {
    test('PlanConfig limits stores to 1 for Standard and Professional plans', () {
      expect(PlanConfig.standardMaxStores, equals(1));
      expect(PlanConfig.getLimit(PlanConfig.planStandard, 'stores'), equals(1));
      expect(PlanConfig.getLimit(PlanConfig.planProfessional, 'stores'), equals(1));
      expect(PlanConfig.getLimit(PlanConfig.planBasic, 'stores'), equals(1));
      expect(PlanConfig.getLimit(PlanConfig.planStarting, 'stores'), equals(1));
    });

    test('PlanConfig does not include multi_store as generic plan feature', () {
      expect(PlanConfig.isFeatureAvailable(PlanConfig.planProfessional, 'multi_store'), isFalse);
      expect(PlanConfig.isFeatureAvailable(PlanConfig.planStandard, 'multi_store'), isFalse);
    });

    test('EntitlementService default limits set stores to 1 for Standard and Professional', () {
      expect(EntitlementService.defaultPlanLimits[PlanTier.starting]?['stores'], equals(1));
      expect(EntitlementService.defaultPlanLimits[PlanTier.basic]?['stores'], equals(1));
      expect(EntitlementService.defaultPlanLimits[PlanTier.standard]?['stores'], equals(1));
      expect(EntitlementService.defaultPlanLimits[PlanTier.professional]?['stores'], equals(1));
    });

    test('EntitlementService default features do not include multi_store in Professional', () {
      expect(
        EntitlementService.defaultPlanFeatures[PlanTier.professional]?.contains('multi_store'),
        isFalse,
      );
    });

    test('EntitlementService.isFeatureEnabled for multi_store checks role and franchise addon', () {
      final service = EntitlementService.instance;
      const storeId = 'test_store_multi_1';

      // Register store entitlement without franchise_management
      final entitlementBasic = StoreEntitlement.create(
        storeId: storeId,
        plan: PlanTier.standard,
        status: PlanStatus.active,
        limits: const {'stores': 1},
        features: const {'pos'},
        addons: {'billing'},
        purchasedAddons: {'billing'},
      );
      service.registerInMemory(entitlementBasic);

      // Store Owner can NEVER have multi_store
      expect(
        service.isFeatureEnabled('multi_store', storeId: storeId, userRole: 'Store Owner'),
        isFalse,
      );

      // Other non-franchise roles can NEVER have multi_store
      expect(
        service.isFeatureEnabled('multi_store', storeId: storeId, userRole: 'Admin'),
        isFalse,
      );
      expect(
        service.isFeatureEnabled('multi_store', storeId: storeId, userRole: 'Cashier'),
        isFalse,
      );

      // Franchise Owner without franchise_management addon is FALSE
      expect(
        service.isFeatureEnabled('multi_store', storeId: storeId, userRole: 'Franchise Owner'),
        isFalse,
      );

      // Super Admin is always TRUE
      expect(
        service.isFeatureEnabled('multi_store', storeId: storeId, userRole: 'Super Admin'),
        isTrue,
      );

      // Now register entitlement with franchise_management addon
      final entitlementWithFranchise = StoreEntitlement.create(
        storeId: storeId,
        plan: PlanTier.standard,
        status: PlanStatus.active,
        limits: const {'stores': 1},
        features: const {'pos'},
        addons: {'franchise_management'},
        purchasedAddons: {'franchise_management'},
      );
      service.registerInMemory(entitlementWithFranchise);

      // Franchise Owner with franchise_management is TRUE
      expect(
        service.isFeatureEnabled('multi_store', storeId: storeId, userRole: 'Franchise Owner'),
        isTrue,
      );

      // Store Owner is STILL FALSE even if store has the addon!
      expect(
        service.isFeatureEnabled('multi_store', storeId: storeId, userRole: 'Store Owner'),
        isFalse,
      );
    });
  });

  group('DashboardProvider - Multi-Store & Store Creation Predicates', () {
    late DashboardProvider provider;

    setUp(() {
      provider = DashboardProvider();
    });

    test('Initial onboarding: any business owner with 0 stores can create first store', () {
      expect(provider.stores.isEmpty, isTrue);
      expect(provider.canCreateAdditionalStore, isTrue);
    });

    test('Store Owner with >= 1 store cannot create additional stores and is not multi-store eligible', () {
      // Setup Store Owner with 1 store
      provider.setUserProfileForTesting(UserProfile(
        uid: 'user_store_owner_1',
        email: 'owner@shop.com',
        name: 'Shop Owner',
        role: 'Store Owner',
        storeId: 'store_1',
        accessibleStoreIds: ['store_1'],
      ));
      provider.setStoresForTesting([
        Store.fromMap({
          'name': 'Main Store',
          'owner': 'user_store_owner_1',
          'ownerEmail': 'owner@shop.com',
          'status': 'Active',
          'subscriptionPlan': 'Professional',
          'addons': ['franchise_management'], // Even if addon was added, Store Owner is restricted
          'purchasedAddons': ['franchise_management'],
        }, 'store_1'),
      ]);

      expect(provider.activeRole, equals('Store Owner'));
      expect(provider.isMultiStoreEligible, isFalse);
      expect(provider.canCreateAdditionalStore, isFalse);
      expect(provider.storeCreationRestrictionReason, contains('Store Owners cannot add more than one store'));

      // Attempting to addStore should throw Exception
      expect(
        () => provider.addStore('Second Store', 'owner@shop.com'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Store Owners cannot add more than one store'),
        )),
      );
    });

    test('Franchise Owner without Franchise Addon cannot create additional stores', () {
      // Setup Franchise Owner with 1 store, NO franchise_management addon
      provider.setUserProfileForTesting(UserProfile(
        uid: 'user_franchise_1',
        email: 'franchise@chain.com',
        name: 'Chain Owner',
        role: 'Franchise Owner',
        franchiseId: 'user_franchise_1',
        franchiseCode: '123456',
        storeId: 'f_store_1',
        accessibleStoreIds: ['f_store_1'],
      ));
      provider.setStoresForTesting([
        Store.fromMap({
          'name': 'Franchise Outlet 1',
          'owner': 'user_franchise_1',
          'ownerEmail': 'franchise@chain.com',
          'status': 'Active',
          'subscriptionPlan': 'Standard',
          'addons': ['billing'],
          'purchasedAddons': ['billing'],
        }, 'f_store_1'),
      ]);

      expect(provider.activeRole, equals('Franchise Owner'));
      expect(provider.hasFranchiseAddon, isFalse);
      expect(provider.isMultiStoreEligible, isFalse);
      expect(provider.canCreateAdditionalStore, isFalse);
      expect(provider.storeCreationRestrictionReason, contains('Franchise Add-on'));

      // Attempting to addStore should throw Exception requiring Franchise Addon
      expect(
        () => provider.addStore('Franchise Outlet 2', 'franchise@chain.com'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Franchise Add-on'),
        )),
      );

      // Attempting to addExistingStoreToFranchise should also throw
      expect(
        () => provider.addExistingStoreToFranchise(
          email: 'partner@shop.com',
          password: 'secretPassword',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Franchise Add-on'),
        )),
      );
    });

    test('Franchise Owner WITH Franchise Addon has multi-store capability unlocked', () {
      provider.setUserProfileForTesting(UserProfile(
        uid: 'user_franchise_1',
        email: 'franchise@chain.com',
        name: 'Chain Owner',
        role: 'Franchise Owner',
        franchiseId: 'user_franchise_1',
        franchiseCode: '123456',
        storeId: 'f_store_1',
        accessibleStoreIds: ['f_store_1'],
      ));
      provider.setStoresForTesting([
        Store.fromMap({
          'name': 'Franchise Outlet 1',
          'owner': 'user_franchise_1',
          'ownerEmail': 'franchise@chain.com',
          'status': 'Active',
          'subscriptionPlan': 'Standard',
          'addons': ['franchise_management'],
          'purchasedAddons': ['franchise_management'],
        }, 'f_store_1'),
      ]);

      expect(provider.activeRole, equals('Franchise Owner'));
      expect(provider.hasFranchiseAddon, isTrue);
      expect(provider.isMultiStoreEligible, isTrue);
      expect(provider.canCreateAdditionalStore, isTrue);
      expect(provider.storeCreationRestrictionReason, isNull);
    });

    test('Super Admin always has full multi-store capability', () {
      provider.setUserProfileForTesting(UserProfile(
        uid: 'user_super_admin',
        email: 'superadmin@bizpos.com',
        name: 'Super Admin',
        role: 'Super Admin',
      ));
      provider.setStoresForTesting([
        Store.fromMap({
          'name': 'Store 1',
          'owner': 'someone',
          'ownerEmail': 'someone@mail.com',
        }, 'store_1'),
      ]);

      expect(provider.isSuperAdmin, isTrue);
      expect(provider.isMultiStoreEligible, isTrue);
      expect(provider.canCreateAdditionalStore, isTrue);
      expect(provider.storeCreationRestrictionReason, isNull);
    });
  });
}
