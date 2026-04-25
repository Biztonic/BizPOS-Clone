// ignore_for_file: use_build_context_synchronously
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../providers/dashboard_provider.dart';
import '../models/customer.dart';
import 'add_edit_customer_screen.dart';
import 'customer_detail_screen.dart';
import '../l10n/app_localizations.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _sortBy = 'Name';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    
    // Trigger initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
       final provider = Provider.of<DashboardProvider>(context, listen: false);
       if (provider.activeStoreId != null) {
          provider.customerProvider?.fetchCustomers(provider.activeStoreId, refresh: true);
       }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Selector to only rebuild when customers or activeStoreId changes
    return Selector<DashboardProvider, _CustomerScreenData>(
      selector: (_, p) => _CustomerScreenData(
        customersLength: p.customers.length,
        activeStoreId: p.activeStoreId,
        customersHash: p.customers.isEmpty ? 0 : Object.hashAll(p.customers.map((c) => c.id)),
      ),
      builder: (context, data, _) {
        final provider = Provider.of<DashboardProvider>(context, listen: false);
        return _buildCustomersBody(context, provider);
      },
    );
  }

  Widget _buildCustomersBody(BuildContext context, DashboardProvider provider) {
    // Check for errors from CustomerProvider
    final error = provider.customerProvider?.error;
    if (error != null) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
                content: Text("Error loading customers: $error"), 
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(label: "Retry", onPressed: () => provider.customerProvider?.fetchCustomers(provider.activeStoreId, refresh: true))
             )
          );
       });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter & Sort
    List<Customer> displayedCustomers = provider.customers.where((c) => 
       c.name.toLowerCase().contains(_searchQuery) || 
       (c.mobile?.contains(_searchQuery) ?? false) ||
       (c.email.toLowerCase().contains(_searchQuery))
    ).toList();

    displayedCustomers.sort((a, b) {
      if (_sortBy == 'Points') return b.loyaltyPoints.compareTo(a.loyaltyPoints);
      if (_sortBy == 'Spent') return b.totalSpent.compareTo(a.totalSpent);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF4F6F9),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('customer_add_button'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditCustomerScreen())),
        label: Text(AppLocalizations.t(context, 'add_customer')),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            sliver: SliverToBoxAdapter(child: _buildModernHeader(context)),
          ),
          if (MediaQuery.of(context).size.width > 600)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(child: _buildStatsRow(provider)),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            sliver: _buildMainContentSliver(context, provider, displayedCustomers),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
             if (context.canPop()) {
                context.pop(); 
             } else {
                context.go('/dashboard');
             }
          },
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSelectionMode ? '${_selectedIds.length} Selected' : 'Customer Management', 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)
              ),
              const SizedBox(height: 8),
              Text(
                _isSelectionMode ? 'Perform bulk actions on selected customers.' : 'Manage loyalty, visits, and customer data.', 
                style: const TextStyle(color: Colors.grey, fontSize: 15)
              ),
            ],
          ),
        ),
        if (_isSelectionMode) ...[
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            tooltip: 'Delete Selected',
            onPressed: () => _confirmBulkDelete(context),
          ),
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select All',
            onPressed: () {
              final provider = Provider.of<DashboardProvider>(context, listen: false);
              setState(() {
                if (_selectedIds.length == provider.customers.length) {
                   _selectedIds.clear();
                } else {
                   _selectedIds.addAll(provider.customers.map((c) => c.id));
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Exit Selection',
            onPressed: () => setState(() {
              _isSelectionMode = false;
              _selectedIds.clear();
            }),
          ),
        ] else ...[
          IconButton(
             icon: const Icon(Icons.refresh),
             tooltip: 'Refresh',
             onPressed: () {
                final provider = Provider.of<DashboardProvider>(context, listen: false);
                provider.customerProvider?.fetchCustomers(provider.activeStoreId, refresh: true);
             },
          ),
          IconButton(
             icon: const Icon(Icons.checklist),
             tooltip: 'Selection Mode',
             onPressed: () => setState(() => _isSelectionMode = true),
          ),
        ]
      ],
    );
  }

  Widget _buildStatsRow(DashboardProvider provider) {
    final total = provider.customers.length;
    final loyalty = provider.customers.where((c) => c.loyaltyPoints > 0).length;
    final vips = provider.customers.where((c) => c.tier == 'VIP' || c.totalSpent > 1000).length;

    return Row(
      children: [
        Expanded(child: _buildStatCard("Total Customers", "$total", Icons.people, Colors.blue)),
        const SizedBox(width: 24),
        Expanded(child: _buildStatCard("Loyalty Active", "$loyalty", Icons.stars, Colors.orange)),
        const SizedBox(width: 24),
        Expanded(child: _buildStatCard("VIP Members", "$vips", Icons.diamond, Colors.purple)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Builder(builder: (context) {
       final isDark = Theme.of(context).brightness == Brightness.dark;
       return Container(
         padding: const EdgeInsets.all(24),
         decoration: BoxDecoration(
           color: isDark ? const Color(0xFF2D2D44) : Colors.white,
           borderRadius: BorderRadius.circular(16),
           boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
           border: isDark ? Border.all(color: Colors.white10) : null,
         ),
         child: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
               child: Icon(icon, color: color, size: 28),
             ),
             const SizedBox(width: 16),
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                 const SizedBox(height: 4),
                 Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
               ],
             )
           ],
         ),
       );
    });
  }

  Widget _buildMainContentSliver(BuildContext context, DashboardProvider provider, List<Customer> customers) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SliverMainAxisGroup(
        slivers: [
           SliverToBoxAdapter(
             child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2D44) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03), blurRadius: 15, offset: const Offset(0, 5))],
                  border: isDark ? Border.all(color: Colors.white10) : null,
                ),
                child: Column(
                  children: [
                    // Toolbar
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('customer_search_field'),
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: "Search customers...",
                                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12),
                             decoration: BoxDecoration(
                               border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                               borderRadius: BorderRadius.circular(10),
                             ),
                             child: DropdownButtonHideUnderline(
                               child: DropdownButton<String>(
                                 value: _sortBy,
                                 items: const [
                                   DropdownMenuItem(value: 'Name', child: Text('Sort by Name')),
                                   DropdownMenuItem(value: 'Points', child: Text('Sort by Points')),
                                   DropdownMenuItem(value: 'Spent', child: Text('Sort by Spent')),
                                 ],
                                 onChanged: (v) => setState(() => _sortBy = v!),
                               )
                             ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                             icon: const Icon(Icons.import_contacts),
                             tooltip: "Import from Contacts",
                             onPressed: _importContacts,
                          )
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (customers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.person_search, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.t(context, 'no_data'), style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                  ],
                ),
             ),
           ),
           if (customers.isNotEmpty)
             SliverList(
               delegate: SliverChildBuilderDelegate(
                 (ctx, i) {
                   final isLast = i == customers.length - 1;
                   return Container(
                     decoration: BoxDecoration(
                       color: isDark ? const Color(0xFF2D2D44) : Colors.white,
                       borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : null,
                       border: isDark ? Border.all(color: Colors.white10) : null,
                     ),
                     child: _buildCustomerTile(customers[i], isDark, provider),
                   );
                 },
                 childCount: customers.length,
               ),
             ),
        ],
    );
  }

  Widget _buildCustomerTile(Customer c, bool isDark, DashboardProvider provider) {
    final isSelected = _selectedIds.contains(c.id);
    
    return ListTile(
      key: Key('customer_tile_${c.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      selected: isSelected,
      selectedTileColor: Colors.blue.withValues(alpha: 0.05),
      leading: _isSelectionMode 
        ? Checkbox(
            value: isSelected, 
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIds.add(c.id);
                } else {
                  _selectedIds.remove(c.id);
                }
              });
            },
          )
        : CircleAvatar(
            radius: 20,
            backgroundColor: Colors.primaries[c.name.length % Colors.primaries.length].withValues(alpha: 0.2),
            child: Text(
              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.primaries[c.name.length % Colors.primaries.length], fontWeight: FontWeight.bold),
            ),
          ),
      title: Row(
         children: [
           Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
           const SizedBox(width: 8),
           if (c.tier == 'VIP')
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
               decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
               child: const Text('VIP', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
             ),
         ],
      ),
      subtitle: Text(c.email.isNotEmpty ? c.email : (c.mobile ?? 'No Contact'), style: const TextStyle(color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           if (c.loyaltyPoints > 0)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.stars, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text("${c.loyaltyPoints} pts", style: const TextStyle(fontSize: 12, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              
           IconButton(
             icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
             onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCustomerScreen(customer: c))),
             tooltip: "Edit",
           ),
           IconButton(
             icon: const Icon(Icons.star_outline, size: 20, color: Colors.amber),
             onPressed: () => _showAdjustPointsDialog(c, provider),
             tooltip: "Adjust Points",
           ),
           IconButton(
             icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
             onPressed: () => _confirmDelete(c, provider),
             tooltip: "Delete",
           ),
        ],
      ),
      onTap: () {
         if (_isSelectionMode) {
            setState(() {
               if (isSelected) {
                 _selectedIds.remove(c.id);
               } else {
                 _selectedIds.add(c.id);
               }
            });
         } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)));
         }
      },
      onLongPress: () {
         if (!_isSelectionMode) {
            setState(() {
               _isSelectionMode = true;
               _selectedIds.add(c.id);
            });
         }
      },
    );
  }

  void _showAdjustPointsDialog(Customer c, DashboardProvider provider) {
     final controller = TextEditingController();
     showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
           title: Text("Adjust Points for ${c.name}"),
           content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Points (+/-)"),
           ),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
              TextButton(
                 onPressed: () {
                    final points = int.tryParse(controller.text) ?? 0;
                    if (points != 0) provider.updateCustomerLoyalty(c.id, points);
                    Navigator.pop(ctx);
                 }, 
                 child: const Text("SAVE")
              ),
           ],
        )
     );
  }

  void _confirmDelete(Customer c, DashboardProvider provider) {
     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           title: const Text("Delete Customer?"),
           content: Text("Are you sure you want to delete ${c.name}?"),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
              ElevatedButton(
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                 onPressed: () {
                    provider.customerProvider?.deleteCustomer(c.id);
                    Navigator.pop(ctx);
                 }, 
                 child: const Text("DELETE")
              ),
           ],
        )
     );
  }

  void _confirmBulkDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete ${_selectedIds.length} Customers?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final provider = Provider.of<DashboardProvider>(context, listen: false);
              final List<String> idsToDelete = _selectedIds.toList();
              
              for (var id in idsToDelete) {
                await provider.customerProvider?.deleteCustomer(id);
              }
              
              if (mounted) {
                setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Deleted ${idsToDelete.length} customers"))
                );
              }
            },
            child: const Text("DELETE ALL")
          ),
        ],
      ),
    );
  }

  Future<void> _importContacts() async {
    // Check Platform
    bool isAndroid = false;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        isAndroid = true;
      }
    } catch (e) {
      isAndroid = false;
    }

    if (!isAndroid) {
      if (mounted) {
        showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: const Text("Feature Not Available"),
            content: const Text("Importing contacts is only available on Android devices."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
            ],
          )
        );
      }
      return;
    }

    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
        if (mounted) _showContactSelectionDialog(contacts);
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error accessing contacts: $e")));
      }
    }
  }

  void _showContactSelectionDialog(List<Contact> contacts) {
    // Filter contacts with at least a phone or email
    final validContacts = contacts.where((c) => c.phones.isNotEmpty || c.emails.isNotEmpty).toList();
    
    // Sort by name
    validContacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    
    List<Contact> selected = [];
    String query = "";
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
       builder: (context, setDialogState) {
          final filtered = validContacts.where((c) => c.displayName.toLowerCase().contains(query.toLowerCase())).toList();
          
          return AlertDialog(
             title: const Text("Import Contacts"),
             content: SizedBox(
               width: double.maxFinite,
               child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     TextField(
                        decoration: const InputDecoration(
                           hintText: "Search...",
                           prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (val) {
                           setDialogState(() => query = val);
                        },
                     ),
                     const SizedBox(height: 16),
                     Expanded(
                        child: ListView.builder(
                           itemCount: filtered.length,
                           itemBuilder: (c, i) {
                              final contact = filtered[i];
                              final isSelected = selected.contains(contact);
                              return CheckboxListTile(
                                 value: isSelected,
                                 onChanged: (val) {
                                    setDialogState(() {
                                       if (val == true) {
                                         selected.add(contact);
                                       } else {
                                         selected.remove(contact);
                                       }
                                    });
                                 },
                                 title: Text(contact.displayName),
                                 subtitle: Text(contact.phones.isNotEmpty ? contact.phones.first.number : (contact.emails.isNotEmpty ? contact.emails.first.address : "")),
                              );
                           },
                        ),
                     ),
                     Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text("${selected.length} selected"),
                           TextButton(
                              onPressed: () {
                                 setDialogState(() {
                                    if (selected.length == validContacts.length) {
                                       selected.clear();
                                    } else {
                                       selected = List.from(validContacts);
                                    }
                                 });
                              }, 
                              child: Text(selected.length == validContacts.length ? "Deselect All" : "Select All")
                           )
                        ],
                     )
                  ],
               ),
             ),
             actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                   onPressed: () {
                      _batchAddContacts(selected);
                      Navigator.pop(ctx);
                   }, 
                   child: const Text("Import")
                )
             ],
          );
       }
    ));
  }
  
  Future<void> _batchAddContacts(List<Contact> contacts) async {
     final provider = Provider.of<DashboardProvider>(context, listen: false);
     int added = 0;
     int skipped = 0;
     if (contacts.isNotEmpty) {
        final List<Customer> newCustomers = [];
        for (var c in contacts) {
           String name = c.displayName;
           if (name.isEmpty) name = "Unknown";
           
           String? mobile = c.phones.isNotEmpty ? c.phones.first.number.replaceAll(RegExp(r'\D'), '') : null;
           String email = c.emails.isNotEmpty ? c.emails.first.address : "";
           
           final exists = provider.customers.any((cust) => 
              (mobile != null && cust.mobile?.replaceAll(RegExp(r'\D'), '') == mobile) || 
              (email.isNotEmpty && cust.email == email && email != "")
           );
           
           if (!exists) {
              newCustomers.add(Customer(
                 id: const Uuid().v4(),
                 storeId: provider.activeStoreId!,
                 name: name,
                 mobile: mobile,
                 email: email,
                 tier: 'Regular',
                 totalSpent: 0,
                 loyaltyPoints: 0,
                 joinDate: DateTime.now(),
                 visitCount: 0,
                 lastVisit: DateTime.now(),
              ));
           } else {
              skipped++;
           }
        }
        
        if (newCustomers.isNotEmpty) {
           await provider.addCustomers(newCustomers);
           added = newCustomers.length;
        }
     }
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Imported $added contacts ($skipped skipped)")));
  }
}

class _CustomerScreenData {
  final int customersLength;
  final String? activeStoreId;
  final int customersHash;

  _CustomerScreenData({
    required this.customersLength,
    required this.activeStoreId,
    required this.customersHash,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CustomerScreenData &&
          runtimeType == other.runtimeType &&
          customersLength == other.customersLength &&
          activeStoreId == other.activeStoreId &&
          customersHash == other.customersHash;

  @override
  int get hashCode => Object.hash(customersLength, activeStoreId, customersHash);
}
