import 'package:flutter/material.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class FranchiseSettingsSection extends StatefulWidget {
  final bool isSubView;
  const FranchiseSettingsSection({super.key, this.isSubView = false});

  @override
  State<FranchiseSettingsSection> createState() =>
      _FranchiseSettingsSectionState();
}

class _FranchiseSettingsSectionState extends State<FranchiseSettingsSection> {
  bool _centralCatalogControl = true;
  bool _crossStoreInventoryTransfer = true;
  bool _unifiedCustomerKhata = true;
  final TextEditingController _royaltyFeePercentController =
      TextEditingController(text: "3.5");
  final TextEditingController _hqShortCodeController =
      TextEditingController(text: "HQ01");

  @override
  void dispose() {
    _royaltyFeePercentController.dispose();
    _hqShortCodeController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text("Franchise & Multi-Store Settings saved successfully!"),
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
                Icons.business_rounded,
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
                    "Franchise & Multi-Store Settings",
                    style: AppTypography.titleLarge
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Configure store network hierarchy, central product catalog control, and royalties.",
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
                title: Text("Centralized Product Catalog Control",
                    style: AppTypography.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  "Child stores inherit prices, taxes, and menu categories from HQ. Individual branches cannot modify base prices.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _centralCatalogControl,
                onChanged: (v) => setState(() => _centralCatalogControl = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 20),
              SwitchListTile(
                title: const Text("Allow Cross-Store Stock Transfers"),
                subtitle: Text(
                  "Permit branches to dispatch inventory items to other stores within the franchise network.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _crossStoreInventoryTransfer,
                onChanged: (v) =>
                    setState(() => _crossStoreInventoryTransfer = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 20),
              SwitchListTile(
                title: const Text("Unified Customer & Khata Across Stores"),
                subtitle: Text(
                  "Customers can redeem loyalty points and view their Udhari balance at any franchise location.",
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                value: _unifiedCustomerKhata,
                onChanged: (v) => setState(() => _unifiedCustomerKhata = v),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _hqShortCodeController,
                      labelText: "Franchise HQ Code",
                      hintText: "HQ01",
                      prefixIcon: const Icon(Icons.qr_code),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _royaltyFeePercentController,
                      labelText: "Franchise Royalty Share (%)",
                      hintText: "3.5",
                      prefixIcon: const Icon(Icons.percent_rounded),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: "Save Franchise Settings",
          icon: Icons.save_rounded,
          onPressed: _saveSettings,
          width: double.infinity,
        ),
      ],
    );

    if (widget.isSubView) return content;

    return PosScaffold(
      title: "Franchise & Multi-Store Settings",
      showSidebar: false,
      mainContent: content,
    );
  }
}
