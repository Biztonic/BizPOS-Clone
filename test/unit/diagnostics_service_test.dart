import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_models.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    DiagnosticsService.isTesting = true;
    tempDir = await Directory.systemTemp.createTemp('diag_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    final service = DiagnosticsService();
    await service.init();
    await service.clearLogs();
  });

  group('DiagnosticsService', () {
    test('trace executes action and records successful event with duration',
        () async {
      final service = DiagnosticsService();
      service.configure(deviceId: 'dev_test_1', appVersion: '2.0.0');

      final result = await service.trace<String>(
        operationId: 'op_test_checkout',
        subsystem: DiagnosticSubsystem.checkout,
        storeId: 'store_101',
        userId: 'user_cashier_1',
        entityId: 'ord_999',
        actionName: 'Test Checkout',
        operation: () async {
          await Future.delayed(const Duration(milliseconds: 15));
          return 'order_completed';
        },
      );

      expect(result, equals('order_completed'));
      final events = service.getRecentEvents();
      expect(events.length, equals(1));

      final ev = events.first;
      expect(ev.operationId, equals('op_test_checkout'));
      expect(ev.subsystem, equals(DiagnosticSubsystem.checkout));
      expect(ev.storeId, equals('store_101'));
      expect(ev.userId, equals('user_cashier_1'));
      expect(ev.entityId, equals('ord_999'));
      expect(ev.deviceId, equals('dev_test_1'));
      expect(ev.result, equals(DiagnosticResult.success));
      expect(ev.durationMs, greaterThanOrEqualTo(10));
      expect(ev.errorCategory, isNull);
    });

    test(
        'trace captures exception and auto-categorizes error across subsystems',
        () async {
      final service = DiagnosticsService();

      // Test database error mapping
      await expectLater(
        service.trace(
          operationId: 'op_db_err',
          subsystem: DiagnosticSubsystem.inventory,
          actionName: 'Test DB Lock',
          operation: () async =>
              throw Exception('sqlite3 error: database is locked'),
        ),
        throwsA(isA<Exception>()),
      );

      final lastError = service.getLastError();
      expect(lastError, isNotNull);
      expect(lastError!.operationId, equals('op_db_err'));
      expect(lastError.result, equals(DiagnosticResult.failure));
      expect(lastError.errorCategory,
          equals(DiagnosticErrorCategory.databaseError));
    });

    test('error categorization correctly maps all mandated categories', () {
      final service = DiagnosticsService();

      expect(
          service.mapExceptionToCategory(
              Exception('invalid credentials on login')),
          equals(DiagnosticErrorCategory.authError));
      expect(
          service
              .mapExceptionToCategory(Exception('unauthorized access denied')),
          equals(DiagnosticErrorCategory.permissionError));
      expect(
          service.mapExceptionToCategory(
              Exception('validation failed: quantity cannot be zero')),
          equals(DiagnosticErrorCategory.validationError));
      expect(
          service.mapExceptionToCategory(
              Exception('socket exception: connection timeout')),
          equals(DiagnosticErrorCategory.networkError));
      expect(
          service.mapExceptionToCategory(Exception('sqflite database locked')),
          equals(DiagnosticErrorCategory.databaseError));
      expect(
          service.mapExceptionToCategory(
              Exception('replication transport closed'),
              DiagnosticSubsystem.sync),
          equals(DiagnosticErrorCategory.syncError));
      expect(
          service.mapExceptionToCategory(Exception('state conflict detected')),
          equals(DiagnosticErrorCategory.conflictError));
      expect(
          service.mapExceptionToCategory(
              Exception('printer paper out / ESC POS error')),
          equals(DiagnosticErrorCategory.printError));
      expect(
          service.mapExceptionToCategory(
              Exception('database migration schema v26 failed')),
          equals(DiagnosticErrorCategory.migrationError));
      expect(
          service.mapExceptionToCategory(Exception('unhandled runtime crash')),
          equals(DiagnosticErrorCategory.internalError));
    });

    test('ring buffer maintains maximum in-memory event bound', () async {
      final service = DiagnosticsService();

      for (var i = 0; i < 250; i++) {
        await service.recordEvent(DiagnosticEvent(
          id: 'evt_$i',
          operationId: 'op_$i',
          subsystem: DiagnosticSubsystem.sync,
          deviceId: 'dev_1',
          timestamp: DateTime.now(),
          result: DiagnosticResult.success,
          durationMs: 5,
          message: 'Sync step $i',
        ));
      }

      final events = service.getRecentEvents(limit: 300);
      expect(events.length, equals(DiagnosticsService.maxEventsInMemory));
      expect(events.first.operationId, equals('op_249'));
      expect(events.last.operationId, equals('op_50'));
    });

    test('getDiagnosticsSummary aggregates telemetry metrics correctly',
        () async {
      final service = DiagnosticsService();

      await service.recordEvent(DiagnosticEvent(
        id: 'evt_1',
        operationId: 'op_1',
        subsystem: DiagnosticSubsystem.checkout,
        deviceId: 'dev_1',
        timestamp: DateTime.now(),
        result: DiagnosticResult.success,
        durationMs: 10,
        message: 'Success',
      ));

      await service.recordEvent(DiagnosticEvent(
        id: 'evt_2',
        operationId: 'op_2',
        subsystem: DiagnosticSubsystem.auth,
        deviceId: 'dev_1',
        timestamp: DateTime.now(),
        result: DiagnosticResult.failure,
        durationMs: 20,
        errorCategory: DiagnosticErrorCategory.authError,
        message: 'Failure',
      ));

      final summary = service.getDiagnosticsSummary();
      expect(summary['totalTrackedEvents'], equals(2));
      expect(summary['totalFailures'], equals(1));
      expect(summary['lastError']?['operationId'], equals('op_2'));
    });

    test('exportDiagnosticsBundle returns sanitized, complete bundle',
        () async {
      final service = DiagnosticsService();

      await service.recordEvent(DiagnosticEvent(
        id: 'export_evt',
        operationId: 'op_export',
        subsystem: DiagnosticSubsystem.checkout,
        storeId: 'store_export',
        deviceId: 'dev_export',
        timestamp: DateTime.now(),
        result: DiagnosticResult.success,
        durationMs: 15,
        message: 'Order created',
        metadata: {
          'orderId': 'ord_123',
          'auth_token': 'secret_token_val',
        },
      ));

      final bundleJson = await service.exportDiagnosticsBundle();
      final bundle = jsonDecode(bundleJson) as Map<String, dynamic>;
      expect(bundle['exportTimestamp'], isNotNull);
      expect(bundle['systemSummary'], isNotNull);
      expect(bundle['diagnosticEvents'], isA<List>());

      final eventList = bundle['diagnosticEvents'] as List;
      final exportedEvent = eventList.first as Map<String, dynamic>;
      final metadata = exportedEvent['metadata'] as Map<String, dynamic>;
      expect(metadata['orderId'], equals('ord_123'));
      expect(metadata['auth_token'], equals('[REDACTED]'));
    });
  });
}
