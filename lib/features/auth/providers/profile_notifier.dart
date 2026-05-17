import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/auth_repository.dart';
import '../domain/entities/user_profile.dart';
import 'auth_notifier.dart';

part 'profile_notifier.g.dart';

@riverpod
class ProfileNotifier extends _$ProfileNotifier {
  final AuthRepository _repository = AuthRepository();

  @override
  AsyncValue<UserProfile?> build() {
    // Watch auth state to react to login/logout
    final authState = ref.watch(authNotifierProvider);
    
    if (authState.user == null) {
      return const AsyncValue.data(null);
    }
    
    // Fire off async profile fetch, set state when complete
    _fetchProfile(authState.user!.uid);
    return const AsyncValue.loading();
  }

  Future<void> _fetchProfile(String uid) async {
    state = await AsyncValue.guard(() async {
      final data = await _repository.fetchUserProfile(uid);
      if (data == null) return null;
      return UserProfile.fromMap(data, uid);
    });
  }

  Future<void> updateProfile({
    String? name,
    String? photoBase64,
    String? phoneNumber,
  }) async {
    final currentProfile = state.value;
    if (currentProfile == null) return;

    state = const AsyncValue.loading();
    
    final Map<String, dynamic> updates = {};
    if (name != null) updates['name'] = name;
    if (photoBase64 != null) updates['photoBase64'] = photoBase64;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;

    if (updates.isEmpty) {
      state = AsyncValue.data(currentProfile);
      return;
    }

    state = await AsyncValue.guard(() async {
      await _repository.updateUserProfile(currentProfile.uid, updates);
      
      // Update local state by refetching or applying locally
      return currentProfile.copyWith(
        name: name,
        photoBase64: photoBase64,
        phoneNumber: phoneNumber,
      );
    });
  }
  
  /// Helper to refresh profile manually if needed
  Future<void> refresh() async {
    final authState = ref.read(authNotifierProvider);
    if (authState.user != null) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        final data = await _repository.fetchUserProfile(authState.user!.uid);
        if (data == null) return null;
        return UserProfile.fromMap(data, authState.user!.uid);
      });
    }
  }
}
