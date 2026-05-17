import 'package:flutter/material.dart';

/// Centralized elevation and shadow tokens.
/// Ensures every card, dialog, and floating element has consistent depth.
///
/// Design philosophy: Subtle shadows that add depth without visual noise.
/// Light mode uses darker shadows; dark mode uses lighter, more diffuse ones.
class AppShadows {
  AppShadows._();

  // --- Light Mode Shadows ---
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A000000), // 4% black
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x0F000000), // 6% black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x05000000), // 2% black
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x14000000), // 8% black
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x08000000), // 3% black
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x1A000000), // 10% black
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A000000), // 4% black
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  // --- Dark Mode Shadows (softer, using white glow) ---
  static const List<BoxShadow> darkSm = [
    BoxShadow(
      color: Color(0x0DFFFFFF), // 5% white
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> darkMd = [
    BoxShadow(
      color: Color(0x0DFFFFFF),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Picks the correct shadow based on brightness.
  static List<BoxShadow> adaptive(BuildContext context, {List<BoxShadow> light = md, List<BoxShadow> dark = darkSm}) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
