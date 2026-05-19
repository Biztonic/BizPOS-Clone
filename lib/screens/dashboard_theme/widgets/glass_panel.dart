// ignore_for_file: deprecated_member_use
import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import '../../../utils/car_dashboard_theme.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Border? border;
  final bool withGlow;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final double? opacity;

  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.border,
    this.withGlow = false,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.opacity,
    this.color, // Add this
    this.gradient, // Add this
    this.borderColor, // Add this
  });

  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    Widget content = ClipRRect(
      borderRadius: BorderRadius.zero,
      child: Container(
        width: width,
        height: height,
        padding: padding ?? const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color ?? CarDashboardTheme.overlayLight.withValues(alpha: opacity ?? 0.05), 
          borderRadius: BorderRadius.zero,
          border: border ?? Border.all(color: borderColor ?? AppColors.surfaceLight.withValues(alpha: 0.1), width: 1.0),
          gradient: gradient ?? (color != null ? null : CarDashboardTheme.glassGradient),
          boxShadow: withGlow ? [
            BoxShadow(
              color: AppColors.textPrimaryLight.withValues(alpha: 0.2),
              blurRadius: 10, // Reduced from 20
              offset: const Offset(0, 5), // Reduced from 10
            ) 
          ] : null,
        ),
        child: child,
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    
    return content;
  }
}



