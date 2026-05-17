import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';

class HiveBootstrap {
  static Future<void> init() async {
    debugPrint('🐝 Initializing Hive...');
    await Hive.initFlutter();
    debugPrint('✅ Hive Initialized');

    await _openBoxes();
  }

  static Future<void> _openBoxes() async {
    debugPrint('📦 Opening Hive Boxes...');

    // Small and medium config/cache boxes — fully loaded for synchronous access
    await Future.wait([
      Hive.openBox('settings'),
      Hive.openBox('sync_queue'),
      Hive.openBox('auth_cache'),
      Hive.openBox('error_logs'),
      Hive.openBox('cache_stores'),
      Hive.openBox('cache_employees'),
      Hive.openBox('cache_floors'),
      Hive.openBox('cache_tables'),
      Hive.openBox('cache_suppliers'),
      Hive.openBox('cache_notes'),
      // Converted to Box because codebase uses Hive.box() for these in multiple locations
      Hive.openBox('cache_inventory'),
      Hive.openBox('cache_orders'),
      Hive.openBox('cache_customers'),
    ]);

    debugPrint('✅ Hive Boxes Opened');
  }
}
