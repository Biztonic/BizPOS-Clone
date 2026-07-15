import 'package:flutter/services.dart';

class HapticEngine {
  Future<void> triggerHaptic() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Fail-soft, do not crash business logic
    }
  }

  Future<void> triggerVibration() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {
      // Fail-soft
    }
  }
}
