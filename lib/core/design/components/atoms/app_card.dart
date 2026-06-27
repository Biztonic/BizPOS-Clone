import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
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
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Padding(
      padding: widget.padding,
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        borderRadius: AppRadius.borderLg,
        child: content,
      );
    }

    // Determine effective border
    final effectiveBorderColor = widget.isSelected
        ? theme.colorScheme.primary
        : (_isHovered && widget.onTap != null
            ? theme.colorScheme.primary.withValues(alpha: 0.5)
            : widget.borderColor);
    final showBorder = widget.outlined || widget.isSelected || widget.borderColor != null || (_isHovered && widget.onTap != null);

    // Determine shadow
    final shadow = widget.isSelected
        ? AppShadows.md
        : (widget.onTap != null 
            ? (_isHovered ? AppShadows.md : AppShadows.sm)
            : AppShadows.none);

    final cardBgColor = widget.isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.05)
        : (widget.backgroundColor ?? (isDark ? theme.cardTheme.color : AppColors.surfaceLight));

    Widget card;
    final isInteractive = widget.onTap != null;

    if (showBorder) {
      card = Card(
        elevation: 0, // Using custom shadows via decoration
        color: cardBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
          side: BorderSide(
            color: effectiveBorderColor ?? theme.dividerColor.withValues(alpha: 0.15),
            width: widget.isSelected ? 2 : 1,
          ),
        ),
        margin: widget.margin ?? EdgeInsets.zero,
        child: content,
      );
    } else {
      card = Container(
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: AppRadius.borderLg,
          boxShadow: AppShadows.adaptive(
            context, 
            light: shadow, 
            dark: widget.isSelected || (_isHovered && widget.onTap != null) ? AppShadows.darkMd : AppShadows.darkSm
          ),
          border: Border.all(
            color: isDark 
                ? (_isHovered && widget.onTap != null 
                    ? theme.colorScheme.primary.withValues(alpha: 0.3) 
                    : AppColors.surfaceLight.withValues(alpha: 0.06))
                : (_isHovered && widget.onTap != null
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : AppColors.textPrimaryLight.withValues(alpha: 0.04)),
            width: 1,
          ),
        ),
        margin: widget.margin ?? EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: AppRadius.borderLg,
          child: Material(
            color: AppColors.transparent,
            child: content,
          ),
        ),
      );
    }

    if (isInteractive) {
      card = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translate(0.0, _isHovered ? -3.0 : 0.0)
            ..scale(_isHovered ? 1.01 : 1.0),
          child: card,
        ),
      );
    }

    if (widget.height != null || widget.width != null) {
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: card,
      );
    }

    return card;
  }
}
