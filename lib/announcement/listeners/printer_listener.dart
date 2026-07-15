import '../../core/events/event_bus.dart';
import '../../core/events/app_events.dart';
import '../models/announcement_type.dart';
import '../service/announcement_service.dart';

class PrinterListener {
  final EventBusScope _scope = EventBusScope();

  void init() {
    _scope.track(EventBus.instance.on<PrintRequestedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.printStarted,
          metadata: {'documentType': event.documentType},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<PrintCompletedEvent>((event) {
      try {
        if (event.success) {
          AnnouncementService().announce(AnnouncementType.printCompleted);
        } else {
          // If printing failed, we can announce printer disconnected/warning
          AnnouncementService().announce(
            AnnouncementType.printerDisconnected,
            metadata: {'error': event.error ?? ''},
          );
        }
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<PrinterConnectedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.printerConnected,
          metadata: {'deviceName': event.deviceName, 'purpose': event.purpose},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<PrinterDisconnectedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.printerDisconnected,
          metadata: {'deviceName': event.deviceName, 'purpose': event.purpose},
        );
      } catch (_) {}
    }));
  }

  void dispose() {
    _scope.disposeAll();
  }
}
