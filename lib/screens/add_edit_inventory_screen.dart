import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_item.dart';
import '../providers/dashboard_provider.dart';
import '../providers/store_provider.dart';
import '../widgets/inventory_image_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/image_cache_service.dart';
import '../features/inventory/presentation/providers/inventory_provider.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/components/atoms/app_text_field.dart';


class AddEditInventoryScreen extends StatefulWidget {
  final InventoryItem? item;

  const AddEditInventoryScreen({super.key, this.item});

  /// Show this screen as a popup dialog
  static Future<void> showAsDialog(BuildContext context, {InventoryItem? item}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: AddEditInventoryScreen(item: item),
      ),
    );
  }

  @override
  State<AddEditInventoryScreen> createState() => _AddEditInventoryScreenState();
}

class _AddEditInventoryScreenState extends State<AddEditInventoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _skuController;
  late TextEditingController _imageController;
  late TextEditingController _lowStockController;
  late TextEditingController _costController;
  String? _selectedCounterId;
  
  String? _selectedCategory;
  String? _selectedDietary;
  String? _selectedPackaging;
  
  File? _pickedImage;
  String? _base64Image;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  
  List<String> _dietaryOptions = [];
  List<String> _packagingOptions = [];
  List<String> _variantOptions = [];
  
  bool _showDietary = false;
  bool _showPackaging = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? '');
    _quantityController = TextEditingController(text: widget.item?.quantity.toString() ?? '0');
    _skuController = TextEditingController(text: widget.item?.sku ?? '');
    _imageController = TextEditingController(text: widget.item?.image ?? '');
    _lowStockController = TextEditingController(text: widget.item?.lowStockThreshold?.toString() ?? '10');
    _costController = TextEditingController(text: widget.item?.cost?.toString() ?? '');
    _selectedCounterId = widget.item?.counterId;
    
    _selectedCategory = (widget.item?.category != null && widget.item!.category.isNotEmpty) 
        ? widget.item!.category 
        : null;
        
    _selectedDietary = widget.item?.dietaryType;
    _selectedPackaging = widget.item?.packagingType;
    _base64Image = widget.item?.localImage;
  }

  bool _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      if (widget.item != null) {
        final provider = Provider.of<DashboardProvider>(context, listen: false);
        _quantityController.text = provider.getItemStock(widget.item!.id).toString();
      }
      _loadData();
    }
  }

  Future<void> _loadData() async {
     try {
       final provider = Provider.of<DashboardProvider>(context, listen: false);
       final storeProvider = Provider.of<StoreProvider>(context, listen: false);
       
       final dietary = await provider.fetchMetadata('dietary_types').timeout(const Duration(seconds: 5), onTimeout: () => []);
       final packaging = await provider.fetchMetadata('packaging_types').timeout(const Duration(seconds: 5), onTimeout: () => []);
       final variants = await provider.fetchMetadata('variant_types').timeout(const Duration(seconds: 5), onTimeout: () => []);
       
       List<String> existingCategories = [];
       try {
         final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
         existingCategories = inventoryProvider.categories.where((c) => c != 'All').toList();
       } catch (e) {
         debugPrint("No InventoryProvider found: $e");
       }
       
       final mergedVariants = <String>{
         ...variants,
         ...existingCategories,
         if (widget.item?.category != null && widget.item!.category.isNotEmpty) widget.item!.category,
       }.toList()..sort();
       
       final store = provider.activeStore;
       bool showD = false, showP = false;
       
       if (store != null) {
          final allConfigs = await storeProvider.fetchStoreTypeConfigs().timeout(const Duration(seconds: 5), onTimeout: () => {});
          final config = allConfigs[store.storeType] as Map<String, dynamic>? ?? {};
          showD = config['enableDietary'] == true;
          showP = config['enablePackaging'] == true;
       }

       if (mounted) {
          setState(() {
             _dietaryOptions = dietary.toSet().toList();
             _packagingOptions = packaging.toSet().toList();
             _variantOptions = mergedVariants;
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
        title: Text(AppLocalizations.t(context, 'Add New Category')),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Category Name', hintText: 'e.g. Beverages'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(AppLocalizations.t(context, 'Add')),
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
        if (mounted) {
          final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
          await dashboardProvider.addMetadata('variant_types', newCategory);
        }
      } else {
        setState(() => _selectedCategory = newCategory);
      }
    }
  }

  Future<void> _pickImage() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorMsg = AppLocalizations.t(context, 'Error selecting image');
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 75,
      );
      
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final base64Str = base64Encode(bytes);
          final format = image.path.endsWith('.png') ? 'png' : 'jpeg';
          setState(() {
            _pickedImage = null;
            _imageController.text = image.name; 
            _base64Image = 'data:image/$format;base64,$base64Str';
          });
        } else {
          setState(() {
            _pickedImage = File(image.path);
            _imageController.text = image.name; 
            _base64Image = null;
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error picking image: $e");
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _skuController.dispose();
    _imageController.dispose();
    _lowStockController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final newItemId = (widget.item != null && widget.item!.id.isNotEmpty) 
          ? widget.item!.id 
          : const Uuid().v4();
      
      String? savedImagePath;
      if (!kIsWeb && _pickedImage != null) {
        savedImagePath = await ImageCacheService.saveLocalImage(_pickedImage!, newItemId);
      }

      final newItem = InventoryItem(
        id: newItemId, 
        name: _nameController.text.trim(),
        category: _selectedCategory ?? 'General',
        price: double.tryParse(_priceController.text) ?? 0.0,
        cost: double.tryParse(_costController.text) ?? 0.0,
        sku: _skuController.text.trim(),
        image: _imageController.text.isEmpty ? null : _imageController.text,
        localImage: savedImagePath ?? _base64Image ?? widget.item?.localImage,
        quantity: int.tryParse(_quantityController.text) ?? 0,
        status: (int.tryParse(_quantityController.text) ?? 0) > 0 ? 'In Stock' : 'Out of Stock',
        trackStock: true,
        lowStockThreshold: int.tryParse(_lowStockController.text) ?? 10,
        dietaryType: _selectedDietary,
        packagingType: _selectedPackaging,
        counterId: _selectedCounterId,
      );

      if (widget.item == null) {
        await provider.addItem(newItem);
      } else {
        await provider.updateItem(newItem);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.t(context, 'Item saved successfully'))),
        );
      }
    } catch (e) {
      debugPrint("❌ Error saving item: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving item: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 700,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.adaptivePrimary(context).withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.adaptivePrimary(context),
                    AppColors.adaptivePrimary(context).withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Item' : 'Add New Item',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEditing
                              ? 'Update details for ${widget.item!.name}'
                              : 'Fill in the details to create a new inventory item',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(context),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Flexible(
              child: _isLoading
                  ? const Padding(padding: EdgeInsets.all(64), child: Center(child: CircularProgressIndicator()))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(context, Icons.info_outline_rounded, 'Basic Information'),
                            const SizedBox(height: 12),
                            AppTextField(key: const Key('item_name_input'), controller: _nameController, labelText: 'Item Name', validator: (v) => v!.trim().isEmpty ? 'Name is required' : null),
                            const SizedBox(height: AppSpacing.md),
                            Row(children: [
                              Expanded(
                                child: AppTextField(
                                  key: const Key('item_price_input'),
                                  controller: _priceController,
                                  labelText: 'Selling Price',
                                  prefixText: '₹ ',
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Price required';
                                    final val = double.tryParse(v);
                                    if (val == null) return 'Invalid price';
                                    final costVal = double.tryParse(_costController.text) ?? 0.0;
                                    if (val < costVal) return 'Must be >= Cost Price';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppTextField(
                                  key: const Key('item_cost_input'),
                                  controller: _costController,
                                  labelText: 'Cost Price',
                                  prefixText: '₹ ',
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final val = double.tryParse(v ?? '') ?? 0.0;
                                    final priceVal = double.tryParse(_priceController.text) ?? 0.0;
                                    if (priceVal < val) return 'Must be <= Selling Price';
                                    return null;
                                  },
                                ),
                              ),
                            ]),
                            const SizedBox(height: 20),
                            _buildDivider(context),
                            const SizedBox(height: 16),

                            _buildSectionHeader(context, Icons.inventory_2_outlined, 'Stock & Category'),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: AppTextField(
                                  key: const Key('item_qty_input'),
                                  controller: _quantityController,
                                  labelText: 'Quantity',
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Qty required';
                                    final val = int.tryParse(v);
                                    if (val == null) return 'Invalid quantity';
                                    if (val < 0) return 'Must be >= 0';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: AppTextField(key: const Key('item_threshold_input'), controller: _lowStockController, labelText: 'Low Stock Alert', helperText: 'Default: 10', keyboardType: TextInputType.number)),
                            ]),
                            const SizedBox(height: AppSpacing.md),
                            Row(children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(labelText: 'Category', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12), filled: true, fillColor: AppColors.surface(context)),
                                  value: (_selectedCategory != null && _variantOptions.contains(_selectedCategory)) ? _selectedCategory : null,
                                  items: _variantOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                  onChanged: (v) => setState(() => _selectedCategory = v),
                                  hint: Text(AppLocalizations.t(context, 'Select Category')),
                                  validator: (value) => (value == null || value.isEmpty) ? 'Please select a category' : null,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Tooltip(
                                message: 'Add New Category',
                                child: Material(
                                  color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  child: InkWell(borderRadius: BorderRadius.circular(8), onTap: _addCategoryDialog, child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.add_rounded, color: AppColors.adaptivePrimary(context), size: 24))),
                                ),
                              ),
                            ]),

                            if (_variantOptions.isEmpty && !_isLoading)
                              Padding(padding: const EdgeInsets.only(top: AppSpacing.sm), child: TextButton.icon(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Please add categories in Settings > Products')))); }, icon: const Icon(Icons.settings, size: 16), label: Text(AppLocalizations.t(context, 'Manage Categories in Settings')))),

                            if (_showDietary) ...[
                              const SizedBox(height: AppSpacing.md),
                              DropdownButtonFormField<String?>(
                                decoration: const InputDecoration(labelText: 'Dietary Type', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12)),
                                value: _selectedDietary != null && _dietaryOptions.contains(_selectedDietary) ? _selectedDietary : null,
                                items: [DropdownMenuItem(value: null, child: Text(AppLocalizations.t(context, 'None'))), ..._dietaryOptions.map((e) => DropdownMenuItem(value: e, child: Text(e)))],
                                onChanged: (v) => setState(() => _selectedDietary = v),
                              ),
                            ],
                            if (_showPackaging) ...[
                              const SizedBox(height: AppSpacing.md),
                              DropdownButtonFormField<String?>(
                                decoration: const InputDecoration(labelText: 'Packaging Type', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12)),
                                value: _selectedPackaging != null && _packagingOptions.contains(_selectedPackaging) ? _selectedPackaging : null,
                                items: [DropdownMenuItem(value: null, child: Text(AppLocalizations.t(context, 'None'))), ..._packagingOptions.map((e) => DropdownMenuItem(value: e, child: Text(e)))],
                                onChanged: (v) => setState(() => _selectedPackaging = v),
                              ),
                            ],

                            const SizedBox(height: 20),
                            _buildDivider(context),
                            const SizedBox(height: 16),

                            _buildSectionHeader(context, Icons.qr_code_rounded, 'SKU & Image'),
                            const SizedBox(height: 12),
                            AppTextField(key: const Key('item_sku_input'), controller: _skuController, labelText: 'SKU / Barcode'),
                            const SizedBox(height: AppSpacing.md),
                            AppTextField(
                              key: const Key('item_image_input'), controller: _imageController, labelText: 'Image (Local Only)',
                              suffixIcon: IconButton(icon: const Icon(Icons.image_search), onPressed: _pickImage, tooltip: "Pick from Gallery"),
                              helperText: 'Select an image from your device', readOnly: true, onTap: _pickImage,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (_pickedImage != null || _base64Image != null || _imageController.text.isNotEmpty) ...[
                              Center(child: Column(children: [
                                Text(AppLocalizations.t(context, 'Preview:'), style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
                                const SizedBox(height: AppSpacing.xs),
                                if (_pickedImage != null)
                                  ClipRRect(borderRadius: BorderRadius.circular(8), child: kIsWeb ? Image.network(_pickedImage!.path, width: 100, height: 100, fit: BoxFit.cover, cacheWidth: 200, cacheHeight: 200) : Image.file(_pickedImage!, width: 100, height: 100, fit: BoxFit.cover, cacheWidth: 200, cacheHeight: 200))
                                else
                                  InventoryImageWidget(item: InventoryItem(id: widget.item?.id ?? 'preview', name: '', category: '', price: 0, quantity: 0, status: 'In Stock', trackStock: false, image: _imageController.text.isEmpty ? null : _imageController.text, localImage: _base64Image ?? widget.item?.localImage), width: 100, height: 100, borderRadius: 8),
                              ])),
                            ],
                            const SizedBox(height: AppSpacing.md),

                            Consumer<DashboardProvider>(builder: (context, provider, child) {
                              final counters = provider.counters;
                              if (counters.isEmpty) return const SizedBox.shrink();
                              return DropdownButtonFormField<String?>(
                                decoration: const InputDecoration(labelText: 'Assign to Counter (KDS)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12)),
                                value: _selectedCounterId,
                                items: [DropdownMenuItem<String?>(value: null, child: Text(AppLocalizations.t(context, 'Default / Kitchen'))), ...counters.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))],
                                onChanged: (val) => setState(() => _selectedCounterId = val),
                              );
                            }),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ),
                      ),
                    ),
            ),

            // ── Footer ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(color: AppColors.surface(context), border: Border(top: BorderSide(color: AppColors.border(context)))),
              child: Row(children: [
                if (isEditing)
                  TextButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                        title: Text(AppLocalizations.t(context, 'Delete Item?')),
                        content: Text(AppLocalizations.t(context, 'This action cannot be undone.')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t(context, 'Cancel'))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.t(context, 'Delete'), style: TextStyle(color: AppColors.adaptiveError(context)))),
                        ],
                      ));
                      if (!context.mounted) return;
                      if (confirm != true) return;
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
                      setState(() => _isLoading = true);
                      try { await dashboardProvider.deleteInventoryItem(widget.item!.id); navigator.pop(); } catch (e) { scaffoldMessenger.showSnackBar(SnackBar(content: Text("Error: $e"))); }
                    },
                    icon: Icon(Icons.delete_outline, color: AppColors.adaptiveError(context), size: 18),
                    label: Text('Delete', style: TextStyle(color: AppColors.adaptiveError(context))),
                  ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.w600))),
                const SizedBox(width: 12),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveItem,
                    icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(isEditing ? Icons.save_rounded : Icons.add_rounded, size: 20),
                    label: Text(isEditing ? 'Save Changes' : 'Create Item', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.adaptivePrimary(context), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 24), elevation: 0),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, IconData icon, String title) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.adaptivePrimary(context)),
      const SizedBox(width: 8),
      Text(title, style: AppTypography.labelLarge.copyWith(color: AppColors.adaptivePrimary(context), fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    ]);
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.border(context).withValues(alpha: 0.0), AppColors.border(context), AppColors.border(context).withValues(alpha: 0.0)]),
      ),
    );
  }
}
