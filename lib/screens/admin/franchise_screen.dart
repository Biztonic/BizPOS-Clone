import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';

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

    return PosScaffold(
      title: isFranchiseOwner ? 'Franchise Performance Dashboard' : 'Franchise Management',
      mainContent: isFranchiseOwner 
          ? _buildFranchiseOwnerContent(context, provider) 
          : _buildSuperAdminViewContent(context),
    );
  }

  Widget _buildFranchiseOwnerContent(BuildContext context, DashboardProvider provider) {
    final uid = provider.userProfile?.uid;
    final franchiseId = provider.userProfile?.franchiseId ?? uid;

    final stores = provider.stores.where((s) => s.franchiseId == franchiseId).toList();
    final filteredStores = stores.where((s) {
      return s.name.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();
    int activeStores = stores.where((s) => s.status == 'Active').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: const Icon(Icons.business_outlined, color: AppColors.primaryLight),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.t(context, 'Franchise Overview'), style: AppTypography.headlineSmall),
                          if (provider.userProfile?.franchiseCode != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            SelectableText(
                              'Franchise Code: ${provider.userProfile!.franchiseCode}',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AppButton.primary(
                      label: 'Link Existing Store',
                      icon: Icons.add,
                      onPressed: () => _showAddExistingStoreDialog(context, provider),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(AppLocalizations.t(context, 'Overview of performance for all stores under your franchise.'),
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Stats Cards
          LayoutBuilder(builder: (context, constraints) {
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _buildStatCard('Total Stores', stores.length.toString(), Icons.store_outlined, AppColors.primary, constraints.maxWidth),
                _buildStatCard('Active Stores', activeStores.toString(), Icons.check_circle_outline, AppColors.success, constraints.maxWidth),
                _buildStatCard('Total Sales (Est)', '₹0', Icons.payments_outlined, AppColors.warning, constraints.maxWidth),
                _buildStatCard('Total Orders (Est)', '0', Icons.receipt_long_outlined, AppColors.primary, constraints.maxWidth),
              ],
            );
          }),

          const SizedBox(height: AppSpacing.xl),

          // Store Performance Section
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.t(context, 'Store Performance'), style: AppTypography.titleLarge),
                const SizedBox(height: AppSpacing.lg),

                // Filters
                LayoutBuilder(builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 800;
                  final filterContent = [
                    Expanded(
                      flex: isNarrow ? 0 : 2,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Filter by Store Name...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        ),
                      ),
                    ),
                    if (!isNarrow) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: isNarrow ? 0 : 1,
                      child: _buildMockDropdown('Filter by Owner...'),
                    ),
                    if (!isNarrow) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: isNarrow ? 0 : 1,
                      child: TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          hintText: provider.franchises.isNotEmpty ? provider.franchises.first.name : 'Your Franchise',
                          filled: true,
                          fillColor: Theme.of(context).disabledColor.withValues(alpha: 0.05),
                          border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        ),
                      ),
                    ),
                    if (!isNarrow) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: isNarrow ? 0 : 1,
                      child: _buildMockDropdown('All Statuses'),
                    ),
                  ];

                  if (isNarrow) {
                    return Column(
                      children: filterContent.map((w) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: SizedBox(width: double.infinity, child: w))).toList(),
                    );
                  }
                  return Row(children: filterContent);
                }),

                const SizedBox(height: AppSpacing.lg),

                // Table
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 800),
                    child: DataTable(
                      headingTextStyle: AppTypography.labelLarge.copyWith(color: AppColors.textSecondary(context)),
                      dataTextStyle: AppTypography.bodyMedium,
                      columns: [
                        DataColumn(label: Text(AppLocalizations.t(context, 'Store Name'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Owner'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Franchise'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Total Sales'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Total Orders'))),
                        DataColumn(label: Text(AppLocalizations.t(context, 'Status'))),
                      ],
                      rows: filteredStores.isEmpty
                          ? [
                              DataRow(cells: [
                                DataCell(Text(AppLocalizations.t(context, 'No stores found matching your criteria.'), style: TextStyle(color: AppColors.textSecondary(context)))),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                                const DataCell(SizedBox()),
                              ])
                            ]
                          : filteredStores.map((store) {
                              return DataRow(cells: [
                                DataCell(Text(store.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(store.owner)),
                                DataCell(Text(store.franchiseName ?? '-')),
                                DataCell(Text(AppLocalizations.t(context, '₹0.00'))),
                                const DataCell(Text('0')),
                                DataCell(_buildStatusBadge(store.status)),
                              ]);
                            }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const AppButton.secondary(onPressed: null, label: 'Previous'),
                    const SizedBox(width: AppSpacing.md),
                    Text(AppLocalizations.t(context, 'Page 1 of 1'), style: AppTypography.bodySmall),
                    const SizedBox(width: AppSpacing.md),
                    const AppButton.secondary(onPressed: null, label: 'Next'),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, double maxWidth) {
    double width = (maxWidth - (AppSpacing.lg * 2) - (AppSpacing.md * 3)) / 4;
    if (width < 160) width = (maxWidth - (AppSpacing.lg * 2) - AppSpacing.md) / 2;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: width - (AppSpacing.lg * 2), // Adjust for card padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondary(context)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTypography.headlineSmall),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMockDropdown(String hint) {
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12),
       decoration: BoxDecoration(border: Border.all(color: AppColors.textSecondary(context)), borderRadius: BorderRadius.zero),
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
    bool isActive = status == 'Active';
    Color color = isActive ? AppColors.success : AppColors.textSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status,
            style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperAdminViewContent(BuildContext context) {
    return Center(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Theme.of(context).disabledColor),
            const SizedBox(height: AppSpacing.lg),
            Text(AppLocalizations.t(context, 'Manage Franchises'), style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(AppLocalizations.t(context, 'Feature Coming Soon'), style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              onPressed: () {},
              label: 'Add Franchise',
              icon: Icons.add,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExistingStoreDialog(BuildContext context, DashboardProvider provider) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Existing Store'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter the credentials of the existing store owner to link it under your franchise.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Store Owner Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter email' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Store Owner Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Please enter password' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => isSubmitting = true);
                          try {
                            await provider.addExistingStoreToFranchise(
                              email: emailController.text.trim(),
                              password: passwordController.text,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Store successfully linked to your franchise!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error linking store: ${e.toString()}'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() => isSubmitting = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surfaceLight,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Link Store'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}


