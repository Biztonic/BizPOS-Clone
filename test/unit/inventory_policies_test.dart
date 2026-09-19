import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_entity.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';

void main() {
  group('Unit Tests: Inventory Policies & Stock Invariants', () {
    test(
        '1. NegativeStockPolicy.block throws InsufficientStockException on negative projection',
        () {
      expect(
        () => InventoryPolicy.validateMovementDelta(
          itemId: 'ITEM_LAPTOP',
          storeId: 'STORE_01',
          currentStock: 2,
          delta: -5,
          policy: NegativeStockPolicy.block,
        ),
        throwsA(isA<InsufficientStockException>()),
      );
    });

    test(
        '2. NegativeStockPolicy.allowWithWarning and allow permit negative projections',
        () {
      // allowWithWarning should not throw
      expect(
        () => InventoryPolicy.validateMovementDelta(
          itemId: 'ITEM_CABLE',
          storeId: 'STORE_01',
          currentStock: 1,
          delta: -3,
          policy: NegativeStockPolicy.allowWithWarning,
        ),
        returnsNormally,
      );

      // allow should not throw
      expect(
        () => InventoryPolicy.validateMovementDelta(
          itemId: 'ITEM_CABLE',
          storeId: 'STORE_01',
          currentStock: 1,
          delta: -3,
          policy: NegativeStockPolicy.allow,
        ),
        returnsNormally,
      );
    });

    test('3. hasSufficientStock respects trackStock flag', () {
      const nonTrackedItem = InventoryEntity(
        id: 'ITEM_SERVICE',
        storeId: 'STORE_01',
        name: 'Gift Wrapping Service',
        price: 50.0,
        cost: 10.0,
        quantity: 0,
        category: 'Services',
        trackStock: false,
      );

      final resultNonTracked =
          InventoryPolicy.hasSufficientStock(nonTrackedItem, 10);
      expect(resultNonTracked.isValid, isTrue);

      const trackedItem = InventoryEntity(
        id: 'ITEM_MUG',
        storeId: 'STORE_01',
        name: 'Ceramic Mug',
        price: 200.0,
        cost: 80.0,
        quantity: 3,
        category: 'Merch',
        trackStock: true,
      );

      final resultTrackedEnough =
          InventoryPolicy.hasSufficientStock(trackedItem, 2);
      expect(resultTrackedEnough.isValid, isTrue);

      final resultTrackedShortage =
          InventoryPolicy.hasSufficientStock(trackedItem, 5);
      expect(resultTrackedShortage.isValid, isFalse);
      expect(resultTrackedShortage.message, contains('Insufficient stock'));
    });

    test('4. Low stock and out-of-stock threshold evaluations', () {
      const lowStockItem = InventoryEntity(
        id: 'ITEM_PEN',
        storeId: 'STORE_01',
        name: 'Ballpoint Pen',
        price: 20.0,
        cost: 5.0,
        quantity: 4,
        lowStockThreshold: 5,
        category: 'Stationery',
        trackStock: true,
      );

      expect(InventoryPolicy.isLowStock(lowStockItem), isTrue);
      expect(InventoryPolicy.isOutOfStock(lowStockItem), isFalse);

      const outOfStockItem = InventoryEntity(
        id: 'ITEM_NOTEBOOK',
        storeId: 'STORE_01',
        name: 'Spiral Notebook',
        price: 100.0,
        cost: 40.0,
        quantity: 0,
        lowStockThreshold: 5,
        category: 'Stationery',
        trackStock: true,
      );

      expect(InventoryPolicy.isLowStock(outOfStockItem), isFalse);
      expect(InventoryPolicy.isOutOfStock(outOfStockItem), isTrue);
    });

    test('5. Pricing and healthy margin validation', () {
      const healthyItem = InventoryEntity(
        id: 'ITEM_CAKE',
        storeId: 'STORE_01',
        name: 'Chocolate Cake',
        price: 450.0,
        cost: 200.0,
        quantity: 10,
        category: 'Bakery',
      );
      expect(InventoryPolicy.hasHealthyMargin(healthyItem).isValid, isTrue);

      const negativeMarginItem = InventoryEntity(
        id: 'ITEM_LOSS_LEADER',
        storeId: 'STORE_01',
        name: 'Promotional Item',
        price: 100.0,
        cost: 150.0,
        quantity: 10,
        category: 'Promotions',
      );
      expect(InventoryPolicy.hasHealthyMargin(negativeMarginItem).isValid,
          isFalse);
      expect(InventoryPolicy.hasHealthyMargin(negativeMarginItem).message,
          contains('negative margin'));
    });

    test('6. Expiry date policy detection', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final expiredItem = InventoryEntity(
        id: 'ITEM_YOGURT',
        storeId: 'STORE_01',
        name: 'Fresh Yogurt',
        price: 40.0,
        cost: 20.0,
        quantity: 5,
        category: 'Dairy',
        expiryDate: pastDate,
      );
      final expiredResult = InventoryPolicy.checkExpiry(expiredItem);
      expect(expiredResult.isValid, isFalse);
      expect(expiredResult.message, contains('has expired'));

      final futureDate = DateTime.now().add(const Duration(days: 30));
      final freshItem = InventoryEntity(
        id: 'ITEM_CHEESE',
        storeId: 'STORE_01',
        name: 'Cheddar Cheese',
        price: 150.0,
        cost: 80.0,
        quantity: 5,
        category: 'Dairy',
        expiryDate: futureDate,
      );
      final freshResult = InventoryPolicy.checkExpiry(freshItem);
      expect(freshResult.isValid, isTrue);
    });

    test('7. NegativeStockPolicy string parser fallback to BLOCK', () {
      expect(
          NegativeStockPolicy.fromString('ALLOW'), NegativeStockPolicy.allow);
      expect(NegativeStockPolicy.fromString('ALLOW_WITH_WARNING'),
          NegativeStockPolicy.allowWithWarning);
      expect(
          NegativeStockPolicy.fromString('BLOCK'), NegativeStockPolicy.block);
      expect(NegativeStockPolicy.fromString('UNKNOWN_XYZ'),
          NegativeStockPolicy.block);
      expect(NegativeStockPolicy.fromString(null), NegativeStockPolicy.block);
    });
  });
}
