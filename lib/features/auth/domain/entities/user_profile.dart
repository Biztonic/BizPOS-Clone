import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String? storeId;
  final String? franchiseId;
  final DateTime? createdAt;
  final List<String>? accessibleStoreIds;
  final String? photoBase64; // NEW: Stored as Base64 string
  final String? phoneNumber; // NEW: Marketing Mobile Number
  final String? employeeId; // NEW: 4-Digit Login ID
  final String? pinHash; // SECURE: SHA-256 Hash
  final String? demoStatus; // 'pending', 'approved', 'rejected', 'none'
  final Map<String, bool>? permissions; // Granular permission overrides
  final double? hourlyRate;
  final double? monthlySalary;
  final List<String>? accessibleAddons; // NEW: Specific addons this employee can access
  final String? preferredTheme; // NEW: 'standard' or 'automotive'

  UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.storeId,
    this.franchiseId,
    this.createdAt,
    this.accessibleStoreIds,
    this.photoBase64,
    this.phoneNumber,
    this.employeeId,
    this.pinHash,
    this.demoStatus,
    this.permissions,
    this.hourlyRate,
    this.monthlySalary,
    this.accessibleAddons,
    this.preferredTheme,
  });


  factory UserProfile.fromMap(dynamic data, String id) {
    return UserProfile(
      uid: id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'Unauthorized',
      storeId: data['storeId'],
      franchiseId: data['franchiseId'],
      accessibleStoreIds: (data['accessibleStoreIds'] is List) 
          ? (data['accessibleStoreIds'] as List).map((e) => e.toString()).toList() 
          : null,
      photoBase64: data['photoBase64'],
      phoneNumber: data['phoneNumber'],
      employeeId: data['employeeId'],
      pinHash: data['pinHash'] ?? data['pin'], // Fallback for migration
      demoStatus: data['demoStatus'],
      permissions: data['permissions'] != null ? Map<String, bool>.from(data['permissions']) : null,
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      monthlySalary: (data['monthlySalary'] ?? 0.0).toDouble(),
      accessibleAddons: (data['accessibleAddons'] is List) 
          ? (data['accessibleAddons'] as List).map((e) => e.toString()).toList() 
          : null,
      preferredTheme: data['preferredTheme'],
      createdAt: (data['createdAt'] != null && data['createdAt'] is Timestamp)

          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(data['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'storeId': storeId,
      'franchiseId': franchiseId,
      'createdAt': createdAt,
      'accessibleStoreIds': accessibleStoreIds,
      'photoBase64': photoBase64,
      'phoneNumber': phoneNumber,
      'employeeId': employeeId,
      'pinHash': pinHash,
      'demoStatus': demoStatus,
      'permissions': permissions,
      'hourlyRate': hourlyRate,
      'monthlySalary': monthlySalary,
      'accessibleAddons': accessibleAddons,
      'preferredTheme': preferredTheme,
    };

  }
  UserProfile copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? storeId,
    String? franchiseId,
    DateTime? createdAt,
    List<String>? accessibleStoreIds,
    String? photoBase64,
    String? phoneNumber,
    String? employeeId,
    String? pinHash,
    String? demoStatus,
    Map<String, bool>? permissions,
    double? hourlyRate,
    double? monthlySalary,
    List<String>? accessibleAddons,
    String? preferredTheme,
  }) {

    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      storeId: storeId ?? this.storeId,
      franchiseId: franchiseId ?? this.franchiseId,
      createdAt: createdAt ?? this.createdAt,
      accessibleStoreIds: accessibleStoreIds ?? this.accessibleStoreIds,
      photoBase64: photoBase64 ?? this.photoBase64,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      employeeId: employeeId ?? this.employeeId,
      pinHash: pinHash ?? this.pinHash,
      demoStatus: demoStatus ?? this.demoStatus,
      permissions: permissions ?? this.permissions,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      accessibleAddons: accessibleAddons ?? this.accessibleAddons,
      preferredTheme: preferredTheme ?? this.preferredTheme,
    );


  }
}
