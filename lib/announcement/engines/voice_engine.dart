abstract class VoiceEngine {
  Future<void> speak(String text, {double volume, double rate, String lang, String? englishFallback});
  Future<void> stop();
  Future<void> dispose();
}
