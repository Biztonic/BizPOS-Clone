import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'; // Added for kIsWeb
import '../providers/dashboard_provider.dart';
import '../models/customer.dart';
import 'add_edit_customer_screen.dart';
import 'customer_detail_screen.dart';
import '../widgets/customer_whatsapp_dialog.dart';
import '../l10n/app_localizations.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/components/atoms/app_text_field.dart';
import '../core/design/components/organisms/pos_data_table.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/density/app_density.dart';
import '../core/design/tokens/app_colors.dart';
import '../core/design/tokens/app_radius.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _searchQuery = "";
  String _sortBy = 'Name';
  String _filterType = 'All'; // 'All', 'Udhari Due', 'VIP'
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      });
    });

    // Trigger initial fetch only if not already populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      if (provider.activeStoreId != null && provider.customers.isEmpty) {
        provider.customerProvider
            ?.fetchCustomers(provider.activeStoreId, refresh: false);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<DashboardProvider, _CustomerScreenData>(
      selector: (_, p) => _CustomerScreenData(
        customersLength: p.customers.length,
        activeStoreId: p.activeStoreId,
        customersHash: p.customers.isEmpty
            ? 0
            : Object.hashAll(p.customers.map((c) => c.id)),
      ),
      builder: (context, data, _) {
        final provider = Provider.of<DashboardProvider>(context, listen: false);
        final isDesktop = MediaQuery.of(context).size.width >= 1100;
        // Merchants always have full access to CRM tools (Udhari Khata & Loyalty)
        const bool isUdhariEnabled = true;
        const bool isLoyaltyEnabled = true;

        List<Customer> displayedCustomers = provider.customers.where((c) {
          final matchesSearch = c.name.toLowerCase().contains(_searchQuery) ||
              (c.mobile?.contains(_searchQuery) ?? false) ||
              (c.email.toLowerCase().contains(_searchQuery));
          if (!matchesSearch) return false;

          if (isUdhariEnabled && _filterType == 'Udhari Due') {
            return c.udhariBalance > 0;
          }
          if (_filterType == 'VIP') return c.tier == 'VIP' || c.totalSpent > 1000;
          return true;
        }).toList();

        displayedCustomers.sort((a, b) {
          if (isUdhariEnabled && _sortBy == 'Udhari') {
            return b.udhariBalance.compareTo(a.udhariBalance);
          }
          if (isLoyaltyEnabled && _sortBy == 'Points') {
            return b.loyaltyPoints.compareTo(a.loyaltyPoints);
          }
          if (_sortBy == 'Spent') return b.totalSpent.compareTo(a.totalSpent);
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

        return PosScaffold(
          title: _isSelectionMode
              ? '${_selectedIds.length} Selected'
              : 'Customers',
          actions: _buildScaffoldActions(context, provider),
          mainContent: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : isDesktop
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatsRow(
                            provider, isUdhariEnabled, isLoyaltyEnabled),
                        _buildFilterBar(
                            context, isUdhariEnabled, isLoyaltyEnabled),
                        Expanded(
                          child: displayedCustomers.isEmpty
                              ? _buildEmptyState()
                              : Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.md,
                                      0,
                                      AppSpacing.md,
                                      AppSpacing.md),
                                  child: _buildTableView(context, provider,
                                      displayedCustomers, isUdhariEnabled, isLoyaltyEnabled),
                                ),
                        ),
                      ],
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                            child: _buildFilterBar(
                                context, isUdhariEnabled, isLoyaltyEnabled)),
                        if (displayedCustomers.isEmpty)
                          SliverFillRemaining(child: _buildEmptyState())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: _buildCustomerCard(context,
                                      displayedCustomers[i], provider, isUdhariEnabled, isLoyaltyEnabled),
                                ),
                                childCount: displayedCustomers.length,
                                addAutomaticKeepAlives: false,
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.xl)),
                      ],
                    ),
        );
      },
    );
  }

  List<Widget> _buildScaffoldActions(
      BuildContext context, DashboardProvider provider) {
    if (_isSelectionMode) {
      return [
        AppButton.danger(
          icon: Icons.delete_sweep,
          onPressed: () => _confirmBulkDelete(context),
        ),
        const SizedBox(width: AppSpacing.xs),
        AppButton.secondary(
          icon: Icons.select_all,
          onPressed: () {
            setState(() {
              if (_selectedIds.length == provider.customers.length) {
                _selectedIds.clear();
              } else {
                _selectedIds.addAll(provider.customers.map((c) => c.id));
              }
            });
          },
        ),
        const SizedBox(width: AppSpacing.xs),
        AppButton.secondary(
          icon: Icons.close,
          onPressed: () => setState(() {
            _isSelectionMode = false;
            _selectedIds.clear();
          }),
        ),
      ];
    }

    return [
      AppButton.secondary(
        icon: Icons.refresh,
        onPressed: () => provider.customerProvider
            ?.fetchCustomers(provider.activeStoreId, refresh: true),
      ),
      const SizedBox(width: AppSpacing.xs),
      AppButton.secondary(
        icon: Icons.checklist,
        onPressed: () => setState(() => _isSelectionMode = true),
      ),
      const SizedBox(width: AppSpacing.xs),
      AppButton.primary(
        label: MediaQuery.of(context).size.width > 600 ? "Add Customer" : null,
        icon: Icons.add,
        onPressed: () => AddEditCustomerScreen.showAsDialog(context),
      ),
    ];
  }

  Widget _buildFilterBar(BuildContext context, bool isUdhariEnabled, bool isLoyaltyEnabled) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: AppTextField(
              controller: _searchController,
              hintText: "Search by name, phone or email...",
              prefixIcon: const Icon(Icons.search),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Filter by Type (All / Udhari Due / VIP)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border.all(color: AppColors.border(context)),
              borderRadius: AppRadius.borderMd,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterType,
                dropdownColor: AppColors.surface(context),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textPrimary(context)),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Customers')),
                  if (isUdhariEnabled)
                    const DropdownMenuItem(
                        value: 'Udhari Due', child: Text('⚠️ Has Udhari Due')),
                  const DropdownMenuItem(value: 'VIP', child: Text('⭐ VIP Customers')),
                ],
                onChanged: (v) => setState(() => _filterType = v ?? 'All'),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Sort Dropdown
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border.all(color: AppColors.border(context)),
              borderRadius: AppRadius.borderMd,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                dropdownColor: AppColors.surface(context),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textPrimary(context)),
                items: [
                  const DropdownMenuItem(
                      value: 'Name', child: Text('Sort by Name')),
                  if (isUdhariEnabled)
                    const DropdownMenuItem(
                        value: 'Udhari', child: Text('Sort by Udhari Due')),
                  if (isLoyaltyEnabled)
                    const DropdownMenuItem(
                        value: 'Points', child: Text('Sort by Loyalty Points')),
                  const DropdownMenuItem(
                      value: 'Spent', child: Text('Sort by Total Spent')),
                ],
                onChanged: (v) => setState(() => _sortBy = v!),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton.secondary(
            icon: Icons.import_contacts,
            onPressed: _importContacts,
          )
        ],
      ),
    );
  }

  Widget _buildTableView(BuildContext context, DashboardProvider provider,
      List<Customer> customers, bool isUdhariEnabled, bool isLoyaltyEnabled) {
    final columns = [
      const PosDataColumn(label: 'Customer', fixedWidth: 240),
      const PosDataColumn(label: 'Contact', fixedWidth: 160),
      const PosDataColumn(label: 'Udhari (Due)', fixedWidth: 140),
      const PosDataColumn(label: 'Loyalty Points', fixedWidth: 130),
      const PosDataColumn(label: 'Total Spent', fixedWidth: 130),
      const PosDataColumn(label: 'Actions', fixedWidth: 190),
    ];

    return PosDataTable(
      rowHeight: 64.0,
      columns: columns,
      rows: customers
          .map((c) => PosDataRow(
                cells: [
                  Row(
                    children: [
                      if (_isSelectionMode)
                        Checkbox(
                          value: _selectedIds.contains(c.id),
                          onChanged: (val) => _toggleSelection(c.id),
                          activeColor: AppColors.adaptivePrimary(context),
                        ),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _getAvatarColor(context, c.name)
                            .withValues(alpha: 0.1),
                        child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: TextStyle(
                                color: _getAvatarColor(context, c.name),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (c.tier.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.adaptivePrimary(context)
                                      .withValues(alpha: 0.1),
                                  borderRadius: AppRadius.borderSm,
                                ),
                                child: Text(c.tier.toUpperCase(),
                                    style: TextStyle(
                                        color: AppColors.adaptivePrimary(context),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    c.mobile?.isNotEmpty == true
                        ? c.mobile!
                        : (c.phone?.isNotEmpty == true
                            ? c.phone!
                            : (c.email.isNotEmpty ? c.email : 'N/A')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium,
                  ),
                  if (isUdhariEnabled)
                    c.udhariBalance > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.adaptiveError(context)
                                  .withValues(alpha: 0.1),
                              borderRadius: AppRadius.borderSm,
                              border: Border.all(
                                  color: AppColors.adaptiveError(context)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              "₹${c.udhariBalance.toStringAsFixed(0)} Due",
                              style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.adaptiveError(context),
                                  fontWeight: FontWeight.bold),
                            ),
                          )
                        : Text("₹0.00",
                            style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary(context))),
                  if (isLoyaltyEnabled)
                    Text("${c.loyaltyPoints} pts",
                        style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.adaptiveWarning(context))),
                  Text("₹${c.totalSpent.toStringAsFixed(0)}",
                      style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.adaptiveSuccess(context))),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: "View Customer Overview",
                        child: AppButton.secondary(
                          size: AppButtonSize.small,
                          icon: Icons.visibility_outlined,
                          onPressed: () => _handleCustomerTap(c),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Tooltip(
                        message: "WhatsApp Hub",
                        child: AppButton.secondary(
                          size: AppButtonSize.small,
                          icon: Icons.chat_outlined,
                          onPressed: () => CustomerWhatsAppDialog.show(
                            context,
                            customer: c,
                            provider: provider,
                            initialCategory: c.udhariBalance > 0
                                ? WhatsAppTemplateCategory.udhariDue
                                : WhatsAppTemplateCategory.promotions,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Tooltip(
                        message: "Edit Customer",
                        child: AppButton.secondary(
                          size: AppButtonSize.small,
                          icon: Icons.edit_outlined,
                          onPressed: () => AddEditCustomerScreen.showAsDialog(
                              context,
                              customer: c),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Tooltip(
                        message: "Delete Customer",
                        child: AppButton.danger(
                          size: AppButtonSize.small,
                          icon: Icons.delete_outline,
                          onPressed: () => _confirmDelete(c, provider),
                        ),
                      ),
                    ],
                  ),
                ],
                onTap: () => _handleCustomerTap(c),
              ))
          .toList(),
    );
  }

  Color _getAvatarColor(BuildContext context, String name) {
    final colors = [
      AppColors.adaptivePrimary(context),
      AppColors.adaptiveSuccess(context),
      AppColors.adaptiveWarning(context),
      AppColors.adaptiveError(context),
      AppColors.adaptiveInfo(context),
    ];
    return colors[name.length % colors.length];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.adaptivePrimary(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.adaptivePrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              "No Customers Found",
              style: AppTypography.headlineSmall
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                "Add customer profiles to maintain bill history, track Udhari (credit khata/borrows), and reward customers with loyalty points.",
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary(context)),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              label: "Add Customer",
              icon: Icons.person_add_outlined,
              onPressed: () => AddEditCustomerScreen.showAsDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(
      BuildContext context, Customer c, DashboardProvider provider, bool isUdhariEnabled, bool isLoyaltyEnabled) {
    final isSelected = _selectedIds.contains(c.id);
    final density = AppDensityProvider.configOf(context);
    return AppCard(
      isSelected: isSelected,
      padding: EdgeInsets.all(density.cardPadding),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(c.id),
                activeColor: AppColors.adaptivePrimary(context),
              )
            : CircleAvatar(
                backgroundColor:
                    _getAvatarColor(context, c.name).withValues(alpha: 0.1),
                child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: _getAvatarColor(context, c.name),
                        fontWeight: FontWeight.bold)),
              ),
        title: Row(
          children: [
            Expanded(
              child: Text(c.name,
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold)),
            ),
            if (isUdhariEnabled && c.udhariBalance > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      AppColors.adaptiveError(context).withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderSm,
                ),
                child: Text(
                  "Due: ₹${c.udhariBalance.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: AppColors.adaptiveError(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(c.mobile?.isNotEmpty == true
                ? c.mobile!
                : (c.phone ?? (c.email.isNotEmpty ? c.email : 'No Contact'))),
            const SizedBox(height: 2),
            Row(
              children: [
                if (isLoyaltyEnabled) ...[
                  Text("${c.loyaltyPoints} Coins",
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.adaptiveWarning(context),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: AppSpacing.sm),
                  Text("•",
                      style: TextStyle(color: AppColors.textSecondary(context))),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text("Spent: ₹${c.totalSpent.toStringAsFixed(0)}",
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.adaptiveSuccess(context),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        trailing: _isSelectionMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                    tooltip: "WhatsApp Hub",
                    onPressed: () => CustomerWhatsAppDialog.show(
                      context,
                      customer: c,
                      provider: provider,
                      initialCategory: c.udhariBalance > 0
                          ? WhatsAppTemplateCategory.udhariDue
                          : WhatsAppTemplateCategory.promotions,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
        onTap: () => _handleCustomerTap(c),
        onLongPress: () {
          if (!_isSelectionMode) {
            setState(() {
              _isSelectionMode = true;
              _selectedIds.add(c.id);
            });
          }
        },
      ),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _handleCustomerTap(Customer c) {
    if (_isSelectionMode) {
      _toggleSelection(c.id);
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)));
    }
  }

  Widget _buildStatsRow(DashboardProvider provider, bool isUdhariEnabled, bool isLoyaltyEnabled) {
    final total = provider.customers.length;
    final totalUdhari = provider.customers.fold<double>(
        0.0, (sum, c) => sum + (c.udhariBalance > 0 ? c.udhariBalance : 0.0));
    final loyalty = provider.customers.where((c) => c.loyaltyPoints > 0).length;
    final vips = provider.customers
        .where((c) => c.tier == 'VIP' || c.totalSpent > 1000)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
              child: _buildStatCard("Total Customers", "$total", Icons.people,
                  AppColors.adaptivePrimary(context))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: _buildStatCard(
                  "Total Udhari Due",
                  "₹${totalUdhari.toStringAsFixed(0)}",
                  Icons.account_balance_wallet,
                  totalUdhari > 0
                      ? AppColors.adaptiveError(context)
                      : AppColors.adaptiveSuccess(context))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: _buildStatCard("Loyalty Active", "$loyalty", Icons.stars,
                  AppColors.adaptiveWarning(context))),
          const SizedBox(width: AppSpacing.md),
          Expanded(
              child: _buildStatCard("VIP Members", "$vips", Icons.diamond,
                  AppColors.adaptiveInfo(context))),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.borderMd,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineSmall
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Customer c, DashboardProvider provider) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface(context),
              title: Text(AppLocalizations.t(context, 'Delete Customer?')),
              content: Text(
                  "Are you sure you want to delete ${c.name}? This will remove all transaction history linked to this customer profile."),
              shape:
                  const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppLocalizations.t(context, 'Cancel'),
                        style: TextStyle(
                            color: AppColors.textSecondary(context)))),
                AppButton.danger(
                    onPressed: () {
                      provider.customerProvider?.deleteCustomer(c.id);
                      Navigator.pop(ctx);
                    },
                    label: "Delete"),
              ],
            ));
  }

  void _confirmBulkDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        title: Text("Delete ${_selectedIds.length} Customers?"),
        content: Text(AppLocalizations.t(context,
            'This action cannot be undone. All selected customer profiles will be permanently removed.')),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.t(context, 'Cancel'),
                  style: TextStyle(color: AppColors.textSecondary(context)))),
          AppButton.danger(
              onPressed: () async {
                final provider =
                    Provider.of<DashboardProvider>(context, listen: false);
                final messenger = ScaffoldMessenger.of(context);
                final List<String> idsToDelete = _selectedIds.toList();

                for (var id in idsToDelete) {
                  await provider.customerProvider?.deleteCustomer(id);
                }

                if (mounted) {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(SnackBar(
                    content: Text("Deleted ${idsToDelete.length} customers"),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              label: "Delete All"),
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
                  backgroundColor: AppColors.surface(context),
                  title: Text(
                      AppLocalizations.t(context, 'Feature Not Available')),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero),
                  content: Text(AppLocalizations.t(context,
                      'Importing contacts is only available on Android devices. Please use a physical device to use this feature.')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(AppLocalizations.t(context, 'OK')))
                  ],
                ));
      }
      return;
    }

    try {
      if (await FlutterContacts.requestPermission()) {
        final contacts = await FlutterContacts.getContacts(
            withProperties: true, withPhoto: false);
        if (context.mounted) _showContactSelectionDialog(contacts);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error accessing contacts: $e")));
      }
    }
  }

  void _showContactSelectionDialog(List<Contact> contacts) {
    // Filter contacts with at least a phone or email
    final validContacts = contacts
        .where((c) => c.phones.isNotEmpty || c.emails.isNotEmpty)
        .toList();

    // Sort by name
    validContacts.sort((a, b) => a.displayName.compareTo(b.displayName));

    List<Contact> selected = [];
    String query = "";

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
              final filtered = validContacts
                  .where((c) =>
                      c.displayName.toLowerCase().contains(query.toLowerCase()))
                  .toList();

              return AlertDialog(
                backgroundColor: AppColors.surface(context),
                title: Text(AppLocalizations.t(context, 'Import Contacts')),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppTextField(
                        hintText: "Search contacts...",
                        prefixIcon: const Icon(Icons.search),
                        onChanged: (val) {
                          setDialogState(() => query = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (c, i) {
                            final contact = filtered[i];
                            final isSelected = selected.contains(contact);
                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppColors.adaptivePrimary(context),
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
                              subtitle: Text(contact.phones.isNotEmpty
                                  ? contact.phones.first.number
                                  : (contact.emails.isNotEmpty
                                      ? contact.emails.first.address
                                      : "")),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("${selected.length} selected",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    if (selected.length ==
                                        validContacts.length) {
                                      selected.clear();
                                    } else {
                                      selected = List.from(validContacts);
                                    }
                                  });
                                },
                                child: Text(
                                    selected.length == validContacts.length
                                        ? "Deselect All"
                                        : "Select All"))
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppLocalizations.t(context, 'Cancel'),
                          style: TextStyle(
                              color: AppColors.textSecondary(context)))),
                  AppButton.primary(
                      onPressed: () {
                        _batchAddContacts(selected);
                        Navigator.pop(ctx);
                      },
                      label: "Import")
                ],
              );
            }));
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

        String? mobile = c.phones.isNotEmpty
            ? c.phones.first.number.replaceAll(RegExp(r'\D'), '')
            : null;
        String email = c.emails.isNotEmpty ? c.emails.first.address : "";

        final exists = provider.customers.any((cust) =>
            (mobile != null &&
                cust.mobile?.replaceAll(RegExp(r'\D'), '') == mobile) ||
            (email.isNotEmpty && cust.email == email && email != ""));

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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Imported $added contacts ($skipped skipped)"),
          behavior: SnackBarBehavior.floating));
    }
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
  int get hashCode =>
      Object.hash(customersLength, activeStoreId, customersHash);
}
