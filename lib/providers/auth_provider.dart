import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import '../services/offline_service.dart';

/// A virtual user for offline sessions to prevent null checks in UI
class OfflineUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;

  OfflineUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
  });
}

class AuthProvider with ChangeNotifier {
  final FirebaseAuth? _auth;
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;

  AuthProvider({FirebaseAuth? auth}) : _auth = auth ?? _getDefaultAuth() {
    _initAuth();
  }

  static FirebaseAuth? _getDefaultAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> _initAuth() async {
    // Initial fetch of persisted offline state
    _isOfflineLoggedIn = OfflineService().getOfflineLoginState();

    final auth = _auth;
    if (auth == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    auth.authStateChanges().listen((User? user) async {
       if (user != null) {
         _user = user;
         _isOfflineLoggedIn = false;
         await OfflineService().setOfflineLoginState(false);
         _isLoading = false;
       } else {
         // If Firebase says no user, check if we were offline-logged-in
         if (_isOfflineLoggedIn) {
           _user = null; 
         } else {
           _user = null;
           _isOfflineLoggedIn = false;
         }
         _isLoading = false;
       }
       notifyListeners();
    });
  }

  /// Returns the Firebase User or a Virtual User if offline
  dynamic get currentUser {
    if (_user != null) return _user;
    if (_isOfflineLoggedIn) {
       // Use the cached real Firebase UID for this specific offline user
       final offlineEmail = OfflineService().getOfflineLoginEmail();
       final cachedUid = OfflineService().getCachedUserId(email: offlineEmail) ?? 'offline_user';
       final cachedProfile = OfflineService().getCachedCredentials(email: offlineEmail);
       return OfflineUser(
         uid: cachedUid,
         email: cachedProfile?['email'] ?? offlineEmail,
         displayName: "Offline User",
       );
    }
    return null;
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      final auth = _auth;
      if (auth == null) {
        throw Exception('Authentication service is not available.');
      }
      final credential = await auth.signInWithEmailAndPassword(email: email, password: password);
      
      // 1. Cache Credentials + UID for offline fallback (keyed by email)
      await OfflineService().cacheCredentials(email, password, uid: credential.user?.uid);
      if (credential.user != null) {
        await OfflineService().cacheUserId(credential.user!.uid, email: email);
      }

      // 2. Fetch and Cache User Profile (keyed by uid)
      if (credential.user != null) {
        final doc = await getFirestore().collection('users').doc(credential.user!.uid).get();
        if (doc.exists) {
           await OfflineService().cacheUserProfile(doc.data()!, uid: credential.user!.uid);
        }
      }
      
      _isOfflineLoggedIn = false;
    } catch (e) {
      // OFFLINE-FIRST: Broader offline detection
      // Catches FirebaseAuthException (network-request-failed, unavailable)
      // AND generic exceptions from connectivity failures (SocketException, etc.)
      bool isNetworkError = false;
      if (e is FirebaseAuthException) {
        isNetworkError = (e.code == 'network-request-failed' || e.code == 'unavailable');
      } else {
        // Generic network failures (SocketException, TimeoutException, etc.)
        final msg = e.toString().toLowerCase();
        isNetworkError = msg.contains('network') || msg.contains('socket') || 
                         msg.contains('timeout') || msg.contains('unreachable') ||
                         msg.contains('connection') || msg.contains('errno');
      }

      if (isNetworkError) {
        final cached = OfflineService().getCachedCredentials(email: email);
        if (cached != null && cached['email'] == email.toLowerCase().trim() && cached['password'] == password) {
             _isOfflineLoggedIn = true;
             await OfflineService().setOfflineLoginState(true, email: email);
             _isLoading = false;
             notifyListeners();
             return;
        }
      }
      
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  bool _isOfflineLoggedIn = false;
  bool get isOfflineLoggedIn => _isOfflineLoggedIn;

  // Override to check offline status
  bool get isLoggedIn => _user != null || _isOfflineLoggedIn;

  Future<void> signUpWithEmail(String email, String password, String mobile, {String? franchiseCode}) async {
    try {
      _isLoading = true;
      notifyListeners();
      final auth = _auth;
      if (auth == null) {
        throw Exception('Authentication service is not available.');
      }
      final credential = await auth.createUserWithEmailAndPassword(email: email, password: password);
      
      if (credential.user != null) {
        // Create User Profile in Firestore
        // We default 'name' to part of email since we aren't asking for it yet
        final name = email.split('@')[0];
        
        final Map<String, dynamic> userData = {
          'uid': credential.user!.uid,
          'email': email,
          'name': name,
          'role': 'Store Owner', // Default role for self-signup
          'phoneNumber': mobile,
          'createdAt': FieldValue.serverTimestamp(),
          'accessibleStoreIds': [],
        };

        if (franchiseCode != null && franchiseCode.trim().isNotEmpty) {
          userData['pendingFranchiseCode'] = franchiseCode.trim();
        }

        await getFirestore().collection('users').doc(credential.user!.uid).set(userData);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        _isLoading = false;
        notifyListeners();
        return null; 
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final auth = _auth;
      if (auth == null) {
        throw Exception('Authentication service is not available.');
      }
      final userCredential = await auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Ensure profile doc exists for Google Users too
        final profileData = {
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? user.email?.split('@')[0],
          'lastLogin': FieldValue.serverTimestamp(),
          // Don't overwrite existing roles/storeIds if they exist
        };
        await getFirestore().collection('users').doc(user.uid).set(profileData, SetOptions(merge: true));
        
        // Cache profile (keyed by uid)
        final doc = await getFirestore().collection('users').doc(user.uid).get();
        if (doc.exists) {
           await OfflineService().cacheUserProfile(doc.data()!, uid: user.uid);
        }
      }

      _isOfflineLoggedIn = false;
      return user;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;    
    }
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    await OfflineService().clearCredentials(); 
    // NOTE: We intentionally do NOT call unpinStore() here.
    // The pinned store must survive logout so _restorePinnedStore
    // can instantly restore the user's last active store on re-login.
    _isOfflineLoggedIn = false;
    await OfflineService().setOfflineLoginState(false);
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Authentication service is not available.');
    }
    await auth.sendPasswordResetEmail(email: email);
  }

  Future<bool> checkIfNewCustomer(String email) async {
    try {
      final inputEmail = email.trim();
      final cleanEmail = inputEmail.toLowerCase();
      debugPrint('🔍 AuthProvider: Checking if $cleanEmail is a new customer...');
      
      // 1. Fetch all documents matching this email to see the full state
      final query = await getFirestore().collection('users')
          .where('email', whereIn: [inputEmail, cleanEmail])
          .get();

      bool hasActiveUser = false;
      bool hasPendingActivation = false;

      // Check by doc field query results
      for (var doc in query.docs) {
        final data = doc.data();
        final bool needsPwd = data['needsInitialPassword'] == true || data['needsInitialPassword'] == 'true';
        final bool isPlaceholderId = doc.id.contains('@');
        final bool lacksRealUid = data['uid'] == null || data['uid'] == '' || data['uid'] == doc.id;

        if (needsPwd || (isPlaceholderId && lacksRealUid)) {
          hasPendingActivation = true;
        } else {
          // It's a UID-keyed doc with no pending flag -> Active User
          hasActiveUser = true;
        }
      }

      // Check by direct doc ID if query didn't find anything (edge case for doc IDs)
      if (query.docs.isEmpty) {
        final docIdsToCheck = {inputEmail, cleanEmail};
        for (final docId in docIdsToCheck) {
           final directDoc = await getFirestore().collection('users').doc(docId).get();
           if (directDoc.exists) {
              final data = directDoc.data();
              if (data?['needsInitialPassword'] == true || data?['uid'] == docId) {
                hasPendingActivation = true;
              }
           }
        }
      }

      // 2. Check 'subscription_requests' (Sales App integration) as a fallback signal
      // Only if we haven't found an active user yet
      if (!hasActiveUser && !hasPendingActivation) {
        final subFields = ['ownerEmail', 'userId', 'customerEmail', 'email'];
        for (final field in subFields) {
          final subQuery = await getFirestore()
              .collection('subscription_requests')
              .where(field, whereIn: [inputEmail, cleanEmail])
              .where('status', isEqualTo: 'PENDING')
              .limit(1)
              .get();
          if (subQuery.docs.isNotEmpty) {
            debugPrint('📄 AuthProvider: Found PENDING subscription request via $field for $cleanEmail');
            hasPendingActivation = true;
            break;
          }
        }
      }

      // ONLY redirect if we have a lead/placeholder AND NO active user account
      // This allows manual signups to correctly coexist with/override Sales App leads
      final result = hasPendingActivation && !hasActiveUser;
      debugPrint('🔎 AuthProvider: Check Results for $cleanEmail - Pending: $hasPendingActivation, Active: $hasActiveUser -> Redirect: $result');
      return result;
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Error in checkIfNewCustomer: $e');
      return false;
    }
  }
}
