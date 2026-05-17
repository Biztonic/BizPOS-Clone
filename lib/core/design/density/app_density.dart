import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';


enum AppDensity {
  compact,
  comfortable,
  touch,
}

class DensityConfig {
  final double buttonHeight;
  final double cardPadding;
  final double gridSpacing;
  final double inputHeight;
  final double rowHeight;
  final double cardRadius;
  final double buttonRadius;
  final EdgeInsetsGeometry contentPadding;

  const DensityConfig({
    required this.buttonHeight,
    required this.cardPadding,
    required this.gridSpacing,
    required this.inputHeight,
    required this.rowHeight,
    required this.cardRadius,
    required this.buttonRadius,
    required this.contentPadding,
  });

  factory DensityConfig.fromDensity(AppDensity density) {
    switch (density) {
      case AppDensity.compact:
        return const DensityConfig(
          buttonHeight: 32,
          cardPadding: 8,
          gridSpacing: 8,
          inputHeight: 32,
          rowHeight: 36,
          cardRadius: 0,
          buttonRadius: 0,
          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        );
      case AppDensity.comfortable:
        return const DensityConfig(
          buttonHeight: 40,
          cardPadding: 16,
          gridSpacing: 16,
          inputHeight: 40,
          rowHeight: 48,
          cardRadius: 0,
          buttonRadius: 0,
          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        );
      case AppDensity.touch:
        return const DensityConfig(
          buttonHeight: 56,
          cardPadding: 24,
          gridSpacing: 24,
          inputHeight: 56,
          rowHeight: 64,
          cardRadius: 0,
          buttonRadius: 0,
          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        );
    }
  }
}

class AppDensityProvider extends InheritedWidget {
  final AppDensity density;
  final DensityConfig config;

  AppDensityProvider({
    super.key,
    required this.density,
    required super.child,
  }) : config = DensityConfig.fromDensity(density);

  static AppDensityProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppDensityProvider>();
  }

  static DensityConfig configOf(BuildContext context) {
    final provider = maybeOf(context);
    return provider?.config ?? DensityConfig.fromDensity(AppDensity.comfortable); // Default to comfortable
  }

  static AppDensity densityOf(BuildContext context) {
    final provider = maybeOf(context);
    return provider?.density ?? AppDensity.comfortable;
  }

  @override
  bool updateShouldNotify(AppDensityProvider oldWidget) {
    return density != oldWidget.density;
  }
}
