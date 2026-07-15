import 'package:hive_flutter/hive_flutter.dart';

class AnnouncementSettings {
  final bool enableSounds;
  final bool enableVoice;
  final double volume; // 0.0 to 1.0
  final double speechRate; // 0.5 to 2.0
  final String language; // 'en', 'hi', 'mr'
  final String profile; // 'Silent', 'Basic', 'Business', 'Verbose'
  final String interactionSound; // '1' to '20', 'none'
  final String marketingPlayMode; // 'none', 'loop', 'interval'
  final int marketingIntervalSeconds; // E.g., 60, 300, etc.

  const AnnouncementSettings({
    this.enableSounds = true,
    this.enableVoice = true,
    this.volume = 1.0,
    this.speechRate = 1.0,
    this.language = 'en',
    this.profile = 'Business',
    this.interactionSound = '1',
    this.marketingPlayMode = 'none',
    this.marketingIntervalSeconds = 300,
  });

  factory AnnouncementSettings.load() {
    try {
      final box = Hive.box('settings');
      return AnnouncementSettings(
        enableSounds: box.get('announcement_enable_sounds', defaultValue: true) as bool,
        enableVoice: box.get('announcement_enable_voice', defaultValue: true) as bool,
        volume: (box.get('announcement_volume', defaultValue: 1.0) as num).toDouble(),
        speechRate: (box.get('announcement_speech_rate', defaultValue: 1.0) as num).toDouble(),
        language: box.get('announcement_language', defaultValue: 'en') as String,
        profile: box.get('announcement_profile', defaultValue: 'Business') as String,
        interactionSound: box.get('announcement_interaction_sound', defaultValue: '1') as String,
        marketingPlayMode: box.get('announcement_marketing_play_mode', defaultValue: 'none') as String,
        marketingIntervalSeconds: box.get('announcement_marketing_interval_seconds', defaultValue: 300) as int,
      );
    } catch (_) {
      return const AnnouncementSettings();
    }
  }

  Future<void> save() async {
    try {
      final box = Hive.box('settings');
      await box.put('announcement_enable_sounds', enableSounds);
      await box.put('announcement_enable_voice', enableVoice);
      await box.put('announcement_volume', volume);
      await box.put('announcement_speech_rate', speechRate);
      await box.put('announcement_language', language);
      await box.put('announcement_profile', profile);
      await box.put('announcement_interaction_sound', interactionSound);
      await box.put('announcement_marketing_play_mode', marketingPlayMode);
      await box.put('announcement_marketing_interval_seconds', marketingIntervalSeconds);
    } catch (_) {
      // Fail-soft, do not crash business logic
    }
  }

  AnnouncementSettings copyWith({
    bool? enableSounds,
    bool? enableVoice,
    double? volume,
    double? speechRate,
    String? language,
    String? profile,
    String? interactionSound,
    String? marketingPlayMode,
    int? marketingIntervalSeconds,
  }) {
    return AnnouncementSettings(
      enableSounds: enableSounds ?? this.enableSounds,
      enableVoice: enableVoice ?? this.enableVoice,
      volume: volume ?? this.volume,
      speechRate: speechRate ?? this.speechRate,
      language: language ?? this.language,
      profile: profile ?? this.profile,
      interactionSound: interactionSound ?? this.interactionSound,
      marketingPlayMode: marketingPlayMode ?? this.marketingPlayMode,
      marketingIntervalSeconds: marketingIntervalSeconds ?? this.marketingIntervalSeconds,
    );
  }
}
