// ignore_for_file: unused_local_variable
import 'package:flutter/material.dart';
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
                 top: 40, // Safe area equivalent
                 right: 16,
                 child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => provider.exitDemoMode(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                         padding: const EdgeInsets.all(8),
                         decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)
                         ),
                         child: const Icon(Icons.close, color: Colors.white, size: 24),
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
