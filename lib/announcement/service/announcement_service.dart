import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/announcement.dart';
import '../models/announcement_type.dart';
import '../models/announcement_log.dart';
import '../settings/announcement_settings.dart';
import '../builder/announcement_builder.dart';
import '../policy/announcement_policy.dart';
import '../queue/announcement_queue.dart';
import '../scheduler/announcement_scheduler.dart';
import '../executor/announcement_executor.dart';
import '../engines/audio_engine.dart';
import '../engines/voice_engine.dart';
import '../engines/haptic_engine.dart';
import '../engines/flutter_audio_engine.dart';
import '../engines/flutter_tts_engine.dart';
import '../engines/web_audio_helper.dart' if (dart.library.js) '../engines/web_audio_helper_web.dart';

class AnnouncementService {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

  late final AnnouncementBuilder _builder;
  late final AnnouncementQueue _queue;
  late final AnnouncementScheduler _scheduler;
  late final AnnouncementExecutor _executor;
  late AnnouncementSettings _settings;

  AnnouncementSettings get settings => _settings;
  List<AnnouncementLog> get logs => List.unmodifiable(_logs);

  final List<AnnouncementLog> _logs = [];
  final Map<AnnouncementType, DateTime> _lastTriggered = {};

  Future<void> init({
    AudioEngine? audioEngine,
    VoiceEngine? voiceEngine,
    HapticEngine? hapticEngine,
  }) async {
    try {
      _settings = AnnouncementSettings.load();
      _builder = AnnouncementBuilder();
      await _builder.init();

      _executor = AnnouncementExecutor(
        audioEngine: audioEngine ?? FlutterAudioEngine(),
        voiceEngine: voiceEngine ?? FlutterTtsEngine.create(),
        hapticEngine: hapticEngine ?? HapticEngine(),
      );

      _queue = AnnouncementQueue(
        executor: _executor,
        onLog: _logExecution,
      );

      _scheduler = AnnouncementScheduler(queue: _queue);

      debugPrint('📣 [AnnouncementService] Layered architecture initialized');
    } catch (e) {
      debugPrint('❌ [AnnouncementService] Init failed: $e');
    }
  }

  void announce(AnnouncementType type, {Map<String, dynamic> metadata = const {}, Duration? delay}) {
    try {
      // 1. Policy check: Cooldown Suppression
      if (_isCooldownActive(type)) {
        _logExecution(AnnouncementLog(
          type: type,
          priority: _builder.getPriorityForType(type),
          suppressed: true,
        ));
        debugPrint('📣 [AnnouncementService] Announcement $type suppressed by cooldown policy');
        return;
      }

      // 2. Build local translation
      final announcement = _builder.build(type, _settings, metadata);
      if (announcement == null) {
        // Suppressed by active profile configurations (e.g. Silent or Basic)
        _logExecution(AnnouncementLog(
          type: type,
          priority: _builder.getPriorityForType(type),
          skipped: true,
        ));
        return;
      }

      // 3. Update cooldown timers
      _lastTriggered[type] = DateTime.now();

      // 4. Pass to Scheduler
      _scheduler.schedule(announcement, delay: delay);
    } catch (e) {
      debugPrint('❌ [AnnouncementService] Error scheduling announcement: $e');
    }
  }

  void playInteractionSound() {
    try {
      if (!_settings.enableSounds) return;
      final sound = _settings.interactionSound;
      if (sound == 'none') return;

      if (kIsWeb) {
        playWebBeep(sound, _settings.volume * 0.3);
        return;
      }

      // Trigger system touch sound on mobile devices
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  void updateSettings(AnnouncementSettings newSettings) {
    try {
      _settings = newSettings;
      unawaited(_settings.save());
      debugPrint('📣 [AnnouncementService] Settings updated: profile=${newSettings.profile}');
    } catch (_) {}
  }

  bool _isCooldownActive(AnnouncementType type) {
    final cooldown = AnnouncementPolicy.getCooldown(type);
    if (cooldown == null) return false;

    final lastTime = _lastTriggered[type];
    if (lastTime == null) return false;

    return DateTime.now().difference(lastTime) < cooldown;
  }

  void clearLogs() {
    _logs.clear();
  }

  void clearQueue() {
    try {
      _scheduler.cancelAll();
      _queue.clear();
    } catch (_) {}
  }

  void _logExecution(AnnouncementLog log) {
    // Thread-safe capped log limit of maximum 100 entries
    if (_logs.length >= 100) {
      _logs.removeAt(0);
    }
    _logs.add(log);
    debugPrint('📣 [AnnouncementLog] $log');
  }
}
