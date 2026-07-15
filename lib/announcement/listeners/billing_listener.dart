import '../../core/events/event_bus.dart';
import '../../core/events/app_events.dart';
import '../models/announcement_type.dart';
import '../service/announcement_service.dart';

class BillingListener {
  final EventBusScope _scope = EventBusScope();

  void init() {
    _scope.track(EventBus.instance.on<OrderCreatedEvent>((event) {
      try {
        final order = event.order;
        final total = (order != null) ? (order.total ?? 0.0) : 0.0;
        AnnouncementService().announce(
          AnnouncementType.paymentSuccess,
          metadata: {'amount': total},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<OrderRefundedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.refund,
          metadata: {'amount': event.refundAmount},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<OrderVoidedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.paymentFailed,
          metadata: {'reason': event.reason ?? ''},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<CartItemAddedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.itemAdded,
          metadata: {'itemName': event.itemName ?? ''},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<CartItemRemovedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.itemRemoved,
          metadata: {'itemName': event.itemName ?? ''},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<CartDiscountAppliedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.discountApplied,
          metadata: {'discount': event.discountAmount},
        );
      } catch (_) {}
    }));
  }

  void dispose() {
    _scope.disposeAll();
  }
}
