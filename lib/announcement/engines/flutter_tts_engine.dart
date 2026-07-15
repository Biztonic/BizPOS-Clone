import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_engine.dart';

class FlutterTtsEngine {
  /// Factory method to select the correct VoiceEngine at runtime based on the platform.
  static VoiceEngine create() {
    if (kIsWeb) {
      return WebSpeechEngine();
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidTtsEngine();
      case TargetPlatform.iOS:
        return IosTtsEngine();
      default:
        return NoVoiceEngine();
    }
  }
}

class AndroidTtsEngine implements VoiceEngine {
  final FlutterTts _flutterTts = FlutterTts();

  AndroidTtsEngine() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _flutterTts.setQueueMode(1); // Android queue mode
    } catch (_) {}
  }

  @override
  Future<void> speak(String text, {double volume = 1.0, double rate = 1.0, String lang = 'en', String? englishFallback}) async {
    try {
      var targetLang = lang;
      var targetText = text;

      if (targetLang != 'en') {
        try {
          final ttsLang = targetLang == 'hi' ? 'hi-IN' : (targetLang == 'mr' ? 'mr-IN' : 'en-US');
          final isAvailable = await _flutterTts.isLanguageAvailable(ttsLang);
          if (isAvailable == false) {
            targetLang = 'en';
            targetText = englishFallback ?? text;
          }
        } catch (_) {}
      }

      final resolvedLang = targetLang == 'hi' ? 'hi-IN' : (targetLang == 'mr' ? 'mr-IN' : 'en-US');
      await _flutterTts.setLanguage(resolvedLang);
      await _flutterTts.setVolume(volume);
      await _flutterTts.setSpeechRate(rate * 0.5);
      await _flutterTts.speak(targetText);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}

class IosTtsEngine implements VoiceEngine {
  final FlutterTts _flutterTts = FlutterTts();

  IosTtsEngine() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
      );
    } catch (_) {}
  }

  @override
  Future<void> speak(String text, {double volume = 1.0, double rate = 1.0, String lang = 'en', String? englishFallback}) async {
    try {
      var targetLang = lang;
      var targetText = text;

      if (targetLang != 'en') {
        try {
          final ttsLang = targetLang == 'hi' ? 'hi-IN' : (targetLang == 'mr' ? 'mr-IN' : 'en-US');
          final isAvailable = await _flutterTts.isLanguageAvailable(ttsLang);
          if (isAvailable == false) {
            targetLang = 'en';
            targetText = englishFallback ?? text;
          }
        } catch (_) {}
      }

      final resolvedLang = targetLang == 'hi' ? 'hi-IN' : (targetLang == 'mr' ? 'mr-IN' : 'en-US');
      await _flutterTts.setLanguage(resolvedLang);
      await _flutterTts.setVolume(volume);
      await _flutterTts.setSpeechRate(rate * 0.5);
      await _flutterTts.speak(targetText);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}

class WebSpeechEngine implements VoiceEngine {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  Future<void> speak(String text, {double volume = 1.0, double rate = 1.0, String lang = 'en', String? englishFallback}) async {
    try {
      var targetLang = lang;
      var targetText = text;

      if (targetLang != 'en') {
        try {
          final ttsLang = targetLang == 'hi' ? 'hi-IN' : (targetLang == 'mr' ? 'mr-IN' : 'en-US');
          final isAvailable = await _flutterTts.isLanguageAvailable(ttsLang);
          if (isAvailable == false) {
            targetLang = 'en';
            targetText = englishFallback ?? text;
          }
        } catch (_) {}
      }

      final resolvedLang = targetLang == 'hi' ? 'hi-IN' : (targetLang == 'mr' ? 'mr-IN' : 'en-US');
      await _flutterTts.setLanguage(resolvedLang);
      await _flutterTts.setVolume(volume);
      await _flutterTts.setSpeechRate(rate * 0.5);
      await _flutterTts.speak(targetText);
      debugPrint('🌐 WebSpeech: "$targetText" (lang: $resolvedLang, volume: $volume, rate: $rate)');
    } catch (e) {
      debugPrint('❌ WebSpeech synthesis failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}

class NoVoiceEngine implements VoiceEngine {
  @override
  Future<void> speak(String text, {double volume = 1.0, double rate = 1.0, String lang = 'en', String? englishFallback}) async {
    debugPrint('🔇 NoVoiceEngine: "$text" (Speech disabled or platform not supported)');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
