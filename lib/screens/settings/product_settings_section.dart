import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/store_provider.dart';
import 'manage_string_list_screen.dart';
import '../../widgets/feature_guard.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/tokens/app_colors.dart';

class ProductSettingsSection extends StatefulWidget {
  const ProductSettingsSection({super.key});
  @override
  State<ProductSettingsSection> createState() => _ProductSettingsSectionState();
}

class _ProductSettingsSectionState extends State<ProductSettingsSection> {
  bool _trackInventory = true;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final store = Provider.of<DashboardProvider>(context).activeStore;
      if (store != null) {
        _trackInventory = store.trackInventory;
      }
      _isInit = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final density = AppDensityProvider.configOf(context);
    final store = provider.activeStore;
    if (store == null) return const SizedBox();

    return FutureBuilder<Map<String, dynamic>>(
      future: storeProvider.fetchStoreTypeConfigs(),
      builder: (context, snapshot) {
        final configs = snapshot.data ?? {};
        final currentType = store.storeType;
        final config = configs[currentType] as Map<String, dynamic>? ?? {};
        final showDietary = config['enableDietary'] == true;
        final showPackaging = config['enablePackaging'] == true;
        final showVariants = config['enableVariants'] == true;
        const showUnits = true;

        return PosScaffold(
          title: "Product Settings",
          mainContent: ListView(
            padding: EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('Inventory Tracking', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: EdgeInsets.zero,
                child: FeatureGuard(
                  featureKey: 'settings.products.inventory',
                  lockedChild: Opacity(
                    opacity: 0.5, 
                    child: IgnorePointer(
                      child: SwitchListTile(
                        title: const Text('Track Inventory Stock', style: AppTypography.bodyLarge), 
                        value: _trackInventory, 
                        onChanged: (v){}
                      )
                    )
                  ), 
                  child: SwitchListTile(
                    title: const Text('Track Inventory Stock', style: AppTypography.bodyLarge),
                    subtitle: const Text('Prevent sales when stock is unavailable', style: AppTypography.bodySmall),
                    value: _trackInventory,
                    onChanged: (val) async {
                       setState(() => _trackInventory = val);
                       final updatedStore = store.copyWith(trackInventory: val);
                       await provider.updateStoreSettings(updatedStore);
                    },
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              Text("Catalog Metadata", style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.md),
              
              if (showUnits)
                FeatureGuard(
                   featureKey: 'settings.products.units',
                   lockedChild: const SizedBox.shrink(),
                   child: _buildConfigTile(context, "Manage Units", Icons.scale, "product_units", "e.g. kg, pcs, ltr")
                ),
              if (showUnits) const SizedBox(height: AppSpacing.sm),

              if (showDietary)
               FeatureGuard(
                  featureKey: 'settings.products.dietary',
                  lockedChild: const SizedBox.shrink(),
                  child: _buildConfigTile(context, "Dietary Types", Icons.restaurant_menu, "dietary_types", "e.g. Veg, Non-Veg, Vegan")
               ),
               if (showDietary) const SizedBox(height: AppSpacing.sm),
               
               if (showPackaging)
               FeatureGuard(
                  featureKey: 'settings.products.packaging',
                  lockedChild: const SizedBox.shrink(),
                  child: _buildConfigTile(context, "Packaging Types", Icons.inventory_2_outlined, "packaging_types", "e.g. Box, Pouch, Bottle")
               ),
              if (showPackaging) const SizedBox(height: AppSpacing.sm),

              if (showVariants)
              FeatureGuard(
                 featureKey: 'settings.products.variants',
                 lockedChild: const SizedBox.shrink(),
                 child: _buildConfigTile(context, "Product Categories", Icons.category, "variant_types", "e.g. Snacks, Drinks, Retail")
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildConfigTile(BuildContext context, String title, IconData icon, String key, String hint) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: AppTypography.bodyLarge),
        subtitle: Text(hint, style: AppTypography.bodySmall),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageStringListScreen(
           title: title,
           metadataKey: key,
           hintText: hint,
        ))),
      ),
    );
  }
}
