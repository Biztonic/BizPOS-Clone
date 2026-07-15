import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/announcement.dart';
import '../models/announcement_type.dart';
import '../models/announcement_channel.dart';
import '../models/announcement_priority.dart';
import '../settings/announcement_settings.dart';
import '../policy/announcement_policy.dart';

class AnnouncementBuilder {
  Map<String, Map<String, String>> _localizations = {};
  bool _loaded = false;

  final Map<String, Map<String, String>> _fallbackLocalizations = {
    'en': {
      "item_added": "Item added to cart",
      "items_added": "{count} items added",
      "item_removed": "Item removed from cart",
      "items_removed": "{count} items removed",
      "discount_applied": "Discount applied",
      "payment_success": "Payment successful",
      "payment_failed": "Payment failed",
      "receipt_printed": "Receipt printed",
      "refund_completed": "Refund completed",
      "stock_low": "Stock low for {itemName}",
      "out_of_stock": "{itemName} is out of stock",
      "item_restored": "Stock restored for {itemName}",
      "printer_connected": "Printer connected",
      "printer_disconnected": "Printer disconnected",
      "print_started": "Printing started",
      "print_completed": "Printing completed",
      "sync_started": "Synchronization started",
      "sync_completed": "Synchronization completed",
      "online": "Device is online",
      "offline": "Device is offline",
      "pending_uploads": "Pending uploads queued",
      "table_occupied": "Table {tableName} is occupied",
      "table_free": "Table {tableName} is free",
      "new_qr_order": "New QR order received for table {tableName}",
      "kitchen_ready": "Order is ready in the kitchen",
      "login_success": "Login successful",
      "logout": "Logged out",
      "store_changed": "Store changed"
    },
    'hi': {
      "item_added": "कार्ट में सामान जोड़ा गया",
      "items_added": "{count} सामान जोड़े गए",
      "item_removed": "कार्ट से सामान हटाया गया",
      "items_removed": "{count} सामान हटाए गए",
      "discount_applied": "छूट लागू की गई",
      "payment_success": "भुगतान सफल रहा",
      "payment_failed": "भुगतान विफल रहा",
      "receipt_printed": "रसीद मुद्रित की गई",
      "refund_completed": "रिफंड पूरा हुआ",
      "stock_low": "{itemName} का स्टॉक कम है",
      "out_of_stock": "{itemName} स्टॉक में नहीं है",
      "item_restored": "{itemName} का स्टॉक बहाल किया गया",
      "printer_connected": "प्रिंटर कनेक्ट हो गया",
      "printer_disconnected": "प्रिंटर डिस्कनेक्ट हो गया",
      "print_started": "प्रिंटिंग शुरू हुई",
      "print_completed": "प्रिंटिंग पूरी हुई",
      "sync_started": "सिंक्रनाइज़ेशन शुरू हुआ",
      "sync_completed": "सिंक्रनाइज़ेशन पूरा हुआ",
      "online": "डिवाइस ऑनलाइन है",
      "offline": "डिवाइस ऑफ़लाइन है",
      "pending_uploads": "लंबित अपलोड कतार में हैं",
      "table_occupied": "टेबल {tableName} व्यस्त है",
      "table_free": "टेबल {tableName} खाली है",
      "new_qr_order": "टेबल {tableName} के लिए नया क्यूआर ऑर्डर प्राप्त हुआ",
      "kitchen_ready": "रसोई में ऑर्डर तैयार है",
      "login_success": "लॉगिन सफल रहा",
      "logout": "लॉग आउट हो गया",
      "store_changed": "स्टोर बदल गया"
    },
    'mr': {
      "item_added": "कार्टमध्ये वस्तू जोडली",
      "items_added": "{count} वस्तू जोडल्या",
      "item_removed": "कार्टमधून वस्तू काढली",
      "items_removed": "{count} वस्तू काढल्या",
      "discount_applied": "सवलत लागू केली",
      "payment_success": "पेमेंट यशस्वी झाले",
      "payment_failed": "पेमेंट अयशस्वी झाले",
      "receipt_printed": "पावती प्रिंट झाली",
      "refund_completed": "रिफंड पूर्ण झाला",
      "stock_low": "{itemName} चा साठा कमी आहे",
      "out_of_stock": "{itemName} स्टॉक संपला आहे",
      "item_restored": "{itemName} चा साठा पुनर्संचयित केला",
      "printer_connected": "प्रिंटर कनेक्ट झाला",
      "printer_disconnected": "प्रिंटर डिस्कनेक्ट झाला",
      "print_started": "प्रिंटिंग सुरू झाले",
      "print_completed": "प्रिंटिंग पूर्ण झाले",
      "sync_started": "सिंक्रोनाइझेशन सुरू झाले",
      "sync_completed": "सिंक्रोनाइझेशन पूर्ण झाले",
      "online": "डिव्हाइस ऑनलाइन आहे",
      "offline": "डिव्हाइस ऑफलाइन आहे",
      "pending_uploads": "प्रलंबित अपलोड्स रांगेत आहेत",
      "table_occupied": "टेबल {tableName} व्यापलेला आहे",
      "table_free": "टेबल {tableName} रिकामी आहे",
      "new_qr_order": "टेबल {tableName} साठी नवीन क्यूआर ऑर्डर मिळाली",
      "kitchen_ready": "स्वयंपाकघरात ऑर्डर तयार आहे",
      "login_success": "लॉगिन यशस्वी झाले",
      "logout": "लॉग आऊट झाले",
      "store_changed": "स्टोअर बदलले"
    }
  };

  Future<void> init() async {
    if (_loaded) return;
    try {
      for (var lang in ['en', 'hi', 'mr']) {
        try {
          final jsonString = await rootBundle.loadString(
              'lib/announcement/localization/announcements_$lang.json');
          final Map<String, dynamic> jsonMap = json.decode(jsonString);
          _localizations[lang] =
              jsonMap.map((key, value) => MapEntry(key, value.toString()));
        } catch (_) {
          _localizations[lang] = _fallbackLocalizations[lang]!;
        }
      }
      _loaded = true;
    } catch (_) {
      _localizations = _fallbackLocalizations;
      _loaded = true;
    }
  }

  String getTranslation(
      String lang, String key, Map<String, dynamic> metadata) {
    if (!_loaded) {
      _localizations = _fallbackLocalizations;
      _loaded = true;
    }
    final langMap = _localizations[lang] ??
        _localizations['en'] ??
        _fallbackLocalizations['en']!;
    String template =
        langMap[key] ?? _fallbackLocalizations['en']![key] ?? key;

    metadata.forEach((k, v) {
      template = template.replaceAll('{$k}', v.toString());
    });
    return template;
  }

  Announcement? build(AnnouncementType type, AnnouncementSettings settings,
      Map<String, dynamic> metadata) {
    if (!AnnouncementPolicy.isVisibleInProfile(type, settings.profile)) {
      return null;
    }

    final lang = settings.language;
    final isMerged = metadata['isMerged'] == true;
    final String key = _getKeyForType(type, isMerged);
    final String translation = getTranslation(lang, key, metadata);

    final priority = getPriorityForType(type);
    final channel = _getChannelForSettings(settings);
    final soundAsset = _getSoundAssetForType(type);

    return Announcement(
      type: type,
      priority: priority,
      channel: channel,
      text: translation,
      soundAsset: soundAsset,
      ttsText: translation,
      interruptible: type != AnnouncementType.paymentSuccess &&
          priority != AnnouncementPriority.critical,
      metadata: {
        'volume': settings.volume,
        'speechRate': settings.speechRate,
        'language': settings.language,
        ...metadata,
      },
    );
  }

  String _getKeyForType(AnnouncementType type, bool isMerged) {
    switch (type) {
      case AnnouncementType.itemAdded:
        return isMerged ? 'items_added' : 'item_added';
      case AnnouncementType.itemRemoved:
        return isMerged ? 'items_removed' : 'item_removed';
      case AnnouncementType.discountApplied:
        return 'discount_applied';
      case AnnouncementType.paymentSuccess:
        return 'payment_success';
      case AnnouncementType.paymentFailed:
        return 'payment_failed';
      case AnnouncementType.receiptPrinted:
        return 'receipt_printed';
      case AnnouncementType.refund:
        return 'refund_completed';
      case AnnouncementType.stockLow:
        return 'stock_low';
      case AnnouncementType.outOfStock:
        return 'out_of_stock';
      case AnnouncementType.itemRestored:
        return 'item_restored';
      case AnnouncementType.printerConnected:
        return 'printer_connected';
      case AnnouncementType.printerDisconnected:
        return 'printer_disconnected';
      case AnnouncementType.printStarted:
        return 'print_started';
      case AnnouncementType.printCompleted:
        return 'print_completed';
      case AnnouncementType.syncStarted:
        return 'sync_started';
      case AnnouncementType.syncCompleted:
        return 'sync_completed';
      case AnnouncementType.online:
        return 'online';
      case AnnouncementType.offline:
        return 'offline';
      case AnnouncementType.pendingUploads:
        return 'pending_uploads';
      case AnnouncementType.tableOccupied:
        return 'table_occupied';
      case AnnouncementType.tableFree:
        return 'table_free';
      case AnnouncementType.newQrOrder:
        return 'new_qr_order';
      case AnnouncementType.kitchenReady:
        return 'kitchen_ready';
      case AnnouncementType.loginSuccess:
        return 'login_success';
      case AnnouncementType.logout:
        return 'logout';
      case AnnouncementType.storeChanged:
        return 'store_changed';
    }
  }

  AnnouncementPriority getPriorityForType(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.paymentFailed:
      case AnnouncementType.printerDisconnected:
      case AnnouncementType.offline:
      case AnnouncementType.outOfStock:
        return AnnouncementPriority.critical;
      case AnnouncementType.paymentSuccess:
      case AnnouncementType.newQrOrder:
      case AnnouncementType.kitchenReady:
      case AnnouncementType.stockLow:
      case AnnouncementType.refund:
        return AnnouncementPriority.high;
      case AnnouncementType.itemAdded:
      case AnnouncementType.itemRemoved:
      case AnnouncementType.discountApplied:
      case AnnouncementType.tableOccupied:
      case AnnouncementType.tableFree:
      case AnnouncementType.online:
      case AnnouncementType.loginSuccess:
      case AnnouncementType.logout:
      case AnnouncementType.storeChanged:
        return AnnouncementPriority.medium;
      default:
        return AnnouncementPriority.low;
    }
  }

  AnnouncementChannel _getChannelForSettings(AnnouncementSettings settings) {
    if (!settings.enableSounds && !settings.enableVoice) {
      return AnnouncementChannel.silent;
    }
    if (settings.enableSounds && settings.enableVoice) {
      return AnnouncementChannel.soundAndVoice;
    }
    if (settings.enableSounds) {
      return AnnouncementChannel.soundOnly;
    }
    return AnnouncementChannel.voiceOnly;
  }

  String? _getSoundAssetForType(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.itemAdded:
        return 'assets/sounds/item_added.mp3';
      case AnnouncementType.paymentSuccess:
        return 'assets/sounds/payment_success.mp3';
      case AnnouncementType.paymentFailed:
        return 'assets/sounds/payment_failed.mp3';
      case AnnouncementType.printerDisconnected:
      case AnnouncementType.offline:
        return 'assets/sounds/warning.mp3';
      default:
        return 'assets/sounds/notification.mp3';
    }
  }
}
