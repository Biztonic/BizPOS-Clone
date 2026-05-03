import 'package:flutter/material.dart';
import '../../tokens/app_spacing.dart';

enum AppTextFieldSize { small, medium, large }

enum AppTextFieldVariant { outlined, filled, underlined }

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final AppTextFieldSize size;
  final AppTextFieldVariant variant;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final TextInputType? keyboardType;
  final int maxLines;

  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.size = AppTextFieldSize.medium,
    this.variant = AppTextFieldVariant.outlined,
    this.enabled = true,
    this.onChanged,
    this.onEditingComplete,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry contentPadding;
    double fontSize;

    switch (size) {
      case AppTextFieldSize.small:
        contentPadding = const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs);
        fontSize = 12;
        break;
      case AppTextFieldSize.medium:
        contentPadding = const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm);
        fontSize = 14;
        break;
      case AppTextFieldSize.large:
        contentPadding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md);
        fontSize = 16;
        break;
    }

    InputBorder buildBorder(Color color, {double width = 1.0}) {
      switch (variant) {
        case AppTextFieldVariant.outlined:
        case AppTextFieldVariant.filled:
          return OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: variant == AppTextFieldVariant.filled 
                ? BorderSide.none 
                : BorderSide(color: color, width: width),
          );
        case AppTextFieldVariant.underlined:
          return UnderlineInputBorder(
            borderSide: BorderSide(color: color, width: width),
          );
      }
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(fontSize: fontSize),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: variant == AppTextFieldVariant.filled,
        fillColor: enabled 
            ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100) 
            : (isDark ? Colors.grey.shade900 : Colors.grey.shade200),
        contentPadding: contentPadding,
        border: buildBorder(theme.dividerColor),
        enabledBorder: buildBorder(theme.dividerColor),
        focusedBorder: buildBorder(theme.primaryColor, width: 2.0),
        errorBorder: buildBorder(theme.colorScheme.error),
        focusedErrorBorder: buildBorder(theme.colorScheme.error, width: 2.0),
        disabledBorder: buildBorder(theme.dividerColor.withValues(alpha: 0.5)),
      ),
    );
  }
}
