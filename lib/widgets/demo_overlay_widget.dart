// ignore_for_file: unused_local_variable
import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
// Import SpotlightPainter

class DemoOverlayWidget extends StatelessWidget {
  final Widget child;
  
  const DemoOverlayWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
         if (!provider.isDemoMode) return child;
         
         final rect = provider.activeTargetRect;
         final instruction = provider.activeTargetInstruction;

         return Stack(
            children: [
               child,
               
               // Spotlight Layer REMOVED
               
               // Close Button (Top Right)
               Positioned(
                 top: AppSpacing.xs, // Safe area equivalent
                 right: AppSpacing.md,
                 child: Material(
                    color: AppColors.transparent,
                    child: InkWell(
                      onTap: () => provider.exitDemoMode(),
                      borderRadius: BorderRadius.zero,
                      child: Container(
                         padding: const EdgeInsets.all(AppSpacing.sm),
                         decoration: BoxDecoration(
                            color: AppColors.textPrimaryLight.withValues(alpha: 0.5),
                            shape: BoxShape.rectangle,
                            border: Border.all(color: AppColors.surfaceLight, width: 2)
                         ),
                         child: const Icon(Icons.close, color: AppColors.surfaceLight, size: 24),
                      ),
                    ),
                 ),
               )


            ],
         );
      },
    );
  }

  // Helper removed as requested to hide text badges
}



