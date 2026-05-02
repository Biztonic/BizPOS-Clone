import 'package:biztonic_pos/core/base/use_case.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/models/store.dart';
import 'package:biztonic_pos/models/business_ledger.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/services/token_service.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class CheckoutOrderParams {
  final OrderModel order;
  final Store activeStore;
  final String deviceId;

  CheckoutOrderParams({
    required this.order,
    required this.activeStore,
    required this.deviceId,
  });
}

class CheckoutOrderResult {
  final OrderModel orderWithMeta;
  final BusinessEvent event;
  final List<InventoryMovement> movements;

  CheckoutOrderResult(this.orderWithMeta, this.event, this.movements);
}

class CheckoutOrderUseCase extends UseCase<CheckoutOrderParams, CheckoutOrderResult?> {
  final Repository repository;
  final TokenService tokenService = TokenService();

  CheckoutOrderUseCase(this.repository);

  String _generateId(String prefix) => '$prefix-${const Uuid().v4()}';

  @override
  Future<CheckoutOrderResult?> execute(CheckoutOrderParams params) async {
    final order = params.order;
    final activeStore = params.activeStore;
    final deviceId = params.deviceId;
    
    final now = DateTime.now();
    String businessDayId = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${activeStore.id}";
    String yearMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    String orderId = order.id.isNotEmpty ? order.id : _generateId('ORD');
    
    final orderWithMeta = order.copyWith(id: orderId);
    final hiveSafeData = orderWithMeta.toHiveMap();
    hiveSafeData['businessDayId'] = businessDayId; 

    final eventId = _generateId('EVT');
    final event = BusinessEvent(
      id: eventId,
      storeId: activeStore.id,
      entityType: 'ORDER',
      entityId: orderId,
      eventType: 'CREATE',
      amount: order.total,
      quantity: 0,
      createdAt: now,
      deviceId: deviceId,
    );

    List<InventoryMovement> movements = [];
    if (activeStore.trackInventory == true) {
       for (var item in order.items) {
          if (!item.item.trackStock) continue;
          
          final movementId = _generateId('MVT');
          movements.add(InventoryMovement(
            id: movementId,
            itemId: item.item.id,
            storeId: activeStore.id,
            type: 'SALE',
            delta: -item.quantity,
            orderId: orderId,
            deviceId: deviceId,
            createdAt: now,
            syncStatus: 'PENDING',
          ));
       }
    }

    try {
      // 1. UPDATE HIVE CACHE FIRST
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

      // 2. ATOMIC LOCAL DATABASE (SQLite)
      if (!kIsWeb) {
        await repository.performAtomicCheckout(
          order: orderWithMeta,
          event: event,
          movements: movements,
          storeId: activeStore.id,
          yearMonth: yearMonth,
        );
      } else {
        await tokenService.incrementOrderCounter(activeStore.id);
      }

      // 3. Fire Decoupled Event (SyncEngine listens to this to queue cloud ops)
      EventBus.instance.fire(OrderCreatedEvent(
         order: orderWithMeta,
         storeId: activeStore.id,
         event: event,
         movements: movements,
      ));
      
      return CheckoutOrderResult(orderWithMeta, event, movements);
    } catch (e) {
      debugPrint('Error in CheckoutOrderUseCase: $e');
      return null;
    }
  }
}

