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
import 'dart:math';

import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/kernel/idempotency/idempotency_service.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/token_service.dart';
import 'package:biztonic_pos/models/order_model.dart';

import '../domain/entities/order_entity.dart';
import '../domain/repositories/billing_repository.dart';
import '../domain/policies/order_policy.dart';
import '../domain/use_cases/calculate_tax.dart';

import 'package:biztonic_pos/features/inventory/domain/entities/inventory_movement.dart';
import 'package:biztonic_pos/features/reporting/domain/entities/business_ledger.dart';

/// Parameters for the checkout orchestration.
class CheckoutParams {
  final OrderEntity order;
  final String activeStoreId;
  final String deviceId;
  final String idempotencyKey;
  final bool trackInventory;
  final double taxRate;

  const CheckoutParams({
    required this.order,
    required this.activeStoreId,
    required this.deviceId,
    required this.idempotencyKey,
    this.trackInventory = false,
    this.taxRate = 0.0,
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

  CheckoutOrchestrator({
    required BillingRepository billingRepository,
  }) : _billingRepository = billingRepository;

  String _generateId(String prefix) => '$prefix-${const Uuid().v4()}';

  Future<CheckoutResult> execute(CheckoutParams params) async {
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
        '🛡️ Idempotency guard: Duplicate checkout blocked '
        '(Key: ${params.idempotencyKey})',
      );
      return CheckoutResult.blocked('Duplicate checkout attempt blocked.');
    }

    // ─── Step 3: Tax Calculation (Pure Domain) ──────────────
    final taxResult = _calculateTax.execute(CalculateTaxParams(
      items: params.order.items,
      taxRate: params.taxRate,
      discountAmount: params.order.discount,
    ));

    // ─── Step 4: Enrich Order with Metadata ─────────────────
    final now = DateTime.now();
    final orderId = params.order.id.isNotEmpty
        ? params.order.id
        : _generateId('ORD');
    final businessDayId =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${params.activeStoreId}';

    final enrichedOrder = params.order.copyWith(
      id: orderId,
      storeId: params.activeStoreId,
      subtotal: taxResult.subtotal,
      cgst: taxResult.cgst,
      sgst: taxResult.sgst,
      taxRateSnapshot: params.taxRate,
      discountSnapshot: params.order.discount,
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
          itemId: item.itemId, // Fix: Changed item.id to item.itemId
          storeId: params.activeStoreId,
          type: MovementType.sale,
          delta: -(item.quantity),
          reason: 'Sale',
          deviceId: params.deviceId,
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
      quantity: enrichedOrder.items.fold(0, (sum, item) => sum + item.quantity),
      createdAt: now,
      deviceId: params.deviceId,
    );

    try {
      // ─── Step 5: Persist to Hive Cache ──────────────────────
      await _persistToCache(enrichedOrder);

      // Decrement stock in-memory Hive cache
      if (movements.isNotEmpty) {
        final invBox = Hive.box('cache_inventory');
        for (var m in movements) {
          final raw = invBox.get(m.itemId);
          if (raw != null && raw is Map) {
            final itemData = Map<String, dynamic>.from(raw);
            final currentQty = (itemData['quantity'] as num?)?.toInt() ?? 0;
            itemData['quantity'] = max(0, currentQty + m.delta); // m.delta is negative
            await invBox.put(m.itemId, itemData);
          }
        }
      }

      // ─── Step 6: Persist via Repository ─────────────────────
      if (!kIsWeb) {
        // NATIVE: Use atomic SQLite transaction
        final legacyOrder = OrderModel.fromEntity(enrichedOrder);
        await _repository.performAtomicCheckout(
          order: legacyOrder,
          movements: movements,
          event: businessEvent,
          storeId: params.activeStoreId,
          yearMonth: '${now.year}-${now.month.toString().padLeft(2, '0')}',
        );
      } else {
        // WEB: Standard Repository Write
        final insertResult = await _billingRepository.insertOrder(enrichedOrder);
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
    }
  }

  /// Persist order to Hive cache for offline-first reads.
  Future<void> _persistToCache(OrderEntity order) async {
    try {
      final orderBox = Hive.box('cache_orders');
      await orderBox.put(order.id, {
        'id': order.id,
        'storeId': order.storeId,
        'total': order.total,
        'status': order.status.value,
        'date': order.date.toIso8601String(),
        'syncStatus': 'PENDING',
      });
    } catch (e) {
      debugPrint('⚠️ Cache persist failed (non-fatal): $e');
    }
  }
}
