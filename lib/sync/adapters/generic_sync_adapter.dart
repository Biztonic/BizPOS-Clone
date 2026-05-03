import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/adapters/sync_adapter.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Generic sync adapter for simple collections that follow the pattern:
/// `repository.insert{Type}(docId, storeId, data)`
///
/// Covers: floors, tables, suppliers, notes
class GenericSyncAdapter extends SyncAdapter {
  final String _collection;
  final Future<void> Function(String docId, String storeId, Map<String, dynamic> data, Repository repo) _insertFn;
  final Future<void> Function(String docId, Repository repo)? _deleteFn;

  GenericSyncAdapter({
    required String collection,
    required Future<void> Function(String docId, String storeId, Map<String, dynamic> data, Repository repo) insertFn,
    Future<void> Function(String docId, Repository repo)? deleteFn,
  })  : _collection = collection,
        _insertFn = insertFn,
        _deleteFn = deleteFn;

  @override
  String get collection => _collection;

  @override
  Future<void> insertFromCloud(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  ) async {
    final storeId = (data['storeId'] ?? '').toString();
    await _insertFn(docId, storeId, data, repository);
  }

  @override
  Future<void> deleteLocal(String docId, Repository repository) async {
    if (_deleteFn != null) {
      await _deleteFn!(docId, repository);
    }
  }

  /// Factory: Creates adapters for all generic collections.
  static Map<String, GenericSyncAdapter> createAll() {
    return {
      SyncCollectionRegistry.floors: GenericSyncAdapter(
        collection: SyncCollectionRegistry.floors,
        insertFn: (id, sid, data, repo) => repo.insertFloor(id, sid, data),
      ),
      SyncCollectionRegistry.tables: GenericSyncAdapter(
        collection: SyncCollectionRegistry.tables,
        insertFn: (id, sid, data, repo) => repo.insertTable(id, sid, data),
      ),
      SyncCollectionRegistry.suppliers: GenericSyncAdapter(
        collection: SyncCollectionRegistry.suppliers,
        insertFn: (id, sid, data, repo) => repo.insertSupplier(id, sid, data),
      ),
      SyncCollectionRegistry.notes: GenericSyncAdapter(
        collection: SyncCollectionRegistry.notes,
        insertFn: (id, sid, data, repo) => repo.insertNote(id, sid, data),
      ),
    };
  }
}
