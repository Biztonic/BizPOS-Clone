import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/adapters/sync_adapter.dart';
import 'package:biztonic_pos/models/inventory_item.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Sync adapter for the `inventory` collection.
///
/// Includes post-sync reconciliation: after pulling cloud quantities,
/// the adapter reconciles with pending local movements to prevent
/// quantity drift.
class InventorySyncAdapter extends SyncAdapter {
  @override
  String get collection => SyncCollectionRegistry.inventory;

  @override
  Future<void> insertFromCloud(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  ) async {
    final item = InventoryItem.fromMap(data, docId);
    await repository.insertInventory(item);
  }

  @override
  Future<void> deleteLocal(String docId, Repository repository) async {
    await repository.deleteInventory(docId);
  }

  /// Reconcile cloud quantity with local pending (unsynced) movements.
  /// Rule: Local Cache = Cloud Quantity + Local Pending Delta
  @override
  Future<void> reconcileAfterPull(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  ) async {
    final cloudQuantity = _parseInt(data['quantity']);
    final pendingDelta = await repository.getPendingInventoryDelta(
      docId,
      storeId: data['storeId'],
    );
    final safeQuantity = cloudQuantity + pendingDelta;
    await repository.updateInventoryCache(
      docId,
      safeQuantity,
      data['storeId'] ?? '',
    );
  }

  /// Rebuilds the full inventory quantity cache after a complete pull.
  @override
  Future<void> onPullComplete(String storeId, Repository repository) async {
    // Rebuilding cache from movement ledger is skipped to maintain reconciled baseline quantities.
  }

  int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}
