/// Application-layer orchestrator for stock adjustment workflows.
///
/// Sits between Presentation and Domain. Coordinates:
///   - Domain policy validation
///   - Repository persistence
///   - Event bus notifications (decoupled sync)
///   - Idempotency guards

import 'package:flutter/foundation.dart';

import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/kernel/idempotency/idempotency_service.dart';

import '../domain/entities/inventory_entity.dart';
import '../domain/repositories/inventory_repository_interface.dart';
import '../domain/policies/inventory_policy.dart';

/// Parameters for creating or updating an inventory item.
class UpsertItemParams {
  final InventoryEntity item;
  final String activeStoreId;
  final String deviceId;
  final String idempotencyKey;

  const UpsertItemParams({
    required this.item,
    required this.activeStoreId,
    required this.deviceId,
    required this.idempotencyKey,
  });
}

/// Result of an inventory orchestration.
class InventoryOrchestratorResult {
  final InventoryEntity? item;
  final String? error;
  final bool isSuccess;
  final List<String> warnings;

  InventoryOrchestratorResult.success(this.item, {this.warnings = const []})
      : error = null,
        isSuccess = true;

  InventoryOrchestratorResult.failure(this.error, {this.warnings = const []})
      : item = null,
        isSuccess = false;
}

/// Orchestrates inventory CRUD workflows.
///
/// Flow for item creation/update:
/// 1. Validate item (Domain Policy)
/// 2. Check idempotency (Infrastructure)
/// 3. Check margin health (Domain Policy)
/// 4. Persist via Repository
/// 5. Fire InventoryUpdatedEvent for SyncEngine
class InventoryOrchestrator {
  final InventoryRepositoryInterface _repository;

  InventoryOrchestrator({
    required InventoryRepositoryInterface repository,
  }) : _repository = repository;

  /// Create or update an inventory item.
  Future<InventoryOrchestratorResult> upsertItem(UpsertItemParams params) async {
    final warnings = <String>[];

    // ─── Step 1: Domain Validation ──────────────────────────
    final validation = InventoryPolicy.canCreate(params.item);
    if (!validation.isValid) {
      return InventoryOrchestratorResult.failure(validation.message);
    }

    // ─── Step 2: Idempotency Guard ──────────────────────────
    final isNew = await IdempotencyService().checkAndReserveKey(
      key: params.idempotencyKey,
      entityType: 'INVENTORY',
      entityId: params.item.id.isNotEmpty ? params.item.id : 'NEW_ITEM',
      deviceId: params.deviceId,
    );

    if (!isNew) {
      debugPrint(
        '🛡️ Idempotency: Duplicate inventory upsert blocked '
        '(Key: ${params.idempotencyKey})',
      );
      return InventoryOrchestratorResult.failure(
        'Duplicate operation blocked.',
      );
    }

    // ─── Step 3: Margin Health Check (Warning, not blocking) ─
    final marginCheck = InventoryPolicy.hasHealthyMargin(params.item);
    if (!marginCheck.isValid) {
      warnings.add(marginCheck.message!);
    }

    // ─── Step 4: Expiry Check (Warning) ─────────────────────
    final expiryCheck = InventoryPolicy.checkExpiry(params.item);
    if (!expiryCheck.isValid) {
      warnings.add(expiryCheck.message!);
    }

    // ─── Step 5: Enrich with Store Metadata ─────────────────
    final enriched = params.item.copyWith(
      storeId: params.activeStoreId,
      deviceId: params.deviceId,
      syncStatus: 'PENDING',
      updatedAt: DateTime.now(),
    );

    try {
      // ─── Step 6: Persist via Repository ─────────────────────
      final insertResult = await _repository.insertItem(enriched);
      if (!insertResult.isSuccess) {
        return InventoryOrchestratorResult.failure(insertResult.error);
      }

      // ─── Step 7: Fire Decoupled Event ───────────────────────
      EventBus.instance.fire(InventoryChangedEvent(
        itemId: enriched.id,
        storeId: params.activeStoreId,
        changeType: 'UPSERT',
      ));

      debugPrint('✅ Inventory upsert complete: ${enriched.id}');
      return InventoryOrchestratorResult.success(enriched, warnings: warnings);
    } catch (e) {
      debugPrint('❌ Inventory upsert failed: $e');
      return InventoryOrchestratorResult.failure('Operation failed: $e');
    }
  }

  /// Delete an inventory item (soft delete).
  Future<InventoryOrchestratorResult> deleteItem({
    required String itemId,
    required String storeId,
  }) async {
    try {
      // Fetch the item first to validate
      final fetchResult = await _repository.getItem(itemId);
      if (!fetchResult.isSuccess || fetchResult.data == null) {
        return InventoryOrchestratorResult.failure('Item not found: $itemId');
      }

      final item = fetchResult.data!;
      final canDelete = InventoryPolicy.canDelete(item);
      if (!canDelete.isValid) {
        return InventoryOrchestratorResult.failure(canDelete.message);
      }

      final deleteResult = await _repository.deleteItem(itemId);
      if (!deleteResult.isSuccess) {
        return InventoryOrchestratorResult.failure(deleteResult.error);
      }

      EventBus.instance.fire(InventoryChangedEvent(
        itemId: itemId,
        storeId: storeId,
        changeType: 'DELETE',
      ));

      debugPrint('✅ Inventory delete complete: $itemId');
      return InventoryOrchestratorResult.success(null);
    } catch (e) {
      debugPrint('❌ Inventory delete failed: $e');
      return InventoryOrchestratorResult.failure('Delete failed: $e');
    }
  }

  /// Get inventory statistics for a store.
  Future<InventoryStats?> getStats(String storeId) async {
    final result = await _repository.getInventoryStats(storeId);
    return result.isSuccess ? result.data : null;
  }
}
