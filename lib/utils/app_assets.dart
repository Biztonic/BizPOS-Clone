import 'package:flutter/widgets.dart';

/// Centralized helper for managing and resolving flavor/theme assets.
class AppAssets {
  AppAssets._();

  // --- Base Asset Paths ---
  static const String defaultLogo = 'assets/logo.jpg';
  static const String standardLogo = 'assets/flavors/standard/logo.png';
  static const String automotiveLogo = 'assets/flavors/automotive/logo.png';
  static const String restaurantLogo = 'assets/flavors/restaurant/logo.png';

  /// Resolves the app logo asset path based on the active theme or flavor name.
  /// Falls back to [defaultLogo] if specific asset is unassigned.
  static String getLogoPath([String? themeName]) {
    switch (themeName?.toLowerCase()) {
      case 'car':
      case 'automotive':
        return automotiveLogo;
      case 'restaurant':
      case 'dine-in':
        return restaurantLogo;
      case 'standard':
      default:
        return standardLogo;
    }
  }

  /// Helper image widget with fallback to default logo on loading error
  static Widget buildLogoWidget({
    String? themeName,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    final path = getLogoPath(themeName);
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) {
        // Safe fallback to default logo
        return Image.asset(
          defaultLogo,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => SizedBox(width: width, height: height),
        );
      },
    );
  }
}
