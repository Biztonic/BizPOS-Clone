import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/store/providers/store_notifier.dart';
import '../../widgets/feature_guard.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_card.dart';

class ProductSettingsSection extends ConsumerStatefulWidget {
  final bool isSubView;
  const ProductSettingsSection({super.key, this.isSubView = false});
  @override
  ConsumerState<ProductSettingsSection> createState() => _ProductSettingsSectionState();
}

class _ProductSettingsSectionState extends ConsumerState<ProductSettingsSection> {
  bool _trackInventory = true;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final store = ref.read(storeNotifierProvider).activeStore;
      if (store != null) {
        _trackInventory = store.trackInventory;
      }
      _isInit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(storeNotifierProvider);
    final store = storeState.activeStore;
    if (store == null) return const Center(child: CircularProgressIndicator());

    final content = ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(AppLocalizations.t(context, 'Inventory Tracking'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          child: FeatureGuard(
            featureKey: 'settings.products.inventory',
            lockedChild: Opacity(
              opacity: 0.5, 
              child: IgnorePointer(
                child: SwitchListTile(
                  title: Text(AppLocalizations.t(context, 'Track Inventory Stock'), style: AppTypography.bodyLarge), 
                  value: _trackInventory, 
                  onChanged: (v){}
                )
              )
            ), 
            child: SwitchListTile(
              title: Text(AppLocalizations.t(context, 'Track Inventory Stock'), style: AppTypography.bodyLarge),
              subtitle: Text(AppLocalizations.t(context, 'Prevent sales when stock is unavailable'), style: AppTypography.bodySmall),
              value: _trackInventory,
              onChanged: (val) async {
                 setState(() => _trackInventory = val);
                 final updatedStore = store.copyWith(trackInventory: val);
                 await ref.read(storeNotifierProvider.notifier).updateStoreSettings(updatedStore);
              },
            ),
          ),
        ),
      ],
    );

    if (widget.isSubView) return content;

    return PosScaffold(
      title: "Product Settings",
      showSidebar: false,
      mainContent: content,
    );
  }
}

