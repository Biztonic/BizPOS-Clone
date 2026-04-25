
import 'package:flutter/material.dart';
import '../../../../utils/car_dashboard_theme.dart';
import 'glass_panel.dart';

class HoloMenuCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLarge;

  const HoloMenuCard({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  State<HoloMenuCard> createState() => _HoloMenuCardState();
}

class _HoloMenuCardState extends State<HoloMenuCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Instant scale feedback
    final double scale = _isPressed ? 0.95 : 1.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Transform.scale(
        scale: scale,
        child: GlassPanel(
          withGlow: true,
          opacity: 0.15, 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(
                 widget.icon,
                 size: widget.isLarge ? 48 : 32,
                 color: CarDashboardTheme.neonBlue,
               ),
               const SizedBox(height: 16),
               Text(
                 widget.label.toUpperCase(),
                 style: CarDashboardTheme.labelStyle.copyWith(
                   fontSize: widget.isLarge ? 18 : 14,
                   color: Colors.white,
                   fontWeight: FontWeight.bold,
                   letterSpacing: 1.2
                 ),
                 textAlign: TextAlign.center,
               ),
            ],
          ),
        ),
      ),
    );
  }
}
