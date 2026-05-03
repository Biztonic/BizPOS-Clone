import 'package:flutter/animation.dart';

/// Defines standard animation curves and durations for the application.
class AppMotion {
  // Durations
  static const Duration instantly = Duration.zero;
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // Curves
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve standardEntrance = Curves.easeOutCubic;
  static const Curve standardExit = Curves.easeInCubic;
  static const Curve emphasize = Curves.easeOutBack;

  // Specific motion types
  static const Duration pageTransition = standard;
  static const Duration modalTransition = standard;
  static const Duration hoverAnimation = fast;
  static const Duration billingFeedback = slow;
  static const Duration successConfirmation = slow;
}
