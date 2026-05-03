import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/adapters/sync_adapter.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Sync adapter for the `inventory_movements` collection (event-sourced ledger).
///
/// This collection is pull-only — movements are generated locally and pushed
/// via the outbound queue, then pulled back for multi-device consistency.
class MovementSyncAdapter extends SyncAdapter {
  @override
  String get collection => SyncCollectionRegistry.inventoryMovements;

  @override
  Future<void> insertFromCloud(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  ) async {
    await repository.insertMovement(InventoryMovement.fromMap(data, docId));
  }

  @override
  Future<void> deleteLocal(String docId, Repository repository) async {
    // Movements are immutable ledger entries — they're never truly deleted.
    // Cloud deletions are ignored for data integrity.
  }
}
