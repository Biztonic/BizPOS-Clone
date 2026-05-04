import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/printer_manager_service.dart';
import '../services/offline_service.dart';
import '../services/sync_service.dart';

class ServiceBootstrap {
  static Future<void> init() async {
    debugPrint('⏳ Starting Service Parallel Init...');
    
    await Future.wait([
      if (!kIsWeb) PrinterManagerService().init().then((_) => debugPrint('🖨️ Printer Service Init Done')),
      OfflineService().init().then((_) => debugPrint('🌐 Offline Service Init Done')),
      SyncService().init().then((_) => debugPrint('🔄 Sync Service Init Done')),
    ]);
    
    debugPrint('✅ Service Initialization Complete');
  }
}
