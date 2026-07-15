import 'dart:typed_data';

class MarketingAudio {
  final String id;
  final String name;
  final Uint8List bytes;

  MarketingAudio({
    required this.id,
    required this.name,
    required this.bytes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bytes': bytes,
    };
  }

  factory MarketingAudio.fromMap(Map<dynamic, dynamic> map) {
    return MarketingAudio(
      id: map['id'] as String,
      name: map['name'] as String,
      bytes: map['bytes'] as Uint8List,
    );
  }
}
