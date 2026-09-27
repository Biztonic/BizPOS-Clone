import 'package:biztonic_pos/core/base/use_case.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:flutter/foundation.dart';

class AdjustStockParams {
  final InventoryMovement movement;

  AdjustStockParams({required this.movement});
}

class AdjustStockUseCase extends UseCase<AdjustStockParams, bool> {
  final InventoryMovementRepository repository;

  AdjustStockUseCase(this.repository);

  @override
  Future<bool> execute(AdjustStockParams params) async {
    try {
      // 1. Update Database
      await repository.insertMovement(params.movement);

      // 2. Queue movement for cloud sync
      await SyncService().queueOperation(
        collection: 'inventory_movements',
        docId: params.movement.id,
        action: 'create',
        payload: {
          ...params.movement.toMap(),
          'createdAt': params.movement.createdAt.toIso8601String(),
        },
      );

      // 3. Fire events so both UI and SyncBridge queue the updated inventory item
      EventBus.instance.fire(InventoryAdjustedEvent(
        itemId: params.movement.itemId,
        delta: params.movement.delta,
        storeId: params.movement.storeId,
        reason: params.movement.type,
      ));
      EventBus.instance.fire(InventoryChangedEvent(
        itemId: params.movement.itemId,
        storeId: params.movement.storeId,
        changeType: 'UPSERT',
      ));

      return true;
    } catch (e) {
      debugPrint('Error in AdjustStockUseCase: $e');
      return false;
    }
  }
}
