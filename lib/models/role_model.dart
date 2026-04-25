class RoleModel {
  final String id;
  final String name;
  final Map<String, bool> permissions;
  final bool isSystem;
  final String? description;
  final String storeAccessMode; // 'single', 'multi_full', 'franchise'

  RoleModel({
    required this.id,
    required this.name,
    required this.permissions,
    this.isSystem = false,
    this.description,
    this.storeAccessMode = 'single',
    this.version = 1,
    this.updatedAt,
  });

  final int version;
  final DateTime? updatedAt;

  factory RoleModel.fromMap(Map<String, dynamic> map, String id) {
    return RoleModel(
      id: id,
      name: map['name'] ?? '',
      permissions: Map<String, bool>.from(map['permissions'] ?? {}),
      isSystem: map['isSystem'] ?? false,
      description: map['description'],
      storeAccessMode: map['storeAccessMode'] ?? 'single',
      version: map['version'] ?? 1,
      updatedAt: map['updatedAt'] != null 
        ? (map['updatedAt'] is String 
            ? DateTime.parse(map['updatedAt']) 
            : (map['updatedAt'] as DateTime)) 
        : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'permissions': permissions,
      'isSystem': isSystem,
      'description': description,
      'storeAccessMode': storeAccessMode,
      'version': version,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

