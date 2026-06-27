import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Manages local and cloud data statistics (counts).
///
/// Decouples UI-related counting logic from the core sync engine.
class StatsEngine {
  final FirebaseFirestore _db;
  final Repository _repository;
  final String? Function() _getActiveStoreId;

  StatsEngine({
    required FirebaseFirestore db,
    required Repository repository,
    required String? Function() getActiveStoreId,
  })  : _db = db,
        _repository = repository,
        _getActiveStoreId = getActiveStoreId;

  /// Refreshes local counts across all registered modules.
  Future<Map<String, int>> refreshLocalCounts() async {
    final storeId = _getActiveStoreId();
    if (storeId == null) return {};

    final sid = storeId.trim().toLowerCase();
    final counts = <String, int>{};

    // If native platform, retrieve counts from SQLite repository
    if (!kIsWeb) {
      try {
        counts[SyncCollectionRegistry.orders] = await _repository.getOrderCount(storeId);
        counts[SyncCollectionRegistry.inventory] = await _repository.getInventoryCount(storeId);
        counts[SyncCollectionRegistry.customers] = await _repository.getCustomerCount(storeId);
        counts[SyncCollectionRegistry.employees] = await _repository.getEmployeeCount(storeId);
        counts[SyncCollectionRegistry.floors] = await _repository.getFloorCount(storeId);
        counts[SyncCollectionRegistry.tables] = await _repository.getTableCount(storeId);
        counts[SyncCollectionRegistry.suppliers] = await _repository.getSupplierCount(storeId);
        counts[SyncCollectionRegistry.notes] = await _repository.getNoteCount(storeId);
        
        // Settings count: check if local settings exist
        final settings = await _repository.getStoreSettings(storeId);
        counts[SyncCollectionRegistry.settings] = (settings != null && settings.isNotEmpty) ? 1 : 0;
        
        return counts;
      } catch (e) {
        debugPrint('⚠️ [StatsEngine] Native SQLite counting failed: $e. Falling back to Hive.');
      }
    }

    for (var module in SyncCollectionRegistry.pullModules) {
      try {
        final boxName = SyncCollectionRegistry.getBoxName(module, storeId: storeId);
        if (boxName == null) continue;

        final box = await Hive.openBox(boxName);
        
        // Count items belonging to this store that aren't deleted
        final count = box.values.where((v) {
          if (v is! Map) return false;
          final itemStoreId = (v['storeId'] ?? '').toString().trim().toLowerCase();
          
          // Special case: settings matches doc ID, others match storeId field
          bool isStoreMatch = (module == SyncCollectionRegistry.settings) 
              ? true // If it's in the store-scoped box, it's a match
              : itemStoreId == sid;

          return isStoreMatch && (v['deletedAt'] == null || v['deletedAt'] == false);
        }).length;

        counts[module] = count;
      } catch (e) {
        debugPrint('⚠️ [StatsEngine] Failed to count local $module: $e');
      }
    }
    return counts;
  }

  /// Refreshes cloud counts for the active store.
  Future<Map<String, int>> refreshCloudCounts() async {
    final storeId = _getActiveStoreId();
    if (storeId == null) return {};

    final counts = <String, int>{};
    
    // Core modules
    final modules = [
      SyncCollectionRegistry.orders,
      SyncCollectionRegistry.inventory,
      SyncCollectionRegistry.customers,
      SyncCollectionRegistry.employees,
      SyncCollectionRegistry.floors,
      SyncCollectionRegistry.tables,
      SyncCollectionRegistry.suppliers,
      SyncCollectionRegistry.notes,
    ];

    for (var module in modules) {
      counts[module] = await _getCloudCount(module, storeId);
    }

    // Special case: settings (usually 1 doc per store)
    try {
      final doc = await _db.collection(SyncCollectionRegistry.settings).doc(storeId).get();
      counts[SyncCollectionRegistry.settings] = doc.exists ? 1 : 0;
    } catch (e) {
      counts[SyncCollectionRegistry.settings] = 0;
    }

    return counts;
  }

  /// Fetches order counts for a store (used for limit checks).
  Future<Map<String, int>> getLocalOrderCounts(String storeId) async {
    final now = DateTime.now();
    
    // FOR NATIVE: Use Optimized SQL Count
    if (!kIsWeb) {
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
      
      final daily = await _repository.getDailyOrderCount(storeId, dateStr);
      final monthly = await _repository.getMonthlyOrderCount(storeId, yearMonth);
      
      return {'daily': daily, 'monthly': monthly};
    }
    
    // FOR WEB: Fallback to Hive enumeration
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    
    int d = 0;
    int m = 0;
    
    final box = await Hive.openBox(SyncCollectionRegistry.boxOrders);
    final sid = storeId.toLowerCase();
    
    for (var val in box.values) {
      if (val is Map) {
        if ((val['storeId'] ?? '').toString().toLowerCase() == sid) {
          final dateStr = val['createdAt'] ?? val['date'];
          if (dateStr != null) {
            final date = DateTime.tryParse(dateStr.toString());
            if (date != null) {
              if (date.isAfter(todayStart)) d++;
              if (date.isAfter(monthStart)) m++;
            }
          }
        }
      }
    }
    return {'daily': d, 'monthly': m};
  }

  Future<int> _getCloudCount(String collection, String storeId) async {
    try {
      Query query = _db.collection(collection).where('storeId', isEqualTo: storeId);
      final snapshot = await query.get();
      
      // Filter out logically deleted docs if they are returned
      final validDocs = snapshot.docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['deletedAt'] == null;
      }).length;
      
      return validDocs;
    } catch (e) {
      debugPrint("⚠️ [StatsEngine] Cloud count error ($collection): $e");
      return -1;
    }
  }

  /// Returns a combined stats map for diagnostics and UI display.
  Map<String, dynamic> getDetailedStats({
    required Map<String, int> localCounts,
    required Map<String, int> cloudCounts,
    required int pendingCount,
    required bool isOnline,
    required bool isBusy,
    required DateTime? lastSync,
    required String? deviceId,
  }) {
    return {
      'localCounts': localCounts,
      'cloudCounts': cloudCounts,
      'pendingUploadCount': pendingCount,
      'isOnline': isOnline,
      'isBusy': isBusy,
      'lastSyncTime': lastSync?.toIso8601String(),
      'deviceId': deviceId,
      'storeId': _getActiveStoreId(),
    };
  }
}
