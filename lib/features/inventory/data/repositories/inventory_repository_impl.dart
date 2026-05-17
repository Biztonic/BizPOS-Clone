// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/features/inventory/domain/entities/inventory_item.dart';
import 'package:biztonic_pos/features/inventory/data/inventory_repository.dart' as legacy;
import '../../domain/entities/inventory_entity.dart';
import '../../domain/repositories/inventory_repository_interface.dart';
import '../mappers/inventory_mapper.dart';

/// Concrete implementation of the InventoryRepositoryInterface.
///
/// Acts as an adapter over the legacy [InventoryRepository] with cross-platform support.
class InventoryRepositoryImpl implements InventoryRepositoryInterface {
  final legacy.InventoryRepository _legacyRepo;

  InventoryRepositoryImpl({required legacy.InventoryRepository legacyRepo})
      : _legacyRepo = legacyRepo;

  @override
  Future<InventoryResult<void>> insertItem(InventoryEntity item) async {
    try {
      final legacyItem = InventoryMapper.toLegacy(item);
      if (kIsWeb) {
        final syncService = SyncService();
        await syncService.performLocalWrite(
          collection: 'inventory',
          docId: item.id,
          data: legacyItem.toHiveMap(),
          action: 'create',
          localCacheBox: 'cache_inventory',
          refreshCounts: true,
        );
      } else {
        await _legacyRepo.insertInventory(legacyItem);
      }
      return InventoryResult.success(null);
    } catch (e, st) {
      debugPrint('🔥 Error inserting inventory item: $e\n$st');
      return InventoryResult.failure('Failed to save inventory item: $e');
    }
  }

  @override
  Future<InventoryResult<InventoryEntity>> getItem(String itemId, {String? storeId}) async {
    try {
      if (kIsWeb) {
        final box = await Hive.openBox('cache_inventory');
        final raw = box.get(itemId);
        if (raw == null || raw is! Map) {
          return InventoryResult.failure('Item not found.');
        }
        
        Map<String, dynamic> recursiveCast(Map map) {
          return map.map((key, value) {
            if (value is Map) return MapEntry(key.toString(), recursiveCast(value));
            if (value is List) return MapEntry(key.toString(), value.map((e) => e is Map ? recursiveCast(e) : e).toList());
            return MapEntry(key.toString(), value);
          });
        }
        
        final legacyItem = InventoryItem.fromMap(recursiveCast(raw), itemId);
        return InventoryResult.success(InventoryMapper.fromLegacy(legacyItem));
      }

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
      if (kIsWeb) {
        final box = await Hive.openBox('cache_inventory');
        final targetStoreId = storeId?.trim();
        if (targetStoreId == null) return InventoryResult.success([]);

        Map<String, dynamic> recursiveCast(Map map) {
          return map.map((key, value) {
            if (value is Map) return MapEntry(key.toString(), recursiveCast(value));
            if (value is List) return MapEntry(key.toString(), value.map((e) => e is Map ? recursiveCast(e) : e).toList());
            return MapEntry(key.toString(), value);
          });
        }

        final cached = box.values
            .where((v) {
               if (v is! Map) return false;
               final vStoreId = (v['storeId'] ?? '').toString().trim();
               final matchesStore = vStoreId == targetStoreId;
               final notDeleted = v['deletedAt'] == null && v['isDeleted'] != true && v['isDeleted'] != 1;
               final matchesCategory = category == null || category == 'All' || v['category'] == category;
               return matchesStore && notDeleted && matchesCategory;
            })
            .map((e) => InventoryItem.fromMap(recursiveCast(e as Map), (e)['id'] ?? ''))
            .toList();

        final items = cached.map(InventoryMapper.fromLegacy).toList();
        return InventoryResult.success(items);
      }

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
      if (kIsWeb) {
        final syncService = SyncService();
        await syncService.performLocalWrite(
          collection: 'inventory',
          docId: itemId,
          data: {
            'deletedAt': DateTime.now().toIso8601String(),
            'isDeleted': true
          },
          action: 'update', // Soft delete is just an update
          localCacheBox: 'cache_inventory',
          refreshCounts: true,
        );
      } else {
        // Fetch current to soft delete
        final legacyItem = await _legacyRepo.getInventoryItem(itemId);
        if (legacyItem == null) return InventoryResult.failure('Item not found');
        
        final deletedItem = legacyItem.copyWith(deletedAt: DateTime.now());
        await _legacyRepo.insertInventory(deletedItem);
      }
      
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
      if (kIsWeb) {
        final syncService = SyncService();
        for (var item in legacyItems) {
          await syncService.performLocalWrite(
            collection: 'inventory',
            docId: item.id,
            data: item.toHiveMap(),
            action: 'create',
            localCacheBox: 'cache_inventory',
            refreshCounts: false,
          );
        }
        await syncService.refreshLocalCounts();
      } else {
        await _legacyRepo.batchInsertInventory(legacyItems);
      }
      return InventoryResult.success(null);
    } catch (e, st) {
      debugPrint('🔥 Error batch inserting inventory items: $e\n$st');
      return InventoryResult.failure('Failed to batch save items: $e');
    }
  }

  @override
  Future<InventoryResult<int>> getStockQuantity(String itemId, {String? storeId}) async {
    try {
      if (kIsWeb) {
        final box = await Hive.openBox('cache_inventory');
        final raw = box.get(itemId);
        if (raw == null || raw is! Map) {
          return InventoryResult.success(0);
        }
        return InventoryResult.success((raw['quantity'] as num?)?.toInt() ?? 0);
      }
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
      if (kIsWeb) {
        return InventoryResult.success(0);
      }
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
      if (kIsWeb) {
        return InventoryResult.success(null);
      }
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
      List<InventoryItem> legacyItems = [];
      if (kIsWeb) {
        final box = await Hive.openBox('cache_inventory');
        final targetStoreId = storeId.trim();

        Map<String, dynamic> recursiveCast(Map map) {
          return map.map((key, value) {
            if (value is Map) return MapEntry(key.toString(), recursiveCast(value));
            if (value is List) return MapEntry(key.toString(), value.map((e) => e is Map ? recursiveCast(e) : e).toList());
            return MapEntry(key.toString(), value);
          });
        }

        final cached = box.values
            .where((v) {
               if (v is! Map) return false;
               final vStoreId = (v['storeId'] ?? '').toString().trim();
               final matchesStore = vStoreId == targetStoreId;
               final notDeleted = v['deletedAt'] == null && v['isDeleted'] != true && v['isDeleted'] != 1;
               return matchesStore && notDeleted;
            })
            .map((e) => InventoryItem.fromMap(recursiveCast(e as Map), (e)['id'] ?? ''))
            .toList();
        
        legacyItems = cached;
      } else {
        legacyItems = await _legacyRepo.getInventory(storeId);
      }

      int totalItems = legacyItems.length;
      int lowStockItems = 0;
      int outOfStockItems = 0;
      double totalCostValue = 0;
      double totalRetailValue = 0;
      final categories = <String>{};

      for (var item in legacyItems) {
        categories.add(item.category);
        totalCostValue += ((item.cost ?? 0.0) * item.quantity);
        totalRetailValue += (item.price * item.quantity);

        if (item.trackStock) {
          if (item.quantity <= 0) {
            outOfStockItems++;
          } else if (item.quantity <= (item.lowStockThreshold ?? 10)) {
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
      List<InventoryItem> legacyItems = [];
      if (kIsWeb) {
        final box = await Hive.openBox('cache_inventory');
        final targetStoreId = storeId?.trim();
        if (targetStoreId == null) return InventoryResult.success([]);

        Map<String, dynamic> recursiveCast(Map map) {
          return map.map((key, value) {
            if (value is Map) return MapEntry(key.toString(), recursiveCast(value));
            if (value is List) return MapEntry(key.toString(), value.map((e) => e is Map ? recursiveCast(e) : e).toList());
            return MapEntry(key.toString(), value);
          });
        }

        final cached = box.values
            .where((v) {
               if (v is! Map) return false;
               final vStoreId = (v['storeId'] ?? '').toString().trim();
               final matchesStore = vStoreId == targetStoreId;
               final notDeleted = v['deletedAt'] == null && v['isDeleted'] != true && v['isDeleted'] != 1;
               return matchesStore && notDeleted;
            })
            .map((e) => InventoryItem.fromMap(recursiveCast(e as Map), (e)['id'] ?? ''))
            .toList();
        
        legacyItems = cached;
      } else {
        legacyItems = await _legacyRepo.getInventory(storeId);
      }

      final categories = legacyItems.map((e) => e.category).toSet().toList();
      categories.sort();
      return InventoryResult.success(categories);
    } catch (e, st) {
      debugPrint('🔥 Error fetching categories: $e\n$st');
      return InventoryResult.failure('Failed to fetch categories: $e');
    }
  }
}
