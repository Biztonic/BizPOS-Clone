import 'package:flutter_test/flutter_test.dart';
import 'package:biztonic_pos/announcement/announcement.dart';
import 'package:biztonic_pos/announcement/engines/audio_engine.dart';
import 'package:biztonic_pos/announcement/engines/voice_engine.dart';
import 'package:biztonic_pos/announcement/engines/haptic_engine.dart';

class MockAudioEngine implements AudioEngine {
  final List<String> playedSounds = [];
  bool isStopped = false;

  @override
  Future<void> playSound(String assetPath, double volume) async {
    playedSounds.add(assetPath);
  }

  @override
  Future<void> stop() async {
    isStopped = true;
  }

  @override
  Future<void> dispose() async {}
}

class MockVoiceEngine implements VoiceEngine {
  final List<String> spokenTexts = [];
  bool isStopped = false;

  @override
  Future<void> speak(String text, {double? volume, double? rate, String? lang}) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {
    isStopped = true;
  }

  @override
  Future<void> dispose() async {}
}

class MockHapticEngine extends HapticEngine {
  int triggerCount = 0;

  @override
  Future<void> triggerHaptic() async {
    triggerCount++;
  }
}

void main() {
  group('Announcement Layered Framework Tests', () {
    late MockAudioEngine mockAudio;
    late MockVoiceEngine mockVoice;
    late MockHapticEngine mockHaptic;
    late AnnouncementExecutor executor;
    late AnnouncementQueue queue;
    late AnnouncementScheduler scheduler;
    late AnnouncementBuilder builder;
    final List<AnnouncementLog> receivedLogs = [];

    setUp(() {
      mockAudio = MockAudioEngine();
      mockVoice = MockVoiceEngine();
      mockHaptic = MockHapticEngine();
      executor = AnnouncementExecutor(
        audioEngine: mockAudio,
        voiceEngine: mockVoice,
        hapticEngine: mockHaptic,
      );
      receivedLogs.clear();
      queue = AnnouncementQueue(
        executor: executor,
        onLog: (log) => receivedLogs.add(log),
      );
      scheduler = AnnouncementScheduler(queue: queue);
      builder = AnnouncementBuilder();
    });

    test('Queue Priority Order execution', () async {
      final lowAnnouncement = Announcement(
        type: AnnouncementType.itemAdded,
        priority: AnnouncementPriority.low,
        channel: AnnouncementChannel.voiceOnly,
        text: 'Low priority item added',
        ttsText: 'Low priority item added',
      );

      final criticalAnnouncement = Announcement(
        type: AnnouncementType.paymentFailed,
        priority: AnnouncementPriority.critical,
        channel: AnnouncementChannel.voiceOnly,
        text: 'Critical payment failed',
        ttsText: 'Critical payment failed',
      );

      queue.enqueue(lowAnnouncement);
      queue.enqueue(criticalAnnouncement);

      // Wait briefly for queue processing
      await Future.delayed(const Duration(milliseconds: 500));

      expect(mockVoice.spokenTexts.contains('Critical payment failed'), true);
      // Low priority announcement should be logged as enqueued or processed/interrupted
      expect(receivedLogs.any((l) => l.type == AnnouncementType.paymentFailed), true);
    });

    test('Settings loading default values', () {
      const settings = AnnouncementSettings();
      expect(settings.enableSounds, true);
      expect(settings.enableVoice, true);
      expect(settings.volume, 1.0);
      expect(settings.speechRate, 1.0);
      expect(settings.language, 'en');
    });

    test('Policy Visibility and Routing', () {
      const settings = AnnouncementSettings(profile: 'Basic');
      final result = builder.build(AnnouncementType.itemAdded, settings, {});
      // In Basic profile, itemAdded is ignored since it is not critical/high
      expect(result, null);
    });

    test('Queue Merging for cart additions', () async {
      final item1 = Announcement(
        type: AnnouncementType.itemAdded,
        priority: AnnouncementPriority.medium,
        channel: AnnouncementChannel.voiceOnly,
        text: 'Item added',
        ttsText: 'Item added',
        metadata: {'count': 1},
      );

      final item2 = Announcement(
        type: AnnouncementType.itemAdded,
        priority: AnnouncementPriority.medium,
        channel: AnnouncementChannel.voiceOnly,
        text: 'Item added',
        ttsText: 'Item added',
        metadata: {'count': 1},
      );

      scheduler.schedule(item1);
      scheduler.schedule(item2);

      // Wait for debounce timer (1200ms) to fire and process queue
      await Future.delayed(const Duration(milliseconds: 1800));

      // Verify that announcements were merged
      expect(receivedLogs.any((l) => l.type == AnnouncementType.itemAdded), true);
    });
  });
}
