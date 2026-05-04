/// Abstract repository interface for inventory operations.
///
/// CRITICAL RULE: This belongs to the DOMAIN layer.
/// It defines the "contract" — the DATA layer provides the implementation.
///
/// No infrastructure imports allowed here.

import '../entities/inventory_entity.dart';

/// Generic result wrapper for inventory operations.
class InventoryResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  InventoryResult.success(this.data)
      : error = null,
        isSuccess = true;

  InventoryResult.failure(this.error)
      : data = null,
        isSuccess = false;
}

/// Inventory statistics for a store.
class InventoryStats {
  final int totalItems;
  final int lowStockItems;
  final int outOfStockItems;
  final double totalCostValue;
  final double totalRetailValue;
  final int categoriesCount;

  const InventoryStats({
    required this.totalItems,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.totalCostValue,
    required this.totalRetailValue,
    required this.categoriesCount,
  });
}

/// Abstract contract for inventory data operations.
///
/// Implementations may use SQLite, Firestore, Hive, or any
/// combination of data sources.
abstract class InventoryRepositoryInterface {
  // ─── CRUD ──────────────────────────────────────────────────

  /// Insert or update an inventory item.
  Future<InventoryResult<void>> insertItem(InventoryEntity item);

  /// Retrieve a single inventory item by ID.
  Future<InventoryResult<InventoryEntity>> getItem(String itemId, {String? storeId});

  /// Retrieve all inventory items for a store.
  Future<InventoryResult<List<InventoryEntity>>> getItems(
    String? storeId, {
    String? category,
  });

  /// Soft-delete an inventory item.
  Future<InventoryResult<void>> deleteItem(String itemId);

  // ─── Batch Operations ─────────────────────────────────────

  /// Batch insert inventory items (used during sync).
  Future<InventoryResult<void>> batchInsertItems(List<InventoryEntity> items);

  // ─── Stock Operations ─────────────────────────────────────

  /// Get the current stock quantity for an item.
  Future<InventoryResult<int>> getStockQuantity(String itemId, {String? storeId});

  /// Get pending inventory delta (unsynced movements).
  Future<InventoryResult<int>> getPendingDelta(String itemId, {String? storeId});

  /// Rebuild the quantity cache from movement history.
  Future<InventoryResult<void>> rebuildQuantityCache(String storeId);

  // ─── Aggregations ─────────────────────────────────────────

  /// Get inventory statistics for a store.
  Future<InventoryResult<InventoryStats>> getInventoryStats(String storeId);

  /// Get all unique categories for a store.
  Future<InventoryResult<List<String>>> getCategories(String? storeId);
}
