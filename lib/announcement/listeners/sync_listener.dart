import '../../core/events/event_bus.dart';
import '../../core/events/app_events.dart';
import '../models/announcement_type.dart';
import '../service/announcement_service.dart';

class SyncListener {
  final EventBusScope _scope = EventBusScope();

  void init() {
    _scope.track(EventBus.instance.on<SyncStartedEvent>((event) {
      try {
        AnnouncementService().announce(AnnouncementType.syncStarted);
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<SyncCompletedEvent>((event) {
      try {
        AnnouncementService().announce(AnnouncementType.syncCompleted);
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<SyncFailedEvent>((event) {
      try {
        AnnouncementService().announce(
          AnnouncementType.pendingUploads,
          metadata: {'error': event.error},
        );
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<ConnectivityChangedEvent>((event) {
      try {
        if (event.isOnline) {
          AnnouncementService().announce(AnnouncementType.online);
        } else {
          AnnouncementService().announce(AnnouncementType.offline);
        }
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<StoreChangedEvent>((event) {
      try {
        AnnouncementService().announce(AnnouncementType.storeChanged);
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<EmployeeLoggedInEvent>((event) {
      try {
        AnnouncementService().announce(AnnouncementType.loginSuccess);
      } catch (_) {}
    }));

    _scope.track(EventBus.instance.on<EmployeeLoggedOutEvent>((event) {
      try {
        AnnouncementService().announce(AnnouncementType.logout);
      } catch (_) {}
    }));
  }

  void dispose() {
    _scope.disposeAll();
  }
}
