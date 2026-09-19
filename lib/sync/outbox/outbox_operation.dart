import 'dart:convert';
import 'package:uuid/uuid.dart';

/// States for an outbox operation lifecycle.
enum OutboxState {
  pending,
  inFlight,
  pushed,
  confirmed,
  failed,
  conflicted,
  deadLetter;

  String toValue() {
    switch (this) {
      case OutboxState.pending:
        return 'PENDING';
      case OutboxState.inFlight:
        return 'IN_FLIGHT';
      case OutboxState.pushed:
        return 'PUSHED';
      case OutboxState.confirmed:
        return 'CONFIRMED';
      case OutboxState.failed:
        return 'FAILED';
      case OutboxState.conflicted:
        return 'CONFLICTED';
      case OutboxState.deadLetter:
        return 'DEAD_LETTER';
    }
  }

  String get value => toValue();

  static OutboxState fromValue(String? value) {
    switch (value?.toUpperCase()) {
      case 'IN_FLIGHT':
        return OutboxState.inFlight;
      case 'PUSHED':
        return OutboxState.pushed;
      case 'CONFIRMED':
        return OutboxState.confirmed;
      case 'FAILED':
        return OutboxState.failed;
      case 'CONFLICTED':
        return OutboxState.conflicted;
      case 'DEAD_LETTER':
        return OutboxState.deadLetter;
      case 'PENDING':
      default:
        return OutboxState.pending;
    }
  }
}

/// Represents an immutable, durable outbox mutation intent.
class OutboxOperation {
  final String operationId;
  final String storeId;
  final String userId;
  final String deviceId;
  final String collection; // entityType
  final String entityId;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final Map<String, dynamic> payload;
  final int baseVersion;
  final int newVersion;
  final int createdAt; // epoch ms
  final int attemptCount;
  final int? nextRetryAt; // epoch ms
  final OutboxState state;
  final String? lastError;
  final Map<String, dynamic>? auditMetadata;

  OutboxOperation({
    String? operationId,
    required this.storeId,
    required this.userId,
    required this.deviceId,
    required this.collection,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.baseVersion = 1,
    this.newVersion = 1,
    int? createdAt,
    this.attemptCount = 0,
    this.nextRetryAt,
    this.state = OutboxState.pending,
    this.lastError,
    this.auditMetadata,
  })  : operationId = operationId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  OutboxOperation copyWith({
    String? operationId,
    String? storeId,
    String? userId,
    String? deviceId,
    String? collection,
    String? entityId,
    String? operation,
    Map<String, dynamic>? payload,
    int? baseVersion,
    int? newVersion,
    int? createdAt,
    int? attemptCount,
    int? nextRetryAt,
    OutboxState? state,
    String? lastError,
    Map<String, dynamic>? auditMetadata,
  }) {
    return OutboxOperation(
      operationId: operationId ?? this.operationId,
      storeId: storeId ?? this.storeId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      collection: collection ?? this.collection,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      baseVersion: baseVersion ?? this.baseVersion,
      newVersion: newVersion ?? this.newVersion,
      createdAt: createdAt ?? this.createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      state: state ?? this.state,
      lastError: lastError ?? this.lastError,
      auditMetadata: auditMetadata ?? this.auditMetadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'storeId': storeId,
      'userId': userId,
      'deviceId': deviceId,
      'collection': collection,
      'entityId': entityId,
      'operation': operation,
      'payload': payload,
      'baseVersion': baseVersion,
      'newVersion': newVersion,
      'createdAt': createdAt,
      'attemptCount': attemptCount,
      'nextRetryAt': nextRetryAt,
      'state': state.toValue(),
      'lastError': lastError,
      'auditMetadata': auditMetadata,
      // Backward compatibility aliases for existing queue consumers
      'docId': entityId,
      'type': operation,
      'activeStoreId': storeId,
      'retryCount': attemptCount,
    };
  }

  Map<String, dynamic> toSqlRow() {
    return {
      'operationId': operationId,
      'storeId': storeId,
      'userId': userId,
      'deviceId': deviceId,
      'collection': collection,
      'entityId': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'baseVersion': baseVersion,
      'newVersion': newVersion,
      'createdAt': createdAt,
      'attemptCount': attemptCount,
      'nextRetryAt': nextRetryAt,
      'state': state.toValue(),
      'lastError': lastError,
      'auditMetadata': auditMetadata != null ? jsonEncode(auditMetadata) : null,
    };
  }

  factory OutboxOperation.fromMap(Map<dynamic, dynamic> map, [String? key]) {
    final payloadRaw = map['payload'];
    Map<String, dynamic> payload = {};
    if (payloadRaw is Map) {
      payload = Map<String, dynamic>.from(payloadRaw);
    } else if (payloadRaw is String) {
      try {
        payload = Map<String, dynamic>.from(jsonDecode(payloadRaw));
      } catch (_) {}
    }

    final auditRaw = map['auditMetadata'];
    Map<String, dynamic>? audit;
    if (auditRaw is Map) {
      audit = Map<String, dynamic>.from(auditRaw);
    } else if (auditRaw is String) {
      try {
        audit = Map<String, dynamic>.from(jsonDecode(auditRaw));
      } catch (_) {}
    }

    final opId = map['operationId']?.toString() ??
        (key != null && key.isNotEmpty ? key : const Uuid().v4());

    final store = map['storeId']?.toString() ??
        map['activeStoreId']?.toString() ??
        payload['storeId']?.toString() ??
        '';

    final user =
        map['userId']?.toString() ?? payload['userId']?.toString() ?? 'SYSTEM';

    final device = map['deviceId']?.toString() ??
        payload['deviceId']?.toString() ??
        'LOCAL';

    final coll = map['collection']?.toString() ??
        payload['collection']?.toString() ??
        'unknown';

    final entId = map['entityId']?.toString() ??
        map['docId']?.toString() ??
        payload['id']?.toString() ??
        '';

    final op =
        map['operation']?.toString() ?? map['type']?.toString() ?? 'CREATE';

    return OutboxOperation(
      operationId: opId,
      storeId: store,
      userId: user,
      deviceId: device,
      collection: coll,
      entityId: entId,
      operation: op.toUpperCase(),
      payload: payload,
      baseVersion: (map['baseVersion'] as num?)?.toInt() ?? 1,
      newVersion: (map['newVersion'] as num?)?.toInt() ?? 1,
      createdAt: (map['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      attemptCount: (map['attemptCount'] as num?)?.toInt() ??
          (map['retryCount'] as num?)?.toInt() ??
          0,
      nextRetryAt: (map['nextRetryAt'] as num?)?.toInt(),
      state: OutboxState.fromValue(map['state']?.toString()),
      lastError: map['lastError']?.toString(),
      auditMetadata: audit,
    );
  }

  factory OutboxOperation.fromSqlRow(Map<String, dynamic> row) {
    return OutboxOperation.fromMap(row);
  }
}
