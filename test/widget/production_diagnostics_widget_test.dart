import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/screens/admin/production_diagnostics_screen.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_models.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_service.dart';
import 'package:biztonic_pos/core/audit/audit_models.dart';
import 'package:biztonic_pos/core/audit/audit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    DiagnosticsService.isTesting = true;
    AuditService.isTesting = true;
    tempDir = await Directory.systemTemp.createTemp('widget_diag_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await DiagnosticsService().init();
    await DiagnosticsService().clearLogs();
    await AuditService().init();
    await AuditService().clearLogs();
  });

  group('ProductionDiagnosticsScreen Widget Tests', () {
    testWidgets('renders telemetry header cards and tab bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: ProductionDiagnosticsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(
          find.text('Production Diagnostics & Observability'), findsOneWidget);
      expect(find.text('Export Bundle'), findsOneWidget);

      // Verify 4 Telemetry Overview Cards
      expect(find.text('App & DB Version'), findsOneWidget);
      expect(find.text('Device & Store'), findsOneWidget);
      expect(find.text('Cloud Connectivity'), findsOneWidget);
      expect(find.text('Queue Health'), findsOneWidget);

      // Verify Tab headers
      expect(find.text('System Diagnostics'), findsOneWidget);
      expect(find.text('Audit Trail'), findsOneWidget);

      // Verify empty diagnostics state
      expect(find.text('No diagnostic events recorded yet'), findsOneWidget);
    });

    testWidgets('displays diagnostic events and switches to audit trail tab',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await DiagnosticsService().recordEvent(DiagnosticEvent(
        id: 'evt_widget_1',
        operationId: 'op_checkout_sync',
        subsystem: DiagnosticSubsystem.checkout,
        storeId: 'store_delhi_1',
        deviceId: 'pos_terminal_1',
        entityId: 'ord_123',
        timestamp: DateTime.now(),
        result: DiagnosticResult.success,
        durationMs: 42,
        message: 'Order ord_123 completed successfully',
      ));

      await AuditService().recordAction(
        storeId: 'store_delhi_1',
        action: AuditActionType.refund,
        actorId: 'manager_smith',
        actorRole: 'MANAGER',
        entityId: 'ord_123',
        entityType: 'ORDER',
        reason: 'Defective item returned',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProductionDiagnosticsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // System Diagnostics should show the event
      expect(find.text('op_checkout_sync'), findsOneWidget);
      expect(find.text('CHECKOUT'), findsWidgets);

      // Switch to Audit Trail tab
      await tester.tap(find.text('Audit Trail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Audit record is rendered
      expect(find.text('REFUND'), findsWidgets);
      expect(find.textContaining('manager_smith'), findsOneWidget);
      expect(find.text('Defective item returned'), findsOneWidget);
    });
  });
}
