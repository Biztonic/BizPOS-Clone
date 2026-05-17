import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_helper.dart';

/// Provider for the FirebaseAuth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for the current Firebase User stream
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Provider for the current user's profile data
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) return null;

  final doc = await getFirestore().collection('users').doc(user.uid).get();
  
  if (doc.exists) {
    return UserProfile.fromMap(doc.data()!, doc.id);
  }
  return null;
});

/// Provider for the current user's role
final userRoleProvider = Provider<String?>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  return profile?.role;
});
