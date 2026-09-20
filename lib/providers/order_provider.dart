import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/store.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/business_ledger.dart';
import 'package:biztonic_pos/features/billing/application/checkout_orchestrator.dart';
import 'package:biztonic_pos/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/sync/entitlements/entitlement_service.dart';
import 'package:biztonic_pos/core/audit/audit_models.dart';
import 'package:biztonic_pos/core/audit/audit_service.dart';
import 'package:intl/intl.dart';

class OrderProvider with ChangeNotifier {
  late final FirebaseFirestore _db = getFirestore(); // ignore: unused_field
  final Repository _repository = Repository();
  final InventoryMovementRepository _movementRepo =
      InventoryMovementRepository();
  final SyncService _syncService;

  // State
  final List<OrderModel> _orders = [];
  bool _isLoading = false;
  bool _isPlacingOrder = false;
  bool _hasMore = true;
  bool _isUnrestricted = false; // NEW
  DateTime? _lastOrderDate;
  String? _lastOrderId;
  final int _ordersPerPage = 20;

  // Getters
  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isPlacingOrder => _isPlacingOrder;
  bool get hasMore => _hasMore;
  bool get isUnrestricted => _isUnrestricted; // NEW
  SyncService get syncService => _syncService;

  set isUnrestricted(bool value) {
    _isUnrestricted = value;
    notifyListeners();
  }

  StreamSubscription? _orderCreatedSub;
  StreamSubscription? _syncCompletedSub;

  OrderProvider(this._syncService) {
    // Listen to OrderCreatedEvent from EventBus so that orders created via
    // BillingProvider.checkout() (standard POS) are also reflected here.
    _orderCreatedSub = EventBus.instance.on<OrderCreatedEvent>((event) {
      _handleOrderCreatedEvent(event);
    });

    // Listen to SyncCompletedEvent to reload orders from cache/DB
    _syncCompletedSub = EventBus.instance.on<SyncCompletedEvent>((event) {
      fetchOrders(event.storeId, refresh: true);
    });
  }

  /// Handle an OrderCreatedEvent by inserting the order into the local list
  /// if it doesn't already exist (avoids duplicates when OrderProvider.placeOrder
  /// already inserted it via the automotive theme path).
  void _handleOrderCreatedEvent(OrderCreatedEvent event) {
    try {
      OrderModel orderModel;
      if (event.order is OrderModel) {
        orderModel = event.order as OrderModel;
      } else {
        // OrderEntity from BillingProvider path — convert to OrderModel
        orderModel = OrderModel.fromEntity(event.order);
      }

      // Avoid duplicates: only insert if the order isn't already in the list
      final alreadyExists = _orders.any((o) => o.id == orderModel.id);
      if (!alreadyExists) {
        _orders.insert(0, orderModel);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('OrderProvider: Error handling OrderCreatedEvent: $e');
    }
  }

  Future<void> clearOrders() async {
    _orders.clear();
    _hasMore = true;
    _lastOrderDate = null;
    _lastOrderId = null;
    notifyListeners();
  }

  // --- FETCHING ---

  Future<void> fetchOrders(String? storeId, {bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _hasMore = true;
      _lastOrderDate = null;
      _lastOrderId = null;
      // Do not clear _orders immediately to prevent flash
    }

    if (!_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        // WEB: Use Hive Cache (SyncService manages the cloud sync)
        try {
          final box = await Hive.openBox('cache_orders');
          final String? targetStoreId = storeId?.trim();

          if (targetStoreId == null) return;

          // HELPER: Recursive cast for Hive maps
          Map<String, dynamic> recursiveCast(Map map) {
            return map.map((key, value) {
              if (value is Map)
                return MapEntry(key.toString(), recursiveCast(value));
              if (value is List)
                return MapEntry(key.toString(),
                    value.map((e) => e is Map ? recursiveCast(e) : e).toList());
              return MapEntry(key.toString(), value);
            });
          }

          final cachedData = box.values
              .where((v) {
                if (v is! Map) return false;
                final vStoreId = (v['storeId'] ?? '').toString().trim();
                return vStoreId == targetStoreId && v['deletedAt'] == null;
              })
              .map((e) => recursiveCast(e as Map))
              .toList();

          // Sort Descending by Date
          cachedData.sort((a, b) => (b['date'] ?? '')
              .toString()
              .compareTo((a['date'] ?? '').toString()));
          _orders.clear();
          _orders.addAll(
              cachedData.map((d) => OrderModel.fromMap(d, d['id'] ?? '')));

          _hasMore = false; // SyncService handles full pull
          notifyListeners();
        } catch (e) {/* Error ignored */}
      } else {
        // MOBILE/DESKTOP: Use Repository
        final DateTime? fetchAfterDate = refresh ? null : _lastOrderDate;
        final String? fetchAfterId = refresh ? null : _lastOrderId;
        final newOrders = await _repository.getPaginatedOrders(storeId,
            limit: _ordersPerPage,
            lastDate: fetchAfterDate,
            lastId: fetchAfterId);

        if (refresh) {
          _orders.clear(); // Clear only when new data arrives
        }

        if (newOrders.isEmpty) {
          // OFFLINE-FIRST: Fallback to Hive if SQLite is empty
          if (refresh) {
            try {
              final box = await Hive.openBox('cache_orders');
              final String? targetStoreId = storeId?.trim();
              if (targetStoreId != null) {
                Map<String, dynamic> recursiveCast(Map map) {
                  return map.map((key, value) {
                    if (value is Map)
                      return MapEntry(key.toString(), recursiveCast(value));
                    if (value is List)
                      return MapEntry(
                          key.toString(),
                          value
                              .map((e) => e is Map ? recursiveCast(e) : e)
                              .toList());
                    return MapEntry(key.toString(), value);
                  });
                }

                final cachedData = box.values
                    .where((v) {
                      if (v is! Map) return false;
                      return (v['storeId'] ?? '').toString().trim() ==
                              targetStoreId &&
                          v['deletedAt'] == null;
                    })
                    .map((e) => recursiveCast(e as Map))
                    .toList();

                if (cachedData.isNotEmpty) {
                  cachedData.sort((a, b) => (b['date'] ?? '')
                      .toString()
                      .compareTo((a['date'] ?? '').toString()));
                  _orders.addAll(cachedData
                      .map((d) => OrderModel.fromMap(d, d['id'] ?? '')));
                }
              }
            } catch (e) {/* Error ignored */}
          }
          _hasMore = false;
        } else {
          _orders.addAll(newOrders);
          _lastOrderDate = newOrders.last.date;
          _lastOrderId = newOrders.last.id;

          if (newOrders.length < _ordersPerPage) {
            _hasMore = false;
          }
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// High-efficiency paginated recent orders fetch (bypassing full in-memory list)
  Future<List<OrderModel>> fetchRecentOrders(
    String? storeId, {
    int limit = 50,
    DateTime? start,
    DateTime? end,
    String? status,
    String? paymentMethod,
  }) async {
    if (kIsWeb) {
      return _orders.take(limit).toList();
    }
    return await _repository.getPaginatedOrders(
      storeId,
      limit: limit,
      start: start,
      end: end,
      status: status,
      paymentMethod: paymentMethod,
    );
  }

  // --- ACTIONS ---

  Future<void> placeOrder(OrderModel order, Store? activeStore,
      {String? idempotencyKey}) async {
    if (activeStore == null) throw Exception("No active store selected");
    if (_isPlacingOrder) {
      throw Exception("Order placement already in progress");
    }
    _isPlacingOrder = true;
    notifyListeners();

    try {
      // 1. Enforce Subscription Limits (Authoritative check via EntitlementService)
      if (!_isUnrestricted) {
        if (!EntitlementService.instance
            .canPerformAction('create_order', storeId: activeStore.id)) {
          final reason = EntitlementService.instance
              .getBlockReason('create_order', storeId: activeStore.id);
          throw PlanLimitExceededException(reason);
        }
        await _syncService.checkOrderLimit(activeStore.id);
      }

      // --- DELEGATE TO AUTHORITATIVE CHECKOUT ORCHESTRATOR ---
      final orchestrator = CheckoutOrchestrator(
        billingRepository: BillingRepositoryImpl(repository: _repository),
      );

      final key = (idempotencyKey != null && idempotencyKey.isNotEmpty)
          ? idempotencyKey
          : (order.id.isNotEmpty
              ? 'order_${order.id}'
              : 'order_intent_${order.storeId}_${order.date.millisecondsSinceEpoch}');

      final result = await orchestrator.execute(CheckoutParams(
        order: order.toEntity(),
        activeStoreId: activeStore.id,
        deviceId: _syncService.deviceId ?? 'unknown',
        idempotencyKey: key,
        trackInventory: activeStore.trackInventory,
      ));

      if (result.isSuccess && result.order != null) {
        final placedModel = OrderModel.fromEntity(result.order!);
        final alreadyExists = _orders.any((o) => o.id == placedModel.id);
        if (!alreadyExists) {
          _orders.insert(0, placedModel);
        }
        notifyListeners();
        await _syncService.refreshLocalCounts(notify: true);
      } else {
        throw Exception(
            result.error ?? "Failed to process order checkout locally");
      }
    } finally {
      _isPlacingOrder = false;
      notifyListeners();
    }
  }

  Future<void> updateOrder(OrderModel order) async {
    // 1. Write (Local + Queue)
    await _syncService.performLocalWrite(
        collection: 'orders',
        docId: order.id,
        data: order.toHiveMap(), // Use Hive-safe
        action: 'update',
        localCacheBox: 'cache_orders',
        refreshCounts: false);

    // 2. Update Local Memory
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      _orders[index] = order;
      notifyListeners();
    }
  }

  Future<OrderModel?> getOrder(String id) async {
    final index = _orders.indexWhere((o) => o.id == id);
    if (index != -1) {
      return _orders[index];
    }
    try {
      final repoOrder = await _repository.getOrder(id);
      if (repoOrder != null) {
        _orders.insert(0, repoOrder);
        notifyListeners();
        return repoOrder;
      }
    } catch (e) {
      debugPrint('OrderProvider: Error fetching order $id: $e');
    }
    return null;
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final index = _orders.indexWhere((o) => o.id == orderId);

    // Immutability Check
    if (index != -1) {
      final order = _orders[index];
      if (order.isImmutable && newStatus != 'Refunded') {
        throw Exception(
            "Order is immutable (Status: ${order.status}). Cannot change to $newStatus.");
      }
      if (order.status == 'Refunded') {
        throw Exception("Cannot change status of refunded order.");
      }

      // OPTIMISTIC UI
      _orders[index] = order.copyWith(status: newStatus);
      notifyListeners();
    }

    await _syncService.performLocalWrite(
        collection: 'orders',
        docId: orderId,
        data: {'status': newStatus},
        action: 'update',
        localCacheBox: 'cache_orders',
        refreshCounts: false);

    if (index != -1) {
      final order = _orders[index];
      await _recordEvent(
        storeId: order.storeId,
        entityType: 'ORDER',
        entityId: orderId,
        eventType: newStatus.toUpperCase(),
        amount: order.total,
      );

      final statusUpper = newStatus.toUpperCase();
      if (statusUpper == 'REFUNDED') {
        await AuditService().recordAction(
          storeId: order.storeId,
          action: AuditActionType.refund,
          actorId: _syncService.userId ?? 'user',
          actorRole: _syncService.userRole ?? 'staff',
          entityId: orderId,
          entityType: 'ORDER',
          reason: 'Order Refunded',
          previousState: {'status': order.status},
          newState: {'status': newStatus, 'amount': order.total},
        );
      } else if (statusUpper == 'VOID' || statusUpper == 'CANCELLED') {
        await AuditService().recordAction(
          storeId: order.storeId,
          action: AuditActionType.voidOrder,
          actorId: _syncService.userId ?? 'user',
          actorRole: _syncService.userRole ?? 'staff',
          entityId: orderId,
          entityType: 'ORDER',
          reason: 'Order Voided/Cancelled',
          previousState: {'status': order.status},
          newState: {'status': newStatus, 'amount': order.total},
        );
      }
    }
  }

  /// Authoritative stream for Kitchen Display System (KDS).
  /// Subscribes to active kitchen orders without leaking Firestore to presentation.
  Stream<List<OrderModel>> watchKitchenOrders(String storeId) {
    try {
      return getFirestore()
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('status', whereIn: ['New', 'Preparing'])
          .orderBy('date', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((d) => OrderModel.fromMap(d.data(), d.id))
              .toList());
    } catch (_) {
      return Stream.value(
        _orders
            .where((o) =>
                o.storeId == storeId &&
                (o.status == 'New' || o.status == 'Preparing'))
            .toList(),
      );
    }
  }

  /// Authoritative stream for Customer Display screen.
  /// Streams public order statuses (Preparing, Ready) without UI-level Firestore usage.
  Stream<List<Map<String, dynamic>>> watchCustomerDisplayOrders(
      String storeId) {
    try {
      return getFirestore()
          .collection('orders')
          .where('storeId', isEqualTo: storeId)
          .where('status', whereIn: ['Preparing', 'Ready'])
          .snapshots()
          .map((snapshot) => snapshot.docs.map((d) {
                final data = Map<String, dynamic>.from(d.data());
                data['orderId'] = d.id;
                return data;
              }).toList());
    } catch (_) {
      return Stream.value(
        _orders
            .where((o) =>
                o.storeId == storeId &&
                (o.status == 'Preparing' || o.status == 'Ready'))
            .map((o) => {
                  'orderId': o.id,
                  'status': o.status,
                  'date': o.date,
                  'total': o.total,
                })
            .toList(),
      );
    }
  }

  Future<void> refundOrder(
    String orderId, {
    String? refundedBy,
    String? reason,
    double? refundAmount,
  }) async {
    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      final currentOrder =
          index != -1 ? _orders[index] : (await _repository.getOrder(orderId));

      if (currentOrder == null) {
        throw Exception("Order $orderId not found");
      }
      if (currentOrder.status == 'Refunded') return;
      if (currentOrder.status == 'Cancelled' || currentOrder.status == 'VOID') {
        throw Exception("Cannot refund cancelled or voided order");
      }

      final now = DateTime.now();
      final effectiveRefundedBy = refundedBy ?? 'staff';
      final effectiveReason = reason ?? 'Order Refund';
      final effectiveRefundAmount = refundAmount ?? currentOrder.total;

      final updatedOrder = currentOrder.copyWith(
        status: 'Refunded',
        voidedAt: now,
        voidedBy: effectiveRefundedBy,
        voidReason: 'Refund ($effectiveRefundAmount): $effectiveReason',
        deviceId: _syncService.deviceId,
      );

      // OPTIMISTIC UI UPDATE
      if (index != -1) {
        _orders[index] = updatedOrder;
        notifyListeners();
      }

      await _syncService.performLocalWrite(
          collection: 'orders',
          docId: orderId,
          data: updatedOrder.toMap(),
          action: 'update',
          localCacheBox: 'cache_orders',
          refreshCounts: true);

      if (!kIsWeb) {
        await _repository.refundOrder(
          orderId,
          refundedBy: effectiveRefundedBy,
          reason: effectiveReason,
          refundAmount: effectiveRefundAmount,
          deviceId: _syncService.deviceId,
        );
      }

      await _recordEvent(
        storeId: currentOrder.storeId,
        entityType: 'ORDER',
        entityId: orderId,
        eventType: 'REFUND',
        amount: effectiveRefundAmount,
      );

      // --- INVENTORY REVERSAL ---
      for (var item in currentOrder.items) {
        if (!item.item.trackStock) continue;

        final movementId = _syncService.generateUniqueId('MVT');
        final movement = InventoryMovement(
          id: movementId,
          itemId: item.item.id,
          storeId: currentOrder.storeId,
          type: MovementType.refund,
          delta: item.quantity, // Positive delta
          orderId: orderId,
          unitCost: item.costSnapshot ?? item.item.cost,
          reason: effectiveReason,
          deviceId: _syncService.deviceId ?? 'unknown',
          operationId: 'refund_${orderId}_${item.item.id}',
          createdAt: now,
          syncStatus: 'PENDING',
        );

        if (!kIsWeb) {
          await _movementRepo.insertMovement(movement);
        } else {
          try {
            final box = await Hive.openBox('cache_inventory');
            final raw = box.get(item.item.id);
            if (raw != null && raw is Map) {
              final itemData = Map<String, dynamic>.from(raw);
              final currentQty = (itemData['quantity'] as num?)?.toInt() ?? 0;
              itemData['quantity'] = currentQty + item.quantity;
              await box.put(item.item.id, itemData);
            }
          } catch (e) {
            debugPrint('⚠️ REFUND INVENTORY: Hive update failed: $e');
          }
        }

        // Queue for sync
        await _syncService.queueOperation(
          collection: 'inventory_movements',
          docId: movementId,
          action: 'create',
          payload: {
            ...movement.toMap(),
            'createdAt': movement.createdAt.toIso8601String(),
          },
        );
      }

      // Publish OrderRefundedEvent to the Event Bus
      EventBus.instance.fire(OrderRefundedEvent(
        orderId: orderId,
        storeId: currentOrder.storeId,
        refundAmount: effectiveRefundAmount,
        items: currentOrder.items,
      ));

      // We already optimistically updated the UI, so no need to do it again here.
    } catch (e) {
      rethrow;
    }
  }

  Future<void> voidOrder(String orderId,
      {String? voidedBy, String? reason}) async {
    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      final currentOrder =
          index != -1 ? _orders[index] : (await _repository.getOrder(orderId))!;

      if (currentOrder.status == 'VOID') return;
      if (currentOrder.status == 'Refunded') {
        throw Exception("Cannot void refunded order");
      }

      final now = DateTime.now();
      final updatedOrder = currentOrder.copyWith(
        status: 'VOID',
        voidedAt: now,
        voidedBy: voidedBy,
        voidReason: reason,
        deviceId: _syncService.deviceId,
      );

      if (index != -1) {
        _orders[index] = updatedOrder;
        notifyListeners();
      }

      await _syncService.performLocalWrite(
          collection: 'orders',
          docId: orderId,
          data: updatedOrder.toMap(),
          action: 'update',
          localCacheBox: 'cache_orders',
          refreshCounts: true);

      // Reversal in movement repo
      if (!kIsWeb) {
        await _movementRepo.voidOrderStock(
          orderId: orderId,
          storeId: currentOrder.storeId,
          deviceId: _syncService.deviceId ?? 'unknown',
          reason: reason,
          voidedBy: voidedBy,
        );
      }

      EventBus.instance.fire(OrderVoidedEvent(
        orderId: orderId,
        storeId: currentOrder.storeId,
        reason: reason,
        voidedBy: voidedBy,
      ));
    } catch (e) {
      rethrow;
    }
  }

  // --- STATS ---
  // Authoritative reporting queries via Repository (SQLite aggregation)

  Future<Map<String, dynamic>> fetchStats(String? storeId,
      {DateTime? start,
      DateTime? end,
      String? status,
      String? paymentMethod}) async {
    if (storeId == null)
      return {'totalSales': 0.0, 'orderCount': 0, 'avgOrderValue': 0.0};

    if (kIsWeb) {
      // WEB: Aggregate from Hive
      try {
        final box = await Hive.openBox('cache_orders');
        double totalSales = 0;
        double cardSales = 0;
        double cashSales = 0;
        double totalCogs = 0;
        int count = 0;

        final Map<String, Map<String, double>> categoryAggregations = {};
        final Map<String, Map<String, double>> dayAggregations = {};

        final targetStoreId = storeId.trim();
        for (var val in box.values) {
          if (val is! Map) continue;
          final vStoreId = (val['storeId'] ?? '').toString().trim();
          if (vStoreId != targetStoreId) continue;
          if (val['deletedAt'] != null) continue;

          final orderStatus = val['status'] ?? 'New';
          final orderDateStr = val['date'] ?? val['createdAt'];
          final orderDate =
              DateTime.tryParse(orderDateStr.toString()) ?? DateTime.now();
          final paymentMethodVal = val['paymentMethod'] ?? 'Cash';

          // Apply Status Filter
          if (status != null) {
            if (orderStatus != status) continue;
          } else {
            if (['Cancelled', 'VOID'].contains(orderStatus)) continue;
          }

          // Apply Payment Method Filter
          if (paymentMethod != null && paymentMethodVal != paymentMethod) {
            continue;
          }

          // Apply Date Filter
          if (start != null && orderDate.isBefore(start)) continue;
          if (end != null &&
              orderDate.isAfter(end.add(const Duration(days: 1)))) continue;

          // HANDLE REFUNDS (Negative Impact)
          final isRefunded = orderStatus == 'Refunded';
          final orderTotal = (val['total'] ?? 0).toDouble();
          final effectiveTotal = isRefunded ? 0.0 : orderTotal;

          totalSales += effectiveTotal;

          if (['Card', 'UPI'].contains(paymentMethodVal)) {
            cardSales += effectiveTotal;
          } else if (paymentMethodVal == 'Cash') {
            cashSales += effectiveTotal;
          }

          final String dayKey = DateFormat('yyyy-MM-dd').format(orderDate);
          dayAggregations.putIfAbsent(
              dayKey, () => {'sales': 0.0, 'cogs': 0.0});

          // CALCULATE COGS (Iterate Items)
          final items = val['items'] as List<dynamic>? ?? [];
          for (var itemRecord in items) {
            if (itemRecord is Map) {
              final qty = (itemRecord['quantity'] ?? 0).toDouble();
              final cost =
                  (itemRecord['costSnapshot'] ?? itemRecord['cost'] ?? 0)
                      .toDouble();
              final price =
                  (itemRecord['priceSnapshot'] ?? itemRecord['price'] ?? 0)
                      .toDouble();

              final itemCogs = cost * qty;
              final itemSales = price * qty;

              totalCogs += isRefunded ? 0.0 : itemCogs;

              final category =
                  (itemRecord['category'] ?? 'Uncategorized').toString();
              categoryAggregations.putIfAbsent(
                  category, () => {'sales': 0.0, 'cogs': 0.0});

              if (!isRefunded) {
                categoryAggregations[category]!['sales'] =
                    categoryAggregations[category]!['sales']! + itemSales;
                categoryAggregations[category]!['cogs'] =
                    categoryAggregations[category]!['cogs']! + itemCogs;

                dayAggregations[dayKey]!['sales'] =
                    dayAggregations[dayKey]!['sales']! + itemSales;
                dayAggregations[dayKey]!['cogs'] =
                    dayAggregations[dayKey]!['cogs']! + itemCogs;
              }
            }
          }

          if (items.isEmpty && !isRefunded) {
            categoryAggregations.putIfAbsent(
                'Uncategorized', () => {'sales': 0.0, 'cogs': 0.0});
            categoryAggregations['Uncategorized']!['sales'] =
                categoryAggregations['Uncategorized']!['sales']! +
                    effectiveTotal;
            categoryAggregations['Uncategorized']!['cogs'] =
                categoryAggregations['Uncategorized']!['cogs']! +
                    (effectiveTotal * 0.7);

            dayAggregations[dayKey]!['sales'] =
                dayAggregations[dayKey]!['sales']! + effectiveTotal;
            dayAggregations[dayKey]!['cogs'] =
                dayAggregations[dayKey]!['cogs']! + (effectiveTotal * 0.7);
          }

          if (!isRefunded) {
            count++;
          }
        }

        final List<Map<String, dynamic>> categoryStats = [];
        categoryAggregations.forEach((cat, data) {
          final sales = data['sales']!;
          final cogs = data['cogs']!;
          categoryStats.add({
            'category': cat,
            'sales': sales,
            'cogs': cogs,
            'profit': sales - cogs,
          });
        });

        final List<Map<String, dynamic>> dayStats = [];
        dayAggregations.forEach((day, data) {
          final sales = data['sales']!;
          final cogs = data['cogs']!;
          dayStats.add({
            'day': day,
            'sales': sales,
            'cogs': cogs,
            'profit': sales - cogs,
          });
        });

        return {
          'totalSales': totalSales,
          'orderCount': count,
          'avgOrderValue': count > 0 ? totalSales / count : 0.0,
          'cardSales': cardSales,
          'cashSales': cashSales,
          'totalCogs': totalCogs,
          'grossProfit': totalSales - totalCogs,
          'categoryStats': categoryStats,
          'dayStats': dayStats,
        };
      } catch (e) {
        return {
          'totalSales': 0.0,
          'orderCount': 0,
          'avgOrderValue': 0.0,
          'cardSales': 0.0,
          'cashSales': 0.0,
          'totalCogs': 0.0,
          'grossProfit': 0.0,
        };
      }
    } else {
      // MOBILE/DESKTOP: Use Repository (SQL)
      return await _repository.getSalesStats(storeId,
          start: start, end: end, status: status, paymentMethod: paymentMethod);
    }
  }

  Future<void> _recordEvent({
    required String storeId,
    required String entityType,
    required String entityId,
    required String eventType,
    double amount = 0.0,
    int quantity = 0,
  }) async {
    final event = BusinessEvent(
      id: _syncService.generateUniqueId('EVT'),
      storeId: storeId,
      entityType: entityType,
      entityId: entityId,
      eventType: eventType,
      amount: amount,
      quantity: quantity,
      createdAt: DateTime.now(),
      deviceId: _syncService.deviceId ?? 'unknown',
    );

    await _repository.insertBusinessEvent(event);
    await _syncService.queueOperation(
      collection: 'business_events',
      docId: event.id,
      action: 'create',
      payload: event.toMap(),
    );
  }

  @override
  void dispose() {
    _orderCreatedSub?.cancel();
    _syncCompletedSub?.cancel();
    super.dispose();
  }
}
