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
}

/// Convenience function to get Firestore instance
FirebaseFirestore getFirestore() => FirestoreHelper.instance;
