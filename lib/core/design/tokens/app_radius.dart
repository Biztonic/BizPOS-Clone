import 'package:flutter/material.dart';

/// Centralized border radius tokens for the entire application.
/// Inspired by modern fintech/POS design language (Mosambee, Stripe, Square).
///
/// USAGE: Always use these constants instead of hardcoded BorderRadius values.
/// Example: `borderRadius: AppRadius.borderMd`
class AppRadius {
  AppRadius._();

  // Raw values (use in BoxDecoration, ClipRRect, etc.)
  static const double xs = 4.0;
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 20.0;
  static const double xxl = 28.0;
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
