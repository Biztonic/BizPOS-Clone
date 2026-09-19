import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_helper.dart';

/// Repository for addon marketplace reviews and ratings.
/// Isolates Firestore access from addon presentation screens.
class AddonReviewRepository {
  final FirebaseFirestore? _firestore;

  AddonReviewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore get _db => _firestore ?? getFirestore();

  Future<List<Map<String, dynamic>>> getReviews(String addonKey) async {
    final snapshot = await _db
        .collection('addon_reviews')
        .where('addonKey', isEqualTo: addonKey)
        .get();

    final reviews = <Map<String, dynamic>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final rating = (data['rating'] as num?)?.toInt() ?? 5;
      reviews.add({
        'id': doc.id,
        'userId': data['userId'] ?? '',
        'userName': data['userName'] ?? 'Anonymous',
        'rating': rating,
        'comment': data['comment'] ?? '',
        'createdAt': data['createdAt'],
      });
    }
    return reviews;
  }

  Future<void> submitReview({
    required String addonKey,
    required String userId,
    required String userName,
    required int rating,
    required String comment,
  }) async {
    await _db.collection('addon_reviews').add({
      'addonKey': addonKey,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteReview(String reviewId) async {
    await _db.collection('addon_reviews').doc(reviewId).delete();
  }
}
