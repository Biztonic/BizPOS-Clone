import 'package:flutter/material.dart';
import '../../tokens/app_spacing.dart';
import '../atoms/app_button.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final String? primaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final bool isDestructive;
  final IconData? icon;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.primaryButtonText,
    this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.isDestructive = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 48,
                color: isDestructive ? Theme.of(context).colorScheme.error : Theme.of(context).primaryColor,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              title,
              textAlign: icon != null ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
              child: content,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (secondaryButtonText != null) ...[
                  Expanded(
                    child: AppButton.outline(
                      label: secondaryButtonText!,
                      onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                if (primaryButtonText != null)
                  Expanded(
                    child: isDestructive 
                        ? AppButton.danger(
                            label: primaryButtonText!,
                            onPressed: onPrimaryPressed,
                          )
                        : AppButton.primary(
                            label: primaryButtonText!,
                            onPressed: onPrimaryPressed,
                          ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String? primaryButtonText,
    VoidCallback? onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    bool isDestructive = false,
    IconData? icon,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AppDialog(
          title: title,
          content: content,
          primaryButtonText: primaryButtonText,
          onPrimaryPressed: onPrimaryPressed,
          secondaryButtonText: secondaryButtonText,
          onSecondaryPressed: onSecondaryPressed,
          isDestructive: isDestructive,
          icon: icon,
        );
      },
    );
  }
}
