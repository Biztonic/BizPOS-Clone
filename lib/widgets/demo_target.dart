import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';

class DemoTarget extends StatefulWidget {
  final String step;
  final String instruction;
  final Widget child;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  const DemoTarget({
    super.key, 
    required this.step, 
    required this.instruction, 
    required this.child,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  @override
  State<DemoTarget> createState() => _DemoTargetState();
}

class _DemoTargetState extends State<DemoTarget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportLocation());
  }

  @override
  void didUpdateWidget(covariant DemoTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportLocation());
  }

  void _reportLocation() {
    if (!mounted) return;
    
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    if (!provider.isDemoMode) return;
    if (provider.demoStep != widget.step) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final position = box.localToGlobal(Offset.zero);
      final rect = position & box.size;
      provider.reportDemoTarget(widget.step, rect, widget.instruction);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We listen to step changes to trigger position reporting when this becomes active
    return Consumer<DashboardProvider>(
       builder: (context, provider, child) {
          if (provider.demoStep == widget.step) {
             WidgetsBinding.instance.addPostFrameCallback((_) => _reportLocation());
          }
          return widget.child;
       },
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final Color overlayColor;

  SpotlightPainter({required this.targetRect, this.overlayColor = const Color(0xAA000000)});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark Overlay (User clicked "Interactive Mode")
    // Keep overlay but make it less opaque or just focus on the red circle? 
    // User said "instead of highlight by rectangle use red spotlight circle"
    // AND "do not show any text for this is demo mode" (This might refer to banner, but spotlight text is needed for instruction).
    
    final Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Add 16px padding to target for the circle
    final center = targetRect.center;
    // Radius should encompass the rect
    final radius = (targetRect.longestSide / 2) + 24;
    
    final Path spotlightPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    // Subtract spotlight from background
    final Path overlayPath = Path.combine(PathOperation.difference, backgroundPath, spotlightPath);

    // Draw Dark Overlay
    canvas.drawPath(overlayPath, Paint()..color = const Color(0xAA000000));
    
    // Draw Red Spotlight Circle (Stroke)
    final paintStroke = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
      
    canvas.drawCircle(center, radius, paintStroke);
    
    // Optional: Inner Glow
    final paintGlow = Paint()
      ..color = Colors.red.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paintGlow);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
