import 'package:flutter/material.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';

enum AppButtonVariant { primary, secondary, danger, outline, ghost, text }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.danger;
  
  const AppButton.outline({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.outline;

  const AppButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.icon,
  }) : variant = AppButtonVariant.ghost;

  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.lg);
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
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? border;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = colorScheme.primary;
        foregroundColor = colorScheme.onPrimary;
        break;
      case AppButtonVariant.secondary:
        backgroundColor = colorScheme.secondaryContainer;
        foregroundColor = colorScheme.onSecondaryContainer;
        break;
      case AppButtonVariant.danger:
        backgroundColor = colorScheme.error;
        foregroundColor = colorScheme.onError;
        break;
      case AppButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = colorScheme.primary;
        border = BorderSide(color: colorScheme.primary, width: 1.5);
        break;
      case AppButtonVariant.ghost:
      case AppButtonVariant.text:
        backgroundColor = Colors.transparent;
        foregroundColor = colorScheme.primary;
        break;
    }

    // Interactive state colors for Ghost/Text
    final isGhost = variant == AppButtonVariant.ghost || variant == AppButtonVariant.text;

    final buttonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          if (isGhost || variant == AppButtonVariant.outline) return Colors.transparent;
          return colorScheme.onSurface.withValues(alpha: 0.12);
        }
        if (isGhost) {
          if (states.contains(WidgetState.pressed)) return foregroundColor.withValues(alpha: 0.12);
          if (states.contains(WidgetState.hovered)) return foregroundColor.withValues(alpha: 0.08);
          return Colors.transparent;
        }
        return backgroundColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        return foregroundColor;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (isGhost) return Colors.transparent; // Handled in backgroundColor
        return foregroundColor.withValues(alpha: 0.1);
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
              color: foregroundColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
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
