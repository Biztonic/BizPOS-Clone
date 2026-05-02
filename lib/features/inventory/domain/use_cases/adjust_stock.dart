import 'package:biztonic_pos/core/base/use_case.dart';
import 'package:biztonic_pos/models/inventory_movement.dart';
import 'package:biztonic_pos/services/inventory_movement_repository.dart';
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

      // 2. Fire event
      EventBus.instance.fire(InventoryUpdatedEvent(
         itemId: params.movement.itemId,
         delta: params.movement.delta,
         storeId: params.movement.storeId,
         reason: params.movement.type,
      ));
      
      return true;
    } catch (e) {
      debugPrint('Error in AdjustStockUseCase: $e');
      return false;
    }
  }
}
