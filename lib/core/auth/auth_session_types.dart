// Explicit Authentication States and Session Types for BizPOS Multi-Tenant Platform

/// Explicit lifecycle states for authentication across BizPOS.
enum AuthStatus {
  /// Initial boot state while inspecting local and cloud credentials.
  UNKNOWN,

  /// Valid authenticated Firebase Auth session with online cloud access.
  ONLINE_AUTHENTICATED,

  /// Valid offline POS session using local salted verifier for the last authorized user.
  OFFLINE_AUTHENTICATED,

  /// Explicitly signed out; no active local or cloud credentials.
  SIGNED_OUT,

  /// Account or terminal locked out due to exceeding failed authentication attempts.
  LOCKED,
}

/// Explicit scopes of active sessions.
enum SessionType {
  /// Session backed by local storage for offline POS operations.
  LOCAL_OFFLINE_SESSION,

  /// Session backed by live Firebase Auth credentials.
  FIREBASE_AUTH_SESSION,

  /// POS terminal session scoped to an employee PIN login and permissions.
  EMPLOYEE_POS_SESSION,
}

/// Domain model representing an active authentication session.
class ActiveAuthSession {
  final SessionType type;
  final String uid;
  final String email;
  final String? storeId;
  final String? role;
  final DateTime authenticatedAt;
  final Map<String, dynamic>? claims;

  const ActiveAuthSession({
    required this.type,
    required this.uid,
    required this.email,
    this.storeId,
    this.role,
    required this.authenticatedAt,
    this.claims,
  });

  bool get isOnline => type == SessionType.FIREBASE_AUTH_SESSION;
  bool get isOffline => type == SessionType.LOCAL_OFFLINE_SESSION;
  bool get isEmployee => type == SessionType.EMPLOYEE_POS_SESSION;

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'uid': uid,
      'email': email,
      'storeId': storeId,
      'role': role,
      'authenticatedAt': authenticatedAt.toIso8601String(),
      'claims': claims,
    };
  }
}
