class Floor {
  final String id;
  final String storeId;
  final String name;

  Floor({
    required this.id,
    required this.storeId,
    required this.name,
  });

  factory Floor.fromMap(Map<String, dynamic> data, String id) {
    return Floor(
      id: id,
      storeId: data['storeId'] ?? '',
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
    };
  }

  Floor copyWith({
    String? id,
    String? storeId,
    String? name,
  }) {
    return Floor(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
    );
  }
}
