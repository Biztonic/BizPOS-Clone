import '../domain/models/app_user.dart';

class AuthState {
  final AppUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = true,
    this.error,
  });

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
