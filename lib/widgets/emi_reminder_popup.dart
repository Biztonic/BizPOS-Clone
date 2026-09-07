import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_typography.dart';
import 'package:biztonic_pos/models/store_hardware.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EmiReminderPopup extends StatelessWidget {
  final StoreHardware hardware;
  final int daysOverdue;

  const EmiReminderPopup({
    super.key,
    required this.hardware,
    required this.daysOverdue,
  });

  @override
  Widget build(BuildContext context) {
    bool isOverdue = daysOverdue > 0;
    bool isDueToday = daysOverdue == 0;
    
    String title = "EMI Reminder";
    Color headerColor = AppColors.primary;
    
    if (isOverdue) {
      title = "⚠ EMI Payment Overdue";
      headerColor = AppColors.error;
    } else if (isDueToday) {
      title = "EMI Due Today";
      headerColor = AppColors.warning;
    }

    String message = isOverdue
        ? "Your hardware EMI is overdue by $daysOverdue days.\n\nPlease pay the outstanding EMI amount of ₹${hardware.remainingAmount / (hardware.totalEmis - hardware.emisPaid)} immediately."
        : "Your upcoming EMI of ₹${hardware.remainingAmount / (hardware.totalEmis - hardware.emisPaid)} is due on ${DateFormat('dd MMM yyyy').format(hardware.nextEmiDueDate)}.";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOverdue ? Icons.warning_amber_rounded : Icons.info_outline,
                  color: headerColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleLarge.copyWith(color: headerColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isOverdue)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Dismiss"),
                  ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to EMI payment screen
                    context.push('/settings/emi_payment', extra: hardware);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surfaceLight,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text("Proceed to Pay"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
