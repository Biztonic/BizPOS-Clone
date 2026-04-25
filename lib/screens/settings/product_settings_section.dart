// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/store_provider.dart';
import 'manage_string_list_screen.dart';
import '../../widgets/feature_guard.dart';


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
    final store = provider.activeStore;
    if (store == null) return const SizedBox();

    return FutureBuilder<Map<String, dynamic>>(
      future: storeProvider.fetchStoreTypeConfigs(),
      builder: (context, snapshot) {
        final configs = snapshot.data ?? {};
        final currentType = store.storeType; // store model needs storeType or we fetch it
        // Note: Store model usually has 'storeType'. If not, we might fall back to just showing all or needing to fetch it.
        // Assuming store.storeType exists as per Store model.
        
        final config = configs[currentType] as Map<String, dynamic>? ?? {};
        final showDietary = config['enableDietary'] == true;
        final showPackaging = config['enablePackaging'] == true;
        final showVariants = config['enableVariants'] == true;
        const showUnits = true; // Always show units? Or maybe configurable too. Keeping true for now.

        return Scaffold(
          appBar: AppBar(title: const Text("Product Settings")),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
                  FeatureGuard(
                   featureKey: 'settings.products.inventory',
                   lockedChild: Opacity(opacity: 0.5, child: IgnorePointer(child: SwitchListTile(title: const Text('Track Inventory Stock'), value: _trackInventory, onChanged: (v){}))), 
                   child: SwitchListTile(
                    title: const Text('Track Inventory Stock'),
                    subtitle: const Text('Prevent sales when stock is unavailable'),
                    value: _trackInventory,
                    onChanged: (val) async {
                       setState(() => _trackInventory = val);
                       // Auto-save toggle for convenience
                       final updatedStore = store.copyWith(trackInventory: val);
                       await provider.updateStoreSettings(updatedStore);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const Divider(),
              const SizedBox(height: 10),
              const Text("Product Configuration", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              if (showUnits)
                FeatureGuard(
                   featureKey: 'settings.products.units',
                   lockedChild: const SizedBox.shrink(),
                   child: _buildConfigTile(context, "Manage Units", Icons.scale, "product_units", "e.g. kg, pcs, ltr")
                ),
              if (showDietary)
               FeatureGuard(
                  featureKey: 'settings.products.dietary',
                  lockedChild: const SizedBox.shrink(),
                  child: _buildConfigTile(context, "Dietary Types", Icons.restaurant_menu, "dietary_types", "e.g. Veg, Non-Veg, Vegan")
               ),
               if (showDietary) const SizedBox(height: 8),
               
               if (showPackaging)
               FeatureGuard(
                  featureKey: 'settings.products.packaging',
                  lockedChild: const SizedBox.shrink(),
                  child: _buildConfigTile(context, "Packaging Types", Icons.inventory_2_outlined, "packaging_types", "e.g. Box, Pouch, Bottle")
               ),
              if (showPackaging) const SizedBox(height: 8),

              if (showVariants)
              FeatureGuard(
                 featureKey: 'settings.products.variants', // Key remains same to preserve data
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
    return ListTile(
            leading: Icon(icon, color: Colors.blueGrey),
            title: Text(title),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageStringListScreen(
               title: title,
               metadataKey: key,
               hintText: hint,
            ))),
            tileColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
