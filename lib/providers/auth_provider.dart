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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    // Initial fetch of persisted offline state
    _isOfflineLoggedIn = OfflineService().getOfflineLoginState();

    _auth.authStateChanges().listen((User? user) async {
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
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      
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

  Future<void> signUpWithEmail(String email, String password, String mobile) async {
    try {
      _isLoading = true;
      notifyListeners();
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      
      if (credential.user != null) {
        // Create User Profile in Firestore
        // We default 'name' to part of email since we aren't asking for it yet
        final name = email.split('@')[0];
        
        await getFirestore().collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'name': name,
          'role': 'Store Owner', // Default role for self-signup
          'phoneNumber': mobile,
          'createdAt': FieldValue.serverTimestamp(),
          'accessibleStoreIds': [],
        });
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
      final userCredential = await _auth.signInWithCredential(credential);
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
    await _auth.signOut();
    await OfflineService().clearCredentials(); 
    // NOTE: We intentionally do NOT call unpinStore() here.
    // The pinned store must survive logout so _restorePinnedStore
    // can instantly restore the user's last active store on re-login.
    _isOfflineLoggedIn = false;
    await OfflineService().setOfflineLoginState(false);
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
