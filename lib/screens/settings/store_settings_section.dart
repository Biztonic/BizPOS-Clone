// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/store_provider.dart';
import 'manage_counters_screen.dart';
import '../../widgets/feature_guard.dart';

class StoreSettingsSection extends StatefulWidget {
  const StoreSettingsSection({super.key});

  @override
  State<StoreSettingsSection> createState() => _StoreSettingsSectionState();
}

class _StoreSettingsSectionState extends State<StoreSettingsSection> {
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
      final provider = Provider.of<DashboardProvider>(context);
      final store = provider.activeStore;
      
      // Load store data
      if (store != null) {
        _nameController.text = store.name;
        _addressController.text = store.address ?? '';
        _phoneController.text = store.phone ?? '';
        _selectedStoreType = store.storeType;
      }
      
      // Load available types & configs from StoreProvider
      // We need to access StoreProvider here. Assuming DashboardProvider or a separate fetch.
      // DashboardProvider doesn't have it, but StoreProvider does. 
      // Often StoreProvider is available in the context or we can fetch via DashboardProvider if it exposes it?
      // For now, let's try reading StoreProvider directly or adding a method to DashboardProvider.
      // But based on previous file, `StoreProvider` is the one with `fetchStoreTypeConfigs`.
      // Let's assume StoreProvider is up the tree (it usually is in this app structure).
      
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      
      
      // Load available types & configs
      storeProvider.fetchStoreTypes().then((types) {
         storeProvider.fetchStoreTypeConfigs().then((configs) {
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
    final provider = Provider.of<DashboardProvider>(context);
    final store = provider.activeStore;

    if (store == null) return const Center(child: Text("No Store Data"));

    // Check Config
    final currentConfig = _selectedStoreType != null ? (_typeConfigs[_selectedStoreType] as Map?) : null;
    final showKitchen = currentConfig?['enableKitchen'] ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text("Store Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Store Name', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            
            // Store Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedStoreType,
              decoration: const InputDecoration(labelText: 'Store Type', border: OutlineInputBorder()),
              items: _availableStoreTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (val) => setState(() => _selectedStoreType = val),
            ),
            const SizedBox(height: 16),

            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            
            if (showKitchen) ...[
              const Divider(),
              const SizedBox(height: 10),
              const Text("Counters & Kitchen", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              FeatureGuard(
                featureKey: 'settings.store.counters',
                lockedChild: const SizedBox.shrink(),
                child: ListTile(
                  leading: const Icon(Icons.kitchen),
                  title: const Text('Manage Counters'),
                  subtitle: const Text('Configure Kitchen, Bar, or Station printers'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCountersScreen())),
                  tileColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),
            ],

            ElevatedButton(
              onPressed: () async {
                final updatedStore = store.copyWith(
                  name: _nameController.text,
                  address: _addressController.text,
                  phone: _phoneController.text,
                  storeType: _selectedStoreType,
                );
                await provider.updateStoreSettings(updatedStore);
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Store Settings Saved")));
                   // Do not auto-pop to avoid race conditions with app-wide rebuilds
                }
              },
              child: const Text("Save Changes"),
            )
          ],
        ),
      ),
    );
  }
}
