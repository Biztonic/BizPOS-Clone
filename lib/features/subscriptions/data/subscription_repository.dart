import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:flutter/foundation.dart';

class SubscriptionRepository {
  final FirebaseFirestore _db = getFirestore();

  Future<Map<String, dynamic>?> findPendingSubscription(String email) async {
    final emailList = {email.trim(), email.toLowerCase().trim()}.toList();
    
    final searchFields = [
      'ownerEmail', 'userId', 'customerEmail', 'email', 
      'customer_email', 'buyer_email', 'contactEmail'
    ];
    
    for (final field in searchFields) {
      try {
        final q = await _db.collection('subscription_requests')
            .where(field, whereIn: emailList)
            .get();
            
        final pendingDocs = q.docs.where((doc) {
           final data = doc.data();
           return data['status'] == 'PENDING';
        }).toList();
        
        if (pendingDocs.isNotEmpty) {
           // Sort by createdAt descending
           try {
             pendingDocs.sort((a, b) {
               final tA = a.get('createdAt');
               final tB = b.get('createdAt');
               if (tA == null || tB == null) return 0;
               return (tB as dynamic).compareTo(tA);
             });
           } catch (e) {
      debugPrint('Error fetching subscriptions: $e');
    }
           
           final doc = pendingDocs.first;
           final data = doc.data();
           data['id'] = doc.id;
           return data;
        }
      } catch (e) {
        debugPrint('⚠️ SubscriptionRepository: Search on $field failed: $e');
      }
    }
    return null;
  }

  Future<void> approveSubscriptionRequest(String requestId, String storeId, String storeName) async {
    await _db.collection('subscription_requests').doc(requestId).update({
      'status': 'APPROVED',
      'storeId': storeId,
      'storeName': storeName,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addSubscriptionHistory(String storeId, String planName, DateTime? expiry) async {
    await _db.collection('stores').doc(storeId).collection('subscription_history').add({
      'planName': planName,
      'startDate': FieldValue.serverTimestamp(),
      'endDate': expiry,
      'status': 'Active',
      'amount': 0.0,
      'paymentId': 'SALES_APP_PREPAID',
    });
  }
}
