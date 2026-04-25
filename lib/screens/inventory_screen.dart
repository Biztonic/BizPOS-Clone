// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/inventory_item.dart';
import 'add_edit_inventory_screen.dart';
import 'central_item_selection_dialog.dart';
import '../l10n/app_localizations.dart'; // LOCALIZATION
import '../widgets/inventory_image_widget.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final allItems = provider.storeInventory;
    
    // Client-Side Search (Instant, Case-Insensitive, Substring)
    final filteredItems = allItems.where((item) {
       if (_searchQuery.isEmpty) return true;
       return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
              (item.sku != null && item.sku!.toLowerCase().contains(_searchQuery.toLowerCase())) ||
              item.id.contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'inventory')),
        elevation: 1,
        actions: [
          // Responsive Actions
          if (MediaQuery.of(context).size.width < 600) ...[
             if (provider.activeStore?.addons.contains('central_catalog') == true)
               IconButton(
                 onPressed: () => _showImportDialog(context, provider),
                 icon: const Icon(Icons.cloud_download),
                 tooltip: AppLocalizations.t(context, 'import'),
               ),
             IconButton(
               key: const Key('add_new_item_mobile'),
               onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditInventoryScreen()));
               },
               icon: const Icon(Icons.add),
               tooltip: 'add_item', // Simplified tooltip for match
               style: IconButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
             ),
          ] else ...[
            if (provider.activeStore?.addons.contains('central_catalog') == true) ...[
              TextButton.icon(
                onPressed: () => _showImportDialog(context, provider),
                icon: const Icon(Icons.cloud_download, size: 18),
                label: Text(AppLocalizations.t(context, 'import')),
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton.icon(
              key: const Key('add_new_item'),
              onPressed: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditInventoryScreen()));
               },
              icon: const Icon(Icons.add, size: 18),
              label: Text(AppLocalizations.t(context, 'add_item')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor, 
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Toolbar & Search
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('inventory_search_field'),
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '${AppLocalizations.t(context, 'search')} ${AppLocalizations.t(context, 'items')}...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Theme.of(context).inputDecorationTheme.fillColor ?? Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      suffixIcon: _searchController.text.isNotEmpty 
                          ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                              _searchController.clear();
                            }) 
                          : null
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // List
          Expanded(
            child: filteredItems.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                       const SizedBox(height: 16),
                       Text(_searchQuery.isEmpty ? 'No items in inventory' : 'No matching items found', style: const TextStyle(color: Colors.grey)),
                    ],
                  ))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      return _buildInventoryCard(context, filteredItems[i]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, DashboardProvider provider) {
    showDialog(
      context: context, 
      builder: (ctx) => const CentralItemSelectionDialog()
    );
  }

  Widget _buildInventoryCard(BuildContext context, InventoryItem item) {
    final provider = Provider.of<DashboardProvider>(context);
    final threshold = item.lowStockThreshold ?? 10;
    final currentStock = provider.getItemStock(item.id);
    final isLow = currentStock < threshold && currentStock > 0;
    final isOut = currentStock <= 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('inventory_item_${item.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditInventoryScreen(item: item)));
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image
                 InventoryImageWidget(item: item),
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Category: ${item.category}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('₹${item.price.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                          const Spacer(),
                          Builder(builder: (context) {
                            final provider = Provider.of<DashboardProvider>(context);
                            final trackInventory = provider.activeStore?.trackInventory ?? true;

                            if (!trackInventory) {
                               return _buildStatusBadge('Available', Colors.green);
                            }

                            if (isOut) {
                               return _buildStatusBadge('Out of Stock', Colors.red);
                            } else if (isLow) {
                               return _buildStatusBadge('Low Stock: ${provider.getItemStock(item.id)}', Colors.orange);
                            } else {
                               return _buildStatusBadge('In Stock: ${provider.getItemStock(item.id)}', Colors.blue);
                            }
                          }),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
