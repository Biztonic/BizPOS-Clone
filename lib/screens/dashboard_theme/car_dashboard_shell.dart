// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart'; // Import for HardwareKeyboard
// Import for PointerScrollEvent
import 'package:biztonic_pos/utils/car_dashboard_theme.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/screens/dashboard_theme/widgets/slide_up_menu_bar.dart';

class CarDashboardShell extends StatefulWidget {
  final Widget child;

  const CarDashboardShell({super.key, required this.child});

  @override
  State<CarDashboardShell> createState() => _CarDashboardShellState();
}

class _CarDashboardShellState extends State<CarDashboardShell> with SingleTickerProviderStateMixin {
  bool _isMenuVisible = false;
  bool _atBottom = true; // Default to true (assumes static page unless told otherwise)
  final FocusNode _focusNode = FocusNode();
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _bounceController.dispose();
    super.dispose();
  }
  
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
       final bool isBottom = notification.metrics.pixels >= (notification.metrics.maxScrollExtent - 1.0); // 1px tolerance
       if (isBottom != _atBottom) {
         if (mounted) setState(() => _atBottom = isBottom);
       }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<DashboardProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: CarDashboardTheme.backgroundColor(isDarkMode),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Tablets in portrait (width >= 600) are now supported — many restaurants mount tablets in portrait
          // Only block very narrow non-standard aspect ratios (practically never happens)
          

          return RawKeyboardListener(
            focusNode: _focusNode,
            autofocus: true, 
            onKey: _handleKeyEvent,
            child: Stack(
                children: [
                   // 1. Global Background Mesh & Background Gesture Detector
                     Positioned.fill(
                       child: Container(
                         decoration: BoxDecoration(
                           gradient: isDarkMode 
                               ? RadialGradient(
                                   center: Alignment.center,
                                   radius: 1.2,
                                   colors: [
                                     const Color(0xFF0F2035),
                                     CarDashboardTheme.backgroundColor(isDarkMode),
                                   ],
                                 )
                               : const LinearGradient(
                                   begin: Alignment.topLeft,
                                   end: Alignment.bottomRight,
                                   colors: [
                                     Color(0xFFF8FAFC), // Slate 50
                                     Color(0xFFE0F2FE), // Sky 100 (Subtle Blue Tint)
                                   ]
                                 ),
                         ),
                       ),
                     ),
                   
                   // 2. Main Content Area (Foreground Layer)
                   Positioned.fill(
                     bottom: 0, 
                     child: NotificationListener<ScrollNotification>(
                       onNotification: _handleScrollNotification,
                       child: widget.child
                     ),
                   ),

                   // 4b. Actual Handle Widget (Moves with menu) - HIDE IF POS
                   if (!GoRouterState.of(context).uri.toString().contains('/pos'))
                     AnimatedPositioned(
                       duration: const Duration(milliseconds: 400),
                       curve: Curves.easeOutCubic,
                       bottom: _isMenuVisible ? 220 : 0, 
                       left: 0, 
                       right: 0,
                       height: 60, // Increased height for better touch
                       child: Center(
                           child: GestureDetector(
                             onTap: () => setState(() => _isMenuVisible = !_isMenuVisible),
                             behavior: HitTestBehavior.translucent,
                             child: Container(
                               width: 300, // Much wider touch area
                               height: 60, // Taller touch area
                               color: Colors.transparent, // Ensure hit test works
                               alignment: Alignment.center,
                               child: AnimatedBuilder(
                                 animation: _bounceController,
                                 builder: (context, child) {
                                   return Transform.translate(
                                     offset: Offset(0, _isMenuVisible ? 0 : -10 + (_bounceController.value * 10)), // Bounce UP when closed
                                     child: child,
                                   );
                                 },
                                 child: Icon(
                                    _isMenuVisible ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, 
                                    color: isDarkMode ? Colors.white : const Color(0xFF0D47A1), // White (Dark Mode) vs Dark Blue (Light Mode)
                                    size: 40, // Larger Icon
                                 ),
                               ),
                             ),
                           ),
                       ),
                     ),

                   // 5. Slide Up Menu Bar (Overlay) - HIDE IF POS
                   if (!GoRouterState.of(context).uri.toString().contains('/pos'))
                     AnimatedPositioned(
                       duration: const Duration(milliseconds: 400),
                       curve: Curves.easeOutCubic,
                       left: 0,
                       right: 0,
                       bottom: _isMenuVisible ? 0 : -250, 
                       height: 220, 
                       child: SlideUpMenuBar(
                         onClose: () => setState(() => _isMenuVisible = false),
                       ),
                     ),
                ],
              ),

          );
        },
      ),
    );
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (!_isMenuVisible) setState(() => _isMenuVisible = true);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isMenuVisible) setState(() => _isMenuVisible = false);
      }
    }
  }

}
