/// Application-layer orchestrator for the checkout workflow.
///
/// This is the COORDINATION hub that sits between Presentation and Domain.
/// It orchestrates multi-step workflows that span:
///   - Domain use cases (tax calculation, validation)
///   - Repository operations (local insert, cache update)
///   - Event bus (decoupled sync triggers)
///   - Idempotency guards
///
/// The Presentation layer calls THIS, not the domain directly.
library;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_models.dart';
import 'package:biztonic_pos/core/diagnostics/diagnostics_service.dart';
import 'package:biztonic_pos/kernel/idempotency/idempotency_service.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/token_service.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/sync/outbox/outbox_operation.dart';

import '../domain/entities/order_entity.dart';
import '../domain/repositories/billing_repository.dart';
import '../domain/policies/order_policy.dart';
import '../domain/use_cases/calculate_tax.dart';

import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/inventory/domain/policies/inventory_policy.dart';
import 'package:biztonic_pos/features/reporting/domain/entities/business_ledger.dart';
import 'package:biztonic_pos/services/sync_service.dart';

/// Parameters for the checkout orchestration.
class CheckoutParams {
  final OrderEntity order;
  final String activeStoreId;
  final String deviceId;
  final String idempotencyKey;
  final bool trackInventory;
  final double taxRate;
  final NegativeStockPolicy negativeStockPolicy;

  const CheckoutParams({
    required this.order,
    required this.activeStoreId,
    required this.deviceId,
    required this.idempotencyKey,
    this.trackInventory = true,
    this.taxRate = 0.0,
    this.negativeStockPolicy = NegativeStockPolicy.allowWithWarning,
  });
}

/// Result of the checkout orchestration.
class CheckoutResult {
  final OrderEntity? order;
  final String? error;
  final bool isSuccess;

  CheckoutResult.success(this.order)
      : error = null,
        isSuccess = true;

  CheckoutResult.failure(this.error)
      : order = null,
        isSuccess = false;

  CheckoutResult.blocked(this.error)
      : order = null,
        isSuccess = false;
}

/// Orchestrates the full checkout workflow.
///
/// Flow:
/// 1. Validate order (Domain Policy)
/// 2. Check idempotency (Infrastructure)
/// 3. Calculate tax (Domain UseCase)
/// 4. Enrich order with metadata
/// 5. Persist to local cache (Hive)
/// 6. Persist to local DB via Repository
/// 7. Fire OrderCreatedEvent for SyncEngine
class CheckoutOrchestrator {
  final BillingRepository _billingRepository;
  final Repository _repository = Repository();
  final TokenService _tokenService = TokenService();
  final CalculateTaxUseCase _calculateTax = CalculateTaxUseCase();
  final SyncService _syncService = SyncService();

  CheckoutOrchestrator({
    required BillingRepository billingRepository,
  }) : _billingRepository = billingRepository;

  String _generateId(String prefix) => '$prefix-${const Uuid().v4()}';

  Future<CheckoutResult> execute(CheckoutParams params) async {
    return await DiagnosticsService().trace<CheckoutResult>(
      subsystem: DiagnosticSubsystem.checkout,
      operationId:
          'checkout_${params.order.id.isNotEmpty ? params.order.id : params.idempotencyKey}',
      storeId: params.activeStoreId,
      deviceId: params.deviceId,
      entityId: params.order.id,
      actionName: 'Order Checkout',
      metadata: {
        'itemCount': params.order.items.length,
        'taxRate': params.taxRate,
        'hasDiscount': params.order.discount > 0,
      },
      operation: () => _executeInternal(params),
    );
  }

  Future<CheckoutResult> _executeInternal(CheckoutParams params) async {
    // ─── Step 1: Domain Validation ──────────────────────────
    final validation = OrderPolicy.canCreate(params.order);
    if (!validation.isValid) {
      return CheckoutResult.failure(validation.message);
    }

    // ─── Step 2: Idempotency Guard ──────────────────────────
    final isNewRequest = await IdempotencyService().checkAndReserveKey(
      key: params.idempotencyKey,
      entityType: 'ORDER',
      entityId: params.order.id.isNotEmpty ? params.order.id : 'NEW_ORDER',
      deviceId: params.deviceId,
    );

    if (!isNewRequest) {
      debugPrint(
        '🛡️ Idempotency guard: Duplicate checkout intercepted '
        '(Key: ${params.idempotencyKey})',
      );
      // Attempt to return existing order if already completed
      final reservedId =
          await IdempotencyService().getReservedEntityId(params.idempotencyKey);
      final targetId = (reservedId != null && reservedId != 'NEW_ORDER')
          ? reservedId
          : (params.order.id.isNotEmpty ? params.order.id : null);
      if (targetId != null) {
        final existing = await _billingRepository.getOrder(targetId);
        if (existing.isSuccess && existing.data != null) {
          return CheckoutResult.success(existing.data!);
        }
      }
      return CheckoutResult.blocked('Duplicate checkout attempt blocked.');
    }

    try {
      // ─── Step 3: Tax Calculation (Pure Domain Authority) ────
      final taxResult = _calculateTax.execute(CalculateTaxParams(
        items: params.order.items,
        taxRate: params.taxRate,
        discountAmount: params.order.discount,
      ));

      // ─── Step 4: Enrich Order with Metadata ─────────────────
      final now = DateTime.now();
      final orderId =
          params.order.id.isNotEmpty ? params.order.id : _generateId('ORD');
      final businessDayId =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${params.activeStoreId}';

      final enrichedOrder = params.order.copyWith(
        id: orderId,
        storeId: params.activeStoreId,
        total: taxResult.total,
        subtotal: taxResult.subtotal,
        cgst: taxResult.cgst,
        sgst: taxResult.sgst,
        taxRateSnapshot: params.taxRate,
        discountSnapshot: taxResult.discount,
        deviceId: params.deviceId,
        businessDayId: businessDayId,
        syncStatus: 'PENDING',
        date: now,
      );

      // Generate Inventory Movements if tracking is enabled
      final List<InventoryMovement> movements = [];
      if (params.trackInventory) {
        for (var item in enrichedOrder.items) {
          movements.add(InventoryMovement(
            id: _generateId('INV_MOV'),
            itemId: item.itemId,
            storeId: params.activeStoreId,
            type: MovementType.sale,
            delta: -(item.quantity),
            orderId: orderId,
            unitCost: item.cost,
            reason: 'Sale',
            deviceId: params.deviceId,
            operationId: 'sale_${orderId}_${item.itemId}',
            createdAt: now,
          ));
        }
      }

      // Generate Business Ledger Event
      final businessEvent = BusinessEvent(
        id: _generateId('BIZ'),
        storeId: params.activeStoreId,
        entityType: 'ORDER',
        entityId: orderId,
        eventType: 'CREATE',
        amount: enrichedOrder.total,
        quantity:
            enrichedOrder.items.fold(0, (sum, item) => sum + item.quantity),
        createdAt: now,
        deviceId: params.deviceId,
      );

      // ─── Step 5: Persist to Hive Cache ──────────────────────
      await _persistToCache(enrichedOrder);

      // Decrement stock in-memory Hive cache & sync to cloud
      if (movements.isNotEmpty) {
        final invBox = Hive.isBoxOpen('cache_inventory')
            ? Hive.box('cache_inventory')
            : await Hive.openBox('cache_inventory');
        for (var m in movements) {
          final raw = invBox.get(m.itemId);
          if (raw != null && raw is Map) {
            final itemData = Map<String, dynamic>.from(raw);
            final currentQty = (itemData['quantity'] as num?)?.toInt() ?? 0;
            itemData['quantity'] = currentQty + m.delta; // Keep true net stock
            itemData['updatedAt'] = now.toIso8601String();
            await invBox.put(m.itemId, itemData);

            // Authoritatively persist updated inventory item to cloud & local outbox
            await _syncService.performLocalWrite(
              collection: 'inventory',
              docId: m.itemId,
              data: itemData,
              action: 'update',
              localCacheBox: 'cache_inventory',
              refreshCounts: true,
            );
          }
        }
      }

      // ─── Step 6: Persist via Repository ─────────────────────
      if (!kIsWeb) {
        // NATIVE: Use atomic SQLite transaction
        final legacyOrder = OrderModel.fromEntity(enrichedOrder);
        final outboxOp = OutboxOperation(
          operationId: 'op_order_$orderId',
          storeId: params.activeStoreId,
          userId: 'system',
          deviceId: params.deviceId,
          collection: 'orders',
          entityId: orderId,
          operation: 'CREATE',
          payload: legacyOrder.toHiveMap(),
        );

        await _repository.performAtomicCheckout(
          order: legacyOrder,
          movements: movements,
          event: businessEvent,
          storeId: params.activeStoreId,
          yearMonth: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          outboxOperations: [outboxOp],
          negativeStockPolicy: params.negativeStockPolicy,
        );
      } else {
        // WEB: Standard Repository Write
        final insertResult =
            await _billingRepository.insertOrder(enrichedOrder);
        if (!insertResult.isSuccess) {
          return CheckoutResult.failure(insertResult.error);
        }
        await _tokenService.incrementOrderCounter(params.activeStoreId);
      }

      // ─── Step 7: Fire Decoupled Event ───────────────────────
      EventBus.instance.fire(OrderCreatedEvent(
        order: enrichedOrder,
        storeId: params.activeStoreId,
        event: businessEvent,
        movements: movements,
      ));

      debugPrint('✅ Checkout complete: $orderId');
      return CheckoutResult.success(enrichedOrder);
    } catch (e) {
      debugPrint('❌ Checkout failed: $e');
      return CheckoutResult.failure('Checkout failed: $e');
    } finally {
      IdempotencyService().releaseInFlight(params.idempotencyKey);
    }
  }

  /// Persist order to Hive cache for offline-first reads.
  Future<void> _persistToCache(OrderEntity order) async {
    try {
      final orderBox = Hive.box('cache_orders');
      final legacyOrder = OrderModel.fromEntity(order);
      await orderBox.put(order.id, legacyOrder.toHiveMap());
    } catch (e) {
      debugPrint('⚠️ Cache persist failed (non-fatal): $e');
    }
  }
}
