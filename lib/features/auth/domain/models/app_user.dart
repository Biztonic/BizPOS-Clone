class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final bool isOffline;
  final Map<String, dynamic>? profileData;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.isOffline = false,
    this.profileData,
  });

  factory AppUser.fromFirebaseUser(dynamic user, {Map<String, dynamic>? profile}) {
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      isOffline: false,
      profileData: profile,
    );
  }

  factory AppUser.offline({
    required String uid,
    String? email,
    String? displayName,
    Map<String, dynamic>? profile,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      isOffline: true,
      profileData: profile,
    );
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    bool? isOffline,
    Map<String, dynamic>? profileData,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isOffline: isOffline ?? this.isOffline,
      profileData: profileData ?? this.profileData,
    );
  }
}
