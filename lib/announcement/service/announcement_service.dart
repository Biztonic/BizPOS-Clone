import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../models/announcement.dart';
import '../models/announcement_type.dart';
import '../models/announcement_log.dart';
import '../models/marketing_audio.dart';
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
  
  // Local marketing audio storage
  final List<MarketingAudio> _marketingAudios = [];
  List<MarketingAudio> get marketingAudios => List.unmodifiable(_marketingAudios);

  Timer? _marketingTimer;
  int _currentMarketingIndex = 0;
  AudioPlayer? _nativeMarketingPlayer;

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

      // Load marketing tracks from local Hive box
      _marketingAudios.clear();
      final mBox = await Hive.openBox('marketing_audio');
      for (var key in mBox.keys) {
        final map = mBox.get(key);
        if (map is Map) {
          _marketingAudios.add(MarketingAudio.fromMap(map));
        }
      }

      // Start scheduler if configured
      startMarketingScheduler();

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
        playWebBeep(sound, _settings.volume * 0.45); // Louder interaction volume
        return;
      }

      // Trigger system touch sound on mobile devices
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  // --- Marketing Audio Storage & Scheduling ---

  Future<void> addMarketingAudio(String name, Uint8List bytes) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final audio = MarketingAudio(id: id, name: name, bytes: bytes);
      _marketingAudios.add(audio);

      final mBox = Hive.box('marketing_audio');
      await mBox.put(id, audio.toMap());

      restartMarketingScheduler();
    } catch (_) {}
  }

  Future<void> deleteMarketingAudio(String id) async {
    try {
      _marketingAudios.removeWhere((audio) => audio.id == id);
      final mBox = Hive.box('marketing_audio');
      await mBox.delete(id);

      restartMarketingScheduler();
    } catch (_) {}
  }

  void restartMarketingScheduler() {
    stopMarketingScheduler();
    startMarketingScheduler();
  }

  void startMarketingScheduler() {
    if (_settings.marketingPlayMode == 'none' || _marketingAudios.isEmpty) {
      return;
    }

    _currentMarketingIndex = 0;
    if (_settings.marketingPlayMode == 'loop') {
      _playNextMarketingLoop();
    } else if (_settings.marketingPlayMode == 'interval') {
      _marketingTimer = Timer.periodic(
        Duration(seconds: _settings.marketingIntervalSeconds),
        (_) => _playNextMarketingInterval(),
      );
    }
  }

  void stopMarketingScheduler() {
    _marketingTimer?.cancel();
    _marketingTimer = null;
    try {
      _nativeMarketingPlayer?.stop();
      _nativeMarketingPlayer?.dispose();
      _nativeMarketingPlayer = null;
    } catch (_) {}
  }

  void _playNextMarketingLoop() {
    if (_settings.marketingPlayMode != 'loop' || _marketingAudios.isEmpty) return;

    final audio = _marketingAudios[_currentMarketingIndex];
    _currentMarketingIndex = (_currentMarketingIndex + 1) % _marketingAudios.length;

    _playMarketingAudioItem(audio, onComplete: () {
      if (_settings.marketingPlayMode == 'loop') {
        // Wait 1 second and play next in rotation
        Timer(const Duration(seconds: 1), _playNextMarketingLoop);
      }
    });
  }

  void _playNextMarketingInterval() {
    if (_marketingAudios.isEmpty) return;

    final audio = _marketingAudios[_currentMarketingIndex];
    _currentMarketingIndex = (_currentMarketingIndex + 1) % _marketingAudios.length;
    _playMarketingAudioItem(audio);
  }

  void _playMarketingAudioItem(MarketingAudio audio, {VoidCallback? onComplete}) {
    if (!_settings.enableSounds) {
      onComplete?.call();
      return;
    }

    try {
      if (kIsWeb) {
        playWebAudioBytes(audio.bytes, _settings.volume);
        // Fallback completion callback since Web Audio API Audio node doesn't easily expose triggers to Dart directly
        Timer(const Duration(seconds: 8), () {
          onComplete?.call();
        });
      } else {
        getTemporaryDirectory().then((tempDir) {
          final tempFile = File('${tempDir.path}/${audio.name}');
          tempFile.writeAsBytes(audio.bytes).then((file) {
            _nativeMarketingPlayer = AudioPlayer();
            _nativeMarketingPlayer!.setVolume(_settings.volume);
            _nativeMarketingPlayer!.play(DeviceFileSource(file.path)).then((_) {
              _nativeMarketingPlayer!.onPlayerComplete.listen((_) {
                _nativeMarketingPlayer?.dispose();
                _nativeMarketingPlayer = null;
                onComplete?.call();
              });
            });
          });
        });
      }
    } catch (_) {
      onComplete?.call();
    }
  }

  void updateSettings(AnnouncementSettings newSettings) {
    try {
      final modeChanged = _settings.marketingPlayMode != newSettings.marketingPlayMode ||
          _settings.marketingIntervalSeconds != newSettings.marketingIntervalSeconds;

      _settings = newSettings;
      unawaited(_settings.save());
      debugPrint('📣 [AnnouncementService] Settings updated: profile=${newSettings.profile}');

      if (modeChanged) {
        restartMarketingScheduler();
      }
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
