import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audio_engine.dart';
import 'web_audio_helper.dart' if (dart.library.js) 'web_audio_helper_web.dart';

class FlutterAudioEngine implements AudioEngine {
  final List<AudioPlayer> _players = List.generate(3, (_) => AudioPlayer());
  int _playerIndex = 0;

  FlutterAudioEngine() {
    for (var p in _players) {
      try {
        p.setReleaseMode(ReleaseMode.stop);
        p.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {}
    }
  }

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

      final player = _players[_playerIndex];
      _playerIndex = (_playerIndex + 1) % _players.length;

      await player.stop();
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.play(AssetSource(sourcePath), mode: PlayerMode.lowLatency);
    } catch (_) {
      // Fail-soft, do not crash
    }
  }

  @override
  Future<void> stop() async {
    try {
      for (var p in _players) {
        await p.stop();
      }
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      for (var p in _players) {
        await p.dispose();
      }
    } catch (_) {}
  }
}
