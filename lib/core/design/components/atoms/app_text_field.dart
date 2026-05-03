import '../../../../core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import '../../tokens/app_spacing.dart';

enum AppTextFieldSize { small, medium, large }

enum AppTextFieldVariant { outlined, filled, underlined }

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? label; // Alias for labelText
  final String? hintText;
  final String? hint; // Alias for hintText
  final String? errorText;
  final String? helperText;
  final String? prefixText;
  final String? suffixText;
  final String? initialValue;
  final bool obscureText;
  final bool readOnly;
  final bool isFullWidth;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? icon;
  final AppTextFieldSize size;
  final AppTextFieldVariant variant;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final double? width;

  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.label,
    this.hintText,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefixText,
    this.suffixText,
    this.initialValue,
    this.obscureText = false,
    this.readOnly = false,
    this.isFullWidth = false,
    this.prefixIcon,
    this.suffixIcon,
    this.icon,
    this.size = AppTextFieldSize.medium,
    this.variant = AppTextFieldVariant.outlined,
    this.enabled = true,
    this.onChanged,
    this.onEditingComplete,
    this.onTap,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.width,
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

    final field = TextFormField(
      controller: controller,
      initialValue: initialValue,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(fontSize: fontSize),
      decoration: InputDecoration(
        labelText: labelText ?? label,
        hintText: hintText ?? hint,
        helperText: helperText,
        errorText: errorText,
        prefixText: prefixText,
        suffixText: suffixText,
        prefixIcon: prefixIcon ?? (icon != null ? icon : null),
        suffixIcon: suffixIcon,
        filled: variant == AppTextFieldVariant.filled,
        fillColor: enabled 
            ? (isDark ? AppColors.textSecondary(context).withValues(alpha: 0.1) : Colors.grey[100]) 
            : (isDark ? Colors.transparent : Colors.grey[50]),
        contentPadding: contentPadding,
        border: buildBorder(theme.dividerColor),
        enabledBorder: buildBorder(theme.dividerColor),
        focusedBorder: buildBorder(theme.primaryColor, width: 2.0),
        errorBorder: buildBorder(theme.colorScheme.error),
        focusedErrorBorder: buildBorder(theme.colorScheme.error, width: 2.0),
        disabledBorder: buildBorder(theme.dividerColor.withValues(alpha: 0.5)),
      ),
    );

    if (isFullWidth || width != null) {
      return SizedBox(width: isFullWidth ? double.infinity : width, child: field);
    }
    return field;
  }
}
