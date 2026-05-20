import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/policies/order_policy.dart';

void main() {
  group('OrderPolicy Tests', () {
    final now = DateTime.now();

    test('canCreate: valid order should pass', () {
      final order = OrderEntity(
        id: 'ord_1',
        storeId: 'store_1',
        items: const [
          OrderItemEntity(
            itemId: 'item_1',
            itemName: 'Item 1',
            price: 10.0,
            cost: 5.0,
            quantity: 1,
          )
        ],
        total: 10.0,
        date: now,
      );

      final result = OrderPolicy.canCreate(order);
      expect(result.isValid, isTrue);
      expect(result.message, isNull);
    });

    test('canCreate: order without items should be invalid', () {
      final order = OrderEntity(
        id: 'ord_1',
        storeId: 'store_1',
        items: const [],
        total: 10.0,
        date: now,
      );

      final result = OrderPolicy.canCreate(order);
      expect(result.isValid, isFalse);
      expect(result.message, 'Order must have at least one item.');
    });

    test('canCreate: order without storeId should be invalid', () {
      final order = OrderEntity(
        id: 'ord_1',
        storeId: '',
        items: const [
          OrderItemEntity(
            itemId: 'item_1',
            itemName: 'Item 1',
            price: 10.0,
            cost: 5.0,
            quantity: 1,
          )
        ],
        total: 10.0,
        date: now,
      );

      final result = OrderPolicy.canCreate(order);
      expect(result.isValid, isFalse);
      expect(result.message, 'Order must be associated with a store.');
    });

    test('canCreate: order total <= 0 should be invalid', () {
      final order = OrderEntity(
        id: 'ord_1',
        storeId: 'store_1',
        items: const [
          OrderItemEntity(
            itemId: 'item_1',
            itemName: 'Item 1',
            price: 10.0,
            cost: 5.0,
            quantity: 1,
          )
        ],
        total: 0.0,
        date: now,
      );

      final result = OrderPolicy.canCreate(order);
      expect(result.isValid, isFalse);
      expect(result.message, 'Order total must be greater than zero.');
    });

    test('canVoid: states that cannot be voided', () {
      final voidedOrder = OrderEntity(
        id: '1', storeId: 's', items: const [], total: 10, date: now,
        status: OrderStatus.voided,
      );
      final refundedOrder = OrderEntity(
        id: '1', storeId: 's', items: const [], total: 10, date: now,
        status: OrderStatus.refunded,
      );
      final cancelledOrder = OrderEntity(
        id: '1', storeId: 's', items: const [], total: 10, date: now,
        status: OrderStatus.cancelled,
      );
      final completedOrder = OrderEntity(
        id: '1', storeId: 's', items: const [], total: 10, date: now,
        status: OrderStatus.completed,
      );

      expect(OrderPolicy.canVoid(voidedOrder).isValid, isFalse);
      expect(OrderPolicy.canVoid(refundedOrder).isValid, isFalse);
      expect(OrderPolicy.canVoid(cancelledOrder).isValid, isFalse);
      expect(OrderPolicy.canVoid(completedOrder).isValid, isTrue);
    });

    test('canRefund: only completed orders can be refunded', () {
      final completedOrder = OrderEntity(
        id: '1', storeId: 's', items: const [], total: 10, date: now,
        status: OrderStatus.completed,
      );
      final newOrder = OrderEntity(
        id: '1', storeId: 's', items: const [], total: 10, date: now,
        status: OrderStatus.newOrder,
      );

      expect(OrderPolicy.canRefund(completedOrder).isValid, isTrue);
      expect(OrderPolicy.canRefund(newOrder).isValid, isFalse);
    });

    test('canModify: terminal states are immutable', () {
      final completedOrder = OrderEntity(
        id: '1', storeId: 's', items: const [], total: 10, date: now,
        status: OrderStatus.completed,
      );
      final newOrder = OrderEntity(
        id: '1', storeId: 's', items: const [], total: 10, date: now,
        status: OrderStatus.newOrder,
      );

      expect(OrderPolicy.canModify(completedOrder).isValid, isFalse);
      expect(OrderPolicy.canModify(newOrder).isValid, isTrue);
    });
  });
}
