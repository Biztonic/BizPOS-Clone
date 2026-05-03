import 'package:flutter/material.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class BarcodeScannerSettingsScreen extends StatefulWidget {
  const BarcodeScannerSettingsScreen({super.key});

  @override
  State<BarcodeScannerSettingsScreen> createState() => _BarcodeScannerSettingsScreenState();
}

class _BarcodeScannerSettingsScreenState extends State<BarcodeScannerSettingsScreen> {
  bool _autoEnter = true;
  String _prefix = "";
  String _suffix = "";

  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);

    return PosScaffold(
      title: "Barcode Scanners",
      mainContent: ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
        children: [
          Text("Scanner Behavior", style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text("Auto Enter", style: AppTypography.bodyLarge),
              subtitle: const Text("Automatically submit after scan", style: AppTypography.bodySmall),
              activeColor: Theme.of(context).colorScheme.primary,
              value: _autoEnter,
              onChanged: (val) => setState(() => _autoEnter = val),
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          Text("Prefix & Suffix", style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Configure special scanner characters",
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        labelText: "Prefix",
                        hintText: "Enter prefix",
                        onChanged: (val) => _prefix = val,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        labelText: "Suffix",
                        hintText: "Enter suffix",
                        onChanged: (val) => _suffix = val,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  "Connect your scanner via USB or Bluetooth. It will work as a keyboard input.",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

