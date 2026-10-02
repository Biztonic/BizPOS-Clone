import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/dashboard_provider.dart';
import '../models/customer.dart';
import '../models/customer_crm_models.dart';
import '../models/order_model.dart';
import 'add_edit_customer_screen.dart';
import '../widgets/customer_whatsapp_dialog.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/design_system.dart';
import '../features/store/domain/entities/settings.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final cs = provider.activeStore?.customerSettings ?? const CustomerAddonSettings();

    // Keep active customer in sync with provider memory
    final customer = provider.customers.firstWhere(
      (c) => c.id == widget.customer.id,
      orElse: () => widget.customer,
    );

    final tabs = <Widget>[
      const Tab(icon: Icon(Icons.person_outline, size: 18), text: "Overview"),
      const Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: "Bills & Transactions"),
      Tab(
        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Udhari (Khata)"),
            if (customer.udhariBalance > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveError(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "₹${customer.udhariBalance.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
      const Tab(icon: Icon(Icons.stars_outlined, size: 18), text: "Loyalty & Points"),
      const Tab(icon: Icon(Icons.card_giftcard_outlined, size: 18), text: "Coupons & Gifts"),
    ];

    final tabViews = <Widget>[
      _buildOverviewTab(customer, provider, cs: cs),
      _buildTransactionsTab(customer, provider),
      _buildUdhariTab(customer, provider),
      _buildLoyaltyTab(customer, provider, cs: cs),
      _buildCouponsAndGiftsTab(customer, provider),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: PosScaffold(
        showSidebar: false,
        title: customer.name,
        actions: [
          AppButton.secondary(
            icon: Icons.chat_outlined,
            label: "WhatsApp Hub",
            onPressed: () => CustomerWhatsAppDialog.show(
              context,
              customer: customer,
              provider: provider,
              initialCategory: customer.udhariBalance > 0
                  ? WhatsAppTemplateCategory.udhariDue
                  : WhatsAppTemplateCategory.promotions,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppButton.secondary(
            icon: Icons.edit_outlined,
            label: "Edit",
            onPressed: () => AddEditCustomerScreen.showAsDialog(context, customer: customer),
          ),
        ],
        mainContent: Column(
          children: [
            Container(
              color: AppColors.surface(context),
              child: TabBar(
                isScrollable: true,
                labelColor: AppColors.adaptivePrimary(context),
                unselectedLabelColor: AppColors.textSecondary(context),
                indicatorColor: AppColors.adaptivePrimary(context),
                tabs: tabs,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: tabViews,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: OVERVIEW & PROFILE
  // ─────────────────────────────────────────────────────────────

  Widget _buildOverviewTab(Customer c, DashboardProvider provider, {required CustomerAddonSettings cs}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor:
                          AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: AppTypography.headlineMedium
                            .copyWith(color: AppColors.adaptivePrimary(context)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c.name,
                                  style: AppTypography.headlineSmall
                                      .copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _getTierColor(c.tier).withValues(alpha: 0.15),
                                  borderRadius: AppRadius.borderSm,
                                  border: Border.all(
                                      color: _getTierColor(c.tier).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  c.tier.toUpperCase(),
                                  style: TextStyle(
                                    color: _getTierColor(c.tier),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Customer since ${DateFormat('dd MMM yyyy').format(c.joinDate)}",
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary(context)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.mobile?.isNotEmpty == true
                                ? c.mobile!
                                : (c.phone ?? (c.email.isNotEmpty ? c.email : 'No Phone')),
                            style: AppTypography.bodyMedium
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                // Key Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: "Udhari Balance (Due)",
                        value: "₹${c.udhariBalance.toStringAsFixed(0)}",
                        subtitle: c.creditLimit > 0
                            ? "Limit: ₹${c.creditLimit.toStringAsFixed(0)}"
                            : "No Limit Set",
                        color: c.udhariBalance > 0
                            ? AppColors.adaptiveError(context)
                            : AppColors.adaptiveSuccess(context),
                        icon: Icons.account_balance_wallet,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildMetricCard(
                        title: "Loyalty Coins",
                        value: "${c.loyaltyPoints} pts",
                        subtitle: "₹${(c.loyaltyPoints * cs.pointRedemptionValue).toStringAsFixed(0)} value",
                        color: AppColors.adaptiveWarning(context),
                        icon: Icons.stars,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildMetricCard(
                        title: "Total Spent",
                        value: "₹${c.totalSpent.toStringAsFixed(0)}",
                        subtitle: "Lifetime purchases",
                        color: AppColors.adaptivePrimary(context),
                        icon: Icons.shopping_bag,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _buildMetricCard(
                        title: "Total Visits",
                        value: "${c.visitCount}",
                        subtitle: "Completed orders",
                        color: AppColors.adaptiveInfo(context),
                        icon: Icons.receipt_long,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Quick Action Hub
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, color: AppColors.adaptiveWarning(context), size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      "Quick Actions",
                      style: AppTypography.titleMedium
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: [
                    AppButton.danger(
                      icon: Icons.add_circle_outline,
                      label: "+ Give Credit (Udhari)",
                      onPressed: () => _showAddUdhariDialog(context, c, provider, isBorrow: true),
                    ),
                    AppButton.primary(
                      icon: Icons.check_circle_outline,
                      label: "✓ Collect Payment (Settle)",
                      onPressed: () => _showAddUdhariDialog(context, c, provider, isBorrow: false),
                    ),
                    AppButton.secondary(
                      icon: Icons.chat_outlined,
                      label: "WhatsApp Reminder / Offers",
                      onPressed: () => CustomerWhatsAppDialog.show(
                        context,
                        customer: c,
                        provider: provider,
                        initialCategory: c.udhariBalance > 0
                            ? WhatsAppTemplateCategory.udhariDue
                            : WhatsAppTemplateCategory.promotions,
                      ),
                    ),
                    AppButton.secondary(
                      icon: Icons.stars_outlined,
                      label: "Adjust Loyalty Points",
                      onPressed: () => _showAdjustPointsDialog(context, c, provider),
                    ),
                    AppButton.secondary(
                      icon: Icons.local_offer_outlined,
                      label: "Issue Coupon",
                      onPressed: () => _showIssueCouponDialog(context, c, provider),
                    ),
                    AppButton.secondary(
                      icon: Icons.card_giftcard_outlined,
                      label: "Issue Gift Voucher",
                      onPressed: () => _showIssueGiftDialog(context, c, provider),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Contact & Business Information
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t(context, 'Contact & Business Details'),
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildInfoRow(Icons.phone_outlined, "Mobile / WhatsApp",
                    c.mobile ?? c.phone ?? 'Not specified'),
                _buildInfoRow(Icons.email_outlined, "Email Address",
                    c.email.isNotEmpty ? c.email : 'Not specified'),
                _buildInfoRow(Icons.location_on_outlined, "Billing Address",
                    c.billingAddress?.isNotEmpty == true ? c.billingAddress! : 'Not specified'),
                _buildInfoRow(Icons.receipt_outlined, "GST / Tax ID",
                    c.taxNumber?.isNotEmpty == true ? c.taxNumber! : 'Not specified'),
                _buildInfoRow(Icons.credit_card_outlined, "Credit Limit",
                    c.creditLimit > 0 ? "₹${c.creditLimit.toStringAsFixed(0)}" : "No Limit Set"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: BILLS & TRANSACTIONS
  // ─────────────────────────────────────────────────────────────

  Widget _buildTransactionsTab(Customer c, DashboardProvider provider) {
    return FutureBuilder<List<OrderModel>>(
      future: provider.fetchCustomerOrders(c.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 70, color: AppColors.border(context)),
                  const SizedBox(height: AppSpacing.md),
                  Text("No Order History Yet",
                      style: AppTypography.titleMedium
                          .copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    "Orders placed with this customer's profile will automatically show here.",
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (ctx, i) {
            final order = orders[i];
            return AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "#${order.shortId}",
                            style: AppTypography.titleMedium
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getOrderStatusColor(order.status).withValues(alpha: 0.1),
                              borderRadius: AppRadius.borderSm,
                            ),
                            child: Text(
                              order.status.toUpperCase(),
                              style: TextStyle(
                                color: _getOrderStatusColor(order.status),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "₹${order.total.toStringAsFixed(2)}",
                        style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.adaptiveSuccess(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(order.date),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary(context)),
                  ),
                  const Divider(height: AppSpacing.md),
                  Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 15, color: AppColors.textSecondary(context)),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        "${order.items.length} Items • ${order.paymentMethod.isNotEmpty ? order.paymentMethod : 'Cash'}",
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary(context)),
                      ),
                      const Spacer(),
                      AppButton.secondary(
                        icon: Icons.visibility_outlined,
                        label: "View Bill",
                        onPressed: () => _showBillDetailsModal(context, order),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: UDHARI (CUSTOMER KHATA / BORROW LEDGER)
  // ─────────────────────────────────────────────────────────────

  Widget _buildUdhariTab(Customer c, DashboardProvider provider) {
    return FutureBuilder<List<UdhariTransaction>>(
      future: provider.getUdhariTransactions(c.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final txs = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Khata Summary Banner
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Outstanding Udhari (Khata Due)",
                              style: AppTypography.labelMedium
                                  .copyWith(color: AppColors.textSecondary(context)),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              "₹${c.udhariBalance.toStringAsFixed(0)}",
                              style: AppTypography.headlineMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: c.udhariBalance > 0
                                    ? AppColors.adaptiveError(context)
                                    : AppColors.adaptiveSuccess(context),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            AppButton.danger(
                              icon: Icons.add,
                              label: "+ Add Borrow",
                              onPressed: () => _showAddUdhariDialog(context, c, provider, isBorrow: true),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            AppButton.primary(
                              icon: Icons.check,
                              label: "✓ Settle Payment",
                              onPressed: () => _showAddUdhariDialog(context, c, provider, isBorrow: false),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (c.creditLimit > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Credit Limit: ₹${c.creditLimit.toStringAsFixed(0)}",
                              style: AppTypography.bodySmall),
                          Text(
                            "Available: ₹${(c.creditLimit - c.udhariBalance).clamp(0, double.infinity).toStringAsFixed(0)}",
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: (c.creditLimit - c.udhariBalance) < 0
                                  ? AppColors.adaptiveError(context)
                                  : AppColors.adaptiveSuccess(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: c.creditLimit > 0
                              ? (c.udhariBalance / c.creditLimit).clamp(0.0, 1.0)
                              : 0.0,
                          backgroundColor: AppColors.border(context),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            c.udhariBalance > c.creditLimit
                                ? AppColors.adaptiveError(context)
                                : AppColors.adaptiveWarning(context),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Ledger Transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Credit Ledger History (${txs.length} entries)",
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.chat_outlined, size: 16),
                    label: const Text("WhatsApp Hub"),
                    onPressed: () => CustomerWhatsAppDialog.show(
                      context,
                      customer: c,
                      provider: provider,
                      initialCategory: c.udhariBalance > 0
                          ? WhatsAppTemplateCategory.udhariDue
                          : WhatsAppTemplateCategory.paymentReceived,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              if (txs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 50, color: AppColors.border(context)),
                        const SizedBox(height: AppSpacing.sm),
                        const Text("No Udhari ledger transactions recorded yet."),
                        const SizedBox(height: AppSpacing.md),
                        AppButton.secondary(
                          label: "+ Record First Borrow / Payment",
                          onPressed: () => _showAddUdhariDialog(context, c, provider, isBorrow: true),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...txs.map((tx) {
                  final isBorrow = tx.type == 'borrow';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: (isBorrow
                                      ? AppColors.adaptiveError(context)
                                      : AppColors.adaptiveSuccess(context))
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isBorrow ? Icons.arrow_upward : Icons.arrow_downward,
                              color: isBorrow
                                  ? AppColors.adaptiveError(context)
                                  : AppColors.adaptiveSuccess(context),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isBorrow ? "Credit Taken (Borrow)" : "Payment Received (Settle)",
                                      style: AppTypography.bodyMedium
                                          .copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    if (tx.paymentMode?.isNotEmpty == true) ...[
                                      const SizedBox(width: AppSpacing.xs),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.background(context),
                                          borderRadius: AppRadius.borderSm,
                                        ),
                                        child: Text(
                                          tx.paymentMode!,
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context)),
                                        ),
                                      ),
                                    ],
                                    if (tx.referenceId?.isNotEmpty == true) ...[
                                      const SizedBox(width: AppSpacing.xs),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceVariant(context),
                                          borderRadius: AppRadius.borderSm,
                                        ),
                                        child: Text(
                                          "Ref: #${tx.referenceId!.length > 8 ? tx.referenceId!.substring(0, 8).toUpperCase() : tx.referenceId!.toUpperCase()}",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.adaptivePrimary(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(tx.date),
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textSecondary(context)),
                                ),
                                if (tx.notes?.isNotEmpty == true) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "Note: ${tx.notes}",
                                    style: AppTypography.bodySmall
                                        .copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "${isBorrow ? '+' : '-'}₹${tx.amount.toStringAsFixed(0)}",
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isBorrow
                                      ? AppColors.adaptiveError(context)
                                      : AppColors.adaptiveSuccess(context),
                                ),
                              ),
                              Text(
                                "Bal: ₹${tx.balanceAfter.toStringAsFixed(0)}",
                                style: AppTypography.bodySmall
                                    .copyWith(color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 4: LOYALTY & POINTS
  // ─────────────────────────────────────────────────────────────

  Widget _buildLoyaltyTab(Customer c, DashboardProvider provider, {required CustomerAddonSettings cs}) {
    return FutureBuilder<List<LoyaltyTransaction>>(
      future: provider.getLoyaltyHistory(c.id),
      builder: (context, snapshot) {
        final txs = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Points Balance Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.adaptiveWarning(context).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.stars, size: 36, color: AppColors.adaptiveWarning(context)),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${c.loyaltyPoints} Loyalty Coins",
                                  style: AppTypography.headlineSmall
                                      .copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Worth ₹${(c.loyaltyPoints * cs.pointRedemptionValue).toStringAsFixed(1)} • Redeemable on next bill",
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textSecondary(context)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            AppButton.secondary(
                              icon: Icons.chat_outlined,
                              label: "Share Balance",
                              onPressed: () => CustomerWhatsAppDialog.show(
                                context,
                                customer: c,
                                provider: provider,
                                initialCategory: WhatsAppTemplateCategory.loyalty,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            AppButton.primary(
                              icon: Icons.stars_outlined,
                              label: "+ Adjust Points",
                              onPressed: () => _showAdjustPointsDialog(context, c, provider),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    // Tier Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Current Tier: ${c.tier.toUpperCase()}",
                            style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                        Text("Next Tier: ${_getNextTier(c.tier)}",
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _getTierProgress(c.loyaltyPoints),
                        backgroundColor: AppColors.border(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.adaptiveWarning(context)),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Points History
              Text(
                "Loyalty Points History",
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),

              if (txs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        Icon(Icons.stars_outlined, size: 48, color: AppColors.border(context)),
                        const SizedBox(height: AppSpacing.sm),
                        const Text("No points transactions recorded yet."),
                        const SizedBox(height: AppSpacing.md),
                        AppButton.secondary(
                          label: "+ Add Bonus Points",
                          onPressed: () => _showAdjustPointsDialog(context, c, provider),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...txs.map((tx) {
                  final isEarned = tx.type == 'earned' || tx.points > 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(
                            isEarned ? Icons.add_circle_outline : Icons.remove_circle_outline,
                            color: isEarned
                                ? AppColors.adaptiveSuccess(context)
                                : AppColors.adaptiveError(context),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tx.reason,
                                    style: AppTypography.bodyMedium
                                        .copyWith(fontWeight: FontWeight.bold)),
                                Text(
                                  DateFormat('dd MMM yyyy, hh:mm a').format(tx.date),
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "${isEarned ? '+' : ''}${tx.points} pts",
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isEarned
                                      ? AppColors.adaptiveSuccess(context)
                                      : AppColors.adaptiveError(context),
                                ),
                              ),
                              Text("Bal: ${tx.balanceAfter} pts",
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textSecondary(context))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 5: COUPONS & GIFTS
  // ─────────────────────────────────────────────────────────────

  Widget _buildCouponsAndGiftsTab(Customer c, DashboardProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section: Coupons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_offer, color: AppColors.adaptiveError(context), size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    "Customer Coupons",
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  AppButton.secondary(
                    icon: Icons.chat_outlined,
                    label: "Share Offers",
                    onPressed: () => CustomerWhatsAppDialog.show(
                      context,
                      customer: c,
                      provider: provider,
                      initialCategory: WhatsAppTemplateCategory.promotions,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton.primary(
                    icon: Icons.add,
                    label: "+ Issue Coupon",
                    onPressed: () => _showIssueCouponDialog(context, c, provider),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<List<CustomerCoupon>>(
            future: provider.getCustomerCoupons(c.id),
            builder: (ctx, snapshot) {
              final coupons = snapshot.data ?? [];
              if (coupons.isEmpty) {
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.confirmation_number_outlined,
                            size: 40, color: AppColors.border(context)),
                        const SizedBox(height: AppSpacing.xs),
                        const Text("No active coupons issued to this customer."),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: coupons.map((coupon) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                              borderRadius: AppRadius.borderSm,
                              border: Border.all(
                                  color: AppColors.adaptivePrimary(context).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              coupon.code,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: AppColors.adaptivePrimary(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(coupon.title,
                                    style: AppTypography.bodyMedium
                                        .copyWith(fontWeight: FontWeight.bold)),
                                Text(
                                  coupon.discountType == 'percentage'
                                      ? "${coupon.discountValue.toStringAsFixed(0)}% Discount"
                                      : "₹${coupon.discountValue.toStringAsFixed(0)} OFF",
                                  style: TextStyle(
                                      color: AppColors.adaptiveSuccess(context),
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  "Valid until ${DateFormat('dd MMM yyyy').format(coupon.validUntil)}",
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                          if (coupon.isRedeemed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.border(context),
                                borderRadius: AppRadius.borderSm,
                              ),
                              child: const Text("Redeemed", style: TextStyle(fontSize: 11)),
                            )
                          else if (coupon.isExpired)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.adaptiveError(context).withValues(alpha: 0.1),
                                borderRadius: AppRadius.borderSm,
                              ),
                              child: Text("Expired",
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.adaptiveError(context))),
                            )
                          else
                            AppButton.secondary(
                              label: "Redeem",
                              onPressed: () async {
                                await provider.redeemCustomerCoupon(c.id, coupon.id);
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.md),

          // Section: Gift Cards / Vouchers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard, color: AppColors.adaptivePrimary(context), size: 20),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    "Gift Cards & Vouchers",
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              AppButton.primary(
                icon: Icons.add,
                label: "+ Issue Gift Voucher",
                onPressed: () => _showIssueGiftDialog(context, c, provider),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<List<CustomerGift>>(
            future: provider.getCustomerGifts(c.id),
            builder: (ctx, snapshot) {
              final gifts = snapshot.data ?? [];
              if (gifts.isEmpty) {
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.card_giftcard_outlined,
                            size: 40, color: AppColors.border(context)),
                        const SizedBox(height: AppSpacing.xs),
                        const Text("No gift vouchers issued yet."),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: gifts.map((gift) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.adaptiveWarning(context).withValues(alpha: 0.15),
                              borderRadius: AppRadius.borderSm,
                            ),
                            child: Icon(Icons.card_giftcard, color: AppColors.adaptiveWarning(context)),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(gift.title,
                                    style: AppTypography.bodyMedium
                                        .copyWith(fontWeight: FontWeight.bold)),
                                Text(
                                  "Code: ${gift.voucherCode}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.adaptivePrimary(context)),
                                ),
                                Text(
                                  "Valid until ${DateFormat('dd MMM yyyy').format(gift.validUntil)}",
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "₹${gift.amount.toStringAsFixed(0)}",
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.adaptiveSuccess(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (gift.status == 'Active' && !gift.isExpired)
                                AppButton.secondary(
                                  label: "Redeem",
                                  onPressed: () async {
                                    await provider.redeemCustomerGift(c.id, gift.id);
                                    setState(() {});
                                  },
                                )
                              else
                                Text(gift.status,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary(context))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DIALOGS & ACTIONS
  // ─────────────────────────────────────────────────────────────

  void _showAddUdhariDialog(BuildContext context, Customer c, DashboardProvider provider,
      {required bool isBorrow}) {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final refController = TextEditingController();
    String paymentMode = isBorrow ? 'Store Credit' : 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
          final double projectedBalance = isBorrow
              ? (c.udhariBalance + enteredAmount)
              : (c.udhariBalance - enteredAmount).clamp(0, double.infinity);

          return AlertDialog(
            backgroundColor: AppColors.surface(context),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: Row(
              children: [
                Icon(
                  isBorrow ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isBorrow
                      ? AppColors.adaptiveError(context)
                      : AppColors.adaptiveSuccess(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  isBorrow ? "Give Credit / Borrow (Udhari)" : "Receive Udhari Payment (Settle)",
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.background(context),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Current Due", style: AppTypography.labelSmall),
                              Text("₹${c.udhariBalance.toStringAsFixed(0)}",
                                  style: AppTypography.titleMedium
                                      .copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Icon(Icons.arrow_forward, size: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("New Balance", style: AppTypography.labelSmall),
                              Text("₹${projectedBalance.toStringAsFixed(0)}",
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: projectedBalance > 0
                                        ? AppColors.adaptiveError(context)
                                        : AppColors.adaptiveSuccess(context),
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: amountController,
                      label: "Amount (₹) *",
                      hintText: "Enter amount",
                      prefixIcon: const Icon(Icons.currency_rupee),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (!isBorrow && c.udhariBalance > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ActionChip(
                            label: Text("Full Due: ₹${c.udhariBalance.toStringAsFixed(0)}",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            backgroundColor: AppColors.adaptiveSuccess(context).withValues(alpha: 0.15),
                            side: BorderSide(color: AppColors.adaptiveSuccess(context)),
                            onPressed: () {
                              amountController.text = c.udhariBalance.toStringAsFixed(0);
                              setDialogState(() {});
                            },
                          ),
                          if (c.udhariBalance > 500)
                            ActionChip(
                              label: const Text("₹500", style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                amountController.text = "500";
                                setDialogState(() {});
                              },
                            ),
                          if (c.udhariBalance > 1000)
                            ActionChip(
                              label: const Text("₹1000", style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                amountController.text = "1000";
                                setDialogState(() {});
                              },
                            ),
                          if (c.udhariBalance > 2000)
                            ActionChip(
                              label: const Text("₹2000", style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                amountController.text = "2000";
                                setDialogState(() {});
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: paymentMode,
                      decoration: const InputDecoration(
                        labelText: "Payment / Transaction Mode",
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                      ),
                      items: (isBorrow
                              ? ['Store Credit', 'Bill Khata', 'Advance Loan', 'Other']
                              : ['Cash', 'UPI / GPay / PhonePe', 'Card', 'Bank Transfer', 'Cheque'])
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => paymentMode = v);
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: refController,
                      label: "Bill ID / Receipt Reference (Optional)",
                      hintText: "e.g. Bill #1042",
                      prefixIcon: const Icon(Icons.receipt_outlined),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: notesController,
                      label: "Notes / Description",
                      hintText: "e.g. Grocery items purchase or UPI partial settlement",
                      prefixIcon: const Icon(Icons.note_outlined),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.t(context, 'Cancel'),
                    style: TextStyle(color: AppColors.textSecondary(context))),
              ),
              AppButton.primary(
                label: isBorrow ? "Record Borrow" : "Record Payment",
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a valid amount")),
                    );
                    return;
                  }

                  final effectiveStoreId = provider.activeStoreId?.isNotEmpty == true
                      ? provider.activeStoreId!
                      : 'store_default';

                  final tx = UdhariTransaction(
                    id: const Uuid().v4(),
                    customerId: c.id,
                    storeId: effectiveStoreId,
                    type: isBorrow ? 'borrow' : 'payment',
                    amount: amount,
                    balanceAfter: projectedBalance,
                    date: DateTime.now(),
                    paymentMode: paymentMode,
                    referenceId: refController.text.trim(),
                    notes: notesController.text.trim(),
                    createdBy: provider.userProfile?.name ?? 'Admin',
                  );

                  await provider.addUdhariTransaction(tx);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isBorrow
                            ? "Recorded ₹${amount.toStringAsFixed(0)} borrow"
                            : "Recorded ₹${amount.toStringAsFixed(0)} payment received"),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.adaptiveSuccess(context),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAdjustPointsDialog(
      BuildContext context, Customer c, DashboardProvider provider) {
    final controller = TextEditingController();
    final reasonController = TextEditingController(text: "Bonus / Manual Adjustment");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text("Adjust Loyalty Coins for ${c.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Current Points: ${c.loyaltyPoints} Coins",
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: controller,
              keyboardType: TextInputType.number,
              label: "Coins to Add (or negative to deduct)",
              prefixIcon: const Icon(Icons.stars_outlined),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: reasonController,
              label: "Reason",
              prefixIcon: const Icon(Icons.note_outlined),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t(context, 'Cancel'),
                style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          AppButton.primary(
            label: "Save Adjustment",
            onPressed: () async {
              final pts = int.tryParse(controller.text.trim()) ?? 0;
              if (pts != 0) {
                final effectiveStoreId = provider.activeStoreId?.isNotEmpty == true
                    ? provider.activeStoreId!
                    : 'store_default';

                final tx = LoyaltyTransaction(
                  id: const Uuid().v4(),
                  customerId: c.id,
                  storeId: effectiveStoreId,
                  type: pts > 0 ? 'earned' : 'adjusted',
                  points: pts,
                  balanceAfter: (c.loyaltyPoints + pts).clamp(0, 999999),
                  date: DateTime.now(),
                  reason: reasonController.text.trim(),
                );

                await provider.addLoyaltyTransaction(tx);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void _showIssueCouponDialog(
      BuildContext context, Customer c, DashboardProvider provider) {
    final codeController = TextEditingController(
        text: "OFF${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}");
    final titleController = TextEditingController(text: "Special Discount");
    final discountController = TextEditingController(text: "10");
    final minOrderController = TextEditingController(text: "0");
    String discountType = 'percentage';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface(context),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text("Issue New Coupon"),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: codeController,
                  label: "Coupon Code *",
                  prefixIcon: const Icon(Icons.local_offer_outlined),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: titleController,
                  label: "Title / Description",
                  prefixIcon: const Icon(Icons.title_outlined),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: discountController,
                        label: discountType == 'percentage'
                            ? "Discount (%) *"
                            : "Discount (₹) *",
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.percent_outlined),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: discountType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'percentage', child: Text('% Percent')),
                          DropdownMenuItem(value: 'flat', child: Text('₹ Flat')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => discountType = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: minOrderController,
                  label: "Min Order Value (₹)",
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.shopping_cart_outlined),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.t(context, 'Cancel'),
                  style: TextStyle(color: AppColors.textSecondary(context))),
            ),
            AppButton.primary(
              label: "Issue Coupon",
              onPressed: () async {
                final discount = double.tryParse(discountController.text.trim()) ?? 0.0;
                final minOrder = double.tryParse(minOrderController.text.trim()) ?? 0.0;

                final coupon = CustomerCoupon(
                  id: const Uuid().v4(),
                  customerId: c.id,
                  storeId: provider.activeStoreId ?? 'store_default',
                  code: codeController.text.trim().toUpperCase(),
                  title: titleController.text.trim(),
                  discountType: discountType,
                  discountValue: discount,
                  minOrderValue: minOrder,
                  validUntil: DateTime.now().add(const Duration(days: 30)),
                );

                await provider.addCustomerCoupon(coupon);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showIssueGiftDialog(
      BuildContext context, Customer c, DashboardProvider provider) {
    final codeController = TextEditingController(
        text: "GIFT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}");
    final titleController = TextEditingController(text: "Gift Voucher");
    final amountController = TextEditingController(text: "500");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text("Issue Gift Voucher"),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: codeController,
                label: "Voucher Code *",
                prefixIcon: const Icon(Icons.qr_code_outlined),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: titleController,
                label: "Voucher Title",
                prefixIcon: const Icon(Icons.card_giftcard_outlined),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: amountController,
                label: "Voucher Amount (₹) *",
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.currency_rupee),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.t(context, 'Cancel'),
                style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          AppButton.primary(
            label: "Issue Voucher",
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim()) ?? 0.0;
              final gift = CustomerGift(
                id: const Uuid().v4(),
                customerId: c.id,
                storeId: provider.activeStoreId ?? 'store_default',
                voucherCode: codeController.text.trim().toUpperCase(),
                title: titleController.text.trim(),
                amount: amount,
                validUntil: DateTime.now().add(const Duration(days: 90)),
              );

              await provider.addCustomerGift(gift);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void _showBillDetailsModal(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Bill Receipt #${order.shortId}"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getOrderStatusColor(order.status).withValues(alpha: 0.1),
                borderRadius: AppRadius.borderSm,
              ),
              child: Text(
                order.status.toUpperCase(),
                style: TextStyle(
                    color: _getOrderStatusColor(order.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DateFormat('dd MMMM yyyy, hh:mm a').format(order.date),
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text("Payment: ${order.paymentMethod.isNotEmpty ? order.paymentMethod : 'Cash'}"),
                const Divider(height: AppSpacing.lg),
                // Items Table
                ...order.items.map((item) {
                  final price = item.priceSnapshot ?? item.item.price;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text("${item.quantity}x ${item.item.name}",
                              style: AppTypography.bodyMedium),
                        ),
                        Text("₹${(price * item.quantity).toStringAsFixed(2)}",
                            style: AppTypography.bodyMedium
                                .copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }),
                const Divider(height: AppSpacing.lg),
                // Subtotal & Totals
                if (order.subtotal > 0)
                  _buildReceiptSummaryRow("Subtotal", "₹${order.subtotal.toStringAsFixed(2)}"),
                if (order.discount > 0)
                  _buildReceiptSummaryRow(
                      "Discount", "-₹${order.discount.toStringAsFixed(2)}",
                      color: AppColors.adaptiveSuccess(context)),
                if ((order.cgst + order.sgst) > 0)
                  _buildReceiptSummaryRow("Tax", "₹${(order.cgst + order.sgst).toStringAsFixed(2)}"),
                const SizedBox(height: 6),
                _buildReceiptSummaryRow(
                  "Grand Total",
                  "₹${order.total.toStringAsFixed(2)}",
                  isBold: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton.secondary(
            icon: Icons.chat_outlined,
            label: "Send via WhatsApp",
            onPressed: () {
              Navigator.pop(ctx);
              final provider = Provider.of<DashboardProvider>(context, listen: false);
              final customer = provider.customers.firstWhere(
                (c) => c.id == widget.customer.id,
                orElse: () => widget.customer,
              );
              CustomerWhatsAppDialog.show(
                context,
                customer: customer,
                provider: provider,
                initialCategory: WhatsAppTemplateCategory.transactions,
                customAmount: order.total,
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          AppButton.secondary(
            label: "Close",
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptSummaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: isBold
                  ? AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)
                  : AppTypography.bodySmall),
          Text(value,
              style: isBold
                  ? AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold, color: color)
                  : AppTypography.bodySmall.copyWith(color: color)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border.all(color: AppColors.border(context)),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.textSecondary(context))),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value,
              style: AppTypography.headlineSmall
                  .copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary(context), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary(context)),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.textSecondary(context)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'vip':
        return const Color(0xFF9C27B0);
      case 'platinum':
        return const Color(0xFF607D8B);
      case 'gold':
        return const Color(0xFFFFB300);
      case 'silver':
        return const Color(0xFF78909C);
      default:
        return const Color(0xFF2196F3);
    }
  }

  String _getNextTier(String tier) {
    switch (tier.toLowerCase()) {
      case 'regular':
        return 'Silver (at 500 pts)';
      case 'silver':
        return 'Gold (at 2,000 pts)';
      case 'gold':
        return 'Platinum (at 5,000 pts)';
      case 'platinum':
        return 'VIP (at 10,000 pts)';
      default:
        return 'Top Tier Achieved';
    }
  }

  double _getTierProgress(int points) {
    if (points >= 10000) return 1.0;
    if (points >= 5000) return (points - 5000) / 5000.0;
    if (points >= 2000) return (points - 2000) / 3000.0;
    if (points >= 500) return (points - 500) / 1500.0;
    return (points / 500.0).clamp(0.0, 1.0);
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.adaptiveSuccess(context);
      case 'refunded':
      case 'cancelled':
        return AppColors.adaptiveError(context);
      case 'prepare':
        return AppColors.adaptiveWarning(context);
      default:
        return AppColors.adaptivePrimary(context);
    }
  }
}
