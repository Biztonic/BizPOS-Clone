import '../../core/events/event_bus.dart';
import '../../core/events/app_events.dart';
import '../models/announcement_type.dart';
import '../service/announcement_service.dart';
import '../../services/repository.dart';

class InventoryListener {
  final EventBusScope _scope = EventBusScope();
  final Repository _repository = Repository();

  void init() {
    _scope.track(EventBus.instance.on<InventoryChangedEvent>((event) async {
      try {
        final item = await _repository.inventory.getInventoryItem(event.itemId, storeId: event.storeId);
        if (item == null) return;

        if (event.changeType == 'DELETE') {
          AnnouncementService().announce(
            AnnouncementType.outOfStock,
            metadata: {'itemName': item.name},
          );
          return;
        }

        if (item.trackStock) {
          final threshold = item.lowStockThreshold ?? 10;
          if (item.quantity <= 0) {
            AnnouncementService().announce(
              AnnouncementType.outOfStock,
              metadata: {'itemName': item.name},
            );
          } else if (item.quantity <= threshold) {
            AnnouncementService().announce(
              AnnouncementType.stockLow,
              metadata: {'itemName': item.name},
            );
          }
        }
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<InventoryAdjustedEvent>((event) async {
      try {
        final item = await _repository.inventory.getInventoryItem(event.itemId, storeId: event.storeId);
        if (item == null) return;

        if (item.trackStock) {
          final threshold = item.lowStockThreshold ?? 10;
          if (item.quantity <= 0) {
            AnnouncementService().announce(
              AnnouncementType.outOfStock,
              metadata: {'itemName': item.name},
            );
          } else if (item.quantity <= threshold) {
            AnnouncementService().announce(
              AnnouncementType.stockLow,
              metadata: {'itemName': item.name},
            );
          } else if (event.delta > 0 && (item.quantity - event.delta) <= threshold) {
            // If delta was positive, and we moved from low stock/out of stock to healthy stock
            AnnouncementService().announce(
              AnnouncementType.itemRestored,
              metadata: {'itemName': item.name},
            );
          }
        }
      } catch (_) {}
    }));
  }

  void dispose() {
    _scope.disposeAll();
  }
}
