import 'package:flutter/material.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_shadows.dart';

/// A unified card component for all card-based UI in the application.
///
/// Features:
/// - Consistent rounded corners from AppRadius
/// - Adaptive shadows (light/dark mode)
/// - Selection state with primary-tinted background
/// - Optional outlined variant
/// - Hover feedback via InkWell
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool outlined;
  final bool isSelected;
  final EdgeInsetsGeometry? margin;
  final double? height;
  final double? width;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.outlined = false,
    this.isSelected = false,
    this.margin,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderLg,
        child: content,
      );
    }

    // Determine effective border
    final effectiveBorderColor = isSelected
        ? theme.colorScheme.primary
        : borderColor;
    final showBorder = outlined || isSelected || borderColor != null;

    // Determine shadow
    final shadow = isSelected
        ? AppShadows.md
        : (onTap != null ? AppShadows.sm : AppShadows.none);

    Widget card;
    if (showBorder) {
      card = Card(
        elevation: 0, // Using custom shadows via decoration
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : (backgroundColor ?? (isDark ? theme.cardTheme.color : Colors.white)),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
          side: BorderSide(
            color: effectiveBorderColor ?? theme.dividerColor.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        margin: margin ?? EdgeInsets.zero,
        child: content,
      );
    } else {
      card = Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? (isDark ? theme.cardTheme.color : Colors.white),
          borderRadius: AppRadius.borderLg,
          boxShadow: AppShadows.adaptive(context, light: shadow),
          border: Border.all(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
        margin: margin ?? EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: AppRadius.borderLg,
          child: Material(
            color: Colors.transparent,
            child: content,
          ),
        ),
      );
    }

    if (height != null || width != null) {
      return SizedBox(
        height: height,
        width: width,
        child: card,
      );
    }

    return card;
  }
}
