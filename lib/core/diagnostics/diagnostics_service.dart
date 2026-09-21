import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'diagnostics_models.dart';
import '../audit/audit_service.dart';
import '../../services/database_helper.dart';

/// Production-grade diagnostics and observability engine.
/// Provides live monitoring, structured event tracking, automated redaction,
/// and exportable diagnostics for rapid field issue resolution without physical debuggers.
class DiagnosticsService {
  static final DiagnosticsService _instance = DiagnosticsService._internal();
  factory DiagnosticsService() => _instance;
  DiagnosticsService._internal();

  static const String boxName = 'diagnostics_v1';
  static const int maxEventsInMemory = 200;
  static const int maxEventsInStorage = 1000;

  final List<DiagnosticEvent> _inMemoryEvents = [];
  final StreamController<DiagnosticEvent> _eventStreamController =
      StreamController<DiagnosticEvent>.broadcast();

  Stream<DiagnosticEvent> get onDiagnosticEvent =>
      _eventStreamController.stream;

  Box? _box;
  bool _initialized = false;
  String _deviceId = 'device_unknown';
  String _appVersion = '1.0.4+12';

  /// Testing mode toggle to prevent background timer leaks during unit tests
  static bool isTesting = false;

  void configure({required String deviceId, String appVersion = '1.0.4+12'}) {
    _deviceId = deviceId;
    _appVersion = appVersion;
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

      // Preload recent events into memory ring-buffer
      _inMemoryEvents.clear();
      if (_box != null) {
        final values = _box!.values.toList();
        final start = values.length > maxEventsInMemory
            ? values.length - maxEventsInMemory
            : 0;
        for (var i = start; i < values.length; i++) {
          final raw = values[i];
          if (raw is Map) {
            try {
              _inMemoryEvents
                  .add(DiagnosticEvent.fromMap(Map<String, dynamic>.from(raw)));
            } catch (_) {}
          }
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[DiagnosticsService] Init error: $e');
    }
  }

  /// Records a structured diagnostic event.
  Future<void> recordEvent(DiagnosticEvent event) async {
    // In-memory bounded queue
    _inMemoryEvents.add(event);
    if (_inMemoryEvents.length > maxEventsInMemory) {
      _inMemoryEvents.removeAt(0);
    }
    _eventStreamController.add(event);

    // Persistent storage (bounded to 1000 entries)
    if (!isTesting) {
      try {
        if (_box != null && _box!.isOpen) {
          if (_box!.length >= maxEventsInStorage) {
            await _box!.deleteAt(0);
          }
          await _box!.add(event.toMap());
        }
      } catch (e) {
        debugPrint('[DiagnosticsService] Persist error: $e');
      }
    }

    if (kDebugMode && !isTesting) {
      final icon = event.result == DiagnosticResult.success
          ? '✅'
          : (event.result == DiagnosticResult.warning ? '⚠️' : '❌');
      debugPrint(
          '$icon [${event.subsystem.nameUpper}] ${event.operationId}: ${event.message} (${event.durationMs}ms)');
    }
  }

  /// Convenience wrapper to trace asynchronous business operations with automatic duration,
  /// error classification, and secret-safe logging.
  Future<T> trace<T>({
    required DiagnosticSubsystem subsystem,
    required String operationId,
    String? storeId,
    String? userId,
    String? deviceId,
    String? entityId,
    required String actionName,
    Map<String, dynamic>? metadata,
    required Future<T> Function() operation,
    DiagnosticErrorCategory? Function(Object error)? customErrorClassifier,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final result = await operation();
      sw.stop();

      await recordEvent(DiagnosticEvent(
        id: const Uuid().v4(),
        operationId: operationId,
        subsystem: subsystem,
        storeId: storeId,
        userId: userId,
        deviceId: deviceId ?? _deviceId,
        entityId: entityId,
        timestamp: DateTime.now(),
        result: DiagnosticResult.success,
        durationMs: sw.elapsedMilliseconds,
        message: '$actionName succeeded',
        metadata: metadata,
      ));

      return result;
    } catch (e, stack) {
      sw.stop();
      final category =
          customErrorClassifier?.call(e) ?? _classifyError(subsystem, e);

      await recordEvent(DiagnosticEvent(
        id: const Uuid().v4(),
        operationId: operationId,
        subsystem: subsystem,
        storeId: storeId,
        userId: userId,
        deviceId: deviceId ?? _deviceId,
        entityId: entityId,
        timestamp: DateTime.now(),
        result: DiagnosticResult.failure,
        durationMs: sw.elapsedMilliseconds,
        errorCategory: category,
        message:
            '$actionName failed: ${DiagnosticSanitizer.sanitizeString(e.toString())}',
        metadata: metadata,
        stackTrace: stack.toString(),
      ));

      rethrow;
    }
  }

  /// Automatic heuristic error classification.
  DiagnosticErrorCategory _classifyError(
      DiagnosticSubsystem subsystem, Object error) {
    final errStr = error.toString().toLowerCase();

    if (subsystem == DiagnosticSubsystem.migration ||
        errStr.contains('migration') ||
        errStr.contains('schema_upgrade')) {
      return DiagnosticErrorCategory.migrationError;
    }
    if (errStr.contains('socket') ||
        errStr.contains('network') ||
        errStr.contains('timeout') ||
        errStr.contains('connection') ||
        errStr.contains('dns') ||
        errStr.contains('host')) {
      return DiagnosticErrorCategory.networkError;
    }
    if (errStr.contains('sqlite') ||
        errStr.contains('database') ||
        errStr.contains('constraint') ||
        errStr.contains('disk')) {
      return DiagnosticErrorCategory.databaseError;
    }
    if (subsystem == DiagnosticSubsystem.permission ||
        errStr.contains('permission') ||
        errStr.contains('unauthorized') ||
        errStr.contains('forbidden') ||
        errStr.contains('role') ||
        errStr.contains('claims')) {
      return DiagnosticErrorCategory.permissionError;
    }
    if (subsystem == DiagnosticSubsystem.auth ||
        errStr.contains('password') ||
        errStr.contains('auth') ||
        errStr.contains('credentials') ||
        errStr.contains('token') ||
        errStr.contains('lockout')) {
      return DiagnosticErrorCategory.authError;
    }
    if (errStr.contains('conflict') ||
        errStr.contains('divergence') ||
        errStr.contains('version')) {
      return DiagnosticErrorCategory.conflictError;
    }
    if (subsystem == DiagnosticSubsystem.printing ||
        errStr.contains('printer') ||
        errStr.contains('esc/pos') ||
        errStr.contains('bluetooth')) {
      return DiagnosticErrorCategory.printError;
    }
    if (errStr.contains('validation') ||
        errStr.contains('invalid') ||
        errStr.contains('empty')) {
      return DiagnosticErrorCategory.validationError;
    }
    if (subsystem == DiagnosticSubsystem.sync) {
      return DiagnosticErrorCategory.syncError;
    }

    return DiagnosticErrorCategory.internalError;
  }

  /// Maps an exception or error object to its corresponding DiagnosticErrorCategory.
  DiagnosticErrorCategory mapExceptionToCategory(Object error,
      [DiagnosticSubsystem subsystem = DiagnosticSubsystem.recovery]) {
    return _classifyError(subsystem, error);
  }

  /// Retrieve the most recent failure event across the system.
  DiagnosticEvent? getLastError() {
    for (int i = _inMemoryEvents.length - 1; i >= 0; i--) {
      if (_inMemoryEvents[i].result == DiagnosticResult.failure) {
        return _inMemoryEvents[i];
      }
    }
    return null;
  }

  /// Retrieve recent events with optional subsystem and result filtering.
  List<DiagnosticEvent> getRecentEvents({
    DiagnosticSubsystem? subsystem,
    DiagnosticResult? result,
    int limit = 50,
  }) {
    var filtered = _inMemoryEvents.reversed.toList();
    if (subsystem != null) {
      filtered = filtered.where((e) => e.subsystem == subsystem).toList();
    }
    if (result != null) {
      filtered = filtered.where((e) => e.result == result).toList();
    }
    return filtered.take(limit).toList();
  }

  /// Generate a real-time diagnostics summary.
  Map<String, dynamic> getDiagnosticsSummary({
    String? activeStoreId,
    String? cloudConnectivityState,
    int pendingQueueCount = 0,
    int failedQueueCount = 0,
    int deadLetterCount = 0,
    DateTime? lastSyncTime,
  }) {
    final countsBySubsystem = <String, int>{};
    for (final sub in DiagnosticSubsystem.values) {
      countsBySubsystem[sub.nameUpper] = 0;
    }

    int totalFailures = 0;
    for (final e in _inMemoryEvents) {
      countsBySubsystem[e.subsystem.nameUpper] =
          (countsBySubsystem[e.subsystem.nameUpper] ?? 0) + 1;
      if (e.result == DiagnosticResult.failure) {
        totalFailures++;
      }
    }

    final lastErr = getLastError();

    return {
      'appVersion': _appVersion,
      'dbVersion': DatabaseHelper.version,
      'deviceId': _deviceId,
      'activeStoreId': activeStoreId ?? 'none',
      'cloudConnectivity': cloudConnectivityState ?? 'unknown',
      'lastSync': lastSyncTime?.toIso8601String() ?? 'never',
      'queueHealth': {
        'pending': pendingQueueCount,
        'failed': failedQueueCount,
        'deadLetter': deadLetterCount,
        'status': deadLetterCount > 0
            ? 'CRITICAL'
            : (failedQueueCount > 0 ? 'DEGRADED' : 'HEALTHY'),
      },
      'totalTrackedEvents': _inMemoryEvents.length,
      'totalFailures': totalFailures,
      'subsystemEventCounts': countsBySubsystem,
      'lastError': lastErr?.toMap(),
    };
  }

  /// Exports a complete, privacy-compliant diagnostics and audit bundle.
  /// Zero credentials, passwords, PINs, tokens, or raw customer PII are exported.
  Future<String> exportDiagnosticsBundle({
    String? activeStoreId,
    String? cloudConnectivityState,
    int pendingQueueCount = 0,
    int failedQueueCount = 0,
    int deadLetterCount = 0,
    DateTime? lastSyncTime,
  }) async {
    final summary = getDiagnosticsSummary(
      activeStoreId: activeStoreId,
      cloudConnectivityState: cloudConnectivityState,
      pendingQueueCount: pendingQueueCount,
      failedQueueCount: failedQueueCount,
      deadLetterCount: deadLetterCount,
      lastSyncTime: lastSyncTime,
    );

    final recentDiagnostics =
        _inMemoryEvents.reversed.take(150).map((e) => e.toMap()).toList();

    List<Map<String, dynamic>> recentAudit = [];
    try {
      final auditRecords = AuditService().getRecentAuditRecords(limit: 50);
      recentAudit = auditRecords.map((a) => a.toMap()).toList();
    } catch (_) {}

    final bundle = {
      'exportTimestamp': DateTime.now().toIso8601String(),
      'systemSummary': summary,
      'diagnosticEvents': recentDiagnostics,
      'auditTrail': recentAudit,
      'redactionStatement':
          'CONFIDENTIAL: Scrubbed of passwords, PINs, tokens, secret keys, and customer PII.',
    };

    return const JsonEncoder.withIndent('  ').convert(bundle);
  }

  /// Clears in-memory and persistent diagnostic events.
  Future<void> clearLogs() async {
    _inMemoryEvents.clear();
    if (_box != null && _box!.isOpen) {
      await _box!.clear();
    }
  }
}
