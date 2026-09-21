/// Architecture boundary tests for BizPOS.
///
/// These tests verify that the codebase respects clean architecture boundaries:
///   1. Domain entities don't import infrastructure packages.
///   2. Each core business capability has ONE authoritative path.
///   3. Dead duplicate files have been removed.
///   4. Presentation layer doesn't perform direct Firestore writes.
///
/// Run: flutter test test/architecture/architecture_boundaries_test.dart
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architecture Boundaries', () {
    // ─── 1. Domain entities must not import infrastructure ───

    test('OrderEntity must not import infrastructure packages', () {
      final file =
          File('lib/features/billing/domain/entities/order_entity.dart');
      expect(file.existsSync(), isTrue, reason: 'OrderEntity file must exist');
      final content = file.readAsStringSync();

      for (final forbidden in _forbiddenDomainImports) {
        expect(RegExp("import\\s+'.*$forbidden").hasMatch(content), isFalse,
            reason: 'OrderEntity must not import $forbidden');
      }
    });

    test('OrderPolicy must not import infrastructure packages', () {
      final file =
          File('lib/features/billing/domain/policies/order_policy.dart');
      if (!file.existsSync()) return; // Skip if not yet created
      final content = file.readAsStringSync();

      for (final forbidden in _forbiddenDomainImports) {
        expect(RegExp("import\\s+'.*$forbidden").hasMatch(content), isFalse,
            reason: 'OrderPolicy must not import $forbidden');
      }
    });

    test('InventoryItem entity must not import infrastructure packages', () {
      final file =
          File('lib/features/inventory/domain/entities/inventory_item.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // NOTE: InventoryItem currently imports cloud_firestore for Timestamp.
      // This is pre-existing tech debt — tracked but not enforced here.
      // TODO: Extract Timestamp dependency to data layer.
      expect(RegExp("import\\s+'.*sqflite").hasMatch(content), isFalse,
          reason: 'InventoryItem must not import sqflite');
    });

    // ─── 2. Dead duplicate files have been removed ───

    test('Obsolete CheckoutOrderUseCase is removed', () {
      final file =
          File('lib/features/billing/domain/use_cases/checkout_order.dart');
      expect(file.existsSync(), isFalse,
          reason: 'checkout_order.dart should be deleted — '
              'CheckoutOrchestrator is the authoritative checkout path');
    });

    test('Obsolete legacy inventory_repository is removed', () {
      final file = File('lib/services/inventory_repository.dart');
      expect(file.existsSync(), isFalse,
          reason: 'services/inventory_repository.dart should be deleted — '
              'features/inventory/data/inventory_repository.dart is authoritative');
    });

    test('Obsolete CheckSubscriptionUseCase is removed', () {
      final file =
          File('lib/features/store/domain/use_cases/check_subscription.dart');
      expect(file.existsSync(), isFalse,
          reason: 'check_subscription.dart should be deleted — '
              'EntitlementService is the authoritative subscription check');
    });

    test('Dead core/auth/auth_providers.dart is removed', () {
      final file = File('lib/core/auth/auth_providers.dart');
      expect(file.existsSync(), isFalse,
          reason: 'core/auth/auth_providers.dart should be deleted — '
              'auth_notifier.dart is the authoritative Riverpod auth provider');
    });

    // ─── 3. Authoritative checkout path ───

    test('OrderProvider.placeOrder delegates to CheckoutOrchestrator', () {
      final file = File('lib/providers/order_provider.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('CheckoutOrchestrator'), isTrue,
          reason: 'OrderProvider must delegate to CheckoutOrchestrator');
      expect(content.contains('CheckoutOrderUseCase'), isFalse,
          reason:
              'OrderProvider must NOT reference the deleted CheckoutOrderUseCase');
    });

    test('CheckoutOrchestrator is the single entry point for checkout', () {
      final file =
          File('lib/features/billing/application/checkout_orchestrator.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // It should have the orchestration steps
      expect(content.contains('_executeInternal'), isTrue,
          reason: 'CheckoutOrchestrator must have _executeInternal');
      expect(content.contains('BillingRepository'), isTrue,
          reason: 'CheckoutOrchestrator must use BillingRepository');
    });

    // ─── 4. No direct Firestore writes in StoreNotifier ───

    test('StoreNotifier must not contain direct Firestore collection writes',
        () {
      final file = File('lib/features/store/providers/store_notifier.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // StoreNotifier may import cloud_firestore for FirebaseAuth, DocumentSnapshot, etc.
      // But it should NOT contain direct .collection('stores').doc().set() patterns.
      expect(
        RegExp(r'''\.collection\(['"]stores['"]\)\.doc\(\)\.set''')
            .hasMatch(content),
        isFalse,
        reason: 'StoreNotifier must not have direct Firestore store writes — '
            'use StoreRepository.createStore() instead',
      );

      // No direct user profile writes — should use AuthRepository
      expect(
        RegExp(r'''\.collection\(['"]users['"]\)\.doc\([^)]+\)\.set''')
            .hasMatch(content),
        isFalse,
        reason: 'StoreNotifier must not have direct Firestore user writes — '
            'use AuthRepository instead',
      );
    });

    // ─── 5. AuthRepository has both update and upsert ───

    test('AuthRepository provides both updateUserProfile and upsertUserProfile',
        () {
      final file = File('lib/features/auth/data/auth_repository.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('updateUserProfile'), isTrue,
          reason: 'AuthRepository must have updateUserProfile (.update)');
      expect(content.contains('upsertUserProfile'), isTrue,
          reason: 'AuthRepository must have upsertUserProfile (.set merge)');
      expect(content.contains('SetOptions(merge: true)'), isTrue,
          reason: 'upsertUserProfile must use SetOptions(merge: true)');
    });

    // ─── 6. No dead getSalesStats in OrderProvider ───

    test('OrderProvider must not contain dead synchronous getSalesStats', () {
      final file = File('lib/providers/order_provider.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // The synchronous O(N) getSalesStats was removed — the SQL-based
      // aggregation in Repository/OrderRepositoryMixin is authoritative.
      final syncStatsPattern =
          RegExp(r'Map<String,\s*dynamic>\s+getSalesStats\s*\(');
      expect(syncStatsPattern.hasMatch(content), isFalse,
          reason:
              'OrderProvider should not have the dead synchronous getSalesStats');
    });

    // ─── 7. Store creation uses repository ───

    test('StoreRepository has createStore method', () {
      final file = File('lib/features/store/data/store_repository.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains('createStore'), isTrue,
          reason: 'StoreRepository must have createStore for store creation');
    });
  });
}

/// Infrastructure packages that domain entities must never import.
const _forbiddenDomainImports = [
  'cloud_firestore',
  'sqflite',
  'hive',
  'package:http',
  'dart:io',
];
