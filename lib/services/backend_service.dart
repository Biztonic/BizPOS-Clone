import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item.dart';

class BackendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  // This simulates an external 'global' catalog that might be managed by a separate system
  // or a master collection in the same Firestore acting as the source of truth for products.
  static const String _globalCatalogCollection = 'central_catalog';

  /// Fetches central catalog items from the external backend (simulated via Firestore).
  /// Returns a list of [InventoryItem]s.
  /// Throws an exception if the request fails.
  Future<List<InventoryItem>> fetchCentralCatalogItems() async {
    try {
      final snapshot = await _db.collection(_globalCatalogCollection).get();
      
      // If collection is empty, we return empty list so the provider can fallback to local JSON if needed
      if (snapshot.docs.isEmpty) {
        return [];
      }

      return snapshot.docs.map((doc) => _mapFirestoreToInventoryItem(doc)).toList();
    } catch (e) {

      rethrow;
    }
  }

  /// Helper to map Firestore document to our Store's InventoryItem model.
  InventoryItem _mapFirestoreToInventoryItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InventoryItem.fromMap(data, doc.id).copyWith(
       storeId: null, // Central items don't belong to a store
       quantity: 0,   // Central items are templates
       status: 'In Stock'
    );
  }
}
