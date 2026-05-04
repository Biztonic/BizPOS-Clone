import 'package:flutter/foundation.dart';
import 'package:biztonic_pos/features/inventory/data/inventory_repository.dart' as legacy;
import '../../domain/entities/inventory_entity.dart';
import '../../domain/repositories/inventory_repository_interface.dart';
import '../mappers/inventory_mapper.dart';

/// Concrete implementation of the InventoryRepositoryInterface.
///
/// Acts as an adapter over the legacy [InventoryRepository].
class InventoryRepositoryImpl implements InventoryRepositoryInterface {
  final legacy.InventoryRepository _legacyRepo;

  InventoryRepositoryImpl({required legacy.InventoryRepository legacyRepo})
      : _legacyRepo = legacyRepo;

  @override
  Future<InventoryResult<void>> insertItem(InventoryEntity item) async {
    try {
      final legacyItem = InventoryMapper.toLegacy(item);
      await _legacyRepo.insertInventory(legacyItem);
      return InventoryResult.success(null);
    } catch (e, st) {
      debugPrint('🔥 Error inserting inventory item: $e\n$st');
      return InventoryResult.failure('Failed to save inventory item: $e');
    }
  }

  @override
  Future<InventoryResult<InventoryEntity>> getItem(String itemId, {String? storeId}) async {
    try {
      final legacyItem = await _legacyRepo.getInventoryItem(itemId, storeId: storeId);
      if (legacyItem == null) {
        return InventoryResult.failure('Item not found.');
      }
      return InventoryResult.success(InventoryMapper.fromLegacy(legacyItem));
    } catch (e, st) {
      debugPrint('🔥 Error fetching inventory item: $e\n$st');
      return InventoryResult.failure('Failed to fetch item: $e');
    }
  }

  @override
  Future<InventoryResult<List<InventoryEntity>>> getItems(
    String? storeId, {
    String? category,
  }) async {
    try {
      final legacyItems = await _legacyRepo.getInventory(storeId, category: category);
      final items = legacyItems.map(InventoryMapper.fromLegacy).toList();
      return InventoryResult.success(items);
    } catch (e, st) {
      debugPrint('🔥 Error fetching inventory items: $e\n$st');
      return InventoryResult.failure('Failed to fetch items: $e');
    }
  }

  @override
  Future<InventoryResult<void>> deleteItem(String itemId) async {
    try {
      // Fetch current to soft delete
      final legacyItem = await _legacyRepo.getInventoryItem(itemId);
      if (legacyItem == null) return InventoryResult.failure('Item not found');
      
      final deletedItem = legacyItem.copyWith(deletedAt: DateTime.now());
      await _legacyRepo.insertInventory(deletedItem);
      
      return InventoryResult.success(null);
    } catch (e, st) {
      debugPrint('🔥 Error deleting inventory item: $e\n$st');
      return InventoryResult.failure('Failed to delete item: $e');
    }
  }

  @override
  Future<InventoryResult<void>> batchInsertItems(List<InventoryEntity> items) async {
    try {
      final legacyItems = items.map(InventoryMapper.toLegacy).toList();
      await _legacyRepo.batchInsertInventory(legacyItems);
      return InventoryResult.success(null);
    } catch (e, st) {
      debugPrint('🔥 Error batch inserting inventory items: $e\n$st');
      return InventoryResult.failure('Failed to batch save items: $e');
    }
  }

  @override
  Future<InventoryResult<int>> getStockQuantity(String itemId, {String? storeId}) async {
    try {
      final legacyItem = await _legacyRepo.getInventoryItem(itemId, storeId: storeId);
      return InventoryResult.success(legacyItem?.quantity ?? 0);
    } catch (e, st) {
      debugPrint('🔥 Error fetching stock quantity: $e\n$st');
      return InventoryResult.failure('Failed to fetch stock: $e');
    }
  }

  @override
  Future<InventoryResult<int>> getPendingDelta(String itemId, {String? storeId}) async {
    try {
      final delta = await _legacyRepo.getPendingInventoryDelta(itemId, storeId: storeId);
      return InventoryResult.success(delta);
    } catch (e, st) {
      debugPrint('🔥 Error fetching pending delta: $e\n$st');
      return InventoryResult.failure('Failed to fetch delta: $e');
    }
  }

  @override
  Future<InventoryResult<void>> rebuildQuantityCache(String storeId) async {
    try {
      await _legacyRepo.rebuildQuantityCache(storeId);
      return InventoryResult.success(null);
    } catch (e, st) {
      debugPrint('🔥 Error rebuilding cache: $e\n$st');
      return InventoryResult.failure('Failed to rebuild cache: $e');
    }
  }

  @override
  Future<InventoryResult<InventoryStats>> getInventoryStats(String storeId) async {
    try {
      final legacyItems = await _legacyRepo.getInventory(storeId);
      
      int totalItems = legacyItems.length;
      int lowStockItems = 0;
      int outOfStockItems = 0;
      double totalCostValue = 0;
      double totalRetailValue = 0;
      final categories = <String>{};

      for (var item in legacyItems) {
        categories.add(item.category);
        totalCostValue += (item.cost * item.quantity);
        totalRetailValue += (item.price * item.quantity);

        if (item.trackStock) {
          if (item.quantity <= 0) {
            outOfStockItems++;
          } else if (item.quantity <= item.lowStockThreshold) {
            lowStockItems++;
          }
        }
      }

      final stats = InventoryStats(
        totalItems: totalItems,
        lowStockItems: lowStockItems,
        outOfStockItems: outOfStockItems,
        totalCostValue: totalCostValue,
        totalRetailValue: totalRetailValue,
        categoriesCount: categories.length,
      );

      return InventoryResult.success(stats);
    } catch (e, st) {
      debugPrint('🔥 Error fetching stats: $e\n$st');
      return InventoryResult.failure('Failed to fetch stats: $e');
    }
  }

  @override
  Future<InventoryResult<List<String>>> getCategories(String? storeId) async {
    try {
      final legacyItems = await _legacyRepo.getInventory(storeId);
      final categories = legacyItems.map((e) => e.category).toSet().toList();
      categories.sort();
      return InventoryResult.success(categories);
    } catch (e, st) {
      debugPrint('🔥 Error fetching categories: $e\n$st');
      return InventoryResult.failure('Failed to fetch categories: $e');
    }
  }
}
