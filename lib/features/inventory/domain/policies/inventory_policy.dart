/// Pure domain policies for inventory validation.
///
/// These are stateless business rules that enforce invariants
/// on inventory entities and movements. No infrastructure imports allowed.
library;

import '../entities/inventory_entity.dart';

/// Explicit policy governing negative stock behavior per store.
enum NegativeStockPolicy {
  /// Block any operation that causes stock to drop below zero.
  block,

  /// Allow stock to drop below zero, but log a diagnostic warning.
  allowWithWarning,

  /// Allow stock to drop below zero without restriction.
  allow;

  static NegativeStockPolicy fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'ALLOW':
        return NegativeStockPolicy.allow;
      case 'ALLOW_WITH_WARNING':
        return NegativeStockPolicy.allowWithWarning;
      case 'BLOCK':
      default:
        return NegativeStockPolicy.block;
    }
  }

  String toValue() {
    switch (this) {
      case NegativeStockPolicy.block:
        return 'BLOCK';
      case NegativeStockPolicy.allowWithWarning:
        return 'ALLOW_WITH_WARNING';
      case NegativeStockPolicy.allow:
        return 'ALLOW';
    }
  }
}

// ─── Domain Exceptions ───────────────────────────────────────

class InsufficientStockException implements Exception {
  final String itemId;
  final String storeId;
  final int currentStock;
  final int requestedDelta;
  final String message;

  InsufficientStockException({
    required this.itemId,
    required this.storeId,
    required this.currentStock,
    required this.requestedDelta,
  }) : message =
            'Insufficient stock for item $itemId in store $storeId. Current stock: $currentStock, requested delta: $requestedDelta. Operation blocked by store negative-stock policy.';

  @override
  String toString() => 'InsufficientStockException: $message';
}

class DuplicateMovementException implements Exception {
  final String? movementId;
  final String? operationId;
  final String storeId;
  final String message;

  DuplicateMovementException({
    this.movementId,
    this.operationId,
    required this.storeId,
  }) : message =
            'Duplicate inventory movement detected for store $storeId (movementId: $movementId, operationId: $operationId).';

  @override
  String toString() => 'DuplicateMovementException: $message';
}

class CrossStoreViolationException implements Exception {
  final String movementStoreId;
  final String itemStoreId;
  final String itemId;
  final String message;

  CrossStoreViolationException({
    required this.movementStoreId,
    required this.itemStoreId,
    required this.itemId,
  }) : message =
            'Cross-store movement prohibited: item $itemId belongs to store $itemStoreId, but movement targets store $movementStoreId.';

  @override
  String toString() => 'CrossStoreViolationException: $message';
}

class InvalidRefundException implements Exception {
  final String orderId;
  final String itemId;
  final int requestedQuantity;
  final int soldQuantity;
  final int alreadyRefundedQuantity;
  final String message;

  InvalidRefundException({
    required this.orderId,
    required this.itemId,
    required this.requestedQuantity,
    required this.soldQuantity,
    required this.alreadyRefundedQuantity,
    String? customMessage,
  }) : message = customMessage ??
            'Invalid refund for item $itemId on order $orderId: attempted to refund $requestedQuantity, but original sold was $soldQuantity and already refunded was $alreadyRefundedQuantity.';

  @override
  String toString() => 'InvalidRefundException: $message';
}

/// Result of a policy validation.
class PolicyValidation {
  final bool isValid;
  final String? message;

  const PolicyValidation.valid()
      : isValid = true,
        message = null;

  const PolicyValidation.invalid(this.message) : isValid = false;
}

/// Business rules and validations for inventory operations.
class InventoryPolicy {
  // ─── Creation Rules ────────────────────────────────────────

  /// Validate that an item can be created.
  static PolicyValidation canCreate(InventoryEntity item) {
    if (item.name.trim().isEmpty) {
      return const PolicyValidation.invalid('Item name is required.');
    }
    if (item.price < 0) {
      return const PolicyValidation.invalid('Price cannot be negative.');
    }
    if (item.cost < 0) {
      return const PolicyValidation.invalid('Cost cannot be negative.');
    }
    if (item.category.trim().isEmpty) {
      return const PolicyValidation.invalid('Category is required.');
    }
    return const PolicyValidation.valid();
  }

  // ─── Stock Rules ───────────────────────────────────────────

  /// Enforce negative stock policy for a proposed movement delta against current stock.
  static void validateMovementDelta({
    required String itemId,
    required String storeId,
    required int currentStock,
    required int delta,
    required NegativeStockPolicy policy,
  }) {
    final projected = currentStock + delta;
    if (projected < 0) {
      if (policy == NegativeStockPolicy.block) {
        throw InsufficientStockException(
          itemId: itemId,
          storeId: storeId,
          currentStock: currentStock,
          requestedDelta: delta,
        );
      }
    }
  }

  /// Check if an item has sufficient stock for a sale of [requiredQty].
  static PolicyValidation hasSufficientStock(
    InventoryEntity item,
    int requiredQty,
  ) {
    if (!item.trackStock) return const PolicyValidation.valid();
    if (item.quantity < requiredQty) {
      return PolicyValidation.invalid(
        'Insufficient stock for "${item.name}". '
        'Available: ${item.quantity}, Required: $requiredQty.',
      );
    }
    return const PolicyValidation.valid();
  }

  /// Check if an item is below low stock threshold.
  static bool isLowStock(InventoryEntity item) {
    if (!item.trackStock) return false;
    return item.quantity > 0 && item.quantity <= item.lowStockThreshold;
  }

  /// Check if an item is out of stock.
  static bool isOutOfStock(InventoryEntity item) {
    if (!item.trackStock) return false;
    return item.quantity <= 0;
  }

  // ─── Pricing Rules ─────────────────────────────────────────

  /// Validate that margin is healthy (cost < price).
  static PolicyValidation hasHealthyMargin(InventoryEntity item) {
    if (item.cost > item.price && item.price > 0) {
      return PolicyValidation.invalid(
        'Warning: "${item.name}" has negative margin. '
        'Cost (${item.cost}) exceeds price (${item.price}).',
      );
    }
    return const PolicyValidation.valid();
  }

  // ─── Expiry Rules ──────────────────────────────────────────

  /// Check if an item is expired or expiring soon.
  static PolicyValidation checkExpiry(
    InventoryEntity item, {
    int warningDays = 7,
  }) {
    if (item.expiryDate == null) return const PolicyValidation.valid();
    final now = DateTime.now();
    if (item.expiryDate!.isBefore(now)) {
      return PolicyValidation.invalid(
        '"${item.name}" has expired on ${item.expiryDate}.',
      );
    }
    final daysUntilExpiry = item.expiryDate!.difference(now).inDays;
    if (daysUntilExpiry <= warningDays) {
      return PolicyValidation.invalid(
        '"${item.name}" expires in $daysUntilExpiry days.',
      );
    }
    return const PolicyValidation.valid();
  }

  // ─── Deletion Rules ────────────────────────────────────────

  /// Validate that an item can be deleted.
  static PolicyValidation canDelete(InventoryEntity item) {
    if (item.isDeleted) {
      return const PolicyValidation.invalid('Item is already deleted.');
    }
    return const PolicyValidation.valid();
  }
}
