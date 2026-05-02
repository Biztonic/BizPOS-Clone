import 'package:biztonic_pos/core/base/use_case.dart';
import 'package:biztonic_pos/models/order_model.dart';
import 'package:biztonic_pos/services/repository.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:flutter/foundation.dart';

class CreateOrderParams {
  final OrderModel order;
  final String storeId;

  CreateOrderParams({required this.order, required this.storeId});
}

class CreateOrderUseCase extends UseCase<CreateOrderParams, bool> {
  final Repository repository;

  CreateOrderUseCase(this.repository);

  @override
  Future<bool> execute(CreateOrderParams params) async {
    try {
      // 1. Insert Order
      await repository.insertOrder(params.order);

      // 2. Fire decoupled event (SyncEngine listens to this)
      EventBus.instance.fire(OrderCreatedEvent(
         order: params.order,
         storeId: params.storeId,
         deductStock: false,
      ));
      
      return true;
    } catch (e) {
      debugPrint('Error in CreateOrderUseCase: $e');
      return false;
    }
  }
}
