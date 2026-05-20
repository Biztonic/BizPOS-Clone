import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

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
import '../core/design/design_system.dart';

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
                   backgroundColor: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                   child: Text(
                     c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                     style: AppTypography.headlineMedium.copyWith(color: AppColors.adaptivePrimary(context)),
                   ),
                 ),
                 const SizedBox(height: AppSpacing.md),
                 Text(c.name, style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold)),
                 const SizedBox(height: AppSpacing.xs),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.xs),
                   decoration: BoxDecoration(
                     color: AppColors.adaptiveWarning(context).withValues(alpha: 0.1),
                     borderRadius: AppRadius.borderSm,
                   ),
                   child: Text(
                     c.tier.toUpperCase(),
                     style: AppTypography.labelSmall.copyWith(color: AppColors.adaptiveWarning(context), fontWeight: FontWeight.bold, letterSpacing: 1.2),
                   ),
                 ),
                 
                 const SizedBox(height: AppSpacing.xl),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                      _buildStatItem("Visits", "${c.visitCount}", AppColors.adaptivePrimary(context)),
                      Container(height: 30, width: 1, color: AppColors.border(context)),
                      _buildStatItem("Spent", "\$${c.totalSpent.toStringAsFixed(0)}", AppColors.adaptiveSuccess(context)),
                      Container(height: 30, width: 1, color: AppColors.border(context)),
                      _buildStatItem("Points", "${c.loyaltyPoints}", AppColors.adaptiveWarning(context)),
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
                 Text(AppLocalizations.t(context, 'Loyalty & Rewards'), style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                 const SizedBox(height: AppSpacing.md),
                 ListTile(
                   contentPadding: EdgeInsets.zero,
                   leading: Container(
                     padding: const EdgeInsets.all(AppSpacing.sm),
                     decoration: BoxDecoration(color: AppColors.adaptiveWarning(context).withValues(alpha: 0.1), borderRadius: AppRadius.borderMd),
                     child: Icon(Icons.stars, color: AppColors.adaptiveWarning(context)),
                   ),
                   title: Text("${c.loyaltyPoints} Coins Available", style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                   subtitle: Text(AppLocalizations.t(context, 'Redeemable against next bill'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                   trailing: AppButton.secondary(
                     onPressed: () => _showTopUpDialog(c, provider),
                     label: "Manage",
                   ),
                 ),
                 const Divider(height: AppSpacing.lg),
                 ListTile(
                   contentPadding: EdgeInsets.zero,
                   leading: Container(
                     padding: const EdgeInsets.all(AppSpacing.sm),
                     decoration: BoxDecoration(color: AppColors.adaptiveError(context).withValues(alpha: 0.1), borderRadius: AppRadius.borderMd),
                     child: Icon(Icons.local_offer, color: AppColors.adaptiveError(context)),
                   ),
                   title: Text(AppLocalizations.t(context, 'Active Coupons'), style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                   subtitle: Text(AppLocalizations.t(context, 'No active coupons found'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                   trailing: TextButton(onPressed: (){}, child: Text(AppLocalizations.t(context, 'View All'), style: TextStyle(color: AppColors.adaptivePrimary(context)))),
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
                 Text(AppLocalizations.t(context, 'Contact Information'), style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
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
                    Text(AppLocalizations.t(context, 'No purchase history found'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
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
                             padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                             decoration: BoxDecoration(
                               color: _getStatusColor(context, order.status).withValues(alpha: 0.1),
                               borderRadius: AppRadius.borderSm,
                             ),
                             child: Text(
                               order.status.toUpperCase(),
                               style: AppTypography.labelSmall.copyWith(
                                 color: _getStatusColor(context, order.status),
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
                             style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.adaptiveSuccess(context)),
                           ),
                        ],
                      ),
                      const Divider(height: AppSpacing.lg),
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textSecondary(context)),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            "${order.items.length} Items • ${order.type}",
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {}, // Link to order detail
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: Text(AppLocalizations.t(context, 'View Bill'), style: AppTypography.labelMedium.copyWith(color: AppColors.adaptivePrimary(context))),
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

  Color _getStatusColor(BuildContext context, String status) {
    switch (status) {
      case 'Completed': return AppColors.adaptiveSuccess(context);
      case 'Refunded': return AppColors.adaptiveError(context);
      case 'Cancelled': return AppColors.adaptiveError(context);
      case 'Prepare': return AppColors.adaptiveWarning(context);
      case 'Ready': return AppColors.adaptivePrimary(context);
      default: return AppColors.textSecondary(context);
    }
  }

  Widget _buildStatItem(String label, String val, Color? color) {
    return Column(
      children: [
        Text(val, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: AppSpacing.xs),
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
             padding: const EdgeInsets.all(AppSpacing.sm),
             decoration: BoxDecoration(
               color: AppColors.background(context),
               borderRadius: AppRadius.borderMd,
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
           title: Text(AppLocalizations.t(context, 'Adjust Loyalty Coins'), style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold)),
           shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
           content: AppTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              label: "Coins to Add (or - to remove)",
              prefixIcon: const Icon(Icons.stars_outlined),
           ),
           actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.t(context, 'Cancel'), style: TextStyle(color: AppColors.textSecondary(context))),
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




