import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/orders/domain/usecases/update_order_status_use_case.dart';
import '../providers/dashboard_provider.dart';
import '../models/order_model.dart';
import 'dart:async'; // Add Timer

class KitchenDisplayScreen extends StatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  State<KitchenDisplayScreen> createState() => _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends State<KitchenDisplayScreen> {
  @override
  void initState() {
    super.initState();
    // Removed global timer that hindered performance. Individual tickets track their own time.
  }

  @override
  void dispose() {
    // _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final storeId = provider.activeStoreId;

    if (storeId == null) {
      return Scaffold(
          body: Center(
              child: Text(AppLocalizations.t(
                  context, 'Please select a store first.'))));
    }

    // Stream of Active Orders (New OR Preparing) via Provider/Application layer
    final Stream<List<OrderModel>> ordersStream =
        provider.watchKitchenOrders(storeId);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(AppLocalizations.t(context, 'Kitchen Display System (KDS)')),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: () {}),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return Center(
                child: Text(AppLocalizations.t(context, 'No active orders'),
                    style: TextStyle(
                        fontSize: 24,
                        color: AppColors.textSecondary(context))));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 350,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: orders.length,
            // Use key based on ID to prevent unnecessary rebuilds of inner state
            itemBuilder: (context, index) {
              return OrderTicket(
                  key: ValueKey(orders[index].id), order: orders[index]);
            },
          );
        },
      ),
    );
  }
}

class OrderTicket extends StatefulWidget {
  final OrderModel order;
  const OrderTicket({super.key, required this.order});

  @override
  State<OrderTicket> createState() => _OrderTicketState();
}

class _OrderTicketState extends State<OrderTicket>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Update "Time Ago" every minute
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true; // Prevent rebuild when scrolling off screen

  Future<void> _advanceOrderStatus() async {
    setState(() => _isLoading = true);

    // Asynchronous state transition via Use Case / Outbox pipeline.

    final nextStatus = widget.order.status == 'New' ? 'Preparing' : 'Ready';

    try {
      final dashboardProvider =
          Provider.of<DashboardProvider>(context, listen: false);
      if (dashboardProvider.orderProvider != null) {
        final useCase =
            UpdateOrderStatusUseCase(dashboardProvider.orderProvider!);
        await useCase.execute(UpdateOrderStatusParams(
          orderId: widget.order.id,
          newStatus: nextStatus,
        ));
      } else {
        await dashboardProvider.updateOrderStatus(widget.order.id, nextStatus);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final order = widget.order;
    final duration = DateTime.now().difference(order.date);
    final isLate = duration.inMinutes > 20;

    return Card(
      elevation: 4,
      color: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
              color: isLate
                  ? AppColors.error
                  : (order.status == 'New'
                      ? AppColors.primaryLight
                      : AppColors.warning),
              width: 2)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: isLate
                ? AppColors.error
                : (order.status == 'New'
                    ? AppColors.primaryLight
                    : AppColors.warning),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${order.shortId}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    if (order.tableName != null || order.tableId != null)
                      Text(order.tableName ?? order.tableId!,
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary(context),
                              fontWeight: FontWeight.w500)),
                  ],
                ),
                Text("${duration.inMinutes}m ago",
                    style: TextStyle(
                        color: isLate
                            ? AppColors.error
                            : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: order.items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = order.items[index];
                // Accessing provider here is fine, but for optimization we could pass font size
                final provider =
                    Provider.of<DashboardProvider>(context, listen: false);
                final fontSize = provider.storeSettings?.kds.fontSize ?? 16.0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${item.quantity}x",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: fontSize)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                        child: Text(item.item.name,
                            style: TextStyle(fontSize: fontSize))),
                  ],
                );
              },
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: order.status == 'New'
                      ? AppColors.warning
                      : AppColors.success,
                ),
                onPressed: _isLoading ? null : _advanceOrderStatus,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: AppColors.surfaceLight, strokeWidth: 2))
                    : Text(
                        order.status == 'New'
                            ? 'Start Preparing'
                            : 'Mark Ready',
                        style: const TextStyle(
                            fontSize: 18, color: AppColors.surfaceLight)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
