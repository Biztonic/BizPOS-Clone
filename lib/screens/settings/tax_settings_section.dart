import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class TaxSettingsSection extends StatefulWidget {
  const TaxSettingsSection({super.key});
  @override
  State<TaxSettingsSection> createState() => _TaxSettingsSectionState();
}

class _TaxSettingsSectionState extends State<TaxSettingsSection> {
  final _taxController = TextEditingController();
  bool _isTaxEnabled = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final store = Provider.of<DashboardProvider>(context).activeStore;
      if (store != null) {
        _taxController.text = (store.taxRate ?? 0).toString();
        _isTaxEnabled = store.isTaxEnabled ?? false;
      }
      _isInit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final store = provider.activeStore;
    if (store == null) return const SizedBox();
    final density = AppDensityProvider.configOf(context);

    return PosScaffold(
      title: "Tax Settings",
      mainContent: ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Enable Tax Calculation', style: AppTypography.titleSmall),
                    subtitle: Text('Apply tax calculated on bill subtotal', 
                      style: AppTypography.bodySmall.copyWith(color: Theme.of(context).disabledColor)),
                    value: _isTaxEnabled,
                    onChanged: (val) => setState(() => _isTaxEnabled = val),
                    contentPadding: EdgeInsets.zero,
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  if (_isTaxEnabled) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _taxController,
                      labelText: 'Tax Rate (%)',
                      hintText: 'Enter percentage',
                      prefixIcon: const Icon(Icons.percent_outlined),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: "Save Changes",
                    onPressed: () async {
                      final double tax = double.tryParse(_taxController.text) ?? 0.0;
                      final updatedStore = store.copyWith(
                        taxRate: tax,
                        isTaxEnabled: _isTaxEnabled,
                      );
                      await provider.updateStoreSettings(updatedStore);
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text("Tax Settings Saved"), behavior: SnackBarBehavior.floating)
                         );
                         Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
