abstract class AudioEngine {
  Future<void> playSound(String assetPath, double volume);
  Future<void> stop();
  Future<void> dispose();
}
