import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import '../../models/settings.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/tokens/app_colors.dart';

class KdsSettingsScreen extends StatefulWidget {
  const KdsSettingsScreen({super.key});

  @override
  State<KdsSettingsScreen> createState() => _KdsSettingsScreenState();
}

class _KdsSettingsScreenState extends State<KdsSettingsScreen> {
  bool _soundEnabled = true;
  double _fontSize = 16.0;
  String _layout = 'Grid';
  List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<StoreProvider>(context, listen: false).storeSettings?.kds;
    if (settings != null) {
      _soundEnabled = settings.soundEnabled;
      _fontSize = settings.fontSize;
      _layout = settings.layout;
      _selectedCategories = List.from(settings.categoryFilters);
    }
  }

  void _save() async {
    final provider = Provider.of<StoreProvider>(context, listen: false);
    final currentSettings = provider.storeSettings;
    if (currentSettings == null) return;

    final newKdsSettings = KdsSettings(
      soundEnabled: _soundEnabled,
      fontSize: _fontSize,
      layout: _layout,
      categoryFilters: _selectedCategories,
    );

    final newSettings = StoreSettings(
      id: currentSettings.id,
      storeName: currentSettings.storeName,
      address: currentSettings.address,
      phone: currentSettings.phone,
      logoUrl: currentSettings.logoUrl,
      receipt: currentSettings.receipt,
      modules: currentSettings.modules,
      dashboard: currentSettings.dashboard,
      syncSettings: currentSettings.syncSettings,
      counters: currentSettings.counters,
      kds: newKdsSettings,
      payment: currentSettings.payment,
    );

    try {
      await provider.updateSettingsConfig(newSettings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t(context, 'KDS Settings Saved'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    

    return PosScaffold(
      title: "KDS Settings",
      mainContent: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(AppLocalizations.t(context, 'Interface Options'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(AppLocalizations.t(context, 'Sound Notifications'), style: AppTypography.bodyLarge),
                  subtitle: Text(AppLocalizations.t(context, 'Play sound when a new order arrives'), style: AppTypography.bodySmall),
                  value: _soundEnabled,
                  onChanged: (v) => setState(() => _soundEnabled = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                ListTile(
                  title: Text(AppLocalizations.t(context, 'Font Size'), style: AppTypography.bodyLarge),
                  subtitle: Text("${_fontSize.toInt()} px", style: AppTypography.bodySmall),
                  contentPadding: EdgeInsets.zero,
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      min: 12,
                      max: 32,
                      divisions: 10,
                      value: _fontSize,
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  title: Text(AppLocalizations.t(context, 'Layout Style'), style: AppTypography.bodyLarge),
                  contentPadding: EdgeInsets.zero,
                  trailing: DropdownButton<String>(
                    value: _layout,
                    style: AppTypography.bodyMedium,
                    items: ['Grid', 'List'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _layout = v!),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          Text(AppLocalizations.t(context, 'Filter Categories'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.xs),
          Text(AppLocalizations.t(context, 'Only show orders containing items from these categories:'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
          const SizedBox(height: AppSpacing.md),
          _buildCategoryFilters(),

          const SizedBox(height: AppSpacing.xxl),
          AppButton.primary(
            label: "Save Settings",
            onPressed: _save,
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final categories = ['Kitchen', 'Pizza', 'Drinks', 'Dessert']; 
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        final isSelected = _selectedCategories.contains(cat);
        return FilterChip(
          label: Text(cat, style: AppTypography.bodySmall),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedCategories.add(cat);
              } else {
                _selectedCategories.remove(cat);
              }
            });
          },
        );
      }).toList(),
    );
  }
}
