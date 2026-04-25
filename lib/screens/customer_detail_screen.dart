import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../models/customer.dart';
import '../models/order_model.dart';
import 'add_edit_customer_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Find latest customer data from provider to keep stats in sync
    final customer = provider.customers.firstWhere((c) => c.id == widget.customer.id, orElse: () => widget.customer);
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(customer.name),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
        titleTextStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCustomerScreen(customer: customer))),
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Bill History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
           _buildOverviewTab(customer, provider, isDarkMode),
           _buildHistoryTab(customer, provider, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Customer c, DashboardProvider provider, bool isDark) {
    final cardColor = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                 CircleAvatar(
                   radius: 40,
                   backgroundColor: Colors.blue.shade100,
                   child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: TextStyle(fontSize: 32, color: Colors.blue.shade800)),
                 ),
                 const SizedBox(height: 16),
                 Text(c.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                 Text(c.tier.toUpperCase(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                 
                 const SizedBox(height: 24),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                      _buildStatItem("Visits", "${c.visitCount}", textColor),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      _buildStatItem("Spent", "₹${c.totalSpent.toStringAsFixed(0)}", textColor),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      _buildStatItem("Points", "${c.loyaltyPoints}", Colors.green),
                   ],
                 )
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Loyalty & Coupons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Loyalty & Rewards", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                 const SizedBox(height: 16),
                 ListTile(
                   contentPadding: EdgeInsets.zero,
                   leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.stars, color: Colors.orange)),
                   title: Text("${c.loyaltyPoints} Coins Available", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                   subtitle: const Text("Redeemable against next bill"),
                   trailing: ElevatedButton(
                     onPressed: () => _showTopUpDialog(c, provider),
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                     child: const Text("Manage"),
                   ),
                 ),
                 const Divider(),
                 ListTile(
                   contentPadding: EdgeInsets.zero,
                   leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.pink.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.local_offer, color: Colors.pink)),
                   title: Text("Active Coupons", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                   subtitle: const Text("No active coupons found"), // Placeholder
                   trailing: TextButton(onPressed: (){}, child: const Text("View All")),
                 )
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Contact Info
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Contact Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                 const SizedBox(height: 16),
                 _buildInfoRow(Icons.phone, c.mobile ?? c.phone ?? 'Not set', textColor),
                 _buildInfoRow(Icons.email, c.email.isNotEmpty ? c.email : 'Not set', textColor),
                 _buildInfoRow(Icons.location_on, c.billingAddress ?? 'Not set', textColor),
                 _buildInfoRow(Icons.calendar_today, "Joined ${DateFormat('dd MMM yyyy').format(c.joinDate)}", textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Customer c, DashboardProvider provider, bool isDark) {
     return FutureBuilder<List<OrderModel>>(
       future: provider.fetchCustomerOrders(c.id), 
       builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final orders = snapshot.data ?? [];
          
          // Sort handled by SQL, but safe to ensure fallback
          // orders.sort((a,b) => b.date.compareTo(a.date));

          if (orders.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    Icon(Icons.receipt_long, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text("No purchase history found", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey)),
                 ],
               ),
             );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
               final order = orders[i];
               return Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                   borderRadius: BorderRadius.circular(12),
                   boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))]
                 ),
                 child: Column(
                   children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text(DateFormat('dd MMM yyyy, hh:mm a').format(order.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                           Chip(
                             label: Text(order.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                             backgroundColor: _getStatusColor(order.status),
                             padding: EdgeInsets.zero,
                             materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                           )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text("#${order.id.substring(0, 8).toUpperCase()}", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                           Text("₹${order.total.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.greenAccent : Colors.green)),
                        ],
                      ),
                      const Divider(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text("${order.items.length} Items • ${order.type}", style: const TextStyle(fontSize: 12, color: Colors.grey))
                      )
                   ],
                 ),
               );
            },
          );
       },
     );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed': return Colors.green;
      case 'Refunded': return Colors.red;
      case 'Cancelled': return Colors.red;
      case 'Prepare': return Colors.orange;
      case 'Ready': return Colors.blue;
      default: return Colors.grey;
    }
  }

  Widget _buildStatItem(String label, String val, Color? color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
  
  Widget _buildInfoRow(IconData icon, String text, Color textColor) {
     return Padding(
       padding: const EdgeInsets.only(bottom: 12),
       child: Row(
         children: [
           Icon(icon, size: 18, color: Colors.grey),
           const SizedBox(width: 12),
           Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: textColor)))
         ],
       ),
     );
  }

  void _showTopUpDialog(Customer c, DashboardProvider provider) {
     final controller = TextEditingController();
     showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
           title: const Text("Adjust Loyalty Coins"),
           content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Coins to Add (or - to remove)"),
           ),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
              TextButton(
                 onPressed: () {
                    final points = int.tryParse(controller.text) ?? 0;
                    if (points != 0) {
                       provider.updateCustomerLoyalty(c.id, points);
                    }
                    Navigator.pop(ctx);
                 }, 
                 child: const Text("UPDATE")
              ),
           ],
        )
     );
  }
}
