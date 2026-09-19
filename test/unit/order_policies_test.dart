import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/features/billing/domain/entities/order_entity.dart';
import 'package:biztonic_pos/features/billing/domain/policies/order_policy.dart';

void main() {
  group('Unit Tests: Order Policies & Domain Invariants', () {
    final now = DateTime.now();

    test(
        '1. Valid order with items, store ID, and positive total passes validation',
        () {
      final order = OrderEntity(
        id: 'ORD_TEST_001',
        storeId: 'STORE_001',
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_001',
            itemName: 'Cold Brew Coffee',
            price: 150.0,
            cost: 60.0,
            quantity: 2,
          )
        ],
        total: 300.0,
        date: now,
      );

      final result = OrderPolicy.canCreate(order);
      expect(result.isValid, isTrue);
      expect(result.message, isNull);
    });

    test('2. Order with empty line items is rejected', () {
      final order = OrderEntity(
        id: 'ORD_EMPTY',
        storeId: 'STORE_001',
        items: const [],
        total: 100.0,
        date: now,
      );

      final result = OrderPolicy.canCreate(order);
      expect(result.isValid, isFalse);
      expect(result.message, 'Order must have at least one item.');
    });

    test('3. Order with empty storeId is rejected (multi-tenant boundary)', () {
      final order = OrderEntity(
        id: 'ORD_NO_STORE',
        storeId: '',
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_001',
            itemName: 'Item 1',
            price: 50.0,
            cost: 20.0,
            quantity: 1,
          )
        ],
        total: 50.0,
        date: now,
      );

      final result = OrderPolicy.canCreate(order);
      expect(result.isValid, isFalse);
      expect(result.message, 'Order must be associated with a store.');
    });

    test('4. Order with zero or negative total is rejected', () {
      final zeroOrder = OrderEntity(
        id: 'ORD_ZERO',
        storeId: 'STORE_001',
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_001',
            itemName: 'Item 1',
            price: 0.0,
            cost: 0.0,
            quantity: 1,
          )
        ],
        total: 0.0,
        date: now,
      );
      expect(OrderPolicy.canCreate(zeroOrder).isValid, isFalse);
      expect(OrderPolicy.canCreate(zeroOrder).message,
          'Order total must be greater than zero.');

      final negativeOrder = OrderEntity(
        id: 'ORD_NEG',
        storeId: 'STORE_001',
        items: const [
          OrderItemEntity(
            itemId: 'ITEM_001',
            itemName: 'Item 1',
            price: 10.0,
            cost: 5.0,
            quantity: 1,
          )
        ],
        total: -50.0,
        date: now,
      );
      expect(OrderPolicy.canCreate(negativeOrder).isValid, isFalse);
    });

    test('5. Order void policy: terminal states cannot be voided', () {
      OrderEntity createWithStatus(OrderStatus status) => OrderEntity(
            id: 'ORD_STATUS',
            storeId: 'STORE_001',
            items: const [],
            total: 100.0,
            date: now,
            status: status,
          );

      expect(OrderPolicy.canVoid(createWithStatus(OrderStatus.voided)).isValid,
          isFalse);
      expect(
          OrderPolicy.canVoid(createWithStatus(OrderStatus.refunded)).isValid,
          isFalse);
      expect(
          OrderPolicy.canVoid(createWithStatus(OrderStatus.cancelled)).isValid,
          isFalse);
      expect(
          OrderPolicy.canVoid(createWithStatus(OrderStatus.completed)).isValid,
          isTrue);
      expect(
          OrderPolicy.canVoid(createWithStatus(OrderStatus.newOrder)).isValid,
          isTrue);
    });

    test('6. Order refund policy: strictly completed orders can be refunded',
        () {
      OrderEntity createWithStatus(OrderStatus status) => OrderEntity(
            id: 'ORD_REFUND',
            storeId: 'STORE_001',
            items: const [],
            total: 100.0,
            date: now,
            status: status,
          );

      expect(
          OrderPolicy.canRefund(createWithStatus(OrderStatus.completed))
              .isValid,
          isTrue);
      expect(
          OrderPolicy.canRefund(createWithStatus(OrderStatus.newOrder)).isValid,
          isFalse);
      expect(
          OrderPolicy.canRefund(createWithStatus(OrderStatus.preparing))
              .isValid,
          isFalse);
      expect(
          OrderPolicy.canRefund(createWithStatus(OrderStatus.voided)).isValid,
          isFalse);
      expect(
          OrderPolicy.canRefund(createWithStatus(OrderStatus.cancelled))
              .isValid,
          isFalse);
    });

    test('7. Order modification policy: terminal states are immutable', () {
      OrderEntity createWithStatus(OrderStatus status) => OrderEntity(
            id: 'ORD_MOD',
            storeId: 'STORE_001',
            items: const [],
            total: 100.0,
            date: now,
            status: status,
          );

      // Terminal immutable states
      expect(
          OrderPolicy.canModify(createWithStatus(OrderStatus.completed))
              .isValid,
          isFalse);
      expect(
          OrderPolicy.canModify(createWithStatus(OrderStatus.refunded)).isValid,
          isFalse);
      expect(
          OrderPolicy.canModify(createWithStatus(OrderStatus.voided)).isValid,
          isFalse);
      expect(
          OrderPolicy.canModify(createWithStatus(OrderStatus.cancelled))
              .isValid,
          isFalse);

      // Mutable draft states
      expect(
          OrderPolicy.canModify(createWithStatus(OrderStatus.newOrder)).isValid,
          isTrue);
      expect(
          OrderPolicy.canModify(createWithStatus(OrderStatus.preparing))
              .isValid,
          isTrue);
    });
  });
}
