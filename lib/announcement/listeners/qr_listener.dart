import '../../core/events/event_bus.dart';
import '../../core/events/app_events.dart';
import '../models/announcement_type.dart';
import '../service/announcement_service.dart';

class QRListener {
  final EventBusScope _scope = EventBusScope();

  void init() {
    _scope.track(EventBus.instance.on<TableOccupiedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.tableOccupied,
          metadata: {'tableName': event.tableName},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<TableClearedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.tableFree,
          metadata: {'tableName': event.tableName},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<NewQrOrderEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.newQrOrder,
          metadata: {'tableName': event.tableName, 'orderId': event.orderId},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<KitchenReadyEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.kitchenReady,
          metadata: {'tableName': event.tableName, 'orderId': event.orderId},
        );
      } catch (_) {}
    }));
  }

  void dispose() {
    _scope.disposeAll();
  }
}
