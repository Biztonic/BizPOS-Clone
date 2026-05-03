import 'package:flutter/material.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_typography.dart';

class SubscriptionReminderDialog extends StatelessWidget {
  final int daysRemaining;
  final VoidCallback onUpgrade;

  const SubscriptionReminderDialog({
    super.key,
    required this.daysRemaining,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
          SizedBox(width: 12),
          Text("Subscription Expiring"),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            daysRemaining <= 0 
              ? "Your Standard subscription has expired."
              : "Your Standard subscription is expiring in $daysRemaining days.",
            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            "Renew now to continue enjoying unlimited features, cloud sync, and priority support without any interruption.",
            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("LATER"),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onUpgrade();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warning,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("RENEW / PURCHASE"),
        ),
      ],
    );
  }
}
