import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../models/customer.dart';
import '../models/order_model.dart';
import 'add_edit_customer_screen.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/tokens/app_colors.dart';

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
    
    // Find latest customer data from provider to keep stats in sync
    final customer = provider.customers.firstWhere((c) => c.id == widget.customer.id, orElse: () => widget.customer);
    
    return PosScaffold(
      title: customer.name,
      actions: [
        AppButton.secondary(
          icon: Icons.edit_outlined,
          label: "Edit",
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddEditCustomerScreen(customer: customer))),
        ),
      ],
      mainContent: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "Overview"),
              Tab(text: "Bill History"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(customer, provider),
                _buildHistoryTab(customer, provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Customer c, DashboardProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Profile Card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                 CircleAvatar(
                   radius: 40,
                   backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                   child: Text(
                     c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                     style: AppTypography.headlineMedium.copyWith(color: AppColors.primary),
                   ),
                 ),
                 const SizedBox(height: AppSpacing.md),
                 Text(c.name, style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 4),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                   decoration: BoxDecoration(
                     color: AppColors.warning.withValues(alpha: 0.1),
                     borderRadius: BorderRadius.circular(20),
                   ),
                   child: Text(
                     c.tier.toUpperCase(),
                     style: AppTypography.labelSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                   ),
                 ),
                 
                 const SizedBox(height: AppSpacing.xl),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                      _buildStatItem("Visits", "${c.visitCount}", AppColors.primary),
                      Container(height: 30, width: 1, color: AppColors.border(context)),
                      _buildStatItem("Spent", "\$${c.totalSpent.toStringAsFixed(0)}", AppColors.success),
                      Container(height: 30, width: 1, color: AppColors.border(context)),
                      _buildStatItem("Points", "${c.loyaltyPoints}", AppColors.warning),
                   ],
                 )
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Loyalty & Coupons
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Loyalty & Rewards", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                 const SizedBox(height: AppSpacing.md),
                 ListTile(
                   contentPadding: EdgeInsets.zero,
                   leading: Container(
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                     child: const Icon(Icons.stars, color: AppColors.warning),
                   ),
                   title: Text("${c.loyaltyPoints} Coins Available", style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                   subtitle: Text("Redeemable against next bill", style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                   trailing: AppButton.secondary(
                     onPressed: () => _showTopUpDialog(c, provider),
                     label: "Manage",
                   ),
                 ),
                 const Divider(height: AppSpacing.lg),
                 ListTile(
                   contentPadding: EdgeInsets.zero,
                   leading: Container(
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                     child: const Icon(Icons.local_offer, color: AppColors.error),
                   ),
                   title: Text("Active Coupons", style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                   subtitle: Text("No active coupons found", style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                   trailing: TextButton(onPressed: (){}, child: Text("View All", style: TextStyle(color: AppColors.primary))),
                 )
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.md),
          
          // Contact Info
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Contact Information", style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                 const SizedBox(height: AppSpacing.md),
                 _buildInfoRow(Icons.phone_outlined, c.mobile ?? c.phone ?? 'Not set'),
                 _buildInfoRow(Icons.email_outlined, c.email.isNotEmpty ? c.email : 'Not set'),
                 _buildInfoRow(Icons.location_on_outlined, c.billingAddress ?? 'Not set'),
                 _buildInfoRow(Icons.calendar_today_outlined, "Joined ${DateFormat('dd MMM yyyy').format(c.joinDate)}"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(Customer c, DashboardProvider provider) {
     return FutureBuilder<List<OrderModel>>(
       future: provider.fetchCustomerOrders(c.id), 
       builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    Icon(Icons.receipt_long, size: 80, color: AppColors.border(context)),
                    const SizedBox(height: AppSpacing.md),
                    Text("No purchase history found", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
                 ],
               ),
             );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (ctx, i) {
               final order = orders[i];
               return AppCard(
                 padding: const EdgeInsets.all(AppSpacing.md),
                 child: Column(
                   children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text(
                             DateFormat('dd MMM yyyy, hh:mm a').format(order.date),
                             style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)),
                           ),
                           Container(
                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                             decoration: BoxDecoration(
                               color: _getStatusColor(order.status).withValues(alpha: 0.1),
                               borderRadius: BorderRadius.circular(4),
                             ),
                             child: Text(
                               order.status.toUpperCase(),
                               style: AppTypography.labelSmall.copyWith(
                                 color: _getStatusColor(order.status),
                                 fontWeight: FontWeight.bold,
                                 fontSize: 9,
                               ),
                             ),
                           )
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text(
                             "#${order.id.substring(0, 8).toUpperCase()}",
                             style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                           ),
                           Text(
                             "\$${order.total.toStringAsFixed(2)}",
                             style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.success),
                           ),
                        ],
                      ),
                      const Divider(height: AppSpacing.lg),
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textSecondary(context)),
                          const SizedBox(width: 4),
                          Text(
                            "${order.items.length} Items • ${order.type}",
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {}, // Link to order detail
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: Text("View Bill", style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
                          )
                        ],
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
      case 'Completed': return AppColors.success;
      case 'Refunded': return AppColors.error;
      case 'Cancelled': return AppColors.error;
      case 'Prepare': return AppColors.warning;
      case 'Ready': return AppColors.primary;
      default: return AppColors.secondary;
    }
  }

  Widget _buildStatItem(String label, String val, Color? color) {
    return Column(
      children: [
        Text(val, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
      ],
    );
  }
  
  Widget _buildInfoRow(IconData icon, String text) {
     return Padding(
       padding: const EdgeInsets.only(bottom: AppSpacing.md),
       child: Row(
         children: [
           Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(
               color: AppColors.background(context),
               borderRadius: BorderRadius.circular(8),
             ),
             child: Icon(icon, size: 18, color: AppColors.textSecondary(context)),
           ),
           const SizedBox(width: AppSpacing.md),
           Expanded(child: Text(text, style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w500)))
         ],
       ),
     );
  }

  void _showTopUpDialog(Customer c, DashboardProvider provider) {
     final controller = TextEditingController();
     showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
           title: Text("Adjust Loyalty Coins", style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           content: AppTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              label: "Coins to Add (or - to remove)",
              prefixIcon: const Icon(Icons.stars_outlined),
           ),
           actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Cancel", style: TextStyle(color: AppColors.textSecondary(context))),
              ),
              AppButton.primary(
                 onPressed: () {
                    final points = int.tryParse(controller.text) ?? 0;
                    if (points != 0) {
                       provider.updateCustomerLoyalty(c.id, points);
                    }
                    Navigator.pop(ctx);
                 }, 
                 label: "Update"
              ),
           ],
        )
     );
  }
}
