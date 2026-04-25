class Franchise {
  final String id;
  final String name;
  final String ownerEmail;

  Franchise({
    required this.id,
    required this.name,
    required this.ownerEmail,
  });

  factory Franchise.fromMap(Map<String, dynamic> data, String id) {
    return Franchise(
      id: id,
      name: data['name'] ?? '',
      ownerEmail: data['ownerEmail'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerEmail': ownerEmail,
    };
  }
}
