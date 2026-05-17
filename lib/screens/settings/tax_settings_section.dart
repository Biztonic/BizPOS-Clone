import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/store/providers/store_notifier.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class TaxSettingsSection extends ConsumerStatefulWidget {
  final bool isSubView;
  const TaxSettingsSection({super.key, this.isSubView = false});
  @override
  ConsumerState<TaxSettingsSection> createState() => _TaxSettingsSectionState();
}

class _TaxSettingsSectionState extends ConsumerState<TaxSettingsSection> {
  final _taxController = TextEditingController();
  bool _isTaxEnabled = false;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final store = ref.read(storeNotifierProvider).activeStore;
      if (store != null) {
        _taxController.text = (store.taxRate ?? 0).toString();
        _isTaxEnabled = store.isTaxEnabled;
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(storeNotifierProvider);
    final store = storeState.activeStore;
    if (store == null) return const Center(child: CircularProgressIndicator());
    

    final content = ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text(AppLocalizations.t(context, 'Enable Tax Calculation'), style: AppTypography.titleSmall),
                    subtitle: Text(AppLocalizations.t(context, 'Apply tax calculated on bill subtotal'), 
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
                      await ref.read(storeNotifierProvider.notifier).updateStoreSettings(updatedStore);
                      if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text(AppLocalizations.t(context, 'Tax Settings Saved')), behavior: SnackBarBehavior.floating)
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
      );

    if (widget.isSubView) return content;

    return PosScaffold(
      title: "Tax Settings",
      showSidebar: false,
      mainContent: content,
    );
  }
}
