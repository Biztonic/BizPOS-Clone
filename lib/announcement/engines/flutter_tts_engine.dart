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
  Future<void> speak(String text, {double volume = 1.0, double rate = 1.0, String lang = 'en'}) async {
    try {
      final ttsLang = lang == 'hi' ? 'hi-IN' : (lang == 'mr' ? 'mr-IN' : 'en-US');
      await _flutterTts.setLanguage(ttsLang);
      await _flutterTts.setVolume(volume);
      await _flutterTts.setSpeechRate(rate * 0.5);
      await _flutterTts.speak(text);
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
  Future<void> speak(String text, {double volume = 1.0, double rate = 1.0, String lang = 'en'}) async {
    try {
      final ttsLang = lang == 'hi' ? 'hi-IN' : (lang == 'mr' ? 'mr-IN' : 'en-US');
      await _flutterTts.setLanguage(ttsLang);
      await _flutterTts.setVolume(volume);
      await _flutterTts.setSpeechRate(rate * 0.5);
      await _flutterTts.speak(text);
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
  Future<void> speak(String text, {double volume = 1.0, double rate = 1.0, String lang = 'en'}) async {
    try {
      final ttsLang = lang == 'hi' ? 'hi-IN' : (lang == 'mr' ? 'mr-IN' : 'en-US');
      await _flutterTts.setLanguage(ttsLang);
      await _flutterTts.setVolume(volume);
      await _flutterTts.setSpeechRate(rate * 0.5);
      await _flutterTts.speak(text);
      debugPrint('🌐 WebSpeech: "$text" (lang: $ttsLang, volume: $volume, rate: $rate)');
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
  Future<void> speak(String text, {double volume = 1.0, double rate = 1.0, String lang = 'en'}) async {
    debugPrint('🔇 NoVoiceEngine: "$text" (Speech disabled or platform not supported)');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
