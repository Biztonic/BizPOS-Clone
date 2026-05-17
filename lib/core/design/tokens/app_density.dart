
/// Defines UI density levels, primarily used to adapt layouts for POS systems.
enum AppDensity {
  /// Condensed layout for efficient data entry (e.g., Desktop back-office)
  compact,
  
  /// Standard layout (e.g., Tablet POS)
  comfortable,
  
  /// Large touch targets for fast-paced environments (e.g., Mobile POS or Touch-heavy terminals)
  touch,
}

class AppDensityValues {
  final AppDensity density;

  const AppDensityValues(this.density);

  /// Base multiplier for padding and spacing
  double get multiplier {
    switch (density) {
      case AppDensity.compact:
        return 0.75;
      case AppDensity.comfortable:
        return 1.0;
      case AppDensity.touch:
        return 1.5;
    }
  }

  /// Minimum height for interactive elements
  double get minInteractiveHeight {
    switch (density) {
      case AppDensity.compact:
        return 32.0;
      case AppDensity.comfortable:
        return 44.0;
      case AppDensity.touch:
        return 56.0;
    }
  }
}
