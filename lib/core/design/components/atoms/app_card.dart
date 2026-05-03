import 'package:flutter/material.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool outlined;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.backgroundColor,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderLg,
        child: content,
      );
    }

    if (outlined) {
      return Card(
        elevation: 0,
        color: backgroundColor ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderLg,
          side: BorderSide(color: theme.dividerColor, width: 1),
        ),
        margin: EdgeInsets.zero,
        child: content,
      );
    }

    return Card(
      color: backgroundColor ?? theme.cardTheme.color,
      margin: EdgeInsets.zero,
      child: content,
    );
  }
}
