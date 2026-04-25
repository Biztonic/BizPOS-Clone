// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';

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
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item already exists")));
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             Row(
               children: [
                 Expanded(
                   child: TextField(
                     controller: _controller,
                     decoration: InputDecoration(
                       labelText: widget.hintText,
                       border: const OutlineInputBorder(),
                     ),
                   ),
                 ),
                 const SizedBox(width: 12),
                 ElevatedButton(
                   onPressed: _isLoading ? null : _addItem,
                   style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                   ),
                   child: const Text("ADD"),
                 )
               ],
             ),
             const SizedBox(height: 24),
             Expanded(
               child: _isLoading 
                   ? const Center(child: CircularProgressIndicator())
                   : _items.isEmpty 
                       ? Center(child: Text("No items found. Add one above.", style: TextStyle(color: Colors.grey.shade600)))
                       : ListView.separated(
                           itemCount: _items.length,
                           separatorBuilder: (_, __) => const Divider(),
                           itemBuilder: (ctx, i) {
                              final item = _items[i];
                              return ListTile(
                                title: Text(item),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteItem(item),
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
