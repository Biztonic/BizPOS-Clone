import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_radius.dart';
import '../../core/diagnostics/diagnostics_models.dart';
import '../../core/diagnostics/diagnostics_service.dart';
import '../../core/audit/audit_models.dart';
import '../../core/audit/audit_service.dart';
import '../../services/database_helper.dart';
import '../../services/sync_service.dart';
import '../../services/offline_service.dart';

/// Production Diagnostics & Observability Screen for Administrators.
/// Provides real-time field telemetry, queue health indicators, automated redaction,
/// secret-safe export, and a financial & governance business audit trail.
class ProductionDiagnosticsScreen extends StatefulWidget {
  const ProductionDiagnosticsScreen({super.key});

  @override
  State<ProductionDiagnosticsScreen> createState() =>
      _ProductionDiagnosticsScreenState();
}

class _ProductionDiagnosticsScreenState
    extends State<ProductionDiagnosticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DiagnosticsService _diagnosticsService = DiagnosticsService();
  final AuditService _auditService = AuditService();
  final SyncService _syncService = SyncService();
  final OfflineService _offlineService = OfflineService();

  DiagnosticSubsystem? _selectedSubsystem;
  DiagnosticResult? _selectedResult;
  AuditActionType? _selectedAuditAction;
  bool _isRetryingDeadLetters = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportDiagnosticsBundle() async {
    final activeStoreId = _syncService.activeStoreId ?? 'store_unknown';
    final deadLetterOps = _syncService.getDeadLetterOperations();

    final jsonBundle = await _diagnosticsService.exportDiagnosticsBundle(
      activeStoreId: activeStoreId,
      cloudConnectivityState: _syncService.networkState.name,
      pendingQueueCount: _syncService.pendingUploadCount,
      failedQueueCount: _syncService.failedUploadCount,
      deadLetterCount: deadLetterOps.length,
      lastSyncTime: _syncService.lastSyncTime,
    );

    await Clipboard.setData(ClipboardData(text: jsonBundle));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            '✅ Sanitized diagnostic bundle copied to clipboard (Scrubbed of credentials & PII)'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 4),
      ),
    );

    _showExportPreviewModal(jsonBundle);
  }

  void _showExportPreviewModal(String jsonBundle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.green),
            SizedBox(width: AppSpacing.sm),
            Text('Sanitized Diagnostic Bundle'),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: AppRadius.borderSm,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user, color: Colors.green, size: 18),
                    SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Redaction active: Passwords, PINs, auth tokens, secret keys, and customer PII are strictly scrubbed.',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonBundle,
                      style: const TextStyle(
                        color: Colors.lightGreenAccent,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy to Clipboard'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonBundle));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _retryDeadLetters() async {
    setState(() => _isRetryingDeadLetters = true);
    try {
      final retried = await _syncService.retryAllDeadLetter();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retried $retried dead-letter operations'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error retrying dead letters: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRetryingDeadLetters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeStoreId = _syncService.activeStoreId ?? 'No Active Store';
    final deviceId = _syncService.deviceId ?? 'device_unknown';
    final deadLetterCount = _syncService.getDeadLetterOperations().length;
    final pendingCount = _syncService.pendingUploadCount;
    final failedCount = _syncService.failedUploadCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Queue Health Status
    final isCritical = deadLetterCount > 0;
    final isDegraded = failedCount > 0 && !isCritical;
    final healthStatus =
        isCritical ? 'CRITICAL' : (isDegraded ? 'DEGRADED' : 'HEALTHY');
    final healthColor = isCritical
        ? AppColors.error
        : (isDegraded ? AppColors.warning : AppColors.success);

    // Connectivity
    final isOnline = _offlineService.isOnline;
    final connectionQuality =
        _offlineService.connectionQuality.name.toUpperCase();

    final lastError = _diagnosticsService.getLastError();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.surface(context),
        title: const Text('Production Diagnostics & Observability',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Diagnostics',
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear In-Memory Logs',
            onPressed: () async {
              await _diagnosticsService.clearLogs();
              setState(() {});
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export Bundle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _exportDiagnosticsBundle,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary(context),
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.troubleshoot), text: 'System Diagnostics'),
            Tab(icon: Icon(Icons.history_edu), text: 'Audit Trail'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Top Status Overview Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.surface(context),
            child: Column(
              children: [
                Row(
                  children: [
                    // Telemetry Box 1: Version & Database
                    Expanded(
                      child: _buildTelemetryCard(
                        context,
                        title: 'App & DB Version',
                        value: 'v1.0.4+12',
                        subtitle: 'SQLite Schema v${DatabaseHelper.version}',
                        icon: Icons.code,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Telemetry Box 2: Device & Store
                    Expanded(
                      child: _buildTelemetryCard(
                        context,
                        title: 'Device & Store',
                        value: activeStoreId.length > 14
                            ? '${activeStoreId.substring(0, 14)}...'
                            : activeStoreId,
                        subtitle:
                            'Device: ${deviceId.length > 12 ? deviceId.substring(0, 12) : deviceId}',
                        icon: Icons.storefront,
                        color: Colors.indigoAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Telemetry Box 3: Connectivity
                    Expanded(
                      child: _buildTelemetryCard(
                        context,
                        title: 'Cloud Connectivity',
                        value: isOnline ? 'ONLINE' : 'OFFLINE',
                        subtitle: 'Route: $connectionQuality',
                        icon: isOnline ? Icons.cloud_done : Icons.cloud_off,
                        color: isOnline ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Telemetry Box 4: Queue Health
                    Expanded(
                      child: _buildTelemetryCard(
                        context,
                        title: 'Queue Health',
                        value: healthStatus,
                        subtitle:
                            'P: $pendingCount | F: $failedCount | DL: $deadLetterCount',
                        icon: isCritical
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        color: healthColor,
                        actionWidget: deadLetterCount > 0
                            ? TextButton(
                                onPressed: _isRetryingDeadLetters
                                    ? null
                                    : _retryDeadLetters,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 20),
                                ),
                                child: const Text('Retry All',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.orange)),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                // Last Error Banner (if present)
                if (lastError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.error, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lastError.errorCategory?.code ?? 'INTERNAL_ERROR',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '[${lastError.subsystem.nameUpper}]',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            lastError.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontSize: 12),
                          ),
                        ),
                        Text(
                          DateFormat('hh:mm:ss a').format(lastError.timestamp),
                          style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDiagnosticsTab(context),
                _buildAuditTrailTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    Widget? actionWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 11)),
                    if (actionWidget != null) actionWidget,
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: DIAGNOSTIC EVENTS FEED ---
  Widget _buildDiagnosticsTab(BuildContext context) {
    return Column(
      children: [
        // Subsystem & Result Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          color: AppColors.surface(context),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Subsystems:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: const Text('ALL'),
                  selected: _selectedSubsystem == null,
                  onSelected: (val) =>
                      setState(() => _selectedSubsystem = null),
                ),
                ...DiagnosticSubsystem.values.map((sub) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(sub.nameUpper),
                      selected: _selectedSubsystem == sub,
                      onSelected: (val) =>
                          setState(() => _selectedSubsystem = val ? sub : null),
                    ),
                  );
                }),
                const SizedBox(width: AppSpacing.md),
                const Text('Result:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: const Text('ALL'),
                  selected: _selectedResult == null,
                  onSelected: (val) => setState(() => _selectedResult = null),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: const Text('FAILURE'),
                    selected: _selectedResult == DiagnosticResult.failure,
                    onSelected: (val) => setState(() => _selectedResult =
                        val ? DiagnosticResult.failure : null),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: const Text('SUCCESS'),
                    selected: _selectedResult == DiagnosticResult.success,
                    onSelected: (val) => setState(() => _selectedResult =
                        val ? DiagnosticResult.success : null),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Live Diagnostic Event List
        Expanded(
          child: StreamBuilder<DiagnosticEvent>(
            stream: _diagnosticsService.onDiagnosticEvent,
            builder: (context, snapshot) {
              final events = _diagnosticsService.getRecentEvents(
                subsystem: _selectedSubsystem,
                result: _selectedResult,
                limit: 100,
              );

              if (events.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monitor_heart_outlined,
                          size: 48, color: AppColors.textSecondary(context)),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No diagnostic events recorded yet',
                          style: TextStyle(
                              color: AppColors.textSecondary(context))),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: events.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _buildDiagnosticEventTile(context, event);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticEventTile(
      BuildContext context, DiagnosticEvent event) {
    final isSuccess = event.result == DiagnosticResult.success;
    final isWarning = event.result == DiagnosticResult.warning;
    final color = isSuccess
        ? AppColors.success
        : (isWarning ? AppColors.warning : AppColors.error);
    final icon = isSuccess
        ? Icons.check_circle_outline
        : (isWarning ? Icons.warning_amber : Icons.highlight_off);

    return Card(
      elevation: 0,
      color: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderSm,
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 22),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event.subsystem.nameUpper,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (event.errorCategory != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  event.errorCategory!.code,
                  style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                event.operationId,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${event.durationMs}ms',
              style: TextStyle(
                  color: AppColors.textSecondary(context), fontSize: 11),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  event.message,
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                DateFormat('hh:mm:ss a').format(event.timestamp),
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 10),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('Operation ID: ${event.operationId}',
                    style: const TextStyle(fontSize: 11)),
                if (event.storeId != null)
                  SelectableText('Store ID: ${event.storeId}',
                      style: const TextStyle(fontSize: 11)),
                if (event.userId != null)
                  SelectableText('User ID: ${event.userId}',
                      style: const TextStyle(fontSize: 11)),
                SelectableText('Device ID: ${event.deviceId}',
                    style: const TextStyle(fontSize: 11)),
                if (event.entityId != null)
                  SelectableText('Entity ID: ${event.entityId}',
                      style: const TextStyle(fontSize: 11)),
                if (event.metadata.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const Text('Metadata (Sanitized):',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: Colors.black12,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ')
                          .convert(event.metadata),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                ],
                if (event.stackTrace != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const Text('Stack Trace (Sanitized):',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.error)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: Colors.black12,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: SelectableText(
                      event.stackTrace!,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: AUDIT TRAIL FEED ---
  Widget _buildAuditTrailTab(BuildContext context) {
    return Column(
      children: [
        // Action Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          color: AppColors.surface(context),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Audit Actions:',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                  label: const Text('ALL'),
                  selected: _selectedAuditAction == null,
                  onSelected: (val) =>
                      setState(() => _selectedAuditAction = null),
                ),
                ...AuditActionType.values.map((act) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(act.code),
                      selected: _selectedAuditAction == act,
                      onSelected: (val) => setState(
                          () => _selectedAuditAction = val ? act : null),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Live Audit List
        Expanded(
          child: StreamBuilder<AuditRecord>(
            stream: _auditService.onAuditRecord,
            builder: (context, snapshot) {
              final records = _auditService.getRecentAuditRecords(
                action: _selectedAuditAction,
                limit: 100,
              );

              if (records.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off,
                          size: 48, color: AppColors.textSecondary(context)),
                      const SizedBox(height: AppSpacing.sm),
                      Text('No business audit records logged',
                          style: TextStyle(
                              color: AppColors.textSecondary(context))),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: records.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final record = records[index];
                  return _buildAuditRecordTile(context, record);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAuditRecordTile(BuildContext context, AuditRecord record) {
    IconData icon = Icons.receipt_long;
    Color color = Colors.blueGrey;

    switch (record.action) {
      case AuditActionType.refund:
        icon = Icons.undo;
        color = Colors.orange;
        break;
      case AuditActionType.voidOrder:
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      case AuditActionType.priceChange:
        icon = Icons.price_change_outlined;
        color = Colors.purple;
        break;
      case AuditActionType.stockAdjustment:
        icon = Icons.inventory_2_outlined;
        color = Colors.teal;
        break;
      case AuditActionType.permissionChange:
        icon = Icons.security;
        color = Colors.indigo;
        break;
      case AuditActionType.subscriptionChange:
        icon = Icons.card_membership;
        color = Colors.deepOrange;
        break;
      case AuditActionType.storeConfigChange:
        icon = Icons.settings_suggest;
        color = Colors.blue;
        break;
      case AuditActionType.adminOperation:
        icon = Icons.admin_panel_settings;
        color = Colors.brown;
        break;
    }

    return Card(
      elevation: 0,
      color: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderSm,
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: AppRadius.borderSm,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                record.action.code,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${record.entityType} (${record.entityId.length > 12 ? record.entityId.substring(0, 12) : record.entityId})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'Actor: ${record.actorId} [${record.actorRole}]',
              style: TextStyle(
                  color: AppColors.textSecondary(context), fontSize: 11),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  record.reason ?? 'No reason provided',
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                DateFormat('MMM dd, hh:mm a').format(record.timestamp),
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 10),
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('Record ID: ${record.id}',
                    style: const TextStyle(fontSize: 11)),
                SelectableText('Store ID: ${record.storeId}',
                    style: const TextStyle(fontSize: 11)),
                SelectableText('Device ID: ${record.deviceId}',
                    style: const TextStyle(fontSize: 11)),
                if (record.previousState != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const Text('Previous State (Sanitized):',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: Colors.black12,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ')
                          .convert(record.previousState),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                ],
                if (record.newState != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const Text('New State (Sanitized):',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: Colors.black12,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ')
                          .convert(record.newState),
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
