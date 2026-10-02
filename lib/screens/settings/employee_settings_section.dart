import 'package:flutter/material.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class EmployeeSettingsSection extends StatefulWidget {
  final bool isSubView;
  const EmployeeSettingsSection({super.key, this.isSubView = false});

  @override
  State<EmployeeSettingsSection> createState() =>
      _EmployeeSettingsSectionState();
}

class _EmployeeSettingsSectionState extends State<EmployeeSettingsSection> {
  bool _requirePinForCheckout = false;
  bool _autoClockOutOnClose = true;
  bool _allowOvertimeLogging = true;
  final TextEditingController _maxShiftHoursController =
      TextEditingController(text: "9");
  final TextEditingController _pinLengthController =
      TextEditingController(text: "4");

  @override
  void dispose() {
    _maxShiftHoursController.dispose();
    _pinLengthController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text("Staff & Attendance Settings saved successfully!"),
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
                Icons.badge_rounded,
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
                    "Staff & Attendance Settings",
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Manage employee access PINs, shift durations, and auto-attendance policies.",
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
                title: Text("Require Employee PIN for Each Checkout",
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Cashiers must enter their personal 4-digit PIN before finishing each POS transaction.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _requirePinForCheckout,
                onChanged: (v) => setState(() => _requirePinForCheckout = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 20),
              SwitchListTile(
                title: const Text("Auto Clock-Out on Register Close"),
                subtitle: Text(
                  "Automatically clock out any active staff when the cash drawer / counter is closed.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _autoClockOutOnClose,
                onChanged: (v) => setState(() => _autoClockOutOnClose = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 20),
              SwitchListTile(
                title: const Text("Allow Overtime Logging"),
                subtitle: Text(
                  "Track and record hours worked beyond the daily standard shift limit.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _allowOvertimeLogging,
                onChanged: (v) => setState(() => _allowOvertimeLogging = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _maxShiftHoursController,
                      labelText: "Standard Shift Duration (Hours)",
                      hintText: "9",
                      prefixIcon: const Icon(Icons.schedule),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _pinLengthController,
                      labelText: "Staff PIN Length (Digits)",
                      hintText: "4",
                      prefixIcon: const Icon(Icons.pin),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: "Save Staff Settings",
          icon: Icons.save_rounded,
          onPressed: _saveSettings,
          width: double.infinity,
        ),
      ],
    );

    if (widget.isSubView) return content;

    return PosScaffold(
      title: "Staff & Attendance Settings",
      showSidebar: false,
      mainContent: content,
    );
  }
}
