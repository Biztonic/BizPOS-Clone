import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../providers/dashboard_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'reports')),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Report Categories", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),
            
            // Grid of Categories
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final int crossAxisCount = width > 900 ? 5 : (width > 600 ? 3 : 2);
                final double itemWidth = (width - ((crossAxisCount - 1) * 16)) / crossAxisCount;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _ReportCategoryCard(
                      title: "Sales Reports", 
                      icon: Icons.bar_chart, 
                      color: Colors.blue, 
                      width: itemWidth,
                      onTap: () {
                        context.push('/reports/sales'); 
                      }
                    ),
                    _ReportCategoryCard(
                      title: "Inventory Reports", 
                      icon: Icons.inventory_2, 
                      color: Colors.orange, 
                      width: itemWidth,
                      onTap: () {
                        context.push('/reports/inventory');
                      },
                    ),
                    _ReportCategoryCard(
                      title: "Customer Reports", 
                      icon: Icons.people, 
                      color: Colors.teal, 
                      width: itemWidth,
                      onTap: () {
                         context.push('/reports/customers');
                      },
                    ),
                    _ReportCategoryCard(
                      title: "Financials", 
                      icon: Icons.attach_money, 
                      color: Colors.green, 
                      width: itemWidth,
                      isLocked: Provider.of<DashboardProvider>(context).activeRole == 'Cashier' || Provider.of<DashboardProvider>(context).activeRole == 'Waiter',
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
                      color: Colors.brown, 
                      width: itemWidth,
                      onTap: () {
                        context.push('/reports/audit');
                      },
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
  final double width;
  final VoidCallback onTap;
  final bool isLocked;

  const _ReportCategoryCard({
    required this.title, 
    required this.icon, 
    required this.color, 
    required this.width,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: isLocked ? Colors.grey : color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isLocked ? Colors.grey.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isLocked ? Icons.lock : icon, color: isLocked ? Colors.grey : color, size: 32),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: Center(
                child: Text(
                  title, 
                  textAlign: TextAlign.center, 
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2, color: isLocked ? Colors.grey : null),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
