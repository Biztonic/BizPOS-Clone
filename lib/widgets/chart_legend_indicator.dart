import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

/// Shared chart legend indicator used across all report screens.
/// Displays a colored dot + label, typically alongside Pie/Bar charts.
class ChartLegendIndicator extends StatelessWidget {
  final Color color;
  final String text;
  final bool isSquare;

  const ChartLegendIndicator({
    super.key,
    required this.color,
    required this.text,
    this.isSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
            borderRadius: isSquare ? BorderRadius.circular(2) : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
