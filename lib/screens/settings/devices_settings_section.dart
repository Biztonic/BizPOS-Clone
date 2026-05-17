import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import '../printer_screen.dart';
import 'barcode_scanner_settings_screen.dart';
import 'display_hardware_settings_screen.dart';
import '../../widgets/feature_guard.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_radius.dart';
import '../../core/design/tokens/app_iconography.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/tokens/app_colors.dart';

class DevicesSettingsSection extends StatelessWidget {
  final bool isSubView;
  const DevicesSettingsSection({super.key, this.isSubView = false});

  @override
  Widget build(BuildContext context) {
    

    final content = ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
          _buildDeviceItem(
            context,
            icon: Icons.print_outlined,
            title: "Printers",
            subtitle: "Manage Receipt, KDS, and Label Printers",
            color: AppColors.primary,
            destination: const PrinterScreen(),
          ),
          _buildDeviceItem(
            context,
            icon: Icons.qr_code_scanner_outlined,
            title: "Barcode Scanners",
            subtitle: "Configure external scanners and behavior",
            color: AppColors.success,
            destination: const BarcodeScannerSettingsScreen(),
          ),
          FeatureGuard(
            featureKey: 'kds_management',
            lockedChild: const SizedBox.shrink(),
            child: _buildDeviceItem(
              context,
              icon: Icons.monitor_outlined,
              title: "Displays",
              subtitle: "Customer facing displays and Kiosks",
              color: AppColors.warning,
              destination: const DisplayHardwareSettingsScreen(),
            ),
          ),
          _buildDeviceItem(
            context,
            icon: Icons.credit_card_outlined,
            title: "Card Terminals",
            subtitle: "Payment terminal integration settings",
            color: AppColors.primaryLight,
            destination: null, // Coming Soon
          ),
          _buildDeviceItem(
            context,
            icon: Icons.scale_outlined,
            title: "Scales",
            subtitle: "Digital weighing scale integration",
            color: AppColors.primary,
            destination: null, // Coming Soon
          ),
        ],
      );

    if (isSubView) return content;

    return PosScaffold(
      title: "Connected Devices",
      showSidebar: false,
      mainContent: content,
    );
  }

  Widget _buildDeviceItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget? destination,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () {
          if (destination != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => destination),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.t(context, 'Coming Soon')),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AppIconography.iconContainer(
                icon: icon,
                color: color,
                size: AppIconography.lg,
                containerSize: AppIconography.containerLg,
                borderRadius: AppRadius.md,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: AppIconography.md,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




