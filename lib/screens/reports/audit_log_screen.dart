import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_radius.dart';

import 'package:flutter/material.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    await provider.fetchAuditLogs();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final logs = provider.auditLogs;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PosScaffold(
      showGlobalActions: false,
      mainContent: Container(
        color: AppColors.background(context),
        child: CustomScrollView(
          slivers: [
            // APP BAR
            SliverAppBar(
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/reports'),
              ),
              title: Text(AppLocalizations.t(context, 'Audit Log'), style: const TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadLogs,
                ),
              ],
            ),

            // Loading state
            if (_isLoading && logs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            // Empty state
            else if (logs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 64, color: AppColors.textSecondary(context)),
                      const SizedBox(height: AppSpacing.md),
                      Text(AppLocalizations.t(context, 'No audit logs found'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16)),
                    ],
                  ),
                ),
              )
            // List
            else
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final log = logs[index];
                      final timeStr = DateFormat('MMM dd, hh:mm a').format(log['createdAt'] ?? DateTime.now());

                      IconData icon = Icons.history;
                      Color iconColor = AppColors.primaryLight;

                      final eventType = log['eventType'] ?? '';
                      if (eventType == 'CREATE') {
                        icon = Icons.add_circle_outline;
                        iconColor = AppColors.success;
                      } else if (eventType == 'REFUND') {
                        icon = Icons.undo;
                        iconColor = AppColors.warning;
                      } else if (eventType == 'VOID') {
                        icon = Icons.cancel_outlined;
                        iconColor = AppColors.error;
                      }

                      return Card(
                        elevation: 0,
                        color: AppColors.surface(context),
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.borderSm,
                          side: BorderSide(color: AppColors.border(context)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.1),
                                  borderRadius: AppRadius.borderSm,
                                ),
                                child: Icon(icon, color: iconColor),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${log['entityType'] ?? 'Unknown'}: $eventType",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isDark ? AppColors.surfaceLight : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      "$timeStr • ID: ${(log['entityId'] ?? '---').toString().substring(0, 8)}...",
                                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              if ((log['amount'] ?? 0) > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.success.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.08),
                                    borderRadius: AppRadius.borderXs,
                                  ),
                                  child: Text(
                                    "₹${log['amount'].toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.success, fontSize: 14),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: logs.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
