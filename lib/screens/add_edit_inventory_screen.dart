import '../core/design/tokens/app_colors.dart';
// ignore_for_file: deprecated_member_use_from_same_package, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../providers/dashboard_provider.dart';
import '../providers/store_provider.dart';
import '../widgets/inventory_image_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/density/app_density.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_text_field.dart';


class AddEditInventoryScreen extends StatefulWidget {
  final InventoryItem? item;

  const AddEditInventoryScreen({super.key, this.item});

  @override
  State<AddEditInventoryScreen> createState() => _AddEditInventoryScreenState();
}

class _AddEditInventoryScreenState extends State<AddEditInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  // late TextEditingController _categoryController; // REMOVED
  late TextEditingController _skuController;
  late TextEditingController _imageController;
  late TextEditingController _lowStockController; // NEW
  late TextEditingController _costController; // NEW
  String? _selectedCounterId;
  
  // New Fields
  String? _selectedCategory; // NEW: Replaces Controller & Variant Dropdown
  String? _selectedDietary;
  String? _selectedPackaging;
  // String? _selectedVariant; // REMOVED
  
  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  
  // Metadata lists
  List<String> _dietaryOptions = [];
  List<String> _packagingOptions = [];
  List<String> _variantOptions = [];
  
  // Config flags
  bool _showDietary = false;
  bool _showPackaging = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '');
    _quantityController = TextEditingController(text: widget.item != null ? provider.getItemStock(widget.item!.id).toString() : '');
    // _categoryController = ... REMOVED
    _skuController = TextEditingController(text: widget.item?.sku ?? '');
    _imageController = TextEditingController(text: widget.item?.image ?? '');
    _lowStockController = TextEditingController(text: widget.item?.lowStockThreshold?.toString() ?? '10');
    _costController = TextEditingController(text: widget.item?.cost?.toString() ?? '');
    _selectedCounterId = widget.item?.counterId;
    
    
    // FIX: Handle empty string as null to avoid Dropdown assertion error
    _selectedCategory = (widget.item?.category != null && widget.item!.category.isNotEmpty) 
        ? widget.item!.category 
        : null;
        
    _selectedDietary = widget.item?.dietaryType;
    _selectedPackaging = widget.item?.packagingType;
    // _selectedVariant = widget.item?.variantCategory; // REMOVED

    _loadData();
  }

  Future<void> _loadData() async {
     try {
       final provider = Provider.of<DashboardProvider>(context, listen: false);
       final storeProvider = Provider.of<StoreProvider>(context, listen: false);
       
       // 1. Fetch Metadata
       final dietary = await provider.fetchMetadata('dietary_types');
       final packaging = await provider.fetchMetadata('packaging_types');
       final variants = await provider.fetchMetadata('variant_types'); // This is now used for CATEGORY
       
       // Ensure current category is in the list
       if (widget.item?.category != null && widget.item!.category.isNotEmpty) {
          if (!variants.contains(widget.item!.category)) {
             variants.add(widget.item!.category);
             variants.sort();
          }
       }
       
       // 2. Fetch Config
       final store = provider.activeStore;
       bool showD = false, showP = false;
       
       if (store != null) {
          final allConfigs = await storeProvider.fetchStoreTypeConfigs();
          final config = allConfigs[store.storeType] as Map<String, dynamic>? ?? {};
          showD = config['enableDietary'] == true;
          showP = config['enablePackaging'] == true;
       }

       if (mounted) {
          setState(() {
             _dietaryOptions = dietary;
             _packagingOptions = packaging;
             _variantOptions = variants;
             _showDietary = showD;
             _showPackaging = showP;
             _isLoading = false;
          });
       }
     } catch (e) {
       debugPrint("❌ AddEditInventoryScreen: Error loading data: $e");
       if (mounted) {
         setState(() => _isLoading = false);
       }
     }
  }

  Future<void> _addCategoryDialog() async {
    final controller = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name', hintText: 'e.g. Beverages'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newCategory != null && newCategory.isNotEmpty) {
      if (!_variantOptions.contains(newCategory)) {
        setState(() {
          _variantOptions.add(newCategory);
          _variantOptions.sort();
          _selectedCategory = newCategory;
        });
        // Save to backend metadata
        final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
        await dashboardProvider.addMetadata('variant_types', newCategory);
      } else {
        setState(() => _selectedCategory = newCategory);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _pickedImage = File(image.path);
          _imageController.text = image.name; 
        });
      }
    } catch (e) {
      debugPrint("❌ Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error selecting image")),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    // _categoryController.dispose(); // REMOVED
    _skuController.dispose();
    _imageController.dispose();
    _lowStockController.dispose(); // NEW
    _costController.dispose(); // NEW
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      
      final newItem = InventoryItem(
        id: widget.item?.id ?? '', 
        name: _nameController.text.trim(),
        category: _selectedCategory ?? '', // Use Dropdown Value
        price: double.tryParse(_priceController.text) ?? 0.0,
        quantity: int.tryParse(_quantityController.text) ?? 0,
        lowStockThreshold: int.tryParse(_lowStockController.text) ?? 10,
        status: (int.tryParse(_quantityController.text) ?? 0) > 0 ? 'In Stock' : 'Out of Stock',
        image: _imageController.text.isNotEmpty ? _imageController.text : null,
        sku: _skuController.text.trim(),
        cost: double.tryParse(_costController.text) ?? 0.0,
        trackStock: true,
        expiryDate: widget.item?.expiryDate, 
        storeId: provider.activeStoreId,
        counterId: _selectedCounterId,
        dietaryType: _showDietary ? _selectedDietary : null,
        packagingType: _showPackaging ? _selectedPackaging : null,
        // variantCategory: _showVariants ? _selectedVariant : null, // REMOVED/MERGED -> Just use category
        variantCategory: null, // REDUNDANT NOW
      );

      if (widget.item == null) {
        await provider.addInventoryItem(newItem, imageFile: _pickedImage);
      } else {
        await provider.updateInventoryItem(newItem, imageFile: _pickedImage);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving item: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);

    return PosScaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      ),
      mainContent: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: EdgeInsets.all(density.cardPadding),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                   AppTextField(
                    key: const Key('item_name_input'),
                    controller: _nameController,
                    labelText: 'Item Name',
                    validator: (v) => v!.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          key: const Key('item_price_input'),
                          controller: _priceController,
                          labelText: 'Price',
                          prefixText: '₹ ',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Price required' : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          key: const Key('item_qty_input'),
                          controller: _quantityController,
                          labelText: 'Quantity',
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? 'Qty required' : null,
                        ),
                      ),
                    ],
                   ),
                   const SizedBox(height: AppSpacing.md),

                   Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          key: const Key('item_cost_input'),
                          controller: _costController,
                          labelText: 'Item Cost',
                          prefixText: '₹ ',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          key: const Key('item_threshold_input'),
                          controller: _lowStockController,
                          labelText: 'Low Stock Threshold', 
                          helperText: 'Default: 10',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                   // Category Dropdown
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Category', 
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          value: (_selectedCategory != null && _variantOptions.contains(_selectedCategory)) 
                                    ? _selectedCategory 
                                    : null,
                          items: _variantOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => _selectedCategory = v),
                          hint: const Text('Select Category'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        onPressed: _addCategoryDialog,
                        icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryLight, size: 32),
                        tooltip: "Add New Category",
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  if (_variantOptions.isEmpty && !_isLoading)
                     Padding(
                       padding: const EdgeInsets.only(bottom: AppSpacing.md),
                       child: TextButton.icon(
                         onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add categories in Settings > Products")));
                         },
                         icon: const Icon(Icons.settings, size: 16),
                         label: const Text("Manage Categories in Settings"),
                       ),
                     ),
                  
                  // Conditional Fields
                  if (_showDietary) ...[
                      DropdownButtonFormField<String?>(
                        decoration: const InputDecoration(
                          labelText: 'Dietary Type', 
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        value: _selectedDietary != null && _dietaryOptions.contains(_selectedDietary) ? _selectedDietary : null,
                        items: [
                           const DropdownMenuItem(value: null, child: Text("None")),
                           ..._dietaryOptions.map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        ],
                        onChanged: (v) => setState(() => _selectedDietary = v),
                      ),
                      const SizedBox(height: AppSpacing.md),
                  ],

                   if (_showPackaging) ...[
                      DropdownButtonFormField<String?>(
                        decoration: const InputDecoration(
                          labelText: 'Packaging Type', 
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        value: _selectedPackaging != null && _packagingOptions.contains(_selectedPackaging) ? _selectedPackaging : null,
                        items: [
                           const DropdownMenuItem(value: null, child: Text("None")),
                           ..._packagingOptions.map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        ],
                        onChanged: (v) => setState(() => _selectedPackaging = v),
                      ),
                      const SizedBox(height: AppSpacing.md),
                  ],

                  AppTextField(
                    key: const Key('item_sku_input'),
                    controller: _skuController,
                    labelText: 'SKU / Barcode',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('item_image_input'),
                    controller: _imageController,
                    labelText: 'Image (Local Only)', 
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.image_search),
                      onPressed: _pickImage,
                      tooltip: "Pick from Gallery",
                    ),
                    helperText: 'Select an image from your device',
                    readOnly: true,
                    onTap: _pickImage,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_pickedImage != null || _imageController.text.isNotEmpty) ...[
                    Center(
                      child: Column(
                        children: [
                          Text('Preview:', style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
                          const SizedBox(height: AppSpacing.xs),
                          if (_pickedImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _pickedImage!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            InventoryImageWidget(
                              item: InventoryItem(
                                id: widget.item?.id ?? 'preview',
                                name: '',
                                category: '',
                                price: 0,
                                quantity: 0,
                                status: 'In Stock',
                                trackStock: false,
                                image: _imageController.text,
                                localImage: widget.item?.localImage,
                              ),
                              width: 120,
                              height: 120,
                              borderRadius: 12,
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  
                  // Counter Selector
                  Consumer<DashboardProvider>(
                    builder: (context, provider, child) {
                      final counters = provider.counters;
                      if (counters.isEmpty) return const SizedBox.shrink();

                      return DropdownButtonFormField<String?>(
                        decoration: const InputDecoration(
                          labelText: 'Assign to Counter (KDS)', 
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        value: _selectedCounterId,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Default / Kitchen')),
                          ...counters.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                        ],
                        onChanged: (val) => setState(() => _selectedCounterId = val),
                      );
                    }
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  AppButton.primary(
                    key: const Key('save_item_button'),
                    onPressed: _saveItem,
                    label: widget.item == null ? 'Create Item' : 'Update Item',
                    width: double.infinity,
                    size: AppButtonSize.large,
                  ),
                  
                  if (widget.item != null) ...[
                     const SizedBox(height: AppSpacing.md),
                     AppButton.ghost(
                       onPressed: () async {
                         final confirm = await showDialog<bool>(
                           context: context,
                           builder: (ctx) => AlertDialog(
                             title: const Text('Delete Item?'),
                             content: const Text('This action cannot be undone.'),
                             actions: [
                               TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text('Cancel')),
                               TextButton(onPressed: ()=>Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
                             ],
                           )
                         );
                         
                         if (confirm == true && mounted) {
                           setState(() => _isLoading = true);
                           try {
                             await Provider.of<DashboardProvider>(context, listen: false).deleteInventoryItem(widget.item!.id);
                             if (mounted) Navigator.pop(context);
                           } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                           }
                         }
                       },
                       label: 'Delete Item',
                       foregroundColor: AppColors.error,
                       width: double.infinity,
                     )
                  ]
                ],
              ),
            ),
          ),
    );
  }
}
