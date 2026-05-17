import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/store/providers/store_notifier.dart';
import 'manage_counters_screen.dart';
import '../../widgets/feature_guard.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/design_system.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';

class StoreSettingsSection extends ConsumerStatefulWidget {
  final bool isSubView;
  const StoreSettingsSection({super.key, this.isSubView = false});

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
  
  bool _isSaving = false;

  bool _dataLoaded = false;

  String? _lastStoreId;

  void _populateControllers(dynamic store) {
    if (store != null) {
      if (!_dataLoaded || _lastStoreId != store.id) {
        _nameController.text = store.name ?? '';
        _addressController.text = store.address ?? '';
        _phoneController.text = store.phone ?? '';
        _selectedStoreType = store.storeType;
        _dataLoaded = true;
        _lastStoreId = store.id;
      }
    }
  }


  @override
  void initState() {
    super.initState();
    // Initial fetch of metadata
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(storeNotifierProvider.notifier);
      notifier.fetchStoreTypes().then((types) {
        notifier.fetchStoreTypeConfigs().then((configs) {
          if (context.mounted) {
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
    });
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

    if (store == null) {
      const widget = Center(child: CircularProgressIndicator());
      if (widget.runtimeType == SizedBox) return widget; // Should not happen but for safety
      
      return widget.runtimeType == Center ? (widget as Widget) : const SizedBox();
    }

    _populateControllers(store);
    

    final currentConfig = _selectedStoreType != null ? (_typeConfigs[_selectedStoreType] as Map?) : null;
    final showKitchen = currentConfig?['enableKitchen'] ?? false;

    final content = ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  AppTextField(
            controller: _nameController, 
            label: 'Store Name', 
            icon: const Icon(Icons.store_outlined),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Store name is required' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _addressController, 
            label: 'Address', 
            icon: const Icon(Icons.location_on_outlined),
            maxLines: 2,
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Address is required' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _phoneController, 
            label: 'Phone', 
            icon: const Icon(Icons.phone_outlined),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Phone is required';
              if (value.trim().length < 10) return 'Please enter a valid phone number';
              return null;
            },
          ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Store Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedStoreType,
                    style: AppTypography.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'Store Type',
                      labelStyle: AppTypography.labelMedium,
                      border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    ),
                    items: _availableStoreTypes.map((type) {
                      return DropdownMenuItem(value: type, child: Text(type));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedStoreType = val),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  
                  if (showKitchen) ...[
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(AppLocalizations.t(context, 'Operational Areas'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.md),
                    FeatureGuard(
                      featureKey: 'settings.store.counters',
                      lockedChild: const SizedBox.shrink(),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.borderMd,
                          ),
                          child: Icon(Icons.kitchen, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(AppLocalizations.t(context, 'Manage Counters'), style: AppTypography.titleSmall),
                        subtitle: Text(AppLocalizations.t(context, 'Configure Kitchen, Bar, or Station printers'), 
                          style: AppTypography.bodySmall.copyWith(color: Theme.of(context).disabledColor)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCountersScreen())),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  AppButton(
                    label: "Save Changes",
                    isLoading: _isSaving,
                    onPressed: () async {
                      setState(() => _isSaving = true);
                      final updatedStore = store.copyWith(
                        name: _nameController.text,
                        address: _addressController.text,
                        phone: _phoneController.text,
                        storeType: _selectedStoreType,
                      );
                      final messenger = ScaffoldMessenger.of(context);
                      final successMsg = AppLocalizations.t(context, 'Store Settings Saved');
                      final errorColor = AppColors.adaptiveError(context);
                      try {
                        await ref.read(storeNotifierProvider.notifier).updateStoreSettings(updatedStore);
                        if (mounted) {
                          setState(() => _isSaving = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text(successMsg), behavior: SnackBarBehavior.floating)
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isSaving = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text("Error: $e"), backgroundColor: errorColor)
                          );
                        }
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
      title: "Store Settings",
      showSidebar: false,
      mainContent: content,
    );
  }
}


