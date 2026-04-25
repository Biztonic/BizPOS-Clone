// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('InventoryItem Model Tests', () {
    final testItem = InventoryItem(
      id: 'item_123',
      name: 'Test Product',
      category: 'Beverages',
      price: 9.99,
      quantity: 50,
      status: 'In Stock',
      image: 'http://example.com/image.png',
      counterId: 'counter_1',
      cost: 5.00,
      unit: 'pcs',
      sku: 'SKU12345',
      expiryDate: DateTime(2025, 12, 31),
      trackStock: true,
      storeId: 'store_001',
      centralItemId: 'central_123',
      storeType: 'Retail',
      cardStyle: 'image',
      cardSize: 'medium',
    );

    test('should correctly serialize to Map', () {
      final map = testItem.toMap();
      expect(map['name'], 'Test Product');
      expect(map['price'], 9.99);
      // expect(map['quantity'], 50); // Quantity is derived, not in toMap
      expect(map['expiryDate'], isA<Timestamp>());
    });

    test('should correctly deserialize from Map', () {
      final map = {
        'name': 'Test Product',
        'category': 'Beverages',
        'price': 9.99,
        'quantity': 50,
        'status': 'In Stock',
        'image': 'http://example.com/image.png',
        'expiryDate': Timestamp.fromDate(DateTime(2025, 12, 31)),
        'trackStock': true,
      };

      final item = InventoryItem.fromMap(map, 'item_123');
      expect(item.id, 'item_123');
      expect(item.name, 'Test Product');
      expect(item.price, 9.99);
      expect(item.expiryDate?.year, 2025);
    });

    test('should correctly copyWith properties', () {
      final newItem = testItem.copyWith(
        name: 'Updated Product',
        quantity: 100,
      );

      expect(newItem.id, testItem.id);
      expect(newItem.name, 'Updated Product');
      expect(newItem.quantity, 100);
      expect(newItem.price, testItem.price);
    });

    test('should correctly serialize to Hive Map', () {
      final hiveMap = testItem.toHiveMap();
      expect(hiveMap['id'], 'item_123');
      expect(hiveMap['expiryDate'], isA<String>()); // Hive stores dates as ISO strings
      expect(hiveMap['expiryDate'], '2025-12-31T00:00:00.000');
    });

    test('should handle null expiry date', () {
      final itemNoExpiry = InventoryItem(
        id: 'item_456',
        name: 'No Expiry Item',
        category: 'General',
        price: 10.0,
        quantity: 10,
        status: 'Active',
        trackStock: false,
        expiryDate: null,
      );

      final map = itemNoExpiry.toMap();
      expect(map['expiryDate'], null);
      
      final hiveMap = itemNoExpiry.toHiveMap();
      expect(hiveMap['expiryDate'], null);
    });
  });
}
