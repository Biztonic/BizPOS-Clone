import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';

class FranchiseScreen extends StatefulWidget {
  const FranchiseScreen({super.key});

  @override
  State<FranchiseScreen> createState() => _FranchiseScreenState();
}

class _FranchiseScreenState extends State<FranchiseScreen> {
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final isFranchiseOwner = provider.activeRole == 'Franchise Owner';

    // If Super Admin, show Admin View (Placeholder/List)
    if (!isFranchiseOwner) {
       return _buildSuperAdminView(context);
    }

    // --- FRANCHISE OWNER DASHBOARD ---
    final stores = provider.stores; // Already filtered by DashboardProvider for Franchise Owner

    // Calculate Stats
    // Note: We need real sales data. For now, we mock or use what's available in Store model if any. 
    // Since Store model doesn't store 'totalSales', we might need to fetch it or just show 0 for now.
    // Let's assume 0 or random for demo until we hook up Sales Aggregation.
    // Actually, we can check if DashboardProvider has a way to get sales for a store. 
    // It filters orders by active store. To get ALL stores sales, we'd need a separate aggregation query.
    // For this UI implementation, we'll placeholder the values or derive from loaded data if possible.
    
    // Using filtered stores for table
    final filteredStores = stores.where((s) => 
       s.name.toLowerCase().contains(_searchController.text.toLowerCase()) || 
       s.owner.toLowerCase().contains(_searchController.text.toLowerCase())
    ).toList();
    
    // Aggregate Stats (Mocked or Basic Count)
    double totalSales = 0; // Requires backend aggregation
    int totalOrders = 0;   // Requires backend aggregation
    int activeStores = stores.where((s) => s.status == 'Active').length;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Header Card
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(12),
                 boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Row(
                      children: [
                         Container(
                           padding: const EdgeInsets.all(10),
                           decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
                           child: const Icon(Icons.business, color: Colors.purple),
                         ),
                         const SizedBox(width: 16),
                         const Text('Franchise Performance Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Overview of performance for all stores under your franchise.', style: TextStyle(color: Colors.grey)),
                 ],
               ),
             ),
             
             const SizedBox(height: 24),

             // Stats Cards (Row)
             LayoutBuilder(builder: (context, constraints) {
                return Wrap(
                  spacing: 16, 
                  runSpacing: 16,
                  children: [
                    _buildStatCard('Total Stores', stores.length.toString(), Icons.store, Colors.blue, constraints.maxWidth),
                    _buildStatCard('Active Stores', activeStores.toString(), Icons.check_circle, Colors.green, constraints.maxWidth),
                    _buildStatCard('Total Sales (Est)', '₹${totalSales.toStringAsFixed(0)}', Icons.attach_money, Colors.orange, constraints.maxWidth), // Placeholder
                    _buildStatCard('Total Orders (Est)', totalOrders.toString(), Icons.receipt, Colors.teal, constraints.maxWidth), // Placeholder
                  ],
                );
             }),

             const SizedBox(height: 24),

             // Store Performance Section
             Container(
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(12),
                 boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    const Text('Store Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    
                    // Filters
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 800) {
                          // Mobile / Tablet Vertical: Stack them
                          return Column(
                            children: [
                              TextField(
                                 controller: _searchController,
                                 onChanged: (v) => setState((){}),
                                 decoration: InputDecoration(
                                   hintText: 'Filter by Store Name...',
                                   prefixIcon: const Icon(Icons.search),
                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                 ),
                              ),
                              const SizedBox(height: 12),
                              _buildMockDropdown('Filter by Owner...'),
                              const SizedBox(height: 12),
                               TextField(
                                 enabled: false,
                                 decoration: InputDecoration(
                                   hintText: provider.franchises.isNotEmpty ? provider.franchises.first.name : 'Your Franchise',
                                   filled: true,
                                   fillColor: Colors.grey.shade100,
                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                 ),
                               ),
                              const SizedBox(height: 12),
                              _buildMockDropdown('All Statuses'),
                            ],
                          );
                        } else {
                          // Desktop: Row
                          return Row(
                            children: [
                              Expanded(
                                child: TextField(
                                   controller: _searchController,
                                   onChanged: (v) => setState((){}),
                                   decoration: InputDecoration(
                                     hintText: 'Filter by Store Name...',
                                     prefixIcon: const Icon(Icons.search),
                                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                     contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                   ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: _buildMockDropdown('Filter by Owner...')),
                              const SizedBox(width: 16),
                              Expanded(
                                 child: TextField(
                                   enabled: false,
                                   decoration: InputDecoration(
                                     hintText: provider.franchises.isNotEmpty ? provider.franchises.first.name : 'Your Franchise',
                                     filled: true,
                                     fillColor: Colors.grey.shade100,
                                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                     contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                   ),
                                 )
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: _buildMockDropdown('All Statuses')),
                            ],
                          );
                        }
                      }
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Table
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 800), // Ensure it has minimum width so it doesn't squash
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                          columns: const [
                            DataColumn(label: Text('Store Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Owner', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Franchise', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Total Sales', style: TextStyle(fontWeight: FontWeight.bold))), // Fixed 'total' typo
                            DataColumn(label: Text('Total Orders', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filteredStores.isEmpty 
                           ? [
                              const DataRow(cells: [
                                DataCell(Text('No stores found matching your criteria.')), // Spans need custom widget or blank cells
                                DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()), DataCell(SizedBox()),
                              ])
                             ]
                           : filteredStores.map((store) {
                                return DataRow(cells: [
                                   DataCell(Text(store.name)),
                                   DataCell(Text(store.owner)),
                                   DataCell(Text(store.franchiseName ?? '-')),
                                   const DataCell(Text('₹0.00')), // Placeholder until sales aggregated
                                   const DataCell(Text('0')),     // Placeholder
                                   DataCell(_buildStatusBadge(store.status)),
                                ]);
                             }).toList(),
                        ),
                      ),
                    ),
                    
                    // Pagination (Visual)
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(onPressed: null, child: Text('Previous')),
                        SizedBox(width: 12),
                        Text('Page 1 of 1'),
                        SizedBox(width: 12),
                        OutlinedButton(onPressed: null, child: Text('Next')),
                      ],
                    )
                 ],
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double maxWidth) {
      double width = (maxWidth - (24 * 2) - (16 * 3)) / 4; // Approx logic
      if (width < 150) width = (maxWidth - 48) / 2; // Mobile logic
      
      return Container(
        width: width,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.circular(12),
           border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Icon(icon, color: color, size: 20),
             ]),
             const SizedBox(height: 12),
             FittedBox(
               fit: BoxFit.scaleDown,
               alignment: Alignment.centerLeft,
               child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
             ),
          ],
        ),
      );
  }
  
  Widget _buildMockDropdown(String hint) {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12),
       decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
       child: DropdownButtonHideUnderline(
         child: DropdownButton<String>(
           hint: Text(hint, style: const TextStyle(fontSize: 14)),
           items: const [],
           onChanged: null,
         ),
       ),
     );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == 'Active' ? Colors.green : Colors.grey;
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
       decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
       child: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  // --- SUPER ADMIN VIEW (Existing Placeholder) ---
  Widget _buildSuperAdminView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Franchise Management')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Manage Franchises', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Feature Coming Soon', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () {}, child: const Text('Add Franchise'))
          ],
        ),
      ),
    );
  }
}
