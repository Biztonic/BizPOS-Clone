/// Domain validation policies for billing operations.
///
/// Pure business rules — no infrastructure imports.
/// These are the "guard rails" that prevent invalid state transitions.

import '../entities/order_entity.dart';

/// Validation result with optional error message.
class ValidationResult {
  final bool isValid;
  final String? message;

  const ValidationResult.valid()
      : isValid = true,
        message = null;

  const ValidationResult.invalid(this.message) : isValid = false;
}

/// Business rules for order validation.
class OrderPolicy {
  /// Validate that an order can be created.
  static ValidationResult canCreate(OrderEntity order) {
    if (order.items.isEmpty) {
      return const ValidationResult.invalid('Order must have at least one item.');
    }
    if (order.storeId.isEmpty) {
      return const ValidationResult.invalid('Order must be associated with a store.');
    }
    if (order.total <= 0) {
      return const ValidationResult.invalid('Order total must be greater than zero.');
    }
    return const ValidationResult.valid();
  }

  /// Validate that an order can be voided.
  static ValidationResult canVoid(OrderEntity order) {
    if (order.status == OrderStatus.voided) {
      return const ValidationResult.invalid('Order is already voided.');
    }
    if (order.status == OrderStatus.refunded) {
      return const ValidationResult.invalid('Cannot void a refunded order.');
    }
    if (order.status == OrderStatus.cancelled) {
      return const ValidationResult.invalid('Cannot void a cancelled order.');
    }
    return const ValidationResult.valid();
  }

  /// Validate that an order can be refunded.
  static ValidationResult canRefund(OrderEntity order) {
    if (order.status != OrderStatus.completed) {
      return const ValidationResult.invalid('Only completed orders can be refunded.');
    }
    return const ValidationResult.valid();
  }

  /// Validate that an order can be modified.
  static ValidationResult canModify(OrderEntity order) {
    if (order.isImmutable) {
      return ValidationResult.invalid(
        'Order in "${order.status.value}" state cannot be modified.',
      );
    }
    return const ValidationResult.valid();
  }
}
