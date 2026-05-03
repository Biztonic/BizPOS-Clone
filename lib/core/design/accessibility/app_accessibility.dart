import 'package:flutter/material.dart';

/// Centralizes accessibility requirements, such as touch targets and contrast.
class AppAccessibility {
  /// Minimum touch target size recommended by Material/Apple guidelines is 44x44 or 48x48.
  static const Size minimumTouchTarget = Size(48.0, 48.0);
  static const double minimumContrastRatio = 4.5; // WCAG AA standard for normal text
}
