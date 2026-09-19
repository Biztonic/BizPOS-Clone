import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
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
      return AppUser.fromFirebaseUser(user,
          profile: profile != null ? Map<String, dynamic>.from(profile) : null);
    }

    final isOffline = _offlineService.getOfflineLoginState();
    if (isOffline) {
      final email = _offlineService.getOfflineLoginEmail();
      final uid =
          _offlineService.getCachedUserId(email: email) ?? 'offline_user';
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
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      final user = credential.user;
      if (user != null) {
        await _offlineService.cacheOfflineVerifier(email, password,
            uid: user.uid);
        await _offlineService.cacheUserId(user.uid, email: email);

        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          await _offlineService.cacheUserProfile(doc.data()!, uid: user.uid);
        }
      }
      await _offlineService.setOfflineLoginState(false);
    } catch (e) {
      if (await _isNetworkError(e)) {
        if (_offlineService.isOfflineLockedOut(email)) {
          final remaining = _offlineService.getRemainingLockoutSeconds(email);
          throw Exception(
              'Account is temporarily locked out. Please wait $remaining seconds.');
        }
        final lastAuth = _offlineService.getLastAuthorizedEmail();
        if (lastAuth != null &&
            lastAuth.isNotEmpty &&
            lastAuth != email.toLowerCase().trim()) {
          throw Exception(
              'Offline POS access is restricted to the last authorized account on this device ($lastAuth).');
        }
        final isValid =
            await _offlineService.verifyOfflinePassword(email, password);
        if (isValid) {
          await _offlineService.setOfflineLoginState(true, email: email);
          return;
        }
      }
      rethrow;
    }
  }

  Future<void> signUpWithEmail(
      String email, String password, String mobile) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
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

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
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
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

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

    final query = await _firestore
        .collection('users')
        .where('email', whereIn: [inputEmail, cleanEmail]).get();

    bool hasActiveUser = false;
    bool hasPendingActivation = false;

    for (var doc in query.docs) {
      final data = doc.data();
      final bool needsPwd = data['needsInitialPassword'] == true ||
          data['needsInitialPassword'] == 'true';
      final bool isPlaceholderId = doc.id.contains('@');
      final bool lacksRealUid =
          data['uid'] == null || data['uid'] == '' || data['uid'] == doc.id;

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
    return msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('timeout') ||
        msg.contains('unreachable') ||
        msg.contains('connection') ||
        msg.contains('errno');
  }

  Future<void> completePasswordSetup({
    required String email,
    required String password,
    required String uid,
  }) async {
    final inputEmail = email.trim();
    final cleanEmail = inputEmail.toLowerCase();

    DocumentSnapshot? emailDoc;
    final docIdsToCheck = {inputEmail, cleanEmail};

    for (final docId in docIdsToCheck) {
      final doc = await _firestore.collection('users').doc(docId).get();
      if (doc.exists) {
        emailDoc = doc;
        break;
      }
    }

    if (emailDoc == null) {
      final query = await _firestore
          .collection('users')
          .where('email', whereIn: [inputEmail, cleanEmail]).get();
      if (query.docs.isNotEmpty) {
        emailDoc = query.docs.first;
      }
    }

    final Map<String, dynamic> userData = (emailDoc != null && emailDoc.exists)
        ? (emailDoc.data() as Map<String, dynamic>? ?? {})
        : {};

    userData['uid'] = uid;
    userData['email'] = cleanEmail;
    userData['needsInitialPassword'] = false;
    userData['updatedAt'] = FieldValue.serverTimestamp();
    userData['role'] ??= 'Store Owner';
    userData['name'] ??= email.split('@')[0];

    await _firestore.collection('users').doc(uid).set(userData);

    if (emailDoc != null && emailDoc.exists) {
      await emailDoc.reference.delete();
    }

    await _offlineService.cacheUserProfile(userData, uid: uid);
    await _offlineService.cacheOfflineVerifier(cleanEmail, password, uid: uid);
    await _offlineService.cacheUserId(uid, email: cleanEmail);
  }

  Future<String?> getPendingFranchiseCode(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists &&
          doc.data()?.containsKey('pendingFranchiseCode') == true) {
        final code = doc.data()?['pendingFranchiseCode']?.toString();
        if (code != null && code.isNotEmpty) {
          return code;
        }
      }
    } catch (e) {
      debugPrint('AuthRepository: Error loading pending franchise code: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> lookupEmployee({
    required String storeCodeOrId,
    required String employeeId,
  }) async {
    // 1. Offline cache check
    if (Hive.isBoxOpen('cache_employees')) {
      final box = Hive.box('cache_employees');
      final key = "${storeCodeOrId}_$employeeId";
      final empMap = box.get(key);
      if (empMap != null) {
        return Map<String, dynamic>.from(empMap as Map);
      }
    }

    // 2. Cloud lookup fallback if authenticated
    if (_auth.currentUser != null) {
      try {
        final cleanCode = storeCodeOrId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        String? targetStoreId = storeCodeOrId.isNotEmpty ? storeCodeOrId : null;

        if (targetStoreId == null || targetStoreId.isEmpty) {
          final storeQuery = await _firestore
              .collection('stores')
              .where('shortCode', isEqualTo: cleanCode)
              .limit(1)
              .get();

          if (storeQuery.docs.isEmpty) {
            final doc =
                await _firestore.collection('stores').doc(cleanCode).get();
            if (doc.exists) {
              targetStoreId = cleanCode;
            }
          } else {
            targetStoreId = storeQuery.docs.first.id;
          }
        }

        if (targetStoreId != null) {
          final subQuery = await _firestore
              .collection('stores')
              .doc(targetStoreId)
              .collection('employees')
              .where('employeeId', isEqualTo: employeeId)
              .limit(1)
              .get();

          if (subQuery.docs.isNotEmpty) {
            final data = subQuery.docs.first.data();
            return {
              ...data,
              'uid': subQuery.docs.first.id,
            };
          }
        }
      } catch (e) {
        debugPrint('AuthRepository: Error looking up employee: $e');
      }
    }
    return null;
  }
}
