/// Billing Feature — Presentation Provider
///
/// This provider serves as the feature-level state manager for billing.
/// It coordinates between the UI (screens/widgets) and the application
/// layer (CheckoutOrchestrator) while exposing reactive state.
///
/// Migration Notes:
/// - Replaces the billing-related portions of [OrderProvider] and
///   [DashboardProvider] over time.
/// - The legacy providers remain functional during the transition.
library;

import 'package:flutter/foundation.dart';

import 'package:biztonic_pos/services/sync_service.dart';

import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/billing_repository.dart';
import '../../application/checkout_orchestrator.dart';
import '../../data/repositories/billing_repository_impl.dart';

/// Presentation-layer state for billing operations.
enum BillingStatus { idle, loading, success, error }

class BillingProvider with ChangeNotifier {
  // ─── Dependencies ──────────────────────────────────────────
  final BillingRepository _repository;
  final CheckoutOrchestrator _orchestrator;
  final SyncService _syncService;

  // ─── State ─────────────────────────────────────────────────
  List<OrderEntity> _orders = [];
  BillingStatus _status = BillingStatus.idle;
  String? _errorMessage;
  SalesStats? _salesStats;
  bool _hasMore = true;

  // Cart State (Maps InventoryEntity ID to Quantity)
  final Map<String, int> _cart = {};

  // ─── Getters ───────────────────────────────────────────────
  List<OrderEntity> get orders => List.unmodifiable(_orders);
  BillingStatus get status => _status;
  String? get errorMessage => _errorMessage;
  SalesStats? get salesStats => _salesStats;
  bool get hasMore => _hasMore;
  bool get isLoading => _status == BillingStatus.loading;
  Map<String, int> get cart => Map.unmodifiable(_cart);

  // ─── Cart Management ───────────────────────────────────────
  
  void addToCart(String itemId) {
    _cart[itemId] = (_cart[itemId] ?? 0) + 1;
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    if (_cart.containsKey(itemId)) {
      if (_cart[itemId]! > 1) {
        _cart[itemId] = _cart[itemId]! - 1;
      } else {
        _cart.remove(itemId);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  double calculateCartTotal(List<dynamic> inventory) {
    double total = 0;
    _cart.forEach((itemId, quantity) {
      try {
        final item = inventory.firstWhere((i) => i.id == itemId);
        total += item.price * quantity;
      } catch (e) {
        // Item not found in inventory
      }
    });
    return total;
  }

  String generateOrderId() => _syncService.generateUniqueId('ORD');

  BillingProvider(this._syncService, {BillingRepository? repository})
      : _repository = repository ?? BillingRepositoryImpl(),
        _orchestrator = CheckoutOrchestrator(
            billingRepository: repository ?? BillingRepositoryImpl());

  // ─── Checkout (via Orchestrator) ───────────────────────────

  /// Execute a full checkout using the clean architecture pipeline.
  ///
  /// This replaces the legacy `OrderProvider.placeOrder()` call.
  /// It coordinates: validation → idempotency → tax → persist → event.
  Future<CheckoutResult> checkout({
    required OrderEntity order,
    required String activeStoreId,
    required String deviceId,
    required String idempotencyKey,
    double taxRate = 0.0,
    bool trackInventory = false,
    bool checkLimits = true,
  }) async {
    _setStatus(BillingStatus.loading);

    try {
      // 1. Subscription limit check (delegates to SyncService)
      if (checkLimits) {
        await _syncService.checkOrderLimit(activeStoreId);
      }

      // 2. Execute orchestrated checkout
      final result = await _orchestrator.execute(CheckoutParams(
        order: order,
        activeStoreId: activeStoreId,
        deviceId: deviceId,
        idempotencyKey: idempotencyKey,
        taxRate: taxRate,
        trackInventory: trackInventory,
      ));

      if (result.isSuccess && result.order != null) {
        // Optimistic UI: prepend the new order
        _orders.insert(0, result.order!);
        _setStatus(BillingStatus.success);
        
        // Refresh sync counts
        await _syncService.refreshLocalCounts(notify: true);
      } else {
        _setStatus(BillingStatus.error, result.error);
      }

      return result;
    } catch (e) {
      _setStatus(BillingStatus.error, e.toString());
      return CheckoutResult.failure(e.toString());
    }
  }

  // ─── Fetch Orders ──────────────────────────────────────────

  /// Load orders for the active store.
  Future<void> fetchOrders(String? storeId, {bool refresh = false}) async {
    if (isLoading) return;
    if (refresh) {
      _hasMore = true;
      _orders.clear();
    }
    if (!_hasMore) return;

    _setStatus(BillingStatus.loading);

    final result = await _repository.getPaginatedOrders(storeId);
    if (result.isSuccess) {
      final fetched = result.data ?? [];
      if (refresh) {
        _orders = fetched;
      } else {
        _orders.addAll(fetched);
      }
      _hasMore = fetched.length >= 20;
      _setStatus(BillingStatus.success);
    } else {
      _setStatus(BillingStatus.error, result.error);
    }
  }

  /// Load all orders (non-paginated) for reports.
  Future<void> fetchAllOrders(String? storeId) async {
    _setStatus(BillingStatus.loading);
    final result = await _repository.getOrders(storeId);
    if (result.isSuccess) {
      _orders = result.data ?? [];
      _setStatus(BillingStatus.success);
    } else {
      _setStatus(BillingStatus.error, result.error);
    }
  }

  // ─── Sales Stats ───────────────────────────────────────────

  /// Fetch aggregated sales statistics.
  Future<void> fetchSalesStats(
    String storeId, {
    DateTime? start,
    DateTime? end,
    String? status,
    String? paymentMethod,
  }) async {
    final result = await _repository.getSalesStats(
      storeId,
      start: start,
      end: end,
      status: status,
      paymentMethod: paymentMethod,
    );
    if (result.isSuccess) {
      _salesStats = result.data;
      notifyListeners();
    }
  }

  // ─── Order Lookup ──────────────────────────────────────────

  /// Get a single order by ID.
  Future<OrderEntity?> getOrder(String orderId) async {
    final result = await _repository.getOrder(orderId);
    return result.isSuccess ? result.data : null;
  }

  /// Get orders for a specific customer.
  Future<List<OrderEntity>> getOrdersByCustomer(
    String storeId,
    String customerId,
  ) async {
    final result = await _repository.getOrdersByCustomer(storeId, customerId);
    return result.isSuccess ? (result.data ?? []) : [];
  }

  // ─── State Helpers ─────────────────────────────────────────

  void _setStatus(BillingStatus newStatus, [String? error]) {
    _status = newStatus;
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _orders.clear();
    _salesStats = null;
    _status = BillingStatus.idle;
    _errorMessage = null;
    _hasMore = true;
    notifyListeners();
  }
}
