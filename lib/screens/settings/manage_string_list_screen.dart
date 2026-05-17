// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/tokens/app_colors.dart';

class ManageStringListScreen extends StatefulWidget {
  final String title;
  final String metadataKey;
  final String hintText;

  const ManageStringListScreen({
    super.key, 
    required this.title, 
    required this.metadataKey,
    this.hintText = "Enter value"
  });

  @override
  State<ManageStringListScreen> createState() => _ManageStringListScreenState();
}

class _ManageStringListScreenState extends State<ManageStringListScreen> {
  final _controller = TextEditingController();
  List<String> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final items = await provider.fetchMetadata(widget.metadataKey);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _addItem() async {
    final val = _controller.text.trim();
    if (val.isEmpty) return;
    
    if (_items.contains(val)) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Item already exists'))));
       return;
    }

    setState(() => _isLoading = true);
    try {
       final provider = Provider.of<DashboardProvider>(context, listen: false);
       await provider.addMetadata(widget.metadataKey, val);
       _controller.clear();
       await _loadItems();
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteItem(String val) async {
    setState(() => _isLoading = true);
    try {
       final provider = Provider.of<DashboardProvider>(context, listen: false);
       await provider.deleteMetadata(widget.metadataKey, val);
       await _loadItems();
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    

    return PosScaffold(
      title: widget.title,
      mainContent: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
             AppCard(
               child: Padding(
                 padding: const EdgeInsets.all(AppSpacing.md),
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     Expanded(
                       child: AppTextField(
                         controller: _controller,
                         labelText: widget.hintText,
                       ),
                     ),
                     const SizedBox(width: AppSpacing.md),
                     AppButton(
                       label: "ADD",
                       onPressed: _isLoading ? null : _addItem,
                       variant: AppButtonVariant.primary,
                       isLoading: _isLoading && _controller.text.isNotEmpty,
                     )
                   ],
                 ),
               ),
             ),
             const SizedBox(height: AppSpacing.lg),
             Expanded(
               child: _isLoading 
                   ? const Center(child: CircularProgressIndicator())
                   : _items.isEmpty 
                       ? Center(
                           child: Text(AppLocalizations.t(context, 'No items found. Add one above.'), 
                             style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))
                           )
                         )
                       : ListView.separated(
                           itemCount: _items.length,
                           separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                           itemBuilder: (ctx, i) {
                               final item = _items[i];
                               return AppCard(
                                 child: ListTile(
                                   contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                   title: Text(item, style: AppTypography.bodyLarge),
                                   trailing: IconButton(
                                     icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                     onPressed: () => _deleteItem(item),
                                   ),
                                 ),
                               );
                           },
                         ),
             )
          ],
        ),
      ),
    );
  }
}
