import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';

enum AppButtonVariant { primary, secondary, danger, outline, ghost, text }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final Color? foregroundColor;

  const AppButton({
    super.key,
    this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.width,
    this.foregroundColor,
  });

  const AppButton.primary({
    super.key,
    this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.width,
    this.foregroundColor,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.width,
    this.foregroundColor,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.width,
    this.foregroundColor,
  }) : variant = AppButtonVariant.danger;
  
  const AppButton.outline({
    super.key,
    this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.width,
    this.foregroundColor,
  }) : variant = AppButtonVariant.outline;

  const AppButton.ghost({
    super.key,
    this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.width,
    this.foregroundColor,
  }) : variant = AppButtonVariant.ghost;

  double _getHeight() {
    switch (size) {
      case AppButtonSize.small:
        return 32.0;
      case AppButtonSize.medium:
        return 44.0;
      case AppButtonSize.large:
        return 56.0;
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    }
  }

  double _getFontSize(TextTheme textTheme) {
    switch (size) {
      case AppButtonSize.small:
        return textTheme.labelMedium?.fontSize ?? 12.0;
      case AppButtonSize.medium:
        return textTheme.labelLarge?.fontSize ?? 14.0;
      case AppButtonSize.large:
        return textTheme.titleMedium?.fontSize ?? 16.0;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppButtonSize.small:
        return 16.0;
      case AppButtonSize.medium:
        return 20.0;
      case AppButtonSize.large:
        return 24.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Base styles
    Color bgColor;
    Color fgColor;
    BorderSide? border;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = colorScheme.primary;
        fgColor = colorScheme.onPrimary;
        break;
      case AppButtonVariant.secondary:
        bgColor = colorScheme.secondaryContainer;
        fgColor = colorScheme.onSecondaryContainer;
        break;
      case AppButtonVariant.danger:
        bgColor = colorScheme.error;
        fgColor = colorScheme.onError;
        break;
      case AppButtonVariant.outline:
        bgColor = AppColors.transparent;
        fgColor = colorScheme.primary;
        border = BorderSide(color: colorScheme.primary, width: 1.5);
        break;
      case AppButtonVariant.ghost:
      case AppButtonVariant.text:
        bgColor = AppColors.transparent;
        fgColor = colorScheme.primary;
        break;
    }

    // Apply foregroundColor override if provided
    if (foregroundColor != null) {
      fgColor = foregroundColor!;
    }

    // Interactive state colors for Ghost/Text
    final isGhost = variant == AppButtonVariant.ghost || variant == AppButtonVariant.text;

    final buttonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          if (isGhost || variant == AppButtonVariant.outline) return AppColors.transparent;
          return colorScheme.onSurface.withValues(alpha: 0.12);
        }
        if (isGhost) {
          if (states.contains(WidgetState.pressed)) return fgColor.withValues(alpha: 0.12);
          if (states.contains(WidgetState.hovered)) return fgColor.withValues(alpha: 0.08);
          return AppColors.transparent;
        }
        return bgColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        return fgColor;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (isGhost) return AppColors.transparent; // Handled in backgroundColor
        return fgColor.withValues(alpha: 0.1);
      }),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled) || isGhost || variant == AppButtonVariant.outline) return 0;
        if (states.contains(WidgetState.pressed)) return 0;
        if (states.contains(WidgetState.hovered)) return 2;
        return 1;
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
          side: border ?? BorderSide.none,
        ),
      ),
      padding: WidgetStateProperty.all(_getPadding()),
      minimumSize: WidgetStateProperty.all(Size(width ?? 0, _getHeight())),
      fixedSize: width != null ? WidgetStateProperty.all(Size(width!, _getHeight())) : null,
    );

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: _getIconSize(),
            height: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fgColor,
            ),
          ),
          if (label != null) const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: _getIconSize()),
          if (label != null) const SizedBox(width: AppSpacing.sm),
        ],
        if (label != null)
          Text(
            label!,
            style: TextStyle(
              fontSize: _getFontSize(theme.textTheme),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );

    return ElevatedButton(
      onPressed: (isLoading || onPressed == null) ? null : onPressed,
      style: buttonStyle,
      child: content,
    );
  }
}

