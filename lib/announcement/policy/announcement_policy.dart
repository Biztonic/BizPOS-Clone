import '../models/announcement.dart';
import '../models/announcement_type.dart';
import '../models/announcement_priority.dart';
import '../settings/announcement_settings.dart';

class AnnouncementPolicy {
  // Cooldown durations for spammy items
  static final Map<AnnouncementType, Duration> _cooldownConfig = {
    AnnouncementType.stockLow: const Duration(minutes: 30),
    AnnouncementType.outOfStock: const Duration(minutes: 5),
    AnnouncementType.offline: const Duration(minutes: 30),
    AnnouncementType.printerDisconnected: const Duration(minutes: 30),
    AnnouncementType.pendingUploads: const Duration(minutes: 30),
  };

  /// Returns the configured cooldown for a type.
  static Duration? getCooldown(AnnouncementType type) {
    return _cooldownConfig[type];
  }

  /// Determines if an event should play in the active settings profile.
  static bool isVisibleInProfile(AnnouncementType type, String profile) {
    if (profile == 'Silent') return false;

    if (profile == 'Basic') {
      return type == AnnouncementType.paymentSuccess ||
          type == AnnouncementType.paymentFailed ||
          type == AnnouncementType.printerDisconnected ||
          type == AnnouncementType.offline ||
          type == AnnouncementType.newQrOrder ||
          type == AnnouncementType.kitchenReady;
    }

    if (profile == 'Business') {
      // Plays everything except frequent cart additions/removals
      return type != AnnouncementType.itemAdded && type != AnnouncementType.itemRemoved;
    }

    // Verbose profile plays everything
    return true;
  }

  /// Determines if a new announcement should interrupt the currently playing one.
  static bool shouldInterrupt(Announcement incoming, Announcement? current) {
    if (current == null) return false;
    if (!current.interruptible) return false;

    // Critical priority announcements can interrupt non-critical playbacks
    return incoming.priority == AnnouncementPriority.critical &&
        current.priority != AnnouncementPriority.critical;
  }

  /// Identifies if an event type is mergeable to prevent sound spam (e.g. cart items).
  static bool isMergeable(AnnouncementType type) {
    return type == AnnouncementType.itemAdded || type == AnnouncementType.itemRemoved;
  }

  /// Merges two announcements of the same type.
  static Announcement merge(Announcement first, Announcement second) {
    if (first.type != second.type) return first;

    final firstCount = (first.metadata['count'] as num?)?.toInt() ?? 1;
    final secondCount = (second.metadata['count'] as num?)?.toInt() ?? 1;
    final newCount = firstCount + secondCount;

    // Create a new merged announcement
    return first.copyWith(
      metadata: {
        ...first.metadata,
        'count': newCount,
        'isMerged': true,
      },
    );
  }
}
