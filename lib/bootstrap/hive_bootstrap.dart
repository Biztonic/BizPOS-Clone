import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import '../services/security_service.dart';

class HiveBootstrap {
  static Future<void> init() async {
    debugPrint('🐝 Initializing Hive...');
    await Hive.initFlutter();
    debugPrint('✅ Hive Initialized');

    await _openBoxes();
  }

  static Future<void> _openBoxes() async {
    debugPrint('📦 Opening Hive Boxes...');

    // 1. Get encryption key for sensitive boxes
    final securityService = SecurityService();
    final hiveKey = await securityService.getHiveKey();
    final cipher = HiveAesCipher(hiveKey);

    // Sensitive boxes to encrypt
    final encryptedBoxes = {
      'auth_cache',
      'sync_queue',
      'cache_orders',
      'cache_customers',
      'cache_employees',
      'cache_suppliers',
      'cache_notes',
    };

    // Open unencrypted boxes in parallel for speed
    await Future.wait([
      Hive.openBox('settings'),
      Hive.openBox('error_logs'),
      Hive.openBox('cache_stores'),
      Hive.openBox('cache_floors'),
      Hive.openBox('cache_tables'),
      Hive.openBox('cache_inventory'),
      Hive.openBox('store_types'),
      Hive.openBox('store_type_configs'),
    ]);

    // Open encrypted boxes with staged migration protection
    for (var boxName in encryptedBoxes) {
      await _openEncryptedBox(boxName, cipher);
    }

    debugPrint('✅ Hive Boxes Opened');
  }

  static Future<void> _openEncryptedBox(String boxName, HiveCipher cipher) async {
    try {
      await Hive.openBox(boxName, encryptionCipher: cipher);
    } catch (e) {
      debugPrint('⚠️ HiveBootstrap: Failed to open encrypted box "$boxName" ($e). Attempting staged migration...');
      try {
        // 1. Open old box unencrypted
        final oldBox = await Hive.openBox(boxName);
        final data = Map<dynamic, dynamic>.from(oldBox.toMap());

        // 2. Open temporary encrypted box
        final tempBoxName = '${boxName}_temp';
        await Hive.deleteBoxFromDisk(tempBoxName);
        final tempBox = await Hive.openBox(tempBoxName, encryptionCipher: cipher);

        // 3. Copy records to temp box
        await tempBox.putAll(data);

        // 4. Verify record count
        if (tempBox.length != data.length) {
          throw Exception("Verification failed: record count mismatch");
        }

        // 5. Close both
        await oldBox.close();
        await tempBox.close();

        // 6. Delete old unencrypted box
        await Hive.deleteBoxFromDisk(boxName);

        // 7. Reopen original box name with encryption
        final newBox = await Hive.openBox(boxName, encryptionCipher: cipher);

        // 8. Reopen temp box and copy back
        final tempBoxRead = await Hive.openBox(tempBoxName, encryptionCipher: cipher);
        await newBox.putAll(Map<dynamic, dynamic>.from(tempBoxRead.toMap()));
        await tempBoxRead.close();

        // 9. Clean up temp box
        await Hive.deleteBoxFromDisk(tempBoxName);

        debugPrint('✅ HiveBootstrap: Successfully migrated box "$boxName" to encrypted format.');
      } catch (migrationError) {
        debugPrint('❌ HiveBootstrap: Failed to migrate box "$boxName": $migrationError. Creating fresh encrypted box.');
        await Hive.deleteBoxFromDisk(boxName);
        await Hive.deleteBoxFromDisk('${boxName}_temp');
        await Hive.openBox(boxName, encryptionCipher: cipher);
      }
    }
  }
}
