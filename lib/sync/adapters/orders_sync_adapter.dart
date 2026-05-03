import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/sync/adapters/sync_adapter.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/sync/registry/sync_collection_registry.dart';

/// Sync adapter for the `orders` collection.
class OrdersSyncAdapter extends SyncAdapter {
  @override
  String get collection => SyncCollectionRegistry.orders;

  @override
  Future<void> insertFromCloud(
    Map<String, dynamic> data,
    String docId,
    Repository repository,
  ) async {
    await repository.insertOrder(OrderModel.fromMap(data, docId));
  }

  @override
  Future<void> deleteLocal(String docId, Repository repository) async {
    await repository.deleteOrder(docId);
  }
}
