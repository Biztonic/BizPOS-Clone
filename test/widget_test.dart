// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/app.dart';
import 'package:biztonic_pos/services/offline_service.dart';
import 'package:biztonic_pos/sync/sync_engine.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';

void main() {
  setUp(() async {
    // Set isTesting flags to prevent background timers from running during tests
    OfflineService.isTesting = true;
    SyncService.isTesting = true;
    DashboardProvider.isTesting = true;

    // Initialize Hive to a temp directory for tests
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    
    // Open the boxes needed by the app
    await Hive.openBox('settings');
    await Hive.openBox('sync_queue');
    await Hive.openBox('sync_failed_queue');
    await Hive.openBox('sync_logs');
    await Hive.openBox('auth_cache');
    await Hive.openBox('error_logs');
    await Hive.openBox('cache_stores');
    await Hive.openBox('cache_employees');
    await Hive.openBox('cache_floors');
    await Hive.openBox('cache_tables');
    await Hive.openBox('cache_suppliers');
    await Hive.openBox('cache_notes');
    await Hive.openBox('cache_inventory');
    await Hive.openBox('cache_orders');
    await Hive.openBox('cache_customers');
  });

  tearDown(() async {
    await Hive.close();
  });

  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Verify the app builds without crashing
    expect(find.byType(MyApp), findsOneWidget);
  });
}
