import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:biztonic_pos/features/store/providers/store_notifier.dart';
import '../../features/store/domain/entities/counter_model.dart';
import '../../models/printer_device.dart';
import '../../services/printer_manager_service.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
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
        if (context.mounted) setState(() {});
    });
  }

  void _addCounter() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'New Counter'), style: AppTypography.titleMedium),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        content: AppTextField(
          controller: nameController,
          labelText: "Counter Name",
          hintText: "e.g. Bar, Kitchen",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
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
                 if (ctx.mounted) Navigator.pop(ctx);
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
        content: Text(AppLocalizations.t(context, 'Are you sure you want to remove this counter? This cannot be undone.'), style: AppTypography.bodyMedium),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.t(context, 'Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(AppLocalizations.t(context, 'Delete'), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(storeNotifierProvider.notifier).removeCounter(counter.id);
      } catch (e) {
          if (mounted) {
           messenger.showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
         }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
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
        const SizedBox(width: AppSpacing.md),
      ],
      mainContent: Builder(
        builder: (context) {
          if (counters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 64, color: Theme.of(context).disabledColor),
                  const SizedBox(height: AppSpacing.md),
                  Text(AppLocalizations.t(context, 'No counters yet.'), style: AppTypography.bodyLarge),
                  const SizedBox(height: AppSpacing.lg),
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
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: counters.length,
            separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (ctx, i) {
              final counter = counters[i];
              final hasPrinter = counter.printerDevice != null;
              
              return AppCard(
                onTap: () => _editCounter(counter),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                      const Divider(height: AppSpacing.xl),
                      Row(
                        children: [
                          Icon(hasPrinter ? Icons.print : Icons.print_disabled, size: 16, color: hasPrinter ? AppColors.success : AppColors.secondary),
                          const SizedBox(width: AppSpacing.sm),
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
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(counter.isCfdEnabled ? Icons.monitor : Icons.monitor_outlined, size: 16, color: counter.isCfdEnabled ? AppColors.primary : AppColors.secondary),
                          const SizedBox(width: AppSpacing.sm),
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

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(storeNotifierProvider.notifier).updateCounter(updatedCounter);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text("Error: $e"), behavior: SnackBarBehavior.floating));
      }
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
            const SizedBox(height: AppSpacing.lg),
            
            DropdownButtonFormField<PrinterDevice?>(
              decoration: const InputDecoration(
                labelText: "Assign Printer",
                labelStyle: AppTypography.labelMedium,
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              ),
              isExpanded: true,
              value: _selectedPrinter != null && savedDevices.any((d) => d.address == _selectedPrinter!.address) 
                     ? savedDevices.firstWhere((d) => d.address == _selectedPrinter!.address) 
                     : null,
              items: [
                DropdownMenuItem<PrinterDevice?>(value: null, child: Text(AppLocalizations.t(context, 'None'), style: AppTypography.bodyMedium)),
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
                 padding: const EdgeInsets.only(top: AppSpacing.sm),
                 child: Text("No printers configured. Go to 'Printer Settings' to add devices.", 
                   style: AppTypography.bodySmall.copyWith(color: AppColors.warning)),
               ),
  
            const SizedBox(height: AppSpacing.lg),
  
            SwitchListTile(
               title: Text(AppLocalizations.t(context, 'Enable Customer Display'), style: AppTypography.titleSmall),
               subtitle: Text(AppLocalizations.t(context, 'Show active order status'), style: AppTypography.bodySmall.copyWith(color: Theme.of(context).disabledColor)),
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
          child: Text(AppLocalizations.t(context, 'Cancel')),
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



