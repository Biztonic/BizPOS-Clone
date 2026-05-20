import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_radius.dart';
import 'package:biztonic_pos/core/design/tokens/app_colors.dart';

class NeonButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final IconData? icon;
  final bool isLarge;

  const NeonButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
    this.isLarge = false,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _isPressed = false;

  Color get _color => widget.color ?? AppColors.adaptivePrimary(context);

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
            color: _color.withValues(alpha: _isPressed ? 0.2 : 0.1),
            borderRadius: AppRadius.borderSm,
            border: Border.all(
              color: _color.withValues(alpha: _isPressed ? 1.0 : 0.6),
              width: 1.5,
            ),
            boxShadow: [
              if (!_isPressed && widget.onPressed != null)
                BoxShadow(
                  color: _color.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: _color,
                  size: widget.isLarge ? 24 : 18,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  color: _color,
                  fontSize: widget.isLarge ? 20 : 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
