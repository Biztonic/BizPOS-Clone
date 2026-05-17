import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/inventory_item.dart';
import 'import_item_dialog.dart';
import '../widgets/inventory_image_widget.dart';

class CentralItemSelectionDialog extends StatefulWidget {
  const CentralItemSelectionDialog({super.key});

  @override
  State<CentralItemSelectionDialog> createState() => _CentralItemSelectionDialogState();
}

class _CentralItemSelectionDialogState extends State<CentralItemSelectionDialog> {
  final _searchController = TextEditingController();
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  final int _limit = 10;
  final List<DocumentSnapshot?> _lastDocs = [null];
  DocumentSnapshot? _currentLastDoc;
  int _currentPage = 0;

  bool _hasMore = true;
  bool _filterByStoreType = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems({bool next = false, bool prev = false}) async {
    setState(() => _isLoading = true);

    DocumentSnapshot? startAfter;
    if (next) {
       startAfter = _currentLastDoc;
       _lastDocs.add(_currentLastDoc);
    } else if (prev) {
       if (_lastDocs.isNotEmpty) {
          _lastDocs.removeLast();
          startAfter = _lastDocs.isNotEmpty ? _lastDocs.last : null;
       }
    } else {
       _lastDocs.clear(); 
       _lastDocs.add(null);
       _currentPage = 0;
    }

    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final query = _searchController.text.trim();
      final storeType = provider.activeStore?.storeType;
      
      // Filter by store type!
      final res = await provider.fetchPaginatedCentralInventory(
        limit: _limit, 
        startAfter: startAfter, 
        queryStr: query.isNotEmpty ? query : null,
        filterStoreType: _filterByStoreType ? storeType : null
      );

      if (mounted) {
        setState(() {
          _items = res['items'] as List<InventoryItem>;
          _currentLastDoc = res['lastDoc'] as DocumentSnapshot?;
          
          if (next) _currentPage++;
          if (prev) _currentPage--;
          
          _hasMore = _items.length == _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("Error loading central items: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
       child: Container(
         width: 500, // Matching web dialog style
         height: 600,
         padding: const EdgeInsets.all(AppSpacing.lg),
         child: Column(
           children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(AppLocalizations.t(context, 'Import from Central Catalog'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                 IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
               ],
             ),
             const SizedBox(height: AppSpacing.md),
             Wrap(
               spacing: 8,
               runSpacing: 8,
                children: [
                   SizedBox(
                     width: 250,
                     child: TextField(
                       controller: _searchController,
                       decoration: const InputDecoration(
                         hintText: 'Search catalog...',
                         prefixIcon: Icon(Icons.search),
                         border: OutlineInputBorder(),
                         contentPadding: EdgeInsets.symmetric(horizontal: 12),
                       ),
                       onTapOutside: (_) => _loadItems(),
                       onSubmitted: (_) => _loadItems(),
                     ),
                   ),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: () => _loadItems()),
                  // Filter Toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _filterByStoreType,
                          onChanged: (val) {
                            setState(() => _filterByStoreType = val);
                            _loadItems();
                          },
                        ),
                      ),
                      Flexible(child: Text("Filter (${Provider.of<DashboardProvider>(context, listen: false).activeStore?.storeType ?? 'None'})", style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
             ),
             const SizedBox(height: AppSpacing.sm),
             Expanded(
               child: _isLoading 
                   ? const Center(child: CircularProgressIndicator())
                   : _items.isEmpty
                       ? Center(child: Text(AppLocalizations.t(context, 'No items found for your store type.')))
                       : ListView.separated(
                           itemCount: _items.length,
                           separatorBuilder: (ctx, i) => const Divider(),
                           itemBuilder: (ctx, i) {
                               final item = _items[i];
                               return Padding(
                                 padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                 child: Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     // Leading Avatar
                                     if (item.image != null && item.image!.isNotEmpty)
                                       CircleAvatar(
                                         radius: 20,
                                         backgroundImage: InventoryImageWidget.getImageProvider(item),
                                       )
                                     else
                                       CircleAvatar(
                                         radius: 20,
                                         child: Text(item.name.isNotEmpty ? item.name[0] : '?'),
                                       ),
                                     const SizedBox(width: 12),
                                     
                                     // Title and Subtitle
                                     Expanded(
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text(
                                             item.name,
                                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                             maxLines: 2,
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                           const SizedBox(height: AppSpacing.xs),
                                           Text(
                                             'SKU: ${item.sku}\nType: ${item.storeType ?? "All"}',
                                             style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                                             maxLines: 2,
                                             overflow: TextOverflow.ellipsis,
                                           ),
                                         ],
                                       ),
                                     ),
                                     const SizedBox(width: AppSpacing.sm),
                                     
                                     // Trailing Action
                                     Builder(
                                       builder: (context) {
                                         final storeInventory = Provider.of<DashboardProvider>(context).storeInventory;
                                         bool exists = storeInventory.any((i) => 
                                           i.name.toLowerCase() == item.name.toLowerCase() || 
                                           (item.sku != null && item.sku!.isNotEmpty && i.sku == item.sku)
                                         );
                                         
                                         if (exists) {
                                           return Padding(
                                             padding: const EdgeInsets.only(top: AppSpacing.sm),
                                             child: Text(AppLocalizations.t(context, 'Imported'), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12)),
                                           );
                                         }
  
                                         return ElevatedButton(
                                           style: ElevatedButton.styleFrom(
                                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.sm),
                                             minimumSize: Size.zero,
                                             tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                           ),
                                           onPressed: () async {
                                              final result = await showDialog(
                                                context: context,
                                                builder: (_) => ImportItemDialog(item: item),
                                              );
  
                                              if (result != null && result is Map && mounted) {
                                                final provider = Provider.of<DashboardProvider>(context, listen: false);
                                                await provider.importCentralItem(
                                                  item,
                                                  overridePrice: result['price'],
                                                  overrideQty: result['quantity'],
                                                  overrideCost: result['cost'],
                                                  counterId: result['counter'],
                                                );
                                                setState(() {}); 
                                                if (mounted) {
                                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported ${item.name}')));
                                                }
                                              }
                                           },
                                           child: Text(AppLocalizations.t(context, 'Import'), style: const TextStyle(fontSize: 13)),
                                         );
                                       }
                                     ),
                                   ],
                                 ),
                               );
                           },
                         ),
             ),
             // Pagination Controls
             if (!_isLoading && (_currentPage > 0 || _hasMore))
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       OutlinedButton(
                         onPressed: _currentPage > 0 ? () => _loadItems(prev: true) : null, 
                         child: Text(AppLocalizations.t(context, 'Previous'))
                       ),
                       const SizedBox(width: AppSpacing.xxs),
                       Text("Page ${_currentPage + 1}"),
                       const SizedBox(width: AppSpacing.xxs),
                       OutlinedButton(
                         onPressed: _hasMore ? () => _loadItems(next: true) : null,
                         child: Text(AppLocalizations.t(context, 'Next'))
                       ),
                    ],
                  ),
                )
           ],
         ),
       ),
    );
  }
}




