import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_radius.dart';

enum AppEmptyStateType {
  general,
  box,
  employee,
  cart,
}

/// A premium, custom-animated empty state widget that paints context-aware vector animations.
class AppEmptyState extends StatefulWidget {
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final Widget? action;
  final AppEmptyStateType type;

  const AppEmptyState({
    super.key,
    this.icon,
    this.title,
    this.subtitle,
    this.action,
    this.type = AppEmptyStateType.general,
  });

  @override
  State<AppEmptyState> createState() => _AppEmptyStateState();
}

class _AppEmptyStateState extends State<AppEmptyState> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = AppColors.adaptivePrimary(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAnimation(t, primaryColor, isDark),
                if (widget.action != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  widget.action!,
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimation(double t, Color primaryColor, bool isDark) {
    switch (widget.type) {
      case AppEmptyStateType.box:
        return SizedBox(
          width: 240,
          height: 200,
          child: CustomPaint(
            size: const Size(240, 200),
            painter: _BoxPainter(
              progress: t,
              color: primaryColor,
              isDark: isDark,
            ),
          ),
        );
      case AppEmptyStateType.employee:
        return SizedBox(
          width: 240,
          height: 200,
          child: CustomPaint(
            size: const Size(240, 200),
            painter: _EmployeePainter(
              progress: t,
              color: primaryColor,
              isDark: isDark,
            ),
          ),
        );
      case AppEmptyStateType.cart:
        return SizedBox(
          width: 240,
          height: 200,
          child: CustomPaint(
            size: const Size(240, 200),
            painter: _CartPainter(
              progress: t,
              color: primaryColor,
              isDark: isDark,
            ),
          ),
        );
      case AppEmptyStateType.general:
        final bobbingOffset = math.sin(t * 2 * math.pi) * 12.0;
        final normalized = (bobbingOffset + 12.0) / 24.0;
        final shadowScale = 0.6 + (normalized * 0.4);
        final shadowOpacity = 0.08 + (normalized * 0.12);

        return SizedBox(
          width: 240,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(240, 200),
                painter: _PulsePainter(
                  progress: t,
                  color: primaryColor,
                  isDark: isDark,
                ),
              ),
              Positioned(
                bottom: 40,
                child: Transform.scale(
                  scale: shadowScale,
                  child: Container(
                    width: 70,
                    height: 12,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: shadowOpacity),
                          blurRadius: 10,
                          spreadRadius: 4,
                        ),
                      ],
                      borderRadius: const BorderRadius.all(Radius.elliptical(35, 6)),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40 + bobbingOffset,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: AppRadius.borderLg,
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.06),
                        offset: const Offset(0, 10),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon ?? Icons.help_outline,
                    size: 40,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _PulsePainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 3; i++) {
      final double waveProgress = (progress + (i / 3.0)) % 1.0;
      final double radius = 30.0 + (waveProgress * 70.0);
      final double opacity = (1.0 - waveProgress) * (isDark ? 0.25 : 0.15);

      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
      
      if (waveProgress > 0.1 && waveProgress < 0.9) {
        final dotPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: opacity * 1.5);
        
        final double angle = (progress * 2 * math.pi) + (i * math.pi * 0.6);
        final dotCenter = Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
        canvas.drawCircle(dotCenter, 3.0, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}

class _BoxPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _BoxPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 10;

    final bobY = math.sin(progress * 2 * math.pi) * 6.0;
    final center = Offset(cx, cy + bobY);

    const double w = 55.0;
    const double h = 28.0;
    const double dy = 45.0;

    final primaryColor = color;

    // 0. Floor Shadow
    for (int i = 0; i < 3; i++) {
      final double scale = 1.0 - i * 0.25;
      final opacity = (0.12 - i * 0.03).clamp(0.0, 1.0);
      final p = Paint()
        ..color = primaryColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy + dy + 15),
          width: w * 2 * scale,
          height: h * scale,
        ),
        p,
      );
    }

    final boxCenter = center;

    // 1. Inside empty space
    final iLeft = Offset(boxCenter.dx - w, boxCenter.dy);
    final iBottom = Offset(boxCenter.dx, boxCenter.dy + h);
    final iRight = Offset(boxCenter.dx + w, boxCenter.dy);
    final iTop = Offset(boxCenter.dx, boxCenter.dy - h);

    final insidePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [Colors.black, primaryColor.withValues(alpha: 0.15)]
            : [Colors.grey.shade800, primaryColor.withValues(alpha: 0.35)],
      ).createShader(Rect.fromPoints(iTop, iBottom))
      ..style = PaintingStyle.fill;

    final insidePath = Path()
      ..moveTo(iLeft.dx, iLeft.dy)
      ..lineTo(iBottom.dx, iBottom.dy)
      ..lineTo(iRight.dx, iRight.dy)
      ..lineTo(iTop.dx, iTop.dy)
      ..close();
    canvas.drawPath(insidePath, insidePaint);

    final insideLinePaint = Paint()
      ..color = primaryColor.withValues(alpha: isDark ? 0.3 : 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(iTop, iBottom, insideLinePaint);

    // 2. Outside Walls
    final oLeftBottom = Offset(boxCenter.dx - w, boxCenter.dy + dy);
    final oFrontBottom = Offset(boxCenter.dx, boxCenter.dy + h + dy);
    final oRightBottom = Offset(boxCenter.dx + w, boxCenter.dy + dy);

    // Front-Left Wall
    final flWallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withValues(alpha: 0.85),
          primaryColor.withValues(alpha: 0.7),
        ],
      ).createShader(Rect.fromPoints(iLeft, oFrontBottom))
      ..style = PaintingStyle.fill;

    final flPath = Path()
      ..moveTo(iLeft.dx, iLeft.dy)
      ..lineTo(iBottom.dx, iBottom.dy)
      ..lineTo(oFrontBottom.dx, oFrontBottom.dy)
      ..lineTo(oLeftBottom.dx, oLeftBottom.dy)
      ..close();
    canvas.drawPath(flPath, flWallPaint);

    // Front-Right Wall
    final frWallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withValues(alpha: 0.65),
          primaryColor.withValues(alpha: 0.5),
        ],
      ).createShader(Rect.fromPoints(iBottom, oRightBottom))
      ..style = PaintingStyle.fill;

    final frPath = Path()
      ..moveTo(iBottom.dx, iBottom.dy)
      ..lineTo(iRight.dx, iRight.dy)
      ..lineTo(oRightBottom.dx, oRightBottom.dy)
      ..lineTo(oFrontBottom.dx, oFrontBottom.dy)
      ..close();
    canvas.drawPath(frPath, frWallPaint);

    // Wall borders
    final borderPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(flPath, borderPaint);
    canvas.drawPath(frPath, borderPaint);

    // 3. Flaps (Lids) breathing
    final breath = math.sin(progress * 2 * math.pi);
    
    // Front-Left flap
    final flapFLPath = Path()
      ..moveTo(iLeft.dx, iLeft.dy)
      ..lineTo(iBottom.dx, iBottom.dy)
      ..lineTo(iBottom.dx - w * 0.6 + breath * 4, iBottom.dy + h * 0.3 + breath * 3)
      ..lineTo(iLeft.dx - w * 0.6 + breath * 4, iLeft.dy + h * 0.3 - breath * 3)
      ..close();
    
    // Front-Right flap
    final flapFRPath = Path()
      ..moveTo(iBottom.dx, iBottom.dy)
      ..lineTo(iRight.dx, iRight.dy)
      ..lineTo(iRight.dx + w * 0.6 - breath * 4, iRight.dy + h * 0.3 - breath * 3)
      ..lineTo(iBottom.dx + w * 0.6 - breath * 4, iBottom.dy + h * 0.3 + breath * 3)
      ..close();

    // Back-Left flap
    final flapBLPath = Path()
      ..moveTo(iLeft.dx, iLeft.dy)
      ..lineTo(iTop.dx, iTop.dy)
      ..lineTo(iTop.dx - w * 0.5 - breath * 3, iTop.dy - h * 0.5 - breath * 4)
      ..lineTo(iLeft.dx - w * 0.5 - breath * 3, iLeft.dy - h * 0.5 + breath * 4)
      ..close();

    // Back-Right flap
    final flapBRPath = Path()
      ..moveTo(iTop.dx, iTop.dy)
      ..lineTo(iRight.dx, iRight.dy)
      ..lineTo(iRight.dx + w * 0.5 + breath * 3, iRight.dy - h * 0.5 + breath * 4)
      ..lineTo(iTop.dx + w * 0.5 + breath * 3, iTop.dy - h * 0.5 - breath * 4)
      ..close();

    final flapPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final flapBorderPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(flapFLPath, flapPaint);
    canvas.drawPath(flapFLPath, flapBorderPaint);
    canvas.drawPath(flapFRPath, flapPaint);
    canvas.drawPath(flapFRPath, flapBorderPaint);
    canvas.drawPath(flapBLPath, flapPaint);
    canvas.drawPath(flapBLPath, flapBorderPaint);
    canvas.drawPath(flapBRPath, flapPaint);
    canvas.drawPath(flapBRPath, flapBorderPaint);

    // 4. Sparkles rising
    final rand = math.Random(42);
    for (int i = 0; i < 5; i++) {
      final double startPhase = i / 5.0;
      final double relativeProgress = (progress + startPhase) % 1.0;
      final double rx = (rand.nextDouble() - 0.5) * w * 1.3;
      final double ry = -relativeProgress * 85.0;
      final double opacity = (1.0 - relativeProgress) * 0.75;
      final double size = 3.0 + rand.nextDouble() * 4.0;

      final sparkleCenter = Offset(cx + rx, cy + bobY - 8 + ry);
      
      final sparklePaint = Paint()
        ..color = primaryColor.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      if (i % 2 == 0) {
        final starPath = Path()
          ..moveTo(sparkleCenter.dx, sparkleCenter.dy - size)
          ..lineTo(sparkleCenter.dx + size * 0.3, sparkleCenter.dy - size * 0.3)
          ..lineTo(sparkleCenter.dx + size, sparkleCenter.dy)
          ..lineTo(sparkleCenter.dx + size * 0.3, sparkleCenter.dy + size * 0.3)
          ..lineTo(sparkleCenter.dx, sparkleCenter.dy + size)
          ..lineTo(sparkleCenter.dx - size * 0.3, sparkleCenter.dy + size * 0.3)
          ..lineTo(sparkleCenter.dx - size, sparkleCenter.dy)
          ..lineTo(sparkleCenter.dx - size * 0.3, sparkleCenter.dy - size * 0.3)
          ..close();
        canvas.drawPath(starPath, sparklePaint);
      } else {
        canvas.drawCircle(sparkleCenter, size * 0.6, sparklePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}

class _EmployeePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _EmployeePainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final bobY = math.sin(progress * 2 * math.pi) * 4.0;
    
    // Background aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 65))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 65, auraPaint);

    final avatarCenter = Offset(cx, cy + bobY);

    // Torso/shoulders
    final torsoPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.4),
        ],
      ).createShader(Rect.fromLTWH(cx - 35, avatarCenter.dy + 15, 70, 40))
      ..style = PaintingStyle.fill;

    final torsoPath = Path()
      ..moveTo(cx - 35, avatarCenter.dy + 45)
      ..quadraticBezierTo(cx - 32, avatarCenter.dy + 18, cx - 18, avatarCenter.dy + 15)
      ..lineTo(cx + 18, avatarCenter.dy + 15)
      ..quadraticBezierTo(cx + 32, avatarCenter.dy + 18, cx + 35, avatarCenter.dy + 45)
      ..close();
    canvas.drawPath(torsoPath, torsoPaint);

    final outlinePaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawPath(torsoPath, outlinePaint);

    // Neck
    final neckPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;
    final neckPath = Path()
      ..moveTo(cx - 7, avatarCenter.dy + 15)
      ..lineTo(cx - 7, avatarCenter.dy + 2)
      ..lineTo(cx + 7, avatarCenter.dy + 2)
      ..lineTo(cx + 7, avatarCenter.dy + 15)
      ..close();
    canvas.drawPath(neckPath, neckPaint);

    // Head
    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.2),
        radius: 0.8,
        colors: [
          color.withValues(alpha: 0.95),
          color.withValues(alpha: 0.7),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, avatarCenter.dy - 12), radius: 18))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, avatarCenter.dy - 12), 18, headPaint);
    canvas.drawCircle(Offset(cx, avatarCenter.dy - 12), 18, outlinePaint);

    // Collar / Tie
    final tiePaint = Paint()
      ..color = isDark ? Colors.white70 : Colors.black87
      ..style = PaintingStyle.fill;
    final tiePath = Path()
      ..moveTo(cx, avatarCenter.dy + 15)
      ..lineTo(cx - 4, avatarCenter.dy + 22)
      ..lineTo(cx, avatarCenter.dy + 28)
      ..lineTo(cx + 4, avatarCenter.dy + 22)
      ..close();
    canvas.drawPath(tiePath, tiePaint);

    // Dotted Orbit Ring
    final orbitPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 110, height: 38),
      orbitPaint,
    );

    // Orbiting magnifying glass
    final double angle = progress * 2 * math.pi;
    final double glassX = cx + 55 * math.cos(angle);
    final double glassY = cy + 19 * math.sin(angle);
    final glassCenter = Offset(glassX, glassY);

    final lensPaint = Paint()
      ..color = isDark ? Colors.grey.shade900.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    final lensBorderPaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(glassCenter, 8.0, lensPaint);
    canvas.drawCircle(glassCenter, 8.0, lensBorderPaint);

    final handlePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
      
    final handleEnd = Offset(
      glassCenter.dx + 6 * math.cos(angle + math.pi / 4),
      glassCenter.dy + 6 * math.sin(angle + math.pi / 4),
    );
    final handleFarEnd = Offset(
      glassCenter.dx + 14 * math.cos(angle + math.pi / 4),
      glassCenter.dy + 14 * math.sin(angle + math.pi / 4),
    );
    canvas.drawLine(handleEnd, handleFarEnd, handlePaint);

    // Floating micro indicators
    for (int i = 0; i < 3; i++) {
      final double phase = (progress + (i / 3.0)) % 1.0;
      final double scale = 1.0 - phase;
      final double dist = 35 + phase * 28;
      final double a = (i * 120.0 + progress * 40.0) * math.pi / 180.0;
      final double px = cx + dist * math.cos(a);
      final double py = cy + dist * math.sin(a) - 10;
      
      final indicatorPaint = Paint()
        ..color = color.withValues(alpha: scale * 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(Offset(px - 3, py), Offset(px + 3, py), indicatorPaint);
      canvas.drawLine(Offset(px, py - 3), Offset(px, py + 3), indicatorPaint);
    }
  }

  @override
  bool shouldRepaint(_EmployeePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}

class _CartPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _CartPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 5;

    final bobY = math.sin(progress * 2 * math.pi) * 3.0;
    final tiltAngle = math.sin(progress * 2 * math.pi) * 0.04;

    canvas.save();
    canvas.translate(cx, cy + bobY);
    canvas.rotate(tiltAngle);

    final cartColor = color;
    final cartPaint = Paint()
      ..color = cartColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cartFillPaint = Paint()
      ..color = cartColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Basket
    final basketPath = Path()
      ..moveTo(-35, -20)
      ..lineTo(20, -20)
      ..lineTo(12, 15)
      ..lineTo(-25, 15)
      ..close();

    canvas.drawPath(basketPath, cartFillPaint);
    canvas.drawPath(basketPath, cartPaint);

    // Grid lines
    canvas.drawLine(const Offset(-31, -8), const Offset(17, -8), cartPaint..strokeWidth = 1.0);
    canvas.drawLine(const Offset(-28, 4), const Offset(14, 4), cartPaint..strokeWidth = 1.0);
    canvas.drawLine(const Offset(-20, -20), const Offset(-15, 15), cartPaint..strokeWidth = 1.0);
    canvas.drawLine(const Offset(-5, -20), const Offset(-5, 15), cartPaint..strokeWidth = 1.0);
    canvas.drawLine(const Offset(10, -20), const Offset(8, 15), cartPaint..strokeWidth = 1.0);

    cartPaint.strokeWidth = 2.0;

    // Handle
    final handlePath = Path()
      ..moveTo(-35, -20)
      ..lineTo(-45, -28)
      ..lineTo(-52, -28);
    canvas.drawPath(handlePath, cartPaint);

    final gripPaint = Paint()
      ..color = cartColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(-55, -31, -48, -25),
        const Radius.circular(2),
      ),
      gripPaint,
    );

    // Wheels supports
    canvas.drawLine(const Offset(-20, 15), const Offset(-20, 24), cartPaint);
    canvas.drawLine(const Offset(8, 15), const Offset(8, 24), cartPaint);

    // Wheels
    const double wheelRadius = 8.5;
    const wheelLeftCenter = Offset(-20, 24);
    const wheelRightCenter = Offset(8, 24);

    final wheelOutlinePaint = Paint()
      ..color = cartColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    
    final wheelInnerPaint = Paint()
      ..color = isDark ? Colors.grey.shade900 : Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(wheelLeftCenter, wheelRadius, wheelInnerPaint);
    canvas.drawCircle(wheelLeftCenter, wheelRadius, wheelOutlinePaint);
    canvas.drawCircle(wheelRightCenter, wheelRadius, wheelInnerPaint);
    canvas.drawCircle(wheelRightCenter, wheelRadius, wheelOutlinePaint);

    final double rotAngle = progress * 2 * math.pi;
    final spokePaint = Paint()
      ..color = cartColor
      ..strokeWidth = 1.2;

    for (int i = 0; i < 3; i++) {
      final double spAngle = rotAngle + (i * 2 * math.pi / 3);
      final spokeOffset = Offset(wheelRadius * math.cos(spAngle), wheelRadius * math.sin(spAngle));
      canvas.drawLine(wheelLeftCenter, wheelLeftCenter + spokeOffset, spokePaint);
      canvas.drawLine(wheelRightCenter, wheelRightCenter + spokeOffset, spokePaint);
    }

    canvas.restore();

    // Floating bubbles
    final rand = math.Random(999);
    for (int i = 0; i < 4; i++) {
      final double phase = (progress + (i / 4.0)) % 1.0;
      final double scale = 1.0 - phase;
      final double wx = (rand.nextDouble() - 0.5) * 40.0 + math.sin(progress * 2 * math.pi + i) * 6.0;
      final double wy = -20 - (phase * 60.0);

      final bubbleCenter = Offset(cx + wx, cy + bobY + wy);
      final double bubbleRadius = 2.0 + rand.nextDouble() * 3.5;

      final bubblePaint = Paint()
        ..color = cartColor.withValues(alpha: scale * 0.45)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      
      canvas.drawCircle(bubbleCenter, bubbleRadius, bubblePaint);
    }
  }

  @override
  bool shouldRepaint(_CartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.isDark != isDark;
  }
}
