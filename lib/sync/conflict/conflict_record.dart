import 'dart:convert';
import 'package:uuid/uuid.dart';

class ConflictRecord {
  final String id;
  final String storeId;
  final String collection;
  final String entityId;
  final String conflictType;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> cloudData;
  final String resolution;
  final String? resolvedBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  ConflictRecord({
    String? id,
    required this.storeId,
    required this.collection,
    required this.entityId,
    required this.conflictType,
    required this.localData,
    required this.cloudData,
    required this.resolution,
    this.resolvedBy,
    DateTime? createdAt,
    this.resolvedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isResolved => resolvedAt != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'collection': collection,
      'entityId': entityId,
      'conflictType': conflictType,
      'localData': localData,
      'cloudData': cloudData,
      'resolution': resolution,
      'resolvedBy': resolvedBy,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toSqlRow() {
    return {
      'id': id,
      'storeId': storeId,
      'collection': collection,
      'entityId': entityId,
      'conflictType': conflictType,
      'localData': jsonEncode(localData),
      'cloudData': jsonEncode(cloudData),
      'resolution': resolution,
      'resolvedBy': resolvedBy,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  factory ConflictRecord.fromMap(Map<dynamic, dynamic> map) {
    Map<String, dynamic> parseJson(dynamic val) {
      if (val is Map) return Map<String, dynamic>.from(val);
      if (val is String) {
        try {
          return Map<String, dynamic>.from(jsonDecode(val));
        } catch (_) {}
      }
      return {};
    }

    return ConflictRecord(
      id: map['id']?.toString() ?? const Uuid().v4(),
      storeId: map['storeId']?.toString() ?? '',
      collection: map['collection']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      conflictType: map['conflictType']?.toString() ?? 'DATA_DIVERGENCE',
      localData: parseJson(map['localData']),
      cloudData: parseJson(map['cloudData']),
      resolution: map['resolution']?.toString() ?? 'MANUAL_REQUIRED',
      resolvedBy: map['resolvedBy']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'].toString())
          : null,
    );
  }
}
