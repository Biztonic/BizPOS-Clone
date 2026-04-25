import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:biztonic_pos/services/firestore_helper.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/store.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/services/token_service.dart'; // NEW
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/models/business_ledger.dart';

class OrderProvider with ChangeNotifier {
  final FirebaseFirestore _db = getFirestore(); // ignore: unused_field
  final Repository _repository = Repository();
  final InventoryMovementRepository _movementRepo = InventoryMovementRepository();
  final SyncService _syncService;

  // State
  final List<OrderModel> _orders = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isUnrestricted = false; // NEW
  DateTime? _lastOrderDate;
  final int _ordersPerPage = 20;

  // Getters
  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isUnrestricted => _isUnrestricted; // NEW
  SyncService get syncService => _syncService;

  set isUnrestricted(bool value) {
    _isUnrestricted = value;
    notifyListeners();
  }

  OrderProvider(this._syncService);

  Future<void> clearOrders() async {
      _orders.clear();
      _hasMore = true;
      _lastOrderDate = null;
      notifyListeners();
  }

  // --- FETCHING ---

  Future<void> fetchOrders(String? storeId, {bool refresh = false}) async {
    if (_isLoading) return;
    
    if (refresh) {
      _hasMore = true;
      _lastOrderDate = null;
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
                if (value is Map) return MapEntry(key.toString(), recursiveCast(value));
                if (value is List) return MapEntry(key.toString(), value.map((e) => e is Map ? recursiveCast(e) : e).toList());
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
            cachedData.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
            _orders.clear();
            _orders.addAll(cachedData.map((d) => OrderModel.fromMap(d, d['id'] ?? '')));

            _hasMore = false; // SyncService handles full pull
            notifyListeners();
         } catch (e) { /* Error ignored */ }
      } else {
          // MOBILE/DESKTOP: Use Repository
          final DateTime? fetchAfterDate = refresh ? null : _lastOrderDate;
          final newOrders = await _repository.getPaginatedOrders(
            storeId, 
            limit: _ordersPerPage, 
            lastDate: fetchAfterDate
          );
          
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
                        if (value is Map) return MapEntry(key.toString(), recursiveCast(value));
                        if (value is List) return MapEntry(key.toString(), value.map((e) => e is Map ? recursiveCast(e) : e).toList());
                        return MapEntry(key.toString(), value);
                      });
                    }
                    final cachedData = box.values.where((v) {
                      if (v is! Map) return false;
                      return (v['storeId'] ?? '').toString().trim() == targetStoreId && v['deletedAt'] == null;
                    }).map((e) => recursiveCast(e as Map)).toList();
                    
                    if (cachedData.isNotEmpty) {
                      cachedData.sort((a, b) => (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
                      _orders.addAll(cachedData.map((d) => OrderModel.fromMap(d, d['id'] ?? '')));
                    }
                  }
                } catch (e) { /* Error ignored */ }
             }
             _hasMore = false;
          } else {
             _orders.addAll(newOrders);
             _lastOrderDate = newOrders.last.date;
             
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
  
  // --- ACTIONS ---

  Future<void> placeOrder(OrderModel order, Store? activeStore) async {
    if (activeStore == null) throw Exception("No active store selected");

    final tokenService = TokenService();
    
    // 1. Enforce Subscription Limits (Fast check via memory cache)
    if (!_isUnrestricted) {
      await _syncService.checkOrderLimit(activeStore.id);
    }

    // 2. Generate Entities and Metadata (Synchronous)
    final now = DateTime.now();
    String businessDayId = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${activeStore.id}";
    String yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    String orderId = order.id.isNotEmpty ? order.id : _syncService.generateUniqueId('ORD');
    
    final orderWithMeta = order.copyWith(id: orderId);
    final hiveSafeData = orderWithMeta.toHiveMap();
    hiveSafeData['businessDayId'] = businessDayId; 

    final eventId = _syncService.generateUniqueId('EVT');
    final event = BusinessEvent(
      id: eventId,
      storeId: activeStore.id,
      entityType: 'ORDER',
      entityId: orderId,
      eventType: 'CREATE',
      amount: order.total,
      quantity: 0,
      createdAt: now,
      deviceId: _syncService.deviceId ?? 'unknown',
    );

    List<InventoryMovement> movements = [];
    if (activeStore.trackInventory == true) {
       for (var item in order.items) {
          if (!item.item.trackStock) continue;
          
          final movementId = _syncService.generateUniqueId('MVT');
          movements.add(InventoryMovement(
            id: movementId,
            itemId: item.item.id,
            storeId: activeStore.id,
            type: 'SALE',
            delta: -item.quantity,
            orderId: orderId,
            deviceId: _syncService.deviceId ?? 'unknown',
            createdAt: now,
            syncStatus: 'PENDING',
          ));
       }
    }

    // --- OPTIMISTIC UI: UPDATE LOCAL STATE IMMEDIATELY ---
    _orders.insert(0, orderWithMeta);
    notifyListeners();

    // --- BACKGROUND PERSISTENCE: OFFLOAD HEAVY I/O ---
    unawaited(() async {
      try {
        // 1. UPDATE HIVE CACHE FIRST (Fast safety net — guarantees data survives restart)
        final orderBox = Hive.box('cache_orders');
        await orderBox.put(orderId, {...hiveSafeData, 'syncStatus': 'PENDING'});
        
        if (movements.isNotEmpty) {
           final invBox = Hive.box('cache_inventory');
           for (var m in movements) {
              final raw = invBox.get(m.itemId);
              if (raw != null && raw is Map) {
                final itemData = Map<String, dynamic>.from(raw);
                final currentQty = (itemData['quantity'] as num?)?.toInt() ?? 0;
                itemData['quantity'] = currentQty + m.delta;
                await invBox.put(m.itemId, itemData);
              }
           }
        }

        // 2. ATOMIC LOCAL DATABASE (SQLite) — heavier but provides relational integrity
        if (!kIsWeb) {
          await _repository.performAtomicCheckout(
            order: orderWithMeta,
            event: event,
            movements: movements,
            storeId: activeStore.id,
            yearMonth: yearMonth,
          );
        } else {
          await tokenService.incrementOrderCounter(activeStore.id);
        }

        // 3. QUEUE FOR CLOUD SYNC
        await _syncService.queueOperation(
          collection: 'orders',
          docId: orderId,
          action: 'create',
          payload: Map<String, dynamic>.from(hiveSafeData),
        );

        await _syncService.queueOperation(
          collection: 'business_events',
          docId: event.id,
          action: 'create',
          payload: event.toMap(),
        );

        for (var movement in movements) {
          await _syncService.queueOperation(
            collection: 'inventory_movements',
            docId: movement.id,
            action: 'create',
            payload: {
              ...movement.toMap(),
              'createdAt': movement.createdAt.toIso8601String(),
            },
          );
        }

        // 4. Final UI Refresh
        await _syncService.refreshLocalCounts(notify: true);
      } catch (e) {
        debugPrint('❌ CRITICAL: Background Persistence Failed: $e');
      }
    }());
  }

  Future<void> updateOrder(OrderModel order) async {
    // 1. Write (Local + Queue)
    await _syncService.performLocalWrite(
      collection: 'orders',
      docId: order.id,
      data: order.toHiveMap(), // Use Hive-safe
      action: 'update',
      localCacheBox: 'cache_orders',
      refreshCounts: false 
    );
    
    // 2. Update Local Memory
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
       _orders[index] = order;
       notifyListeners();
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    
    // Immutability Check
    if (index != -1) {
       final order = _orders[index];
       if (order.isImmutable && newStatus != 'Refunded') {
          throw Exception("Order is immutable (Status: ${order.status}). Cannot change to $newStatus.");
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
      refreshCounts: false
    );

    if (index != -1) {
      final order = _orders[index];
      await _recordEvent(
        storeId: order.storeId,
        entityType: 'ORDER',
        entityId: orderId,
        eventType: newStatus.toUpperCase(),
        amount: order.total,
      );
    }
  }

  Future<void> refundOrder(String orderId) async {
    try {
      final index = _orders.indexWhere((o) => o.id == orderId);
      if (index == -1) {
         // Try checking repo? For now fail friendly.
         final repoOrder = await _repository.getOrder(orderId);
         if (repoOrder == null) throw Exception("Order not found");
      }
      
      final currentOrder = index != -1 ? _orders[index] : (await _repository.getOrder(orderId))!;
      
      if (currentOrder.status == 'Refunded') return;
      if (currentOrder.status == 'Cancelled') throw Exception("Cannot refund cancelled order");
      
      final updatedOrder = currentOrder.copyWith(status: 'Refunded');
      
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
        refreshCounts: true
      );

      await _recordEvent(
        storeId: currentOrder.storeId,
        entityType: 'ORDER',
        entityId: orderId,
        eventType: 'REFUND',
        amount: currentOrder.total,
      );

      // --- INVENTORY REVERSAL ---
      // We assume the caller (DashboardProvider) provides store info if needed, 
      // but here we can check if it's already "Refunded" handled above.
      // We loop through items and create positive delta movements.
      for (var item in currentOrder.items) {
         if (!item.item.trackStock) continue;
         
         final movementId = _syncService.generateUniqueId('MVT');
         final movement = InventoryMovement(
           id: movementId,
           itemId: item.item.id,
           storeId: currentOrder.storeId,
           type: 'REFUND',
           delta: item.quantity, // Positive delta
           orderId: orderId,
           deviceId: _syncService.deviceId ?? 'unknown',
           createdAt: DateTime.now(),
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

      // We already optimistically updated the UI, so no need to do it again here.
    } catch (e) {

      rethrow;
    }
  }

  // --- STATS ---
  // Simple in-memory stats helper, or delegate to Repo for complex queries
  Map<String, dynamic> getSalesStats() {
    double totalSales = 0;
    int count = 0;
    for (var o in _orders) {
       if (o.status != 'Cancelled' && o.status != 'VOID') {
          if (o.status == 'Refunded') {
             totalSales += 0;
          } else {
             totalSales += o.total;
             count++; // Only count non-refunded/active orders
          }
       }
    }
    return {
      'totalSales': totalSales,
      'orderCount': count,
      'avgOrderValue': count > 0 ? totalSales / count : 0.0
    };
  }

  Future<Map<String, dynamic>> fetchStats(String? storeId, {DateTime? start, DateTime? end, String? status, String? paymentMethod}) async {
    if (storeId == null) return {'totalSales': 0.0, 'orderCount': 0, 'avgOrderValue': 0.0};

    if (kIsWeb) {
      // WEB: Aggregate from Hive
      try {
        final box = await Hive.openBox('cache_orders');
        double totalSales = 0;
        double cardSales = 0;
        double cashSales = 0;
        double totalCogs = 0;
        int count = 0;
        
        final targetStoreId = storeId.trim();
        for (var val in box.values) {
          if (val is! Map) continue;
          final vStoreId = (val['storeId'] ?? '').toString().trim();
          if (vStoreId != targetStoreId) continue;
          if (val['deletedAt'] != null) continue;

          final orderStatus = val['status'] ?? 'New';
          final orderDateStr = val['date'] ?? val['createdAt'];
          final orderDate = DateTime.tryParse(orderDateStr.toString()) ?? DateTime.now();
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
          if (end != null && orderDate.isAfter(end.add(const Duration(days: 1)))) continue;

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

          // CALCULATE COGS (Iterate Items)
          final items = val['items'] as List<dynamic>? ?? [];
          for (var itemRecord in items) {
             if (itemRecord is Map) {
                final qty = (itemRecord['quantity'] ?? 0).toDouble();
                final cost = (itemRecord['costSnapshot'] ?? itemRecord['cost'] ?? 0).toDouble();
                final itemCogs = cost * qty;
                totalCogs += isRefunded ? 0.0 : itemCogs;
             }
          }

          if (!isRefunded) {
            count++;
          }
        }
        return {
          'totalSales': totalSales,
          'orderCount': count,
          'avgOrderValue': count > 0 ? totalSales / count : 0.0,
          'cardSales': cardSales,
          'cashSales': cashSales,
          'totalCogs': totalCogs,
          'grossProfit': totalSales - totalCogs,
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
      return await _repository.getSalesStats(storeId, start: start, end: end, status: status, paymentMethod: paymentMethod);
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
}
