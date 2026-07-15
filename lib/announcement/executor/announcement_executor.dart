import '../models/announcement.dart';
import '../models/announcement_channel.dart';
import '../engines/audio_engine.dart';
import '../engines/voice_engine.dart';
import '../engines/haptic_engine.dart';

class ExecutorResult {
  final bool success;
  final int durationMs;
  final String? failureReason;

  ExecutorResult({
    required this.success,
    required this.durationMs,
    this.failureReason,
  });
}

class AnnouncementExecutor {
  final AudioEngine audioEngine;
  final VoiceEngine voiceEngine;
  final HapticEngine hapticEngine;

  AnnouncementExecutor({
    required this.audioEngine,
    required this.voiceEngine,
    required this.hapticEngine,
  });

  /// Plays the announcement components (Haptic -> Sound -> TTS) sequentially.
  Future<ExecutorResult> execute(Announcement announcement) async {
    final stopwatch = Stopwatch()..start();
    try {
      final volume = (announcement.metadata['volume'] as num?)?.toDouble() ?? 1.0;
      final speechRate = (announcement.metadata['speechRate'] as num?)?.toDouble() ?? 1.0;
      final language = (announcement.metadata['language'] as String?) ?? 'en';

      // 1. Trigger Haptics
      if (announcement.channel == AnnouncementChannel.haptic) {
        await hapticEngine.triggerHaptic();
      }

      // 2. Play Audio Sound
      if ((announcement.channel == AnnouncementChannel.soundOnly ||
              announcement.channel == AnnouncementChannel.soundAndVoice) &&
          announcement.soundAsset != null) {
        await audioEngine
            .playSound(announcement.soundAsset!, volume)
            .timeout(const Duration(seconds: 3), onTimeout: () {});
      }

      // 3. Speak Text-to-Speech (TTS)
      if ((announcement.channel == AnnouncementChannel.voiceOnly ||
              announcement.channel == AnnouncementChannel.soundAndVoice) &&
          announcement.ttsText != null &&
          announcement.ttsText!.isNotEmpty) {
        final fallback = announcement.metadata['englishFallback'] as String?;
        await voiceEngine
            .speak(
              announcement.ttsText!,
              volume: volume,
              rate: speechRate,
              lang: language,
              englishFallback: fallback,
            )
            .timeout(const Duration(seconds: 8), onTimeout: () {});
      }

      stopwatch.stop();
      return ExecutorResult(
        success: true,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutorResult(
        success: false,
        durationMs: stopwatch.elapsedMilliseconds,
        failureReason: e.toString(),
      );
    }
  }

  void stop() {
    try {
      audioEngine.stop();
      voiceEngine.stop();
    } catch (_) {}
  }
}
