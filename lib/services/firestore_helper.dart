import 'package:cloud_firestore/cloud_firestore.dart';

/// Global Firestore Helper
/// 
/// Firebase project 'bizpos-clone' uses the default database.
/// This helper exists for migration compatibility.
/// 
/// USAGE: Replace all `FirebaseFirestore.instance` with `getFirestore()`

class FirestoreHelper {
  static FirebaseFirestore? _instance;
  
  /// Get the Firestore instance (default database)
  static FirebaseFirestore get instance {
    _instance ??= FirebaseFirestore.instance;
    return _instance!;
  }

  /// Get a reference to a document within a store's scope.
  /// Currently assumes root-level collections with storeId filtering.
  static DocumentReference storeDoc(String storeId, String collection, String docId) {
    return instance.collection(collection).doc(docId);
  }

  /// Get a reference to a collection.
  static CollectionReference storeCollection(String storeId, String collection) {
    return instance.collection(collection);
  }
}

/// Convenience function to get Firestore instance
FirebaseFirestore getFirestore() => FirestoreHelper.instance;
