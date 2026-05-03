import '../core/design/tokens/app_colors.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/components/atoms/app_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../providers/store_provider.dart';

class ImportItemDialog extends StatefulWidget {
  final InventoryItem item;
  
  const ImportItemDialog({super.key, required this.item});

  @override
  State<ImportItemDialog> createState() => _ImportItemDialogState();
}

class _ImportItemDialogState extends State<ImportItemDialog> {
  late TextEditingController _priceController;
  late TextEditingController _qtyController;
  late TextEditingController _costController;
  String _selectedCounter = 'No specific counter';
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Default price to 0 or simple check, prompt implies "in central catalogue item there should not be price"
    // So we leave it empty for the user to fill, or 0. The image shows a cursor | implying empty/focus.
    _priceController = TextEditingController(); 
    _qtyController = TextEditingController();
    _costController = TextEditingController();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Item to Store', style: AppTypography.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close), 
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Set the price and quantity for "${widget.item.name}" in your store.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 24),
              
              // Item Name Display
              Row(
                children: [
                  const SizedBox(width: 80, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                  const SizedBox(width: 16),
                  Text(widget.item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),

              // Price
              Row(
                children: [
                   const SizedBox(width: 80, child: Text('Price (₹)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                   const SizedBox(width: 16),
                   Expanded(
                     child: TextFormField(
                       controller: _priceController,
                       keyboardType: TextInputType.number,
                       decoration: InputDecoration(
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                       ),
                       validator: (v) => v == null || v.isEmpty ? 'Price is required' : null,
                     ),
                   )
                ],
              ),
              const SizedBox(height: 16),

              // Quantity
              Row(
                children: [
                   const SizedBox(width: 80, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                   const SizedBox(width: 16),
                   Expanded(
                     child: TextFormField(
                       controller: _qtyController,
                       keyboardType: TextInputType.number,
                       decoration: InputDecoration(
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                       ),
                       validator: (v) => v == null || v.isEmpty ? 'Quantity is required' : null,
                     ),
                   )
                ],
              ),
              const SizedBox(height: 16),
              
              // Cost
              Row(
                children: [
                   const SizedBox(width: 80, child: Text('Cost of Goods (₹)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                   const SizedBox(width: 16),
                   Expanded(
                     child: TextFormField(
                       controller: _costController,
                       keyboardType: TextInputType.number,
                       decoration: InputDecoration(
                         hintText: 'Optional',
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                       ),
                     ),
                   )
                ],
              ),
              const SizedBox(height: 16),

              // Counter
              Row(
                children: [
                   const SizedBox(width: 80, child: Text('Counter', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Consumer<StoreProvider>(
                       builder: (context, provider, child) {
                         final counters = provider.counters;
                         
                         // If no counters found, show warning or default
                         if (counters.isEmpty) {
                           return const Padding(
                             padding: EdgeInsets.only(top: 12),
                             child: Text("No counters found. Add in Settings.", style: TextStyle(color: AppColors.error, fontSize: 13)),
                           );
                         }

                         return DropdownButtonFormField<String>(
                           value: _selectedCounter != 'No specific counter' ? _selectedCounter : null,
                           hint: const Text("Select Counter"),
                           items: counters.map<DropdownMenuItem<String>>((c) {
                             return DropdownMenuItem(value: c.id, child: Text(c.name));
                           }).toList(),
                           onChanged: (v) => setState(() => _selectedCounter = v!),
                           decoration: InputDecoration(
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                             contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                           ),
                         );
                       }
                     ),
                   )
                ],
              ),
              const SizedBox(height: 32),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.outline(
                    label: 'Back to Search',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  AppButton.primary(
                    label: 'Add to Store',
                    onPressed: _submit,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
       final result = {
         'price': double.tryParse(_priceController.text) ?? 0.0,
         'quantity': int.tryParse(_qtyController.text) ?? 0,
         'cost': double.tryParse(_costController.text),
         'counter': _selectedCounter == 'No specific counter' ? null : _selectedCounter,
       };
       Navigator.pop(context, result);
    }
  }
}
