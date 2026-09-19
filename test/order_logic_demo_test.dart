import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/features/billing/domain/use_cases/calculate_tax.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';

void main() {
  group('Order Logic Tests', () {
    // 1. Test "Serialization" (JSON Conversion)
    // This ensures that when we save an order to Firestore/Hive, we don't lose data.
    test('Should convert Order to Map and back without data loss', () {
      final item = InventoryItem(
        id: 'item_1',
        name: 'Burger',
        price: 150.0,
        quantity: 10,
        storeId: 'store_1',
        category: 'Food',
        status: 'In Stock',
        trackStock: true,
      );

      final order = OrderModel(
          id: 'order_123',
          storeId: 'store_A',
          items: [OrderItem(item: item, quantity: 2, note: 'Spicy')],
          total: 300.0,
          date: DateTime(2023, 1, 1),
          status: 'Completed',
          type: 'Dine-In',
          paymentMethod: 'Cash');

      // Verify Initial Data
      expect(order.items.length, 1);
      expect(order.items.first.quantity, 2);
      expect(order.total, 300.0);

      // Verify "Map" Conversion (What happens during Sync)
      final map = order.toMap();
      expect(map['storeId'], 'store_A');
      expect(map['total'], 300.0);
      expect(map['items'].length, 1);

      // Verify "Reconstruction" (Loading from DB)
      final reconstructed = OrderModel.fromMap(map, 'order_123');
      expect(reconstructed.id, 'order_123');
      expect(reconstructed.total, 300.0);
      expect(reconstructed.items.first.item.name, 'Burger');
    });

    // 2. Test Real Tax & Total Calculation via CalculateTaxUseCase
    test(
        'Should calculate subtotal, CGST, SGST, and total using CalculateTaxUseCase',
        () {
      final useCase = CalculateTaxUseCase();
      const items = [
        OrderItemEntity(
          itemId: 'item_1',
          itemName: 'Burger',
          price: 150.0,
          quantity: 2,
          cost: 70.0,
        ),
        OrderItemEntity(
          itemId: 'item_2',
          itemName: 'Fries',
          price: 100.0,
          quantity: 1,
          cost: 40.0,
        ),
      ];

      // Subtotal = 150*2 + 100*1 = 400. Discount = 50. Taxable = 350. Tax = 5% (17.50: CGST 8.75, SGST 8.75). Total = 367.50.
      final result = useCase.execute(const CalculateTaxParams(
        items: items,
        taxRate: 5.0,
        discountAmount: 50.0,
      ));

      expect(result.subtotal, 400.0);
      expect(result.discount, 50.0);
      expect(result.cgst, 8.75);
      expect(result.sgst, 8.75);
      expect(result.total, 367.50);
    });
  });
}
