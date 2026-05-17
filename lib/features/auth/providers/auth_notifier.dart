import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

part 'auth_notifier.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  final AuthRepository _repository = AuthRepository();

  @override
  AuthState build() {
    _init();
    return const AuthState();
  }

  void _init() {
    _repository.authStateChanges.listen((user) async {
      if (user != null) {
        final appUser = await _repository.getCurrentUser();
        state = state.copyWith(user: appUser, isLoading: false, clearError: true);
      } else {
        // Check offline state if no firebase user
        final appUser = await _repository.getCurrentUser();
        if (appUser != null && appUser.isOffline) {
          state = state.copyWith(user: appUser, isLoading: false, clearError: true);
        } else {
          state = state.copyWith(isLoading: false, clearUser: true);
        }
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.signInWithEmail(email, password);
      // Listener will handle state update
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String mobile) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.signUpWithEmail(email, password, mobile);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.signInWithGoogle();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signOut();
      state = state.copyWith(isLoading: false, clearUser: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}
