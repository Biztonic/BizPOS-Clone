import 'package:biztonic_pos/core/base/use_case.dart';
import 'package:biztonic_pos/core/events/event_bus.dart';
import 'package:biztonic_pos/core/events/app_events.dart';
import 'package:biztonic_pos/models/store.dart';
import 'package:biztonic_pos/services/offline_service.dart';
import 'package:flutter/foundation.dart';

class SwitchStoreParams {
  final Store store;
  final OfflineService offlineService;

  SwitchStoreParams({required this.store, required this.offlineService});
}

class SwitchStoreUseCase extends UseCase<SwitchStoreParams, bool> {
  SwitchStoreUseCase();

  @override
  Future<bool> execute(SwitchStoreParams params) async {
    try {
      // Setup offline database scope
      await params.offlineService.init();

      // Fire StoreChangedEvent, listeners (Providers, SyncEngine) handle the rest
      EventBus.instance.fire(StoreChangedEvent(newStoreId: params.store.id));
      
      return true;
    } catch (e) {
      debugPrint('Error in SwitchStoreUseCase: $e');
      return false;
    }
  }
}
