import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/dashboard_provider.dart';
import 'package:biztonic_pos/screens/dashboard_screen.dart';
import 'package:biztonic_pos/screens/dashboard_theme/car_dashboard_shell.dart';
import 'package:biztonic_pos/utils/theme.dart';
import 'package:biztonic_pos/utils/responsive.dart';

class UniversalShell extends StatelessWidget {
  final Widget child;

  const UniversalShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Optimization: Listen only to uiStyle changes
    final uiStyle = context.select<DashboardProvider, UIStyle>((p) => p.uiStyle);
    final isMobile = Responsive.isMobile(context);

    if (uiStyle == UIStyle.car_dashboard && !isMobile) {
      return CarDashboardShell(child: child);
    }

    return DashboardScreen(child: child);
  }
}
