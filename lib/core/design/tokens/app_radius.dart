import 'package:flutter/material.dart';

/// Centralized border radius tokens for the entire application.
/// Upgraded to modern, soft 'squircle' aesthetics inspired by premium UI templates.
///
/// USAGE: Always use these constants instead of hardcoded BorderRadius values.
/// Example: `borderRadius: AppRadius.borderMd`
class AppRadius {
  AppRadius._();

  // Raw values (use in BoxDecoration, ClipRRect, etc.)
  static const double xs = 6.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 40.0;
  static const double circular = 999.0;

  // Convenience BorderRadius objects (use in shapes, decoration, etc.)
  static const BorderRadius borderXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius borderXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius borderCircular = BorderRadius.all(Radius.circular(circular));
}
