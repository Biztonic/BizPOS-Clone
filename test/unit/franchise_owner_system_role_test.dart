import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/services/offline_service.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/models/store.dart';
import 'package:biztonic_pos/models/user_profile.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    OfflineService.isTesting = true;
    tempDir = await Directory.systemTemp.createTemp('franchise_role_test_');
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

  group('System Role - Franchise Owner Definitions & Safeguards', () {
    test('Exactly 3 built-in system roles: Super Admin, Store Owner, Franchise Owner', () {
      final systemRoles = StoreProvider.defaultSystemRoles;
      final roleNames = systemRoles.map((r) => r.name).toList();

      expect(systemRoles.length, equals(3));
      expect(roleNames, containsAll(['Super Admin', 'Store Owner', 'Franchise Owner']));
      expect(roleNames, isNot(contains('Admin')));
      expect(roleNames, isNot(contains('Manager')));
      expect(roleNames, isNot(contains('Cashier')));

      final franchiseRole = systemRoles.firstWhere((r) => r.name == 'Franchise Owner');
      expect(franchiseRole.isSystem, isTrue);
      expect(franchiseRole.storeAccessMode, equals('franchise'));
      expect(franchiseRole.permissions['multi_store'], isTrue);
      expect(franchiseRole.permissions['pos'], isTrue);
      expect(franchiseRole.permissions['inventory'], isTrue);

      expect(StoreProvider.isSystemRoleName('Super Admin'), isTrue);
      expect(StoreProvider.isSystemRoleName('Store Owner'), isTrue);
      expect(StoreProvider.isSystemRoleName('Franchise Owner'), isTrue);
      expect(StoreProvider.isSystemRoleName('Admin'), isFalse);
      expect(StoreProvider.isSystemRoleName('Manager'), isFalse);
      expect(StoreProvider.isSystemRoleName('Cashier'), isFalse);
    });

    test('StoreProvider.roles is pre-populated at startup and never empty (prevents hanging UI)', () {
      final provider = StoreProvider(SyncService());
      expect(provider.roles.length, equals(3));
      expect(provider.roles.any((r) => r.name == 'Franchise Owner'), isTrue);
      expect(provider.roles.any((r) => r.name == 'Super Admin'), isTrue);
      expect(provider.roles.any((r) => r.name == 'Store Owner'), isTrue);
      expect(provider.isRolesLoading, isFalse);
    });

    test('System roles (Super Admin, Franchise Owner, Store Owner) cannot be deleted', () async {
      final provider = StoreProvider(SyncService());

      expect(
        () => provider.deleteRole('super_admin'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('System roles cannot be deleted'))),
      );

      expect(
        () => provider.deleteRole('franchise_owner'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('System roles cannot be deleted'))),
      );

      expect(
        () => provider.deleteRole('store_owner'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('System roles cannot be deleted'))),
      );
    });
  });

  group('Franchise Addon Purchase & Multi-Store Creation Workflow', () {
    late DashboardProvider dashboard;

    setUp(() {
      dashboard = DashboardProvider();
    });

    test('Store Owner with 1 store cannot create multiple stores', () {
      dashboard.setUserProfileForTesting(UserProfile(
        uid: 'user_shop_1',
        email: 'user@shop.com',
        name: 'Single Store Owner',
        role: 'Store Owner',
        storeId: 'store_alpha',
        accessibleStoreIds: ['store_alpha'],
      ));
      dashboard.setStoresForTesting([
        Store.fromMap({
          'name': 'Alpha Store',
          'owner': 'user_shop_1',
          'ownerEmail': 'user@shop.com',
          'status': 'Active',
          'subscriptionPlan': 'Standard',
          'addons': <String>[],
          'purchasedAddons': <String>[],
        }, 'store_alpha'),
      ]);

      expect(dashboard.activeRole, equals('Store Owner'));
      expect(dashboard.canCreateAdditionalStore, isFalse);
      expect(dashboard.isMultiStoreEligible, isFalse);
    });

    test('When promoted to Franchise Owner and having Franchise Addon, multi-store is unlocked', () {
      // User is now Franchise Owner with franchise addon
      dashboard.setUserProfileForTesting(UserProfile(
        uid: 'user_franchise_1',
        email: 'franchise@brand.com',
        name: 'Brand Franchise Owner',
        role: 'Franchise Owner',
        franchiseId: 'user_franchise_1',
        franchiseCode: '987654',
        storeId: 'store_hq',
        accessibleStoreIds: ['store_hq'],
      ));
      dashboard.setStoresForTesting([
        Store.fromMap({
          'name': 'HQ Store',
          'owner': 'user_franchise_1',
          'ownerEmail': 'franchise@brand.com',
          'status': 'Active',
          'subscriptionPlan': 'Standard',
          'addons': ['franchise_management'],
          'purchasedAddons': ['franchise_management'],
        }, 'store_hq'),
      ]);

      expect(dashboard.activeRole, equals('Franchise Owner'));
      expect(dashboard.hasFranchiseAddon, isTrue);
      expect(dashboard.canCreateAdditionalStore, isTrue);
      expect(dashboard.isMultiStoreEligible, isTrue);
      expect(dashboard.storeCreationRestrictionReason, isNull);
    });
  });
}
