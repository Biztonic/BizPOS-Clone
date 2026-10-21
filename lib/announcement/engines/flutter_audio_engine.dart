import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'audio_engine.dart';
import 'web_audio_helper.dart' if (dart.library.js) 'web_audio_helper_web.dart';

class FlutterAudioEngine implements AudioEngine {
  final List<AudioPlayer> _players = List.generate(4, (_) => AudioPlayer());
  final List<double> _playerVolumes = List.filled(4, -1.0);
  int _playerIndex = 0;

  static final Map<String, AssetSource> _sourceCache = {};
  static final List<String> _precacheList = [
    'sounds/click.wav',
    'sounds/beep.wav',
    'sounds/chime.wav',
    'sounds/scan.wav',
    'sounds/add.wav',
    'sounds/delete.wav',
    'sounds/keypad.wav',
    'sounds/success.wav',
    'sounds/alert.wav',
  ];

  FlutterAudioEngine() {
    for (var p in _players) {
      try {
        p.setReleaseMode(ReleaseMode.stop);
        p.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {}
    }
    for (final path in _precacheList) {
      _sourceCache[path] = AssetSource(path);
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
      final idx = _playerIndex;
      _playerIndex = (_playerIndex + 1) % _players.length;

      final clampedVolume = volume.clamp(0.0, 1.0);

      // Low latency fire-and-forget: do not block UI thread on native IPC
      unawaited(() async {
        try {
          if ((_playerVolumes[idx] - clampedVolume).abs() > 0.05) {
            _playerVolumes[idx] = clampedVolume;
            await player.setVolume(clampedVolume);
          }
          final source =
              _sourceCache.putIfAbsent(sourcePath, () => AssetSource(sourcePath));
          await player.play(source, mode: PlayerMode.lowLatency);
        } catch (_) {}
      }());
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
