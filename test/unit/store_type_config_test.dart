import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/core/config/store_type_config.dart';

void main() {
  group('StoreTypeConfig - Core vs Peripheral Feature Governance', () {
    test('1. Core features are universally allowed for all store types', () {
      final sampleStoreTypes = [
        'Restaurant',
        'Grocery',
        'Retail',
        'Pharmacy',
        'Automotive',
        'CustomSpecialtyStore',
        '',
        null,
      ];

      final coreFeatures = [
        'dashboard',
        'pos',
        'inventory',
        'reports',
        'sales',
        'settings',
        'biz_store',
        'settings.store',
        'settings.users',
        'settings.products',
        'settings.tax',
        'settings.payment',
        'settings.display',
        'settings.devices',
        'settings.language',
        'settings.announcements',
        'feature.pos.quick_actions',
        'feature.pos.billing_pad',
        'dashboard.summary',
      ];

      for (final type in sampleStoreTypes) {
        for (final feature in coreFeatures) {
          final isAllowed = StoreTypeConfig.isFeatureAllowed(
            type,
            feature,
            storeTypeConfigs: {
              'StrictEmptyStore': {
                'enableKitchen': false,
                'enableTables': false,
                'enableBarcode': false,
                'enableCustomers': false,
                'enableEmployees': false,
                'enableSuppliers': false,
                'enableDataSync': false,
                'enableDietary': false,
                'enablePackaging': false,
                'enableVariants': false,
              }
            },
          );
          expect(isAllowed, isTrue,
              reason: 'Core feature "$feature" must never be restricted for store type "$type"');
        }
      }
    });

    test('2. Preset defaults match business domain requirements', () {
      // Restaurant preset has Kitchen, Tables, CRM, Staff, Suppliers, Dietary, Packaging, Variants
      final restCfg = StoreTypeConfig.getDefaultConfig('Restaurant');
      expect(restCfg['enableKitchen'], isTrue);
      expect(restCfg['enableTables'], isTrue);
      expect(restCfg['enableCustomers'], isTrue);
      expect(restCfg['enableDietary'], isTrue);
      expect(restCfg['enablePackaging'], isTrue);
      expect(restCfg['enableBarcode'], isFalse);

      // Grocery preset has Barcode, CRM, Staff, Suppliers, DataSync, but no Kitchen or Tables
      final grocCfg = StoreTypeConfig.getDefaultConfig('Grocery');
      expect(grocCfg['enableKitchen'], isFalse);
      expect(grocCfg['enableTables'], isFalse);
      expect(grocCfg['enableBarcode'], isTrue);
      expect(grocCfg['enableDataSync'], isTrue);

      // Retail preset has Barcode, CRM, Staff, Suppliers, but no Kitchen or Tables
      final retailCfg = StoreTypeConfig.getDefaultConfig('Retail');
      expect(retailCfg['enableKitchen'], isFalse);
      expect(retailCfg['enableTables'], isFalse);
      expect(retailCfg['enableBarcode'], isTrue);
    });

    test('3. Custom Superadmin store type config strictly restricts allowed peripheral features', () {
      final customConfigs = {
        'CloudKitchen': {
          'enableKitchen': true,
          'enableTables': false, // No dine-in tables
          'enableBarcode': false,
          'enableCustomers': true,
          'enableEmployees': true,
          'enableSuppliers': true,
          'enableDataSync': false,
          'enableDietary': true,
          'enablePackaging': true,
          'enableVariants': true,
        },
        'QuickMart': {
          'enableKitchen': false,
          'enableTables': false,
          'enableBarcode': true,
          'enableCustomers': true,
          'enableEmployees': true,
          'enableSuppliers': true,
          'enableDataSync': true,
          'enableDietary': false,
          'enablePackaging': false,
          'enableVariants': true,
        }
      };

      // CloudKitchen: Kitchen enabled, Tables blocked
      expect(
          StoreTypeConfig.isFeatureAllowed('CloudKitchen', 'kds',
              storeTypeConfigs: customConfigs),
          isTrue);
      expect(
          StoreTypeConfig.isFeatureAllowed('CloudKitchen', 'kds_management',
              storeTypeConfigs: customConfigs),
          isTrue);
      expect(
          StoreTypeConfig.isFeatureAllowed('CloudKitchen', 'settings.kds',
              storeTypeConfigs: customConfigs),
          isTrue);
      expect(
          StoreTypeConfig.isFeatureAllowed('CloudKitchen', 'tables',
              storeTypeConfigs: customConfigs),
          isFalse);
      expect(
          StoreTypeConfig.isFeatureAllowed(
              'CloudKitchen', 'table_reservation',
              storeTypeConfigs: customConfigs),
          isFalse);
      expect(
          StoreTypeConfig.isFeatureAllowed('CloudKitchen', 'settings.tables',
              storeTypeConfigs: customConfigs),
          isFalse);

      // QuickMart: Kitchen & Tables blocked, Barcode & DataSync allowed
      expect(
          StoreTypeConfig.isFeatureAllowed('QuickMart', 'kds',
              storeTypeConfigs: customConfigs),
          isFalse);
      expect(
          StoreTypeConfig.isFeatureAllowed('QuickMart', 'barcode_scanner',
              storeTypeConfigs: customConfigs),
          isTrue);
      expect(
          StoreTypeConfig.isFeatureAllowed('QuickMart', 'data_center',
              storeTypeConfigs: customConfigs),
          isTrue);
      expect(
          StoreTypeConfig.isFeatureAllowed('QuickMart', 'settings.datacenter',
              storeTypeConfigs: customConfigs),
          isTrue);
    });

    test('4. getAllowedFeatures returns correct list of metadata', () {
      final customConfigs = {
        'Boutique': {
          'enableKitchen': false,
          'enableTables': false,
          'enableBarcode': true,
          'enableCustomers': true,
          'enableEmployees': true,
          'enableSuppliers': true,
          'enableDataSync': false,
          'enableDietary': false,
          'enablePackaging': false,
          'enableVariants': true,
        }
      };

      final allowed = StoreTypeConfig.getAllowedFeatures('Boutique',
          storeTypeConfigs: customConfigs);
      final allowedIds = allowed.map((a) => a.id).toSet();

      expect(allowedIds.contains('kitchen'), isFalse);
      expect(allowedIds.contains('tables'), isFalse);
      expect(allowedIds.contains('dietary'), isFalse);
      expect(allowedIds.contains('packaging'), isFalse);

      expect(allowedIds.contains('barcode'), isTrue);
      expect(allowedIds.contains('customers'), isTrue);
      expect(allowedIds.contains('employees'), isTrue);
      expect(allowedIds.contains('suppliers'), isTrue);
      expect(allowedIds.contains('variants'), isTrue);
    });

    test('5. sanitizeConfig harmonizes boolean flags with canonical addon keys', () {
      final raw = {
        'enableKitchen': true,
        'enableTables': false,
        'barcode_scanner': true,
      };

      final sanitized = StoreTypeConfig.sanitizeConfig(raw);
      expect(sanitized['enableKitchen'], isTrue);
      expect(sanitized['kds_management'], isTrue);
      expect(sanitized['enableTables'], isFalse);
      expect(sanitized['table_reservation'], isFalse);
      expect(sanitized['enableBarcode'], isTrue);
      expect(sanitized['barcode_scanner'], isTrue);
    });
  });
}
