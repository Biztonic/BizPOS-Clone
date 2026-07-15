import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audio_engine.dart';
import 'web_audio_helper.dart' if (dart.library.js) 'web_audio_helper_web.dart';

class FlutterAudioEngine implements AudioEngine {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  Future<void> playSound(String assetPath, double volume) async {
    try {
      if (kIsWeb) {
        playWebSynthSound(assetPath, volume);
        return;
      }

      String sourcePath = assetPath;
      if (sourcePath.startsWith('assets/')) {
        sourcePath = sourcePath.replaceFirst('assets/', '');
      }
      await _audioPlayer.setVolume(volume);
      await _audioPlayer.play(AssetSource(sourcePath));
    } catch (_) {
      // Fail-soft, do not crash
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (_) {}
  }
}
