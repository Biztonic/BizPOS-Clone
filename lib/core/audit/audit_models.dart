import 'dart:convert';
import '../diagnostics/diagnostics_models.dart';

/// Business-critical actions tracked in the production audit trail.
enum AuditActionType {
  refund,
  voidOrder,
  priceChange,
  stockAdjustment,
  permissionChange,
  subscriptionChange,
  storeConfigChange,
  adminOperation,
}

extension AuditActionTypeX on AuditActionType {
  String get code {
    switch (this) {
      case AuditActionType.refund:
        return 'REFUND';
      case AuditActionType.voidOrder:
        return 'VOID';
      case AuditActionType.priceChange:
        return 'PRICE_CHANGE';
      case AuditActionType.stockAdjustment:
        return 'STOCK_ADJUSTMENT';
      case AuditActionType.permissionChange:
        return 'PERMISSION_CHANGE';
      case AuditActionType.subscriptionChange:
        return 'SUBSCRIPTION_CHANGE';
      case AuditActionType.storeConfigChange:
        return 'STORE_CONFIG_CHANGE';
      case AuditActionType.adminOperation:
        return 'ADMIN_OPERATION';
    }
  }

  static AuditActionType fromString(String val) {
    final normalized = val.toUpperCase().replaceAll('_', '');
    for (final action in AuditActionType.values) {
      if (action.code.replaceAll('_', '') == normalized ||
          action.name.toUpperCase() == normalized) {
        return action;
      }
    }
    return AuditActionType.adminOperation;
  }
}

/// An immutable business audit record.
class AuditRecord {
  final String id;
  final String storeId;
  final AuditActionType action;
  final String actorId;
  final String actorRole;
  final String entityId;
  final String entityType;
  final Map<String, dynamic>? previousState;
  final Map<String, dynamic>? newState;
  final String? reason;
  final DateTime timestamp;
  final String deviceId;

  AuditRecord({
    required this.id,
    required this.storeId,
    required this.action,
    required this.actorId,
    required this.actorRole,
    required this.entityId,
    required this.entityType,
    Map<String, dynamic>? previousState,
    Map<String, dynamic>? newState,
    this.reason,
    required this.timestamp,
    required this.deviceId,
  })  : previousState = previousState != null
            ? DiagnosticSanitizer.sanitizeMap(previousState)
            : null,
        newState =
            newState != null ? DiagnosticSanitizer.sanitizeMap(newState) : null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'action': action.code,
      'actorId': actorId,
      'actorRole': actorRole,
      'entityId': entityId,
      'entityType': entityType,
      'previousState': previousState,
      'newState': newState,
      'reason':
          reason != null ? DiagnosticSanitizer.sanitizeString(reason!) : null,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
    };
  }

  factory AuditRecord.fromMap(Map<String, dynamic> map) {
    return AuditRecord(
      id: map['id']?.toString() ?? '',
      storeId: map['storeId']?.toString() ?? '',
      action: AuditActionTypeX.fromString(
          map['action']?.toString() ?? 'ADMIN_OPERATION'),
      actorId: map['actorId']?.toString() ?? 'system',
      actorRole: map['actorRole']?.toString() ?? 'unknown',
      entityId: map['entityId']?.toString() ?? '',
      entityType: map['entityType']?.toString() ?? '',
      previousState: map['previousState'] is Map
          ? Map<String, dynamic>.from(map['previousState'] as Map)
          : null,
      newState: map['newState'] is Map
          ? Map<String, dynamic>.from(map['newState'] as Map)
          : null,
      reason: map['reason']?.toString(),
      timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      deviceId: map['deviceId']?.toString() ?? 'unknown',
    );
  }

  String toJson() => jsonEncode(toMap());
}
