import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:biztonic_pos/services/database_helper.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/providers/order_provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/features/orders/domain/usecases/update_order_status_use_case.dart';
import 'package:biztonic_pos/repositories/hardware_repository.dart';
import 'package:biztonic_pos/repositories/addon_review_repository.dart';
import 'package:biztonic_pos/features/settings/data/settings_repository.dart';
import 'package:biztonic_pos/features/auth/data/auth_repository.dart';
import 'package:biztonic_pos/providers/auth_provider.dart';
import 'package:biztonic_pos/sync/outbox/outbox_store.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Presentation Layer Firestore Isolation & Clean Architecture Tests',
      () {
    test(
        '1. Static Codebase Enforcement: Zero direct Firestore calls in lib/screens and lib/widgets',
        () {
      final screensDir = Directory('lib/screens');
      final widgetsDir = Directory('lib/widgets');

      final violations = <String>[];

      void scanDirectory(Directory dir) {
        if (!dir.existsSync()) return;
        final files = dir.listSync(recursive: true).whereType<File>();
        for (final file in files) {
          if (!file.path.endsWith('.dart')) continue;

          final lines = file.readAsLinesSync();
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            final trimmed = line.trim();

            // Ignore comments
            if (trimmed.startsWith('//') ||
                trimmed.startsWith('/*') ||
                trimmed.startsWith('*')) {
              continue;
            }

            if (line.contains('FirebaseFirestore.instance')) {
              violations.add(
                  '${file.path}:${i + 1} -> contains FirebaseFirestore.instance');
            }
            if (line.contains('getFirestore()')) {
              violations
                  .add('${file.path}:${i + 1} -> contains getFirestore()');
            }
            if (line.contains('.collection(')) {
              violations.add('${file.path}:${i + 1} -> contains .collection(');
            }
            if (line.contains('.snapshots(')) {
              violations.add('${file.path}:${i + 1} -> contains .snapshots(');
            }
          }
        }
      }

      scanDirectory(screensDir);
      scanDirectory(widgetsDir);

      if (violations.isNotEmpty) {
        fail(
            'Found direct Firestore operations in presentation layers:\n${violations.join('\n')}');
      }

      expect(violations, isEmpty,
          reason:
              'Presentation layer must be completely free of direct Firestore calls.');
    });

    test(
        '2. UpdateOrderStatusUseCase executes status transition and local mutation pipeline',
        () async {
      final tempDir = Directory.systemTemp.createTempSync('hive_kds_test_');
      Hive.init(tempDir.path);
      await Hive.openBox('cache_orders');
      await Hive.openBox(OutboxStore.primaryQueueBox);
      await Hive.openBox(OutboxStore.deadLetterBox);

      final testDbName = 'test_kds_${DateTime.now().millisecondsSinceEpoch}.db';
      DatabaseHelper.setDbName(testDbName);
      await DatabaseHelper().database;

      final syncService = SyncService();
      await syncService.init();
      final orderProvider = OrderProvider(syncService);

      // Seed an order
      final testOrder = OrderModel(
        id: 'ord_kds_test_001',
        storeId: 'STORE_KDS_ALPHA',
        date: DateTime.now(),
        status: 'New',
        total: 250.0,
        type: 'Dine-In',
        paymentMethod: 'Cash',
        items: [],
      );
      orderProvider.orders.add(testOrder);

      // Execute use case
      final useCase = UpdateOrderStatusUseCase(orderProvider);
      await useCase.execute(const UpdateOrderStatusParams(
        orderId: 'ord_kds_test_001',
        newStatus: 'Preparing',
      ));

      // Verify status changed
      final updated =
          orderProvider.orders.firstWhere((o) => o.id == 'ord_kds_test_001');
      expect(updated.status, equals('Preparing'));

      // Advance to Ready
      await useCase.execute(const UpdateOrderStatusParams(
        orderId: 'ord_kds_test_001',
        newStatus: 'Ready',
      ));
      final readyOrder =
          orderProvider.orders.firstWhere((o) => o.id == 'ord_kds_test_001');
      expect(readyOrder.status, equals('Ready'));

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('3. HardwareRepository encapsulates hardware master data operations',
        () {
      final repo = HardwareRepository();
      expect(repo.getHardwareMasters, isNotNull);
      expect(repo.addHardware, isNotNull);
      expect(repo.updateHardware, isNotNull);
      expect(repo.setHardwareActive, isNotNull);
    });

    test('4. AddonReviewRepository encapsulates review queries and mutations',
        () {
      final repo = AddonReviewRepository();
      expect(repo.getReviews, isNotNull);
      expect(repo.submitReview, isNotNull);
      expect(repo.deleteReview, isNotNull);
    });

    test(
        '5. SettingsRepository exposes app release config publishing without UI direct write',
        () {
      final repo = SettingsRepository();
      expect(repo.getAppReleaseConfig, isNotNull);
      expect(repo.publishAppReleaseConfig, isNotNull);
    });

    test(
        '6. AuthRepository and AuthProvider encapsulate password setup, franchise code and employee lookup',
        () {
      final authRepo = AuthRepository();
      expect(authRepo.completePasswordSetup, isNotNull);
      expect(authRepo.getPendingFranchiseCode, isNotNull);
      expect(authRepo.lookupEmployee, isNotNull);

      final authProvider = AuthProvider();
      expect(authProvider.completePasswordSetup, isNotNull);
      expect(authProvider.getPendingFranchiseCode, isNotNull);
      expect(authProvider.lookupEmployee, isNotNull);
    });

    test(
        '7. OrderProvider and DashboardProvider expose encapsulated KDS and Customer Display streams',
        () {
      final orderProvider = OrderProvider(SyncService());
      final kdsStream = orderProvider.watchKitchenOrders('STORE_XYZ');
      final cfdStream = orderProvider.watchCustomerDisplayOrders('STORE_XYZ');

      expect(kdsStream, isA<Stream<List<OrderModel>>>());
      expect(cfdStream, isA<Stream<List<Map<String, dynamic>>>>());

      final dashboardProvider = DashboardProvider();
      final dkdsStream = dashboardProvider.watchKitchenOrders('STORE_XYZ');
      final dcfdStream =
          dashboardProvider.watchCustomerDisplayOrders('STORE_XYZ');

      expect(dkdsStream, isA<Stream<List<OrderModel>>>());
      expect(dcfdStream, isA<Stream<List<Map<String, dynamic>>>>());
    });
  });
}
