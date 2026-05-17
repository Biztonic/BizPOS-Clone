import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'Audit Log')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/reports'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        child: _isLoading && logs.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
                        const SizedBox(height: AppSpacing.md),
                        Text(AppLocalizations.t(context, 'No audit logs found'), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
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

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            shape: BoxShape.rectangle,
                          ),
                          child: Icon(icon, color: iconColor),
                        ),
                        title: Text("${log['entityType'] ?? 'Unknown'}: $eventType", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("$timeStr â€¢ ID: ${(log['entityId'] ?? '---').toString().substring(0, 8)}..."),
                        trailing: (log['amount'] ?? 0) > 0 
                          ? Text("₹${log['amount'].toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w500))
                          : null,
                      );
                    },
                  ),
      ),
    );
  }
}


