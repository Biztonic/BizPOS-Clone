import 'dart:async';
import '../models/announcement.dart';
import '../models/announcement_type.dart';
import '../policy/announcement_policy.dart';
import '../queue/announcement_queue.dart';

class AnnouncementScheduler {
  final AnnouncementQueue queue;
  
  // Buffers for mergeable announcements
  final Map<AnnouncementType, List<Announcement>> _mergeBuffers = {};
  final Map<AnnouncementType, Timer> _mergeTimers = {};

  AnnouncementScheduler({required this.queue});

  /// Schedules an announcement. Supports optional delays and queue merging policies.
  void schedule(Announcement announcement, {Duration? delay}) {
    final type = announcement.type;

    if (AnnouncementPolicy.isMergeable(type)) {
      _bufferAndMerge(announcement);
      return;
    }

    if (delay != null) {
      Timer(delay, () {
        queue.enqueue(announcement);
      });
      return;
    }

    queue.enqueue(announcement);
  }

  void _bufferAndMerge(Announcement announcement) {
    final type = announcement.type;

    _mergeBuffers[type] ??= [];
    _mergeBuffers[type]!.add(announcement);

    _mergeTimers[type]?.cancel();
    _mergeTimers[type] = Timer(const Duration(milliseconds: 1200), () {
      _flushMergeBuffer(type);
    });
  }

  void _flushMergeBuffer(AnnouncementType type) {
    final buffer = _mergeBuffers[type];
    if (buffer == null || buffer.isEmpty) return;

    if (buffer.length == 1) {
      queue.enqueue(buffer.first);
    } else {
      // Merge all enqueued announcements in the buffer sequentially
      Announcement merged = buffer.first;
      for (int i = 1; i < buffer.length; i++) {
        merged = AnnouncementPolicy.merge(merged, buffer[i]);
      }
      queue.enqueue(merged);
    }

    buffer.clear();
    _mergeTimers.remove(type);
  }

  void cancelAll() {
    for (var timer in _mergeTimers.values) {
      timer.cancel();
    }
    _mergeTimers.clear();
    _mergeBuffers.clear();
  }
}
