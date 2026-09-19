import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/sync/conflict/conflict_engine.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

void main() {
  group('Unit Tests: Deterministic Conflict Resolution Engine', () {
    final engine = ConflictEngine();

    test(
        '1. Inventory collection: stock divergence flags ConflictRecord without LWW overwrite',
        () {
      final cloudData = {
        'id': 'PROD_01',
        'name': 'Espresso Blend',
        'quantity': 50, // Cloud claims 50
        'price': 250.0,
        'version': 3,
      };

      final localData = {
        'id': 'PROD_01',
        'name': 'Espresso Blend',
        'quantity': 45, // Local sold 5 units offline
        'price': 250.0,
        'version': 2,
        'syncStatus': 'PENDING',
      };

      final result = engine.resolve(
        collection: SyncCollectionRegistry.inventory,
        cloudData: cloudData,
        localData: localData,
        storeId: 'STORE_01',
      );

      // Stock divergence creates a ConflictRecord and preserves local quantity
      expect(result.action, ResolutionAction.recordConflict);
      expect(result.conflictRecord, isNotNull);
      expect(result.conflictRecord!.conflictType, 'INVENTORY_STOCK_DIVERGENCE');
      expect(result.conflictRecord!.localData['quantity'], 45);
      expect(result.conflictRecord!.cloudData['quantity'], 50);
    });

    test('2. Customers collection: loyalty points are merged additively', () {
      final cloudData = {
        'id': 'CUST_01',
        'name': 'Rahul Sharma',
        'loyaltyPoints': 120, // Earned 20 on Web
        'version': 5,
      };

      final localData = {
        'id': 'CUST_01',
        'name': 'Rahul Sharma',
        'loyaltyPoints': 150, // Earned 50 offline in Store
        'version': 4,
        'syncStatus': 'PENDING',
      };

      final result = engine.resolve(
        collection: SyncCollectionRegistry.customers,
        cloudData: cloudData,
        localData: localData,
        storeId: 'STORE_01',
      );

      expect(result.action, ResolutionAction.mergeApplied);
      expect(result.mergedData, isNotNull);
      // Merged points should be maximum of both to prevent point loss
      expect(result.mergedData!['loyaltyPoints'], 150);
    });

    test(
        '3. Settings collection: tax rate divergence creates an explicit ConflictRecord',
        () {
      final cloudData = {
        'id': 'tax_settings',
        'taxRate': 18.0,
        'version': 3,
      };

      final localData = {
        'id': 'tax_settings',
        'taxRate': 12.0,
        'version': 2,
        'syncStatus': 'PENDING',
      };

      final result = engine.resolve(
        collection: SyncCollectionRegistry.settings,
        cloudData: cloudData,
        localData: localData,
        storeId: 'STORE_01',
      );

      // Financial divergence cannot be resolved automatically; must record conflict
      expect(result.action, ResolutionAction.recordConflict);
      expect(result.conflictRecord, isNotNull);
      expect(
          result.conflictRecord!.collection, SyncCollectionRegistry.settings);
      expect(result.conflictRecord!.conflictType, 'TAX_RATE_DIVERGENCE');
    });

    test('4. Employees collection: preserves higher privilege role rank', () {
      final cloudData = {
        'id': 'EMP_01',
        'role': 'Cashier',
        'status': 'ACTIVE',
        'version': 3,
      };

      final localData = {
        'id': 'EMP_01',
        'role': 'Manager', // Promoted locally (rank 3 > rank 2)
        'status': 'ACTIVE',
        'version': 2,
        'syncStatus': 'PENDING',
      };

      final result = engine.resolve(
        collection: SyncCollectionRegistry.employees,
        cloudData: cloudData,
        localData: localData,
        storeId: 'STORE_01',
      );

      // Higher privilege Manager role wins
      expect(result.action, ResolutionAction.localWins);
    });

    test(
        '5. Immutable financial ledgers: local append wins to prevent re-writes',
        () {
      final cloudData = {
        'id': 'MOV_100',
        'delta': -2,
        'version': 1,
      };

      final localData = {
        'id': 'MOV_100',
        'delta': -2,
        'version': 1,
        'syncStatus': 'PENDING',
      };

      final result = engine.resolve(
        collection: SyncCollectionRegistry.inventoryMovements,
        cloudData: cloudData,
        localData: localData,
        storeId: 'STORE_01',
      );

      expect(result.action, ResolutionAction.localWins);
    });
  });
}
