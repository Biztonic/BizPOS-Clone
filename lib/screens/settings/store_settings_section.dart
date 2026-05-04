import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/store/providers/store_notifier.dart';
import 'manage_counters_screen.dart';
import '../../widgets/feature_guard.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class StoreSettingsSection extends ConsumerStatefulWidget {
  const StoreSettingsSection({super.key});

  @override
  ConsumerState<StoreSettingsSection> createState() => _StoreSettingsSectionState();
}

class _StoreSettingsSectionState extends ConsumerState<StoreSettingsSection> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedStoreType;
  List<String> _availableStoreTypes = [];
  Map<String, dynamic> _typeConfigs = {};
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final storeState = ref.read(storeNotifierProvider);
      final store = storeState.activeStore;
      
      if (store != null) {
        _nameController.text = store.name;
        _addressController.text = store.address ?? '';
        _phoneController.text = store.phone ?? '';
        _selectedStoreType = store.storeType;
      }
      
      final notifier = ref.read(storeNotifierProvider.notifier);
      
      notifier.fetchStoreTypes().then((types) {
         notifier.fetchStoreTypeConfigs().then((configs) {
             if (mounted) {
                setState(() {
                   _availableStoreTypes = types;
                   _typeConfigs = configs;
                   
                   if (_selectedStoreType != null && !_availableStoreTypes.contains(_selectedStoreType)) {
                      _availableStoreTypes.add(_selectedStoreType!);
                   }
                });
             }
         });
      });

      _isInit = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(storeNotifierProvider);
    final store = storeState.activeStore;

    if (store == null) return const Center(child: Text("No Store Data"));
    final density = AppDensityProvider.configOf(context);

    final currentConfig = _selectedStoreType != null ? (_typeConfigs[_selectedStoreType] as Map?) : null;
    final showKitchen = currentConfig?['enableKitchen'] ?? false;

    return PosScaffold(
      title: "Store Settings",
      mainContent: ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
        children: [
          AppCard(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _nameController, 
                    labelText: 'Store Name', 
                    hintText: 'Enter store name',
                    prefixIcon: const Icon(Icons.store_outlined),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Store Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedStoreType,
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      labelText: 'Store Type',
                      labelStyle: AppTypography.labelMedium,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: _availableStoreTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedStoreType = val),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppTextField(
                    controller: _addressController, 
                    labelText: 'Address', 
                    hintText: 'Enter full address',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _phoneController, 
                    labelText: 'Phone', 
                    hintText: 'Enter contact number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  if (showKitchen) ...[
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    Text("Operational Areas", style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.md),
                    FeatureGuard(
                      featureKey: 'settings.store.counters',
                      lockedChild: const SizedBox.shrink(),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.kitchen, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: const Text('Manage Counters', style: AppTypography.titleSmall),
                        subtitle: Text('Configure Kitchen, Bar, or Station printers', 
                          style: AppTypography.bodySmall.copyWith(color: Theme.of(context).disabledColor)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCountersScreen())),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  AppButton(
                    label: "Save Changes",
                    onPressed: () async {
                      final updatedStore = store.copyWith(
                        name: _nameController.text,
                        address: _addressController.text,
                        phone: _phoneController.text,
                        storeType: _selectedStoreType,
                      );
                      await ref.read(storeNotifierProvider.notifier).updateStoreSettings(updatedStore);
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text("Store Settings Saved"), behavior: SnackBarBehavior.floating)
                         );
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
