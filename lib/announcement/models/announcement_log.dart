import 'announcement_type.dart';
import 'announcement_priority.dart';

class AnnouncementLog {
  final DateTime timestamp;
  final AnnouncementType type;
  final AnnouncementPriority priority;
  final int durationMs;
  final bool interrupted;
  final bool skipped;
  final bool suppressed;
  final String? failureReason;

  AnnouncementLog({
    DateTime? timestamp,
    required this.type,
    required this.priority,
    this.durationMs = 0,
    this.interrupted = false,
    this.skipped = false,
    this.suppressed = false,
    this.failureReason,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'AnnouncementLog{timestamp: $timestamp, type: $type, priority: $priority, durationMs: $durationMs, interrupted: $interrupted, skipped: $skipped, suppressed: $suppressed, failureReason: $failureReason}';
  }
}
