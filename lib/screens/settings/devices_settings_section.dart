import 'package:flutter/material.dart';
import '../printer_screen.dart';
import 'barcode_scanner_settings_screen.dart';
import 'display_hardware_settings_screen.dart';
import '../../widgets/feature_guard.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/tokens/app_colors.dart';

class DevicesSettingsSection extends StatelessWidget {
  const DevicesSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // efficient way to handle sub-navigation within the settings panel
    return Navigator(
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const DevicesMenuScreen(),
        );
      },
    );
  }
}

class DevicesMenuScreen extends StatelessWidget {
  const DevicesMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);

    return PosScaffold(
      title: "Connected Devices",
      mainContent: ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
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
      ),
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
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        onTap: () {
          if (destination != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => destination),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Coming Soon"),
                duration: Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
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
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

