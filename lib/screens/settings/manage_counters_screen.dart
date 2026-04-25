// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biztonic_pos/providers/store_provider.dart';
import '../../models/counter_model.dart';
import '../../models/printer_device.dart';
import '../../services/printer_manager_service.dart';

class ManageCountersScreen extends StatefulWidget {
  const ManageCountersScreen({super.key});

  @override
  State<ManageCountersScreen> createState() => _ManageCountersScreenState();
}

class _ManageCountersScreenState extends State<ManageCountersScreen> {
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
        title: const Text("New Counter"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Counter Name", hintText: "e.g. Bar, Kitchen"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                 final newCounter = CounterModel(
                    id: '', 
                    name: nameController.text.trim(),
                    isCfdEnabled: false
                 );
                 await Provider.of<StoreProvider>(context, listen: false).addStoreCounter(newCounter);
                 if (mounted) Navigator.pop(ctx);
              }
            }, 
            child: const Text("Create")
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
        title: Text('Delete "${counter.name}"?'),
        content: const Text('Are you sure you want to remove this counter? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true && mounted) {
      try {
        await Provider.of<StoreProvider>(context, listen: false).removeStoreCounter(counter.id);
      } catch (e) {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Counters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addCounter,
            tooltip: "Add Counter",
          )
        ],
      ),
      body: Consumer<StoreProvider>(
        builder: (context, provider, child) {
          final counters = provider.counters;
          
          if (counters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("No counters yet.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _addCounter, child: const Text("Create First Counter"))
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: counters.length,
            separatorBuilder: (c, i) => const SizedBox(height: 16),
            itemBuilder: (ctx, i) {
              final counter = counters[i];
              final hasPrinter = counter.printerDevice != null;
              
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () => _editCounter(counter),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(counter.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Icon(Icons.edit, color: Theme.of(context).primaryColor),
                          ],
                        ),
                        const Divider(),
                        Row(
                          children: [
                            Icon(hasPrinter ? Icons.print : Icons.print_disabled, size: 16, color: hasPrinter ? Colors.green : Colors.grey),
                            const SizedBox(width: 8),
                            Text(hasPrinter 
                               ? "Printer: ${(counter.printerDevice!['name'] ?? 'Unknown')} (${counter.printerDevice!['type']})" 
                               : "No Printer Assigned",
                               style: TextStyle(color: hasPrinter ? Colors.black87 : Colors.grey)
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(counter.isCfdEnabled ? Icons.monitor : Icons.monitor_outlined, size: 16, color: counter.isCfdEnabled ? Colors.blue : Colors.grey),
                            const SizedBox(width: 8),
                            Text(counter.isCfdEnabled ? "Customer Display Active" : "No Customer Display",
                                style: TextStyle(color: counter.isCfdEnabled ? Colors.black87 : Colors.grey)
                            ),
                          ],
                        )
                      ],
                    ),
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

class _EditCounterDialog extends StatefulWidget {
  final CounterModel counter;
  final PrinterManagerService printerManager;
  final VoidCallback onDelete;

  const _EditCounterDialog({
    required this.counter, 
    required this.printerManager,
    required this.onDelete,
  });

  @override
  State<_EditCounterDialog> createState() => _EditCounterDialogState();
}

class _EditCounterDialogState extends State<_EditCounterDialog> {
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
      await Provider.of<StoreProvider>(context, listen: false).updateCounter(updatedCounter);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
          Expanded(child: Text("Edit ${widget.counter.name}")),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
               Navigator.pop(context); // Close dialog first
               widget.onDelete();      // Trigger delete confirmation flow
            },
            tooltip: "Delete Counter",
          )
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Counter Name", hintText: "e.g. Bar"),
            ),
            const SizedBox(height: 16),
            
            // Printer Selector
            DropdownButtonFormField<PrinterDevice?>(
              decoration: const InputDecoration(labelText: "Assign Printer"),
              isExpanded: true,
              value: _selectedPrinter != null && savedDevices.any((d) => d.address == _selectedPrinter!.address) 
                     ? savedDevices.firstWhere((d) => d.address == _selectedPrinter!.address) 
                     : null,
              items: [
                const DropdownMenuItem<PrinterDevice?>(value: null, child: Text("None")),
                ...savedDevices.map((device) => DropdownMenuItem(
                  value: device, 
                  child: Text("${device.name} (${device.type.name})", overflow: TextOverflow.ellipsis)
                )),
              ],
              onChanged: (val) {
                setState(() => _selectedPrinter = val);
              },
            ),
            if (savedDevices.isEmpty) 
               Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text("No printers configured. Go to 'Printer Settings' to add devices.", style: TextStyle(color: Colors.orange.shade800, fontSize: 12)),
               ),
  
            const SizedBox(height: 16),
  
            // Settings
            SwitchListTile(
              title: const Text("Enable Customer Display"),
               subtitle: const Text("Show active order status"),
               value: _isCfdEnabled,
               onChanged: (val) => setState(() => _isCfdEnabled = val),
               contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text("Save"),
        ),
      ],
    );
  }
}
