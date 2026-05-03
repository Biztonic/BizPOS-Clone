import 'package:flutter/material.dart';

enum PosLayoutType { mobile, tablet, desktop }

/// A foundational layout structure specifically designed for POS interactions.
/// Unlike traditional app scaffolds that just scale down, this explicitly changes
/// the structure of the UI based on device type.
class PosScaffold extends StatelessWidget {
  final Widget? leftPanel; // Categories / Nav
  final Widget mainContent; // Products / Core
  final Widget? rightPanel; // Cart / Order Summary
  final Widget? bottomBar; // Mobile Action Bar
  final PreferredSizeWidget? appBar; // Mobile App Bar
  final Widget? drawer; // Mobile Drawer
  
  const PosScaffold({
    super.key,
    this.leftPanel,
    required this.mainContent,
    this.rightPanel,
    this.bottomBar,
    this.appBar,
    this.drawer,
  });

  PosLayoutType _getLayoutType(BoxConstraints constraints) {
    if (constraints.maxWidth < 600) return PosLayoutType.mobile;
    if (constraints.maxWidth < 1100) return PosLayoutType.tablet;
    return PosLayoutType.desktop;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutType = _getLayoutType(constraints);
        
        switch (layoutType) {
          case PosLayoutType.mobile:
            return Scaffold(
              appBar: appBar,
              drawer: drawer,
              body: mainContent,
              bottomNavigationBar: bottomBar,
              // Mobile relies heavily on modals/bottom sheets for Cart
            );
          
          case PosLayoutType.tablet:
            return Scaffold(
              appBar: appBar,
              drawer: drawer,
              body: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: mainContent,
                  ),
                  if (rightPanel != null) ...[
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 4,
                      child: rightPanel!,
                    ),
                  ],
                ],
              ),
            );

          case PosLayoutType.desktop:
            return Scaffold(
              body: Row(
                children: [
                  if (leftPanel != null) ...[
                    SizedBox(width: 250, child: leftPanel),
                    const VerticalDivider(width: 1),
                  ],
                  Expanded(
                    flex: 6,
                    child: mainContent,
                  ),
                  if (rightPanel != null) ...[
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 4,
                      child: rightPanel!,
                    ),
                  ],
                ],
              ),
            );
        }
      },
    );
  }
}
