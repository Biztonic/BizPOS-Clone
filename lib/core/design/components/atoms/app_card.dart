import 'package:flutter/material.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../density/app_density.dart';

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
    final density = AppDensityProvider.configOf(context);
    
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(density.cardRadius),
        child: content,
      );
    }

    // Determine effective border
    final effectiveBorderColor = isSelected
        ? theme.colorScheme.primary
        : borderColor;
    final showBorder = outlined || isSelected || borderColor != null;

    Widget card;
    if (showBorder) {
      card = Card(
        elevation: isSelected ? 2 : 0,
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : (backgroundColor ?? Colors.transparent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(density.cardRadius),
          side: BorderSide(
            color: effectiveBorderColor ?? theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        margin: margin ?? EdgeInsets.zero,
        child: content,
      );
    } else {
      card = Card(
        color: backgroundColor ?? theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(density.cardRadius),
        ),
        margin: margin ?? EdgeInsets.zero,
        child: content,
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

