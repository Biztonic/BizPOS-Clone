import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/printer_manager_service.dart';
import '../services/offline_service.dart';
import '../services/sync_service.dart';
import '../core/di/service_locator.dart';
import '../announcement/announcement.dart';
import '../announcement/listeners/billing_listener.dart';
import '../announcement/listeners/inventory_listener.dart';
import '../announcement/listeners/printer_listener.dart';
import '../announcement/listeners/sync_listener.dart';
import '../announcement/listeners/qr_listener.dart';

import '../core/diagnostics/diagnostics_service.dart';
import '../core/audit/audit_service.dart';

class ServiceBootstrap {
  static Future<void> init() async {
    debugPrint('⏳ Starting Service Parallel Init...');

    await Future.wait([
      DiagnosticsService()
          .init()
          .then((_) => debugPrint('🩺 Diagnostics Service Init Done')),
      AuditService()
          .init()
          .then((_) => debugPrint('📜 Audit Service Init Done')),
      if (!kIsWeb)
        PrinterManagerService()
            .init()
            .then((_) => debugPrint('🖨️ Printer Service Init Done')),
      OfflineService()
          .init()
          .then((_) => debugPrint('🌐 Offline Service Init Done')),
      SyncService().init().then((_) => debugPrint('🔄 Sync Service Init Done')),
    ]);

    try {
      debugPrint('⏳ Initializing Announcement Service...');
      final service = AnnouncementService();
      ServiceLocator.instance.registerSingleton<AnnouncementService>(service);
      await service.init();

      // Initialize event bus listeners
      BillingListener().init();
      InventoryListener().init();
      PrinterListener().init();
      SyncListener().init();
      QRListener().init();

      debugPrint('📣 Announcement Service & Listeners Init Done');
    } catch (e) {
      debugPrint('❌ Announcement Service Init Failed: $e');
    }

    debugPrint('✅ Service Initialization Complete');
  }
}
