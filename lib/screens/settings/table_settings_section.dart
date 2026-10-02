import 'package:flutter/material.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class TableSettingsSection extends StatefulWidget {
  final bool isSubView;
  const TableSettingsSection({super.key, this.isSubView = false});

  @override
  State<TableSettingsSection> createState() => _TableSettingsSectionState();
}

class _TableSettingsSectionState extends State<TableSettingsSection> {
  bool _enableReservations = true;
  bool _autoReleaseUnclaimed = true;
  final TextEditingController _releaseHoldMinsController =
      TextEditingController(text: "15");
  final TextEditingController _defaultSeatingCapacityController =
      TextEditingController(text: "4");
  bool _enableServiceCharge = false;
  final TextEditingController _serviceChargePercentController =
      TextEditingController(text: "5");

  @override
  void dispose() {
    _releaseHoldMinsController.dispose();
    _defaultSeatingCapacityController.dispose();
    _serviceChargePercentController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text("Table & Dining Settings saved successfully!"),
          ],
        ),
        backgroundColor: AppColors.adaptiveSuccess(context),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.table_restaurant_rounded,
                color: AppColors.adaptivePrimary(context),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Table & Dining Area Settings",
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Manage table reservations, hold timers, and dining service policies.",
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: Text("Enable Advance Table Reservations",
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Allow reservations to be booked ahead of time and shown in POS floor view.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _enableReservations,
                onChanged: (v) => setState(() => _enableReservations = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 20),
              SwitchListTile(
                title: const Text("Auto-Release Unclaimed Tables"),
                subtitle: Text(
                  "Automatically free reserved tables if guests do not arrive within the grace period.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _autoReleaseUnclaimed,
                onChanged: (v) => setState(() => _autoReleaseUnclaimed = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_autoReleaseUnclaimed) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _releaseHoldMinsController,
                  labelText: "Grace Period Before Auto-Release (Minutes)",
                  hintText: "15",
                  prefixIcon: const Icon(Icons.timer_outlined),
                  keyboardType: TextInputType.number,
                ),
              ],
              const Divider(height: 24),
              AppTextField(
                controller: _defaultSeatingCapacityController,
                labelText: "Default Seating Capacity per Table",
                hintText: "4",
                prefixIcon: const Icon(Icons.people_outline),
                keyboardType: TextInputType.number,
              ),
              const Divider(height: 24),
              SwitchListTile(
                title: const Text("Apply Dine-In Service Charge"),
                subtitle: Text(
                  "Automatically append service charge to Dine-In table bills.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _enableServiceCharge,
                onChanged: (v) => setState(() => _enableServiceCharge = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_enableServiceCharge) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _serviceChargePercentController,
                  labelText: "Service Charge Percentage (%)",
                  hintText: "5",
                  prefixIcon: const Icon(Icons.percent_rounded),
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: "Save Table Settings",
          icon: Icons.save_rounded,
          onPressed: _saveSettings,
          width: double.infinity,
        ),
      ],
    );

    if (widget.isSubView) return content;

    return PosScaffold(
      title: "Table & Dining Settings",
      showSidebar: false,
      mainContent: content,
    );
  }
}
