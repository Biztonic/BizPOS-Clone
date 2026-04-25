import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/subscription_request.dart';
import 'package:intl/intl.dart';

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
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final requests = provider.pendingSubscriptions;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending Subscriptions"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty 
              ? const Center(child: Text("No pending subscription requests"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.storeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(req.ownerEmail, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(req.planType, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_month, "Billing Policy", req.billingCycle),
            _buildInfoRow(Icons.payments, "Amount Paid", "₹${req.amount}"),
            _buildInfoRow(Icons.access_time, "Requested On", df.format(req.createdAt)),
            const SizedBox(height: 12),
            const Text("Requested Add-ons:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 6),
            if (req.selectedAddons.isEmpty)
              const Text("None (Base Plan Only)", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: req.selectedAddons.map((addonKey) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.teal.withValues(alpha: 0.2))),
                  child: Text(
                    addonKey.replaceAll('_', ' ').toUpperCase(), 
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                )).toList(),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleAction(req, false),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text("REJECT"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAction(req, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    child: const Text("APPROVE & ACTIVATE"),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
        title: Text(approve ? "Approve Subscription?" : "Reject Subscription?"),
        content: Text(approve 
          ? "This will activate the Standard plan for ${req.storeName}. Please ensure payment is verified in your bank/UPI account." 
          : "Are you sure you want to reject this request?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: approve ? Colors.green : Colors.red, foregroundColor: Colors.white),
            child: Text(approve ? "CONFIRM" : "REJECT"),
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
          content: Text(approve ? "Subscription Approved!" : "Subscription Rejected"), 
          backgroundColor: approve ? Colors.green : Colors.black
        ));
        
        // No need for _refresh() here as DashboardProvider.approveSubscriptionRequest 
        // already updates its internal state and notifies listeners.
      } catch (e) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}
