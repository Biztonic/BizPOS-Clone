import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../services/offline_service.dart';
import '../../../services/firestore_helper.dart';
import '../domain/models/app_user.dart';

class AuthRepository {
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  late final FirebaseFirestore _firestore = getFirestore();
  final OfflineService _offlineService = OfflineService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      final profile = await _offlineService.getCachedUserProfile(uid: user.uid);
      return AppUser.fromFirebaseUser(user, profile: profile != null ? Map<String, dynamic>.from(profile) : null);
    }

    final isOffline = _offlineService.getOfflineLoginState();
    if (isOffline) {
      final email = _offlineService.getOfflineLoginEmail();
      final uid = _offlineService.getCachedUserId(email: email) ?? 'offline_user';
      final profile = await _offlineService.getCachedUserProfile(uid: uid);
      return AppUser.offline(
        uid: uid,
        email: email,
        displayName: "Offline User",
        profile: profile != null ? Map<String, dynamic>.from(profile) : null,
      );
    }

    return null;
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      final user = credential.user;
      if (user != null) {
        await _offlineService.cacheCredentials(email, password, uid: user.uid);
        await _offlineService.cacheUserId(user.uid, email: email);
        
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          await _offlineService.cacheUserProfile(doc.data()!, uid: user.uid);
        }
      }
      await _offlineService.setOfflineLoginState(false);
    } catch (e) {
      if (await _isNetworkError(e)) {
        final cached = _offlineService.getCachedCredentials(email: email);
        if (cached != null && cached['email'] == email.toLowerCase().trim() && cached['password'] == password) {
          await _offlineService.setOfflineLoginState(true, email: email);
          return;
        }
      }
      rethrow;
    }
  }

  Future<void> signUpWithEmail(String email, String password, String mobile) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = credential.user;
    if (user != null) {
      final name = email.split('@')[0];
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'name': name,
        'role': 'Store Owner',
        'phoneNumber': mobile,
        'createdAt': FieldValue.serverTimestamp(),
        'accessibleStoreIds': [],
      });
    }
  }

  Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      final profileData = {
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? user.email?.split('@')[0],
        'lastLogin': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('users').doc(user.uid).set(profileData, SetOptions(merge: true));
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        await _offlineService.cacheUserProfile(doc.data()!, uid: user.uid);
      }
    }

    await _offlineService.setOfflineLoginState(false);
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _offlineService.clearCredentials();
    await _offlineService.setOfflineLoginState(false);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<bool> checkIfNewCustomer(String email) async {
    final inputEmail = email.trim();
    final cleanEmail = inputEmail.toLowerCase();
    
    final query = await _firestore.collection('users')
        .where('email', whereIn: [inputEmail, cleanEmail])
        .get();

    bool hasActiveUser = false;
    bool hasPendingActivation = false;

    for (var doc in query.docs) {
      final data = doc.data();
      final bool needsPwd = data['needsInitialPassword'] == true || data['needsInitialPassword'] == 'true';
      final bool isPlaceholderId = doc.id.contains('@');
      final bool lacksRealUid = data['uid'] == null || data['uid'] == '' || data['uid'] == doc.id;

      if (needsPwd || (isPlaceholderId && lacksRealUid)) {
        hasPendingActivation = true;
      } else {
        hasActiveUser = true;
      }
    }

    if (query.docs.isEmpty) {
      final docIdsToCheck = {inputEmail, cleanEmail};
      for (final docId in docIdsToCheck) {
         final directDoc = await _firestore.collection('users').doc(docId).get();
         if (directDoc.exists) {
            final data = directDoc.data();
            if (data?['needsInitialPassword'] == true || data?['uid'] == docId) {
              hasPendingActivation = true;
            }
         }
      }
    }

    if (!hasActiveUser && !hasPendingActivation) {
      final subFields = ['ownerEmail', 'userId', 'customerEmail', 'email'];
      for (final field in subFields) {
        final subQuery = await _firestore
            .collection('subscription_requests')
            .where(field, whereIn: [inputEmail, cleanEmail])
            .where('status', isEqualTo: 'PENDING')
            .limit(1)
            .get();
        if (subQuery.docs.isNotEmpty) {
          hasPendingActivation = true;
          break;
        }
      }
    }

    return hasPendingActivation && !hasActiveUser;
  }

  // --- Roles & Permissions ---
  Future<List<Map<String, dynamic>>> fetchRolesOnline() async {
    final snap = await _firestore.collection('roles').get();
    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();
  }

  Future<void> addRole(Map<String, dynamic> roleData) async {
    final ref = _firestore.collection('roles').doc();
    roleData['id'] = ref.id;
    await ref.set(roleData);
  }

  Future<void> updateRole(String id, Map<String, dynamic> roleData) async {
    await _firestore.collection('roles').doc(id).update(roleData);
  }

  Future<void> deleteRole(String id) async {
    await _firestore.collection('roles').doc(id).delete();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
    
    // Refresh cache
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      await _offlineService.cacheUserProfile(doc.data()!, uid: uid);
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    // Try online first
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        await _offlineService.cacheUserProfile(doc.data()!, uid: uid);
        return doc.data();
      }
    } catch (e) {
      debugPrint("AuthRepository: Online fetch failed, trying cache: $e");
    }
    
    final cached = await _offlineService.getCachedUserProfile(uid: uid);
    return cached != null ? Map<String, dynamic>.from(cached) : null;
  }

  Future<bool> _isNetworkError(dynamic e) async {
    if (e is FirebaseAuthException) {
      return (e.code == 'network-request-failed' || e.code == 'unavailable');
    }
    final msg = e.toString().toLowerCase();
    return msg.contains('network') || msg.contains('socket') || 
           msg.contains('timeout') || msg.contains('unreachable') ||
           msg.contains('connection') || msg.contains('errno');
  }
}
