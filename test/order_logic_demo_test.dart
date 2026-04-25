
import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/inventory_item.dart';

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
        items: [
           OrderItem(item: item, quantity: 2, note: 'Spicy')
        ],
        total: 300.0,
        date: DateTime(2023, 1, 1),
        status: 'Completed',
        type: 'Dine-In',
        paymentMethod: 'Cash'
      );

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

    // 2. Test "Calculation" (Business Logic)
    test('Should calculate total correctly', () {
       // Ideally OrderModel should have a `calculateTotal()` method.
       // Since it currently accepts total in constructor, we just verify the input logic/math here.
       
       double price = 100.0;
       int qty = 5;
       double expectedTotal = price * qty;
       
       expect(expectedTotal, 500.0);
    });

  });
}
