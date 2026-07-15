import 'package:audioplayers/audioplayers.dart';
import 'audio_engine.dart';

class FlutterAudioEngine implements AudioEngine {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  Future<void> playSound(String assetPath, double volume) async {
    try {
      await _audioPlayer.setVolume(volume);
      // In audioplayers 6.0+, AssetSource is used for playing bundled assets
      // E.g., assets/sounds/payment_success.mp3 -> AssetSource('sounds/payment_success.mp3')
      // Let's normalize assetPath to work with AssetSource:
      String sourcePath = assetPath;
      if (sourcePath.startsWith('assets/')) {
        sourcePath = sourcePath.replaceFirst('assets/', '');
      }
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
