// ignore_for_file: constant_identifier_names
import 'package:cloud_firestore/cloud_firestore.dart';

enum BusinessEventType {
  CREATE_ORDER,
  VOID_ORDER,
  REFUND_ORDER,
  UPDATE_ORDER_STATUS,
  STOCK_ADJUST,
  CREATE_CUSTOMER,
  UPDATE_ROLE
}

class BusinessEvent {
  final String id; // Unique ID formatted via SyncService (idempotency key)
  final String storeId;
  final String entityType; // 'order' | 'inventory' | 'customer' | 'employee' | 'role'
  final String entityId;
  final String eventType;
  final Map<String, dynamic> payload;
  final String? deviceId;
  final DateTime createdAt;
  final String? userId; // Who performed the action

  BusinessEvent({
    required this.id,
    required this.storeId,
    required this.entityType,
    required this.entityId,
    required this.eventType,
    required this.payload,
    this.deviceId,
    required this.createdAt,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'entityType': entityType,
      'entityId': entityId,
      'eventType': eventType,
      'payload': payload,
      'deviceId': deviceId,
      'createdAt': createdAt,
      'userId': userId,
      'idempotencyKey': id, // Explicit key for server-side deduplication
      'serverUpdatedAt': FieldValue.serverTimestamp(), // Authoritative sync clock
    };
  }

  factory BusinessEvent.fromMap(Map<String, dynamic> map, String id) {
    return BusinessEvent(
      id: id,
      storeId: map['storeId'] ?? '',
      entityType: map['entityType'] ?? '',
      entityId: map['entityId'] ?? '',
      eventType: map['eventType'] ?? '',
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      deviceId: map['deviceId'],
      createdAt: (map['createdAt'] is Timestamp) 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.parse(map['createdAt'].toString()),
      userId: map['userId'],
    );
  }

  // SQL Persistence (Local Ledger)
  Map<String, dynamic> toSqlMap() {
    return {
      'id': id,
      'storeId': storeId,
      'entityType': entityType,
      'entityId': entityId,
      'eventType': eventType,
      'createdAt': createdAt.toIso8601String(),
      'deviceId': deviceId,
      'synced': 0,
    };
  }
}
