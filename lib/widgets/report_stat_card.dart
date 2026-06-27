import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_radius.dart';

import '../core/design/tokens/app_typography.dart';

class ReportStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color baseColor;
  final String? subtitle;

  const ReportStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.baseColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              baseColor.withValues(alpha: 0.8),
              baseColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.borderSm,
          boxShadow: [
            BoxShadow(
              color: baseColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha: 0.2),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Icon(icon, color: AppColors.surfaceLight, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.surfaceLight,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.surfaceLight,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.surfaceLight.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}



