import 'package:flutter/material.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class SupplierSettingsSection extends StatefulWidget {
  final bool isSubView;
  const SupplierSettingsSection({super.key, this.isSubView = false});

  @override
  State<SupplierSettingsSection> createState() =>
      _SupplierSettingsSectionState();
}

class _SupplierSettingsSectionState extends State<SupplierSettingsSection> {
  bool _enableAutoPO = false;
  bool _enableSupplierKhata = true;
  final TextEditingController _poPrefixController =
      TextEditingController(text: "PO-");
  final TextEditingController _defaultCreditDaysController =
      TextEditingController(text: "30");

  @override
  void dispose() {
    _poPrefixController.dispose();
    _defaultCreditDaysController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text("Supplier & Purchase Settings saved successfully!"),
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
                Icons.local_shipping_rounded,
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
                    "Supplier & Purchase Settings",
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Manage vendor credit periods, purchase order numbering, and restocking thresholds.",
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
                title: Text("Vendor Ledger & Payables Tracking",
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Maintain payables ledger for goods purchased on credit from vendors.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _enableSupplierKhata,
                onChanged: (v) => setState(() => _enableSupplierKhata = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 20),
              SwitchListTile(
                title: const Text("Automatic Purchase Order on Low Stock"),
                subtitle: Text(
                  "Draft purchase order automatically when inventory reaches reorder point.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _enableAutoPO,
                onChanged: (v) => setState(() => _enableAutoPO = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _poPrefixController,
                      labelText: "Purchase Order Prefix",
                      hintText: "PO-",
                      prefixIcon: const Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _defaultCreditDaysController,
                      labelText: "Default Credit Terms (Days)",
                      hintText: "30",
                      prefixIcon: const Icon(Icons.calendar_today),
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
          label: "Save Supplier Settings",
          icon: Icons.save_rounded,
          onPressed: _saveSettings,
          width: double.infinity,
        ),
      ],
    );

    if (widget.isSubView) return content;

    return PosScaffold(
      title: "Supplier & Purchase Settings",
      showSidebar: false,
      mainContent: content,
    );
  }
}
