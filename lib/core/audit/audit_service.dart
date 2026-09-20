import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'audit_models.dart';
import '../diagnostics/diagnostics_models.dart';
import '../diagnostics/diagnostics_service.dart';
import '../../services/database_helper.dart';

/// Production-grade business audit trail service.
/// Tracks financial and governance events: refunds, voids, price changes,
/// stock adjustments, permission changes, subscription modifications, store configs,
/// and admin actions.
class AuditService {
  static final AuditService _instance = AuditService._internal();
  factory AuditService() => _instance;
  AuditService._internal();

  static const String boxName = 'audit_trail_v1';
  static const int maxRecordsInMemory = 200;
  static const int maxRecordsInStorage = 2000;

  final List<AuditRecord> _inMemoryRecords = [];
  final StreamController<AuditRecord> _streamController = StreamController<AuditRecord>.broadcast();

  Stream<AuditRecord> get onAuditRecord => _streamController.stream;
  List<AuditRecord> get cachedRecords => List.unmodifiable(_inMemoryRecords);

  Box? _box;
  bool _initialized = false;
  String _deviceId = 'device_unknown';
  String _storeId = 'store_default';

  /// Testing mode toggle to prevent background timer or side-effect leaks
  static bool isTesting = false;

  void configure({required String deviceId, String? storeId}) {
    _deviceId = deviceId;
    if (storeId != null && storeId.isNotEmpty) {
      _storeId = storeId;
    }
  }

  Future<void> init({Box? boxOverride}) async {
    if (_initialized && boxOverride == null) return;
    try {
      if (boxOverride != null) {
        _box = boxOverride;
      } else if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box(boxName);
      } else {
        _box = await Hive.openBox(boxName);
      }

      _inMemoryRecords.clear();
      if (_box != null) {
        final values = _box!.values.toList();
        final start = values.length > maxRecordsInMemory ? values.length - maxRecordsInMemory : 0;
        for (var i = start; i < values.length; i++) {
          final raw = values[i];
          if (raw is Map) {
            try {
              _inMemoryRecords.add(AuditRecord.fromMap(Map<String, dynamic>.from(raw)));
            } catch (_) {}
          }
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[AuditService] Init error: $e');
    }
  }

  /// Records an audit event across Hive storage and SQLite business_events.
  Future<void> record(AuditRecord record) async {
    // In-memory bounded buffer
    _inMemoryRecords.add(record);
    if (_inMemoryRecords.length > maxRecordsInMemory) {
      _inMemoryRecords.removeAt(0);
    }
    _streamController.add(record);

    // Persistent Hive storage
    if (!isTesting) {
      try {
        if (_box != null && _box!.isOpen) {
          if (_box!.length >= maxRecordsInStorage) {
            await _box!.deleteAt(0);
          }
          await _box!.add(record.toMap());
        }
      } catch (e) {
        debugPrint('[AuditService] Hive persist error: $e');
      }
    }

    // Persist to local SQLite business_events table
    if (!isTesting) {
      try {
        final db = await DatabaseHelper().database;
        await db.insert('business_events', {
          'id': record.id,
          'storeId': record.storeId,
          'entityType': record.entityType,
          'entityId': record.entityId,
          'eventType': record.action.code,
          'amount': (record.newState?['amount'] as num?)?.toDouble() ?? 0.0,
          'quantity': (record.newState?['quantity'] as num?)?.toInt() ?? 1,
          'createdAt': record.timestamp.toIso8601String(),
          'deviceId': record.deviceId,
          'synced': 0,
        });
      } catch (e) {
        // Best-effort SQLite insert, never break transaction if SQLite is uninitialized/closing
        debugPrint('[AuditService] SQLite business_events insert ignored: $e');
      }
    }

    // Correlate with Diagnostics Engine
    try {
      await DiagnosticsService().recordEvent(DiagnosticEvent(
        id: const Uuid().v4(),
        operationId: 'audit_${record.action.code.toLowerCase()}',
        subsystem: _mapActionToSubsystem(record.action),
        storeId: record.storeId,
        userId: record.actorId,
        deviceId: record.deviceId,
        entityId: record.entityId,
        timestamp: record.timestamp,
        result: DiagnosticResult.success,
        durationMs: 0,
        message: 'AUDIT: ${record.action.code} on ${record.entityType} (${record.entityId}) by ${record.actorId} [${record.actorRole}]',
        metadata: {
          'reason': record.reason,
          'previousState': record.previousState,
          'newState': record.newState,
        },
      ));
    } catch (_) {}
  }

  /// Helper to record an audit action with auto-generated ID and current timestamp.
  Future<void> recordAction({
    String? storeId,
    required AuditActionType action,
    required String actorId,
    String actorRole = 'staff',
    required String entityId,
    required String entityType,
    Map<String, dynamic>? previousState,
    Map<String, dynamic>? newState,
    String? reason,
    String? deviceId,
  }) async {
    final record = AuditRecord(
      id: const Uuid().v4(),
      storeId: storeId ?? _storeId,
      action: action,
      actorId: actorId,
      actorRole: actorRole,
      entityId: entityId,
      entityType: entityType,
      previousState: previousState,
      newState: newState,
      reason: reason,
      timestamp: DateTime.now(),
      deviceId: deviceId ?? _deviceId,
    );
    await this.record(record);
  }

  /// Retrieve recent audit records, filtered optionally by storeId and action type.
  List<AuditRecord> getRecentAuditRecords({
    String? storeId,
    AuditActionType? action,
    int limit = 50,
  }) {
    var records = _inMemoryRecords.reversed.toList();
    if (storeId != null && storeId.isNotEmpty) {
      records = records.where((r) => r.storeId == storeId).toList();
    }
    if (action != null) {
      records = records.where((r) => r.action == action).toList();
    }
    return records.take(limit).toList();
  }

  /// Clears in-memory and persistent audit records.
  Future<void> clear() async {
    _inMemoryRecords.clear();
    if (_box != null && _box!.isOpen) {
      await _box!.clear();
    }
  }

  /// Alias for clear() to maintain symmetric interface with DiagnosticsService.
  Future<void> clearLogs() async => clear();

  /// Exports an audit trail JSON bundle.
  Future<String> exportAuditTrail({String? storeId}) async {
    final records = getRecentAuditRecords(storeId: storeId, limit: 500);
    final list = records.map((r) => r.toMap()).toList();
    final bundle = {
      'exportedAt': DateTime.now().toIso8601String(),
      'storeId': storeId ?? 'all',
      'totalRecords': list.length,
      'records': list,
    };
    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  /// Exports raw map list of audit records.
  Future<List<Map<String, dynamic>>> exportAuditLog({String? storeId}) async {
    final records = getRecentAuditRecords(storeId: storeId, limit: 500);
    return records.map((r) => r.toMap()).toList();
  }

  DiagnosticSubsystem _mapActionToSubsystem(AuditActionType action) {
    switch (action) {
      case AuditActionType.refund:
      case AuditActionType.voidOrder:
        return DiagnosticSubsystem.checkout;
      case AuditActionType.priceChange:
      case AuditActionType.stockAdjustment:
        return DiagnosticSubsystem.inventory;
      case AuditActionType.permissionChange:
        return DiagnosticSubsystem.permission;
      case AuditActionType.subscriptionChange:
        return DiagnosticSubsystem.subscription;
      case AuditActionType.storeConfigChange:
      case AuditActionType.adminOperation:
        return DiagnosticSubsystem.recovery;
    }
  }
}
