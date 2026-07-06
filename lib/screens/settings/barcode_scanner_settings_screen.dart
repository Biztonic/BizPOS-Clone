import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:biztonic_pos/l10n/app_localizations.dart';

import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_radius.dart';
import '../../core/design/tokens/app_iconography.dart';
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
  bool _playSound = true;
  bool _vibrateOnScan = true;
  String _scanMode = 'Keyboard Wedge';
  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();
  final TextEditingController _testController = TextEditingController();

  @override
  void dispose() {
    _prefixController.dispose();
    _suffixController.dispose();
    _testController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PosScaffold(
      title: "Barcode Scanners",
      showSidebar: false,
      mainContent: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // --- Back Button ---
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(AppLocalizations.t(context, 'Back to Devices')),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // --- Connected Scanners Section ---
          Text(AppLocalizations.t(context, 'Connected Scanners'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                _buildScannerDeviceRow(
                  context,
                  name: 'Default Keyboard Input',
                  type: 'Built-in',
                  connected: true,
                  icon: Icons.keyboard,
                ),
                if (!kIsWeb) ...[
                  const Divider(height: 1),
                  _buildScannerDeviceRow(
                    context,
                    name: 'USB Scanner',
                    type: 'HID Device',
                    connected: false,
                    icon: Icons.usb,
                  ),
                  const Divider(height: 1),
                  _buildScannerDeviceRow(
                    context,
                    name: 'Bluetooth Scanner',
                    type: 'BLE Device',
                    connected: false,
                    icon: Icons.bluetooth,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // --- Scan Mode ---
          Text(AppLocalizations.t(context, 'Scan Mode'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                RadioListTile<String>(
                  title: Text('Keyboard Wedge', style: AppTypography.bodyLarge),
                  subtitle: Text(AppLocalizations.t(context, 'Scanner sends keystrokes like a keyboard'), style: AppTypography.bodySmall),
                  value: 'Keyboard Wedge',
                  groupValue: _scanMode,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _scanMode = val!),
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: Text('Camera Scanner', style: AppTypography.bodyLarge),
                  subtitle: Text(AppLocalizations.t(context, 'Use device camera to scan barcodes'), style: AppTypography.bodySmall),
                  value: 'Camera',
                  groupValue: _scanMode,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _scanMode = val!),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // --- Scanner Behavior ---
          Text(AppLocalizations.t(context, 'Scanner Behavior'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(AppLocalizations.t(context, 'Auto Enter'), style: AppTypography.bodyLarge),
                  subtitle: Text(AppLocalizations.t(context, 'Automatically submit after scan'), style: AppTypography.bodySmall),
                  activeColor: AppColors.primary,
                  value: _autoEnter,
                  onChanged: (val) => setState(() => _autoEnter = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(AppLocalizations.t(context, 'Play Sound'), style: AppTypography.bodyLarge),
                  subtitle: Text(AppLocalizations.t(context, 'Beep sound on successful scan'), style: AppTypography.bodySmall),
                  activeColor: AppColors.primary,
                  value: _playSound,
                  onChanged: (val) => setState(() => _playSound = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(AppLocalizations.t(context, 'Vibrate on Scan'), style: AppTypography.bodyLarge),
                  subtitle: Text(AppLocalizations.t(context, 'Haptic feedback on scan (mobile only)'), style: AppTypography.bodySmall),
                  activeColor: AppColors.primary,
                  value: _vibrateOnScan,
                  onChanged: (val) => setState(() => _vibrateOnScan = val),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),

          // --- Prefix & Suffix ---
          Text(AppLocalizations.t(context, 'Prefix & Suffix'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'Configure special scanner characters'),
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _prefixController,
                        labelText: "Prefix",
                        hintText: "e.g. \\x02",
                        onChanged: (val) {},
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        controller: _suffixController,
                        labelText: "Suffix",
                        hintText: "e.g. \\x0D",
                        onChanged: (val) {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // --- Test Scanner ---
          Text(AppLocalizations.t(context, 'Test Scanner'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                AppTextField(
                  controller: _testController,
                  labelText: AppLocalizations.t(context, 'Scan a barcode here'),
                  hintText: AppLocalizations.t(context, 'Focus this field and scan...'),
                  onChanged: (val) {},
                ),
                const SizedBox(height: AppSpacing.md),
                if (_testController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Scanned: ${_testController.text}',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // --- Info Card ---
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
                Text(AppLocalizations.t(context, 'Connect your scanner via USB or Bluetooth. It will work as a keyboard input.'),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildScannerDeviceRow(
    BuildContext context, {
    required String name,
    required String type,
    required bool connected,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          AppIconography.iconContainer(
            icon: icon,
            color: connected ? AppColors.success : AppColors.textSecondary(context),
            size: AppIconography.md,
            containerSize: AppIconography.containerMd,
            borderRadius: AppRadius.sm,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                Text(type, style: AppTypography.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: connected
                  ? AppColors.success.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              connected ? 'Connected' : 'Not Connected',
              style: AppTypography.labelSmall.copyWith(
                color: connected ? AppColors.success : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
