import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/subscription_request.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_colors.dart';

class SubscriptionApprovalScreen extends StatefulWidget {
  const SubscriptionApprovalScreen({super.key});

  @override
  State<SubscriptionApprovalScreen> createState() => _SubscriptionApprovalScreenState();
}

class _SubscriptionApprovalScreenState extends State<SubscriptionApprovalScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await Provider.of<DashboardProvider>(context, listen: false).fetchPendingSubscriptions();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final requests = provider.pendingSubscriptions;

    return PosScaffold(
      title: "Pending Subscriptions",
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
          tooltip: "Refresh",
        ),
      ],
      mainContent: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.textSecondary(context).withValues(alpha: 0.3)),
                      const SizedBox(height: AppSpacing.lg),
                      Text("All caught up!", style: AppTypography.titleLarge.copyWith(color: AppColors.textSecondary(context))),
                      const SizedBox(height: AppSpacing.xs),
                      Text("No pending subscription requests at the moment.", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return _buildRequestCard(context, req);
                  },
                ),
    );
  }

  Widget _buildRequestCard(BuildContext context, SubscriptionRequest req) {
    final df = DateFormat('dd MMM yyyy, hh:mm a');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.storeName, style: AppTypography.titleLarge),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(req.ownerEmail, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    req.planType.toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            
            _buildInfoRow(Icons.calendar_month, "Billing Policy", req.billingCycle),
            _buildInfoRow(Icons.payments, "Amount Paid", "₹${req.amount}"),
            _buildInfoRow(Icons.access_time, "Requested On", df.format(req.createdAt)),
            
            const SizedBox(height: AppSpacing.md),
            Text("REQUESTED ADD-ONS", style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context), fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            if (req.selectedAddons.isEmpty)
              Text("None (Base Plan Only)", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context), fontStyle: FontStyle.italic))
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: req.selectedAddons.map((addonKey) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    addonKey.replaceAll('_', ' ').toUpperCase(),
                    style: AppTypography.labelSmall.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                  ),
                )).toList(),
              ),
              
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: "REJECT",
                    onPressed: () => _handleAction(req, false),
                    variant: AppButtonVariant.outline,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: "APPROVE & ACTIVATE",
                    onPressed: () => _handleAction(req, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary(context).withValues(alpha: 0.5)),
          const SizedBox(width: AppSpacing.sm),
          Text("$label: ", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
          Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _handleAction(SubscriptionRequest req, bool approve) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? "Approve Subscription?" : "Reject Subscription?", style: AppTypography.titleLarge),
        content: Text(approve 
          ? "This will activate the Standard plan for ${req.storeName}. Please ensure payment is verified." 
          : "Are you sure you want to reject this request?",
          style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("CANCEL", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
          ),
          AppButton(
            label: approve ? "CONFIRM" : "REJECT",
            onPressed: () => Navigator.pop(ctx, true),
            variant: approve ? AppButtonVariant.primary : AppButtonVariant.outline,
          ),
        ],
      ),
    );
 
    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        if (approve) {
          await provider.approveSubscriptionRequest(req);
        } else {
          await provider.rejectSubscriptionRequest(req);
        }
        
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text(approve ? "Subscription Approved!" : "Subscription Rejected", style: const TextStyle(color: Colors.white)), 
          backgroundColor: approve ? AppColors.success : AppColors.error,
        ));
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text("Error: $e", style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.error,
          ));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
