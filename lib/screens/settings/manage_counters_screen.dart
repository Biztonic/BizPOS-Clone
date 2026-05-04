import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:biztonic_pos/features/store/providers/store_notifier.dart';
import '../../features/store/domain/entities/counter_model.dart';
import '../../models/printer_device.dart';
import '../../services/printer_manager_service.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_text_field.dart';
import '../../core/design/tokens/app_colors.dart';

class ManageCountersScreen extends ConsumerStatefulWidget {
  const ManageCountersScreen({super.key});

  @override
  ConsumerState<ManageCountersScreen> createState() => _ManageCountersScreenState();
}

class _ManageCountersScreenState extends ConsumerState<ManageCountersScreen> {
  final PrinterManagerService _printerManager = PrinterManagerService();

  @override
  void initState() {
    super.initState();
    // Ensure printer list is loaded
    _printerManager.init().then((_) {
        if (mounted) setState(() {});
    });
  }

  void _addCounter() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Counter", style: AppTypography.titleMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: AppTextField(
          controller: nameController,
          labelText: "Counter Name",
          hintText: "e.g. Bar, Kitchen",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          AppButton(
            label: "Create",
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                 final newCounter = CounterModel(
                    id: '', 
                    name: nameController.text.trim(),
                    isCfdEnabled: false
                 );
                 await ref.read(storeNotifierProvider.notifier).addCounter(newCounter);
                 if (mounted) Navigator.pop(ctx);
              }
            },
            variant: AppButtonVariant.primary,
            size: AppButtonSize.small,
          )
        ],
      )
    );
  }

  void _editCounter(CounterModel counter) {
    showDialog(
      context: context,
      builder: (ctx) => _EditCounterDialog(
        counter: counter, 
        printerManager: _printerManager,
        onDelete: () => _deleteCounter(counter),
      )
    );
  }

  void _deleteCounter(CounterModel counter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${counter.name}"?', style: AppTypography.titleMedium),
        content: const Text('Are you sure you want to remove this counter? This cannot be undone.', style: AppTypography.bodyMedium),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(storeNotifierProvider.notifier).removeCounter(counter.id);
      } catch (e) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);
    final storeState = ref.watch(storeNotifierProvider);
    final counters = storeState.counters;

    return PosScaffold(
      title: 'Manage Counters',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _addCounter,
          tooltip: "Add Counter",
        ),
        SizedBox(width: AppSpacing.md),
      ],
      mainContent: Builder(
        builder: (context) {
          if (counters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 64, color: Theme.of(context).disabledColor),
                  SizedBox(height: AppSpacing.md),
                  const Text("No counters yet.", style: AppTypography.bodyLarge),
                  SizedBox(height: AppSpacing.lg),
                  AppButton(
                    onPressed: _addCounter, 
                    label: "Create First Counter",
                    variant: AppButtonVariant.primary,
                  )
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(AppSpacing.lg),
            itemCount: counters.length,
            separatorBuilder: (c, i) => SizedBox(height: AppSpacing.md),
            itemBuilder: (ctx, i) {
              final counter = counters[i];
              final hasPrinter = counter.printerDevice != null;
              
              return AppCard(
                onTap: () => _editCounter(counter),
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(counter.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                          Icon(Icons.edit_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                      Divider(height: AppSpacing.xl),
                      Row(
                        children: [
                          Icon(hasPrinter ? Icons.print : Icons.print_disabled, size: 16, color: hasPrinter ? AppColors.success : AppColors.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(hasPrinter 
                               ? "Printer: ${(counter.printerDevice!['name'] ?? 'Unknown')} (${counter.printerDevice!['type']})" 
                               : "No Printer Assigned",
                               style: AppTypography.bodySmall.copyWith(
                                 color: hasPrinter ? Theme.of(context).colorScheme.onSurface : Theme.of(context).disabledColor,
                               )
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(counter.isCfdEnabled ? Icons.monitor : Icons.monitor_outlined, size: 16, color: counter.isCfdEnabled ? AppColors.primary : AppColors.secondary),
                          const SizedBox(width: 8),
                          Text(counter.isCfdEnabled ? "Customer Display Active" : "No Customer Display",
                              style: AppTypography.bodySmall.copyWith(
                                color: counter.isCfdEnabled ? Theme.of(context).colorScheme.onSurface : Theme.of(context).disabledColor,
                              )
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EditCounterDialog extends ConsumerStatefulWidget {
  final CounterModel counter;
  final PrinterManagerService printerManager;
  final VoidCallback onDelete;

  const _EditCounterDialog({
    required this.counter, 
    required this.printerManager,
    required this.onDelete,
  });

  @override
  ConsumerState<_EditCounterDialog> createState() => _EditCounterDialogState();
}

class _EditCounterDialogState extends ConsumerState<_EditCounterDialog> {
  late TextEditingController _nameController;
  late bool _isCfdEnabled;
  PrinterDevice? _selectedPrinter;
  
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.counter.name);
    _isCfdEnabled = widget.counter.isCfdEnabled;
    
    // Attempt to match existing printer
    if (widget.counter.printerDevice != null) {
       final savedMap = widget.counter.printerDevice!;
       try {
         // Reconstruct from map
         _selectedPrinter = PrinterDevice.fromJson(savedMap);
       } catch (_) { /* Error ignored */ }
    }
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    final updatedCounter = CounterModel(
      id: widget.counter.id,
      name: newName,
      isCfdEnabled: _isCfdEnabled,
      printerDevice: _selectedPrinter?.toJson(),
      assignedPrinterId: _selectedPrinter?.address
    );

    try {
      await ref.read(storeNotifierProvider.notifier).updateCounter(updatedCounter);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get saved devices + null option
    final savedDevices = widget.printerManager.savedDevices;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text("Edit ${widget.counter.name}", style: AppTypography.titleMedium)),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () {
               Navigator.pop(context); // Close dialog first
               widget.onDelete();      // Trigger delete confirmation flow
            },
            tooltip: "Delete Counter",
          )
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _nameController,
              labelText: "Counter Name",
              hintText: "e.g. Bar",
            ),
            SizedBox(height: AppSpacing.lg),
            
            DropdownButtonFormField<PrinterDevice?>(
              decoration: InputDecoration(
                labelText: "Assign Printer",
                labelStyle: AppTypography.labelMedium,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              isExpanded: true,
              value: _selectedPrinter != null && savedDevices.any((d) => d.address == _selectedPrinter!.address) 
                     ? savedDevices.firstWhere((d) => d.address == _selectedPrinter!.address) 
                     : null,
              items: [
                const DropdownMenuItem<PrinterDevice?>(value: null, child: Text("None", style: AppTypography.bodyMedium)),
                ...savedDevices.map((device) => DropdownMenuItem(
                  value: device, 
                  child: Text("${device.name} (${device.type.name})", style: AppTypography.bodyMedium, overflow: TextOverflow.ellipsis)
                )),
              ],
              onChanged: (val) {
                setState(() => _selectedPrinter = val);
              },
            ),
            if (savedDevices.isEmpty) 
               Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text("No printers configured. Go to 'Printer Settings' to add devices.", 
                   style: AppTypography.bodySmall.copyWith(color: AppColors.warning)),
               ),
  
            SizedBox(height: AppSpacing.lg),
  
            SwitchListTile(
               title: const Text("Enable Customer Display", style: AppTypography.titleSmall),
               subtitle: Text("Show active order status", style: AppTypography.bodySmall.copyWith(color: Theme.of(context).disabledColor)),
               value: _isCfdEnabled,
               onChanged: (val) => setState(() => _isCfdEnabled = val),
               contentPadding: EdgeInsets.zero,
               activeColor: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        AppButton(
          onPressed: _save,
          label: "Save",
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
        ),
      ],
    );
  }
}

