
import 'package:flutter/material.dart';
import '../../../utils/car_dashboard_theme.dart';

class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool isLarge;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = CarDashboardTheme.neonBlue,
    this.icon,
    this.isLarge = false,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    widget.onPressed!();
  }

  void _onTapCancel() {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    // Instant feedback without animation
    final scale = _isPressed ? 0.95 : 1.0;
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Transform.scale(
        scale: scale,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isLarge ? 32 : 16,
            vertical: widget.isLarge ? 20 : 12,
          ),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withValues(alpha: _isPressed ? 1.0 : 0.6),
              width: 2,
            ),
            boxShadow: [
              if (!_isPressed && widget.onPressed != null)
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              if (_isPressed)
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: widget.color,
                  size: widget.isLarge ? 24 : 18,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label.toUpperCase(),
                style: CarDashboardTheme.buttonText.copyWith(
                  color: widget.color,
                  fontSize: widget.isLarge ? 20 : 14,
                  shadows: [
                    Shadow(
                      color: widget.color,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
