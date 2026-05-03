import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_card.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';
import '../core/design/density/app_density.dart';
import '../core/design/tokens/app_colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);

    return PosScaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      mainContent: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Report Categories",
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.lg),
            
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final int crossAxisCount = width > 1200 ? 5 : (width > 900 ? 4 : (width > 600 ? 3 : 2));
                
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: AppSpacing.lg,
                  crossAxisSpacing: AppSpacing.lg,
                  childAspectRatio: 1.0,
                  children: [
                    _ReportCategoryCard(
                      title: "Sales Reports",
                      icon: Icons.bar_chart,
                      color: AppColors.primary,
                      onTap: () => context.push('/reports/sales'),
                    ),
                    _ReportCategoryCard(
                      title: "Inventory Reports",
                      icon: Icons.inventory_2,
                      color: AppColors.warning,
                      onTap: () => context.push('/reports/inventory'),
                    ),
                    _ReportCategoryCard(
                      title: "Customer Reports",
                      icon: Icons.people,
                      color: AppColors.primary,
                      onTap: () => context.push('/reports/customers'),
                    ),
                    _ReportCategoryCard(
                      title: "Financials",
                      icon: Icons.attach_money,
                      color: AppColors.success,
                      isLocked: Provider.of<DashboardProvider>(context).activeRole == 'Cashier' ||
                          Provider.of<DashboardProvider>(context).activeRole == 'Waiter',
                      onTap: () {
                        if (Provider.of<DashboardProvider>(context, listen: false).activeRole == 'Cashier') {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied")));
                          return;
                        }
                        GoRouter.of(context).push('/reports/financials');
                      },
                    ),
                    _ReportCategoryCard(
                      title: "Audit Log",
                      icon: Icons.history,
                      color: AppColors.textSecondary(context),
                      onTap: () => context.push('/reports/audit'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLocked;

  const _ReportCategoryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isLocked ? AppColors.secondary.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLocked ? Icons.lock : icon,
              color: isLocked ? AppColors.secondary : color,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isLocked ? AppColors.secondary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

