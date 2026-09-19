import '../../../../core/base/use_case.dart';
import '../../../../providers/order_provider.dart';

class UpdateOrderStatusParams {
  final String orderId;
  final String newStatus;

  const UpdateOrderStatusParams({
    required this.orderId,
    required this.newStatus,
  });
}

/// Domain use case for updating order status from presentation layers (e.g. KDS).
/// Routes mutations through [OrderProvider], optimistic UI, local durable outbox,
/// audit events, and background sync.
class UpdateOrderStatusUseCase
    implements UseCase<UpdateOrderStatusParams, void> {
  final OrderProvider _orderProvider;

  UpdateOrderStatusUseCase(this._orderProvider);

  @override
  Future<void> execute(UpdateOrderStatusParams params) async {
    await _orderProvider.updateOrderStatus(params.orderId, params.newStatus);
  }
}
