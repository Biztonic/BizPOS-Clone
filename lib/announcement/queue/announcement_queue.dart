import 'dart:async';
import '../models/announcement.dart';
import '../models/announcement_priority.dart';
import '../models/announcement_log.dart';
import '../executor/announcement_executor.dart';
import '../policy/announcement_policy.dart';

class AnnouncementQueue {
  final AnnouncementExecutor executor;
  final void Function(AnnouncementLog log) onLog;
  
  final List<Announcement> _queue = [];
  bool _isPlaying = false;
  Announcement? _current;

  AnnouncementQueue({
    required this.executor,
    required this.onLog,
  });

  void enqueue(Announcement announcement) {
    if (AnnouncementPolicy.shouldInterrupt(announcement, _current)) {
      _interruptCurrent();
      _queue.insert(0, announcement);
    } else if (announcement.priority == AnnouncementPriority.critical) {
      _queue.insert(0, announcement);
    } else if (announcement.priority == AnnouncementPriority.high) {
      int index = 0;
      while (index < _queue.length &&
          (_queue[index].priority == AnnouncementPriority.critical ||
              _queue[index].priority == AnnouncementPriority.high)) {
        index++;
      }
      _queue.insert(index, announcement);
    } else if (announcement.priority == AnnouncementPriority.medium) {
      int index = 0;
      while (index < _queue.length &&
          (_queue[index].priority == AnnouncementPriority.critical ||
              _queue[index].priority == AnnouncementPriority.high ||
              _queue[index].priority == AnnouncementPriority.medium)) {
        index++;
      }
      _queue.insert(index, announcement);
    } else {
      _queue.add(announcement);
    }

    _processNext();
  }

  void _interruptCurrent() {
    if (_current != null) {
      executor.stop();
      onLog(AnnouncementLog(
        type: _current!.type,
        priority: _current!.priority,
        interrupted: true,
      ));
    }
    _isPlaying = false;
  }

  Future<void> _processNext() async {
    if (_isPlaying || _queue.isEmpty) return;

    _isPlaying = true;
    _current = _queue.removeAt(0);

    try {
      final announcement = _current!;
      final result = await executor.execute(announcement);

      onLog(AnnouncementLog(
        type: announcement.type,
        priority: announcement.priority,
        durationMs: result.durationMs,
        interrupted: false,
        skipped: false,
        suppressed: false,
        failureReason: result.failureReason,
      ));
    } catch (e) {
      if (_current != null) {
        onLog(AnnouncementLog(
          type: _current!.type,
          priority: _current!.priority,
          failureReason: e.toString(),
        ));
      }
    } finally {
      _isPlaying = false;
      _current = null;
      // Trigger next iteration
      Timer(const Duration(milliseconds: 100), _processNext);
    }
  }

  void clear() {
    _queue.clear();
    _interruptCurrent();
  }
}
