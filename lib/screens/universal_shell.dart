import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/screens/dashboard_screen.dart';
import 'package:biztonic_pos/screens/dashboard_theme/car_dashboard_shell.dart';
import 'package:biztonic_pos/utils/theme.dart';
import 'package:biztonic_pos/utils/responsive.dart';
import 'package:biztonic_pos/services/offline_service.dart';

class UniversalShell extends StatefulWidget {
  final Widget child;

  const UniversalShell({super.key, required this.child});

  @override
  State<UniversalShell> createState() => _UniversalShellState();
}

class _UniversalShellState extends State<UniversalShell> {
  Timer? _inactivityTimer;
  final FocusNode _focusNode = FocusNode();

  // Inactivity timeout duration: 5 minutes
  static const _inactivityDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    if (OfflineService.isTesting) return;
    _inactivityTimer = Timer(_inactivityDuration, _lockStation);
  }

  void _lockStation() {
    try {
      final router = GoRouter.of(context);
      final currentPath = router.routeInformationProvider.value.uri.path;
      
      if (currentPath != '/admin/lock' && 
          currentPath != '/login' && 
          currentPath != '/splash' && 
          currentPath != '/set-password') {
        debugPrint('🕒 Auto-Lock: User inactive for 5 minutes. Locking station.');
        router.go('/admin/lock');
      }
    } catch (e) {
      debugPrint('⚠️ Auto-Lock: Failed to lock station: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiStyle = context.select<DashboardProvider, UIStyle>((p) => p.uiStyle);
    final isMobile = Responsive.isMobile(context);

    Widget shellChild;
    if (uiStyle == UIStyle.car_dashboard && !isMobile) {
      shellChild = CarDashboardShell(child: widget.child);
    } else {
      shellChild = DashboardScreen(child: widget.child);
    }

    // Intercept user interactions (clicks, taps, scroll, keyboard) to reset inactivity timer
    return Listener(
      onPointerDown: (_) => _resetTimer(),
      onPointerHover: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerSignal: (_) => _resetTimer(),
      child: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: (_) => _resetTimer(),
        child: shellChild,
      ),
    );
  }
}
