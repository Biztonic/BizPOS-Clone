import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import '../../models/settings.dart';

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
          const SnackBar(content: Text("KDS Settings Saved")),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("KDS Settings"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text("Sound Notifications"),
            subtitle: const Text("Play sound when a new order arrives"),
            value: _soundEnabled,
            onChanged: (v) => setState(() => _soundEnabled = v),
          ),
          const Divider(),
          ListTile(
            title: const Text("Font Size"),
            subtitle: Text("${_fontSize.toInt()} px"),
            trailing: SizedBox(
              width: 200,
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
            title: const Text("Layout Style"),
            trailing: DropdownButton<String>(
              value: _layout,
              items: ['Grid', 'List'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _layout = v!),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text("Filter Categories", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text("Only show orders containing items from these categories:", style: TextStyle(color: Colors.grey)),
          ),
          // In a real app, fetch actual categories. Here we use some defaults or empty.
          _buildCategoryFilters(),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text("Save Settings", style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    // Ideally fetch from provider.inventoryCategories
    // For now, let's just show a few common ones or a text input if empty
    final categories = ['Kitchen', 'Pizza', 'Drinks', 'Dessert']; 
    
    return Wrap(
      spacing: 8,
      children: categories.map((cat) {
        final isSelected = _selectedCategories.contains(cat);
        return FilterChip(
          label: Text(cat),
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
