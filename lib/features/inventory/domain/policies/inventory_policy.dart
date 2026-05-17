/// Pure domain policies for inventory validation.
///
/// These are stateless business rules that enforce invariants
/// on inventory entities. No infrastructure imports allowed.
library;

import '../entities/inventory_entity.dart';

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
