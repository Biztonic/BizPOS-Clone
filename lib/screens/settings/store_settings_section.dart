import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy_provider;
import '../../providers/dashboard_provider.dart' as legacy;
import '../../features/store/domain/entities/store.dart';
import '../../features/store/providers/store_notifier.dart';
import 'manage_counters_screen.dart';
import '../../widgets/feature_guard.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/design_system.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/components/atoms/app_card.dart';
import 'package:hive/hive.dart';
import '../../core/config/store_type_config.dart';

class StoreSettingsSection extends ConsumerStatefulWidget {
  final bool isSubView;
  final Store? store;
  const StoreSettingsSection({super.key, this.isSubView = false, this.store});

  @override
  ConsumerState<StoreSettingsSection> createState() =>
      _StoreSettingsSectionState();
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
        final existingType = store.storeType as String?;
        if (existingType != null && existingType.trim().isNotEmpty) {
          _selectedStoreType = existingType.trim();
          if (!_availableStoreTypes.contains(_selectedStoreType)) {
            _availableStoreTypes.add(_selectedStoreType!);
          }
        } else {
          _selectedStoreType = _availableStoreTypes.isNotEmpty
              ? _availableStoreTypes.first
              : null;
        }
        _dataLoaded = true;
        _lastStoreId = store.id;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Synchronous initial load from Hive if available
    if (Hive.isBoxOpen('store_type_configs')) {
      final box = Hive.box('store_type_configs');
      final cachedTypes = box.get('types') as List?;
      final cachedConfigs = box.get('configs') as Map?;
      if (cachedConfigs != null && cachedConfigs.isNotEmpty) {
        _typeConfigs = Map<String, dynamic>.from(cachedConfigs);
      }
      if (cachedTypes != null && cachedTypes.isNotEmpty) {
        _availableStoreTypes = cachedTypes.map((e) => e.toString()).toList();
      } else if (_typeConfigs.isNotEmpty) {
        _availableStoreTypes = _typeConfigs.keys.toList();
      }
    }

    // Initial fetch of metadata from repository & dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(storeNotifierProvider.notifier);
      final dashboard = legacy_provider.Provider.of<legacy.DashboardProvider>(
          context,
          listen: false);
      notifier.fetchStoreTypes().then((types) {
        notifier.fetchStoreTypeConfigs().then((configs) {
          if (context.mounted) {
            setState(() {
              if (configs.isNotEmpty) {
                _typeConfigs = configs;
              } else if (dashboard.storeTypeConfigs.isNotEmpty) {
                _typeConfigs = dashboard.storeTypeConfigs;
              }

              List<String> resolvedTypes = [];
              if (types.isNotEmpty) {
                resolvedTypes = List<String>.from(types);
              } else if (dashboard.storeTypes.isNotEmpty) {
                resolvedTypes = List<String>.from(dashboard.storeTypes);
              } else if (configs.isNotEmpty) {
                resolvedTypes = configs.keys.toList();
              } else if (_availableStoreTypes.isNotEmpty) {
                resolvedTypes = List<String>.from(_availableStoreTypes);
              }

              if (resolvedTypes.isNotEmpty) {
                _availableStoreTypes = resolvedTypes;
              }

              if (_selectedStoreType != null &&
                  _selectedStoreType!.isNotEmpty &&
                  !_availableStoreTypes.contains(_selectedStoreType)) {
                _availableStoreTypes.add(_selectedStoreType!);
              } else if (_selectedStoreType == null &&
                  _availableStoreTypes.isNotEmpty) {
                _selectedStoreType = _availableStoreTypes.first;
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
    Store? store = widget.store ?? storeState.activeStore;

    // Fallback to legacy DashboardProvider if not found in widget/riverpod
    if (store == null) {
      try {
        final dashboard = legacy_provider.Provider.of<legacy.DashboardProvider>(
            context,
            listen: false);
        store = dashboard.activeStore;
        if (store != null && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(storeNotifierProvider.notifier).setActiveStoreId(
                    store!.id,
                    initialStore: store,
                  );
            }
          });
        }
      } catch (_) {}
    }

    if (store == null) {
      if (storeState.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store_mall_directory_outlined,
                  size: 64, color: Theme.of(context).disabledColor),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No Active Store Found',
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Please select an active store to manage settings.',
                style: AppTypography.bodyMedium
                    .copyWith(color: Theme.of(context).disabledColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Retry',
                onPressed: () {
                  try {
                    final dashboard =
                        legacy_provider.Provider.of<legacy.DashboardProvider>(
                            context,
                            listen: false);
                    if (dashboard.activeStoreId != null) {
                      ref.read(storeNotifierProvider.notifier).setActiveStoreId(
                            dashboard.activeStoreId,
                            initialStore: dashboard.activeStore,
                          );
                    }
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),
      );
    }

    _populateControllers(store);

    final showKitchen = _selectedStoreType != null &&
        StoreTypeConfig.isFeatureAllowed(
          _selectedStoreType!,
          'kds',
          storeTypeConfigs: _typeConfigs,
        );
    final allowedFeatures = _selectedStoreType != null
        ? StoreTypeConfig.getAllowedFeatures(
            _selectedStoreType!,
            storeTypeConfigs: _typeConfigs,
          )
        : <PeripheralFeatureMeta>[];

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
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Store name is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _addressController,
                  label: 'Address',
                  icon: const Icon(Icons.location_on_outlined),
                  maxLines: 2,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Address is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _phoneController,
                  label: 'Phone',
                  icon: const Icon(Icons.phone_outlined),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone is required';
                    }
                    if (value.trim().length < 10) {
                      return 'Please enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Store Type Dropdown
                DropdownButtonFormField<String>(
                  value: _availableStoreTypes.contains(_selectedStoreType)
                      ? _selectedStoreType
                      : (_availableStoreTypes.isNotEmpty
                          ? _availableStoreTypes.first
                          : null),
                  style: AppTypography.bodyMedium,
                  decoration: const InputDecoration(
                    labelText: 'Store Type',
                    labelStyle: AppTypography.labelMedium,
                    border:
                        OutlineInputBorder(borderRadius: AppRadius.borderMd),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  ),
                  items: _availableStoreTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedStoreType = val),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Allowed features indicator card for the selected store type
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded,
                              size: 16,
                              color: AppColors.adaptivePrimary(context)),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            AppLocalizations.t(context,
                                'Included features for ${_selectedStoreType ?? 'this Store Type'}:'),
                            style: AppTypography.labelSmall
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.check_circle_outline,
                                size: 14, color: AppColors.primary),
                            label: const Text('Core: POS, Inventory & Reports',
                                style: TextStyle(fontSize: 11)),
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.08),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          ...allowedFeatures.map((feat) => Chip(
                                avatar: Icon(feat.icon,
                                    size: 14, color: AppColors.success),
                                label: Text(feat.label,
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor:
                                    AppColors.success.withValues(alpha: 0.08),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLocalizations.t(context,
                            'Feature visibility in navigation and settings adapts automatically when you save.'),
                        style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondary(context),
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                if (showKitchen) ...[
                  const Divider(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(AppLocalizations.t(context, 'Operational Areas'),
                      style: AppTypography.titleSmall
                          .copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.md),
                  FeatureGuard(
                    featureKey: 'settings.store.counters',
                    lockedChild: const SizedBox.shrink(),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: AppRadius.borderMd,
                        ),
                        child: Icon(Icons.kitchen,
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(
                          AppLocalizations.t(context, 'Manage Counters'),
                          style: AppTypography.titleSmall),
                      subtitle: Text(
                          AppLocalizations.t(context,
                              'Configure Kitchen, Bar, or Station printers'),
                          style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context).disabledColor)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ManageCountersScreen())),
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.borderMd),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                AppButton(
                  label: "Save Changes",
                  isLoading: _isSaving,
                  onPressed: () async {
                    setState(() => _isSaving = true);
                    final currentStore = store!;
                    final updatedStore = currentStore.copyWith(
                      name: _nameController.text,
                      address: _addressController.text,
                      phone: _phoneController.text,
                      storeType: _selectedStoreType,
                    );
                    final messenger = ScaffoldMessenger.of(context);
                    final dashboard =
                        legacy_provider.Provider.of<legacy.DashboardProvider>(
                            context,
                            listen: false);
                    final successMsg =
                        AppLocalizations.t(context, 'Store Settings Saved');
                    final errorColor = AppColors.adaptiveError(context);
                    try {
                      await ref
                          .read(storeNotifierProvider.notifier)
                          .updateStoreSettings(updatedStore);
                      try {
                        await dashboard.updateStoreSettings(updatedStore);
                      } catch (_) {}
                      if (mounted) {
                        setState(() => _isSaving = false);
                        messenger.showSnackBar(SnackBar(
                            content: Text(successMsg),
                            behavior: SnackBarBehavior.floating));
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isSaving = false);
                        messenger.showSnackBar(SnackBar(
                            content: Text("Error: $e"),
                            backgroundColor: errorColor));
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
