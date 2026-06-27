import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/dashboard_provider.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/molecules/app_dialog.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_radius.dart';


class DataSyncControlScreen extends StatefulWidget {
  const DataSyncControlScreen({super.key});

  @override
  State<DataSyncControlScreen> createState() => _DataSyncControlScreenState();
}

class _DataSyncControlScreenState extends State<DataSyncControlScreen> {
  // Removed local _isGridView

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<DashboardProvider>(context, listen: false);
        provider.syncService.refreshLocalCounts();
        if (provider.syncService.isOnline) {
          provider.syncService.refreshCloudCounts();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final syncService = provider.syncService;
        final isGridView = provider.dataControlGridView;

        return ListenableBuilder(
          listenable: syncService,
          builder: (context, _) {
            final stats = syncService.getDetailedStats();
            final isOnline = stats['isOnline'] as bool;
            final pendingBreakdown = stats['pendingBreakdown'] as Map<String, int>;

            return PosScaffold(
              title: "Data Control Center - ${provider.activeStore?.name ?? 'Global'}",
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Cloud Stats',
                  onPressed: () {
                     syncService.refreshCloudCounts();
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Refreshing Cloud Stats...'))));
                  },
                )
              ],
              mainContent: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHealthHeader(context, provider, syncService, stats),
                    const SizedBox(height: AppSpacing.xl),
                    
                    _buildSyncConfigSection(context, syncService),
                    const SizedBox(height: AppSpacing.xl),

                    _buildMatrixHeader(context, provider, isGridView),
                    const SizedBox(height: AppSpacing.lg),
                    
                    if (isGridView)
                      GridView.count(
                        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 3 : (MediaQuery.of(context).size.width > 800 ? 2 : 1),
                        childAspectRatio: 1.5,
                        crossAxisSpacing: AppSpacing.lg,
                        mainAxisSpacing: AppSpacing.lg,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _buildModuleList(context, syncService, stats, pendingBreakdown, provider),
                      )
                    else
                      Column(
                        children: _buildModuleList(context, syncService, stats, pendingBreakdown, provider, isList: true),
                      ),

                    if (MediaQuery.of(context).size.width < 1100) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _buildMobileActions(context, syncService, isOnline, stats, provider),
                    ],
                  ],
                ),
              ),
              rightPanel: MediaQuery.of(context).size.width >= 1100 
                  ? _buildDesktopSidebar(context, syncService, stats, provider) 
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildMatrixHeader(BuildContext context, DashboardProvider provider, bool isGridView) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(isGridView ? Icons.grid_view : Icons.view_list, size: 20, color: AppColors.textSecondary(context)),
            const SizedBox(width: AppSpacing.sm),
            Text(AppLocalizations.t(context, 'Module Control Matrix'), style: AppTypography.h4),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: AppRadius.borderSm,
            border: Border.all(color: AppColors.surfaceVariant(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.grid_view, size: 18),
                color: isGridView ? AppColors.primary : AppColors.textSecondary(context),
                onPressed: () => provider.setDataControlGridView(true),
              ),
              Container(width: 1, height: 16, color: AppColors.surfaceVariant(context)),
              IconButton(
                icon: const Icon(Icons.view_list, size: 18),
                color: !isGridView ? AppColors.primary : AppColors.textSecondary(context),
                onPressed: () => provider.setDataControlGridView(false),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildDesktopSidebar(BuildContext context, SyncService syncService, Map<String, dynamic> stats, DashboardProvider provider) {
    bool isOnline = stats['isOnline'] as bool;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.t(context, 'Global Actions'), style: AppTypography.h4),
          const SizedBox(height: AppSpacing.lg),
          _buildGlobalActions(context, syncService, isOnline, stats, provider),
          const SizedBox(height: AppSpacing.xl * 2),
          Text(AppLocalizations.t(context, 'Backup & Restore'), style: AppTypography.h4),
          const SizedBox(height: AppSpacing.lg),
          _buildBackupSection(context, provider),
        ],
      ),
    );
  }

  Widget _buildMobileActions(BuildContext context, SyncService syncService, bool isOnline, Map<String, dynamic> stats, DashboardProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppSpacing.xl * 2),
        Text(AppLocalizations.t(context, 'Global Actions'), style: AppTypography.h4),
        const SizedBox(height: AppSpacing.lg),
        _buildGlobalActions(context, syncService, isOnline, stats, provider),
        const SizedBox(height: AppSpacing.xl * 2),
        Text(AppLocalizations.t(context, 'Backup & Restore'), style: AppTypography.h4),
        const SizedBox(height: AppSpacing.lg),
        _buildBackupSection(context, provider),
      ],
    );
  }

  List<Widget> _buildModuleList(BuildContext context, SyncService syncService, Map<String, dynamic> stats, Map<String, int> pendingBreakdown, DashboardProvider provider, {bool isList = false}) {
     // Helper to safely convert stat values to int (handle null and -1 sentinel values)
     int safeInt(dynamic value) => (value is int && value >= 0) ? value : 0;
     
     final list = [
        _buildModuleCard(context, syncService, "Orders", Icons.receipt_long, AppColors.primary, safeInt(stats['orders']), safeInt(stats['cloudOrders']), pendingBreakdown['orders'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Inventory", Icons.inventory_2, AppColors.warning, safeInt(stats['inventory']), safeInt(stats['cloudInventory']), pendingBreakdown['inventory'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Customers", Icons.people, AppColors.primaryLight, safeInt(stats['customers']), safeInt(stats['cloudCustomers']), pendingBreakdown['customers'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Settings", Icons.settings, AppColors.primaryLightGrey, safeInt(stats['settings']), safeInt(stats['cloudSettings']), pendingBreakdown['settings'] ?? 0, provider, isSettings: true, isList: isList),
        _buildModuleCard(context, syncService, "Employees", Icons.badge, AppColors.primary, safeInt(stats['employees']), safeInt(stats['cloudEmployees']), pendingBreakdown['employees'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Floors", Icons.layers, AppColors.primary, safeInt(stats['floors']), safeInt(stats['cloudFloors']), pendingBreakdown['floors'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Tables", Icons.table_restaurant, AppColors.textSecondary(context), safeInt(stats['tables']), safeInt(stats['cloudTables']), pendingBreakdown['tables'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Suppliers", Icons.local_shipping, AppColors.warning, safeInt(stats['suppliers']), safeInt(stats['cloudSuppliers']), pendingBreakdown['suppliers'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Notes", Icons.note_alt, AppColors.primaryLight, safeInt(stats['notes']), safeInt(stats['cloudNotes']), pendingBreakdown['notes'] ?? 0, provider, isList: isList),
     ];
     return isList ? list.map((e) => Padding(padding: const EdgeInsets.only(bottom: 12), child: e)).toList() : list;
  }

  Future<void> _handleSyncAction(BuildContext context, Future<void> Function() action, String label) async {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label Started..."), duration: const Duration(seconds: 1)));
      try {
         await action();
         if (context.mounted) {
            final service = Provider.of<DashboardProvider>(context, listen: false).syncService;
            if (service.lastSyncError != null && service.lastSyncError!.isNotEmpty) {
               
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text("Sync Error: ${service.lastSyncError}"), 
                 backgroundColor: AppColors.error,
                 duration: const Duration(seconds: 10),
               ));
               service.lastSyncError = null; // Clear after showing
            } else if (service.lastSyncWarning != null && service.lastSyncWarning!.isNotEmpty) {
               final indexUrl = service.lastIndexErrorUrl;
               
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text(service.lastSyncWarning!), 
                 backgroundColor: AppColors.warning,
                 duration: const Duration(seconds: 10),
                 action: indexUrl != null ? SnackBarAction(
                    label: "FIX INDEX", 
                    textColor: AppColors.surfaceLight,
                    onPressed: () async {
                       if (await canLaunchUrl(Uri.parse(indexUrl))) {
                          await launchUrl(Uri.parse(indexUrl), mode: LaunchMode.externalApplication);
                       }
                    }
                 ) : null,
               ));
               service.lastSyncWarning = null; // Clear after showing
            } else {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label Complete!"), backgroundColor: AppColors.success));
            }
         }
      } catch (e) {
         if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error));
      }
  }

  Widget _buildHealthHeader(BuildContext context, DashboardProvider provider, SyncService service, Map<String, dynamic> stats) {
      bool isOnline = stats['isOnline'] ?? false;
      int totalPending = stats['pending'] ?? 0;
      
      bool isSuper = provider.userProfile?.role == 'Super Admin';
      String plan = provider.activeStore?.subscriptionPlan ?? 'Basic';
      bool isOfflineMode = (plan == 'Basic' || plan == 'Starting');
      bool hasAddon = provider.activeStore?.addons.contains('data_center') ?? false;
      bool canSync = !isOfflineMode || isSuper || hasAddon;
      
      int safeInt(dynamic value) => (value is int && value >= 0) ? value : 0;
      
      bool hasMismatch = (safeInt(stats['orders']) != safeInt(stats['cloudOrders'])) || 
                        (safeInt(stats['inventory']) != safeInt(stats['cloudInventory'])) || 
                        (safeInt(stats['customers']) != safeInt(stats['cloudCustomers'])) ||
                        (safeInt(stats['settings']) != safeInt(stats['cloudSettings'])) ||
                        (safeInt(stats['employees']) != safeInt(stats['cloudEmployees'])) ||
                        (safeInt(stats['floors']) != safeInt(stats['cloudFloors'])) ||
                        (safeInt(stats['tables']) != safeInt(stats['cloudTables'])) ||
                        (safeInt(stats['suppliers']) != safeInt(stats['cloudSuppliers'])) ||
                        (safeInt(stats['notes']) != safeInt(stats['cloudNotes']));

      String title = "System Healthy";
      String sub = "All data is synchronized";
      Color statusColor = AppColors.success;
      
      if (!isOnline) {
         title = "Offline Mode";
         sub = "Changes queued locally";
         statusColor = AppColors.textSecondary(context);
      } else if (totalPending > 0) {
         title = "Syncing...";
         sub = "$totalPending items waiting to upload";
         statusColor = AppColors.warning;
      } else if (hasMismatch) {
         title = "Data Mismatch";
         sub = "Cloud and Local data differ. Run 'Sync All Down'.";
         statusColor = AppColors.error;
      }
      
      return AppCard(
        backgroundColor: statusColor.withValues(alpha: 0.1),
        borderColor: statusColor.withValues(alpha: 0.2),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: AppRadius.borderSm,
              ),
              child: Icon(
                isOnline ? ((totalPending > 0 || hasMismatch) ? Icons.cloud_sync : Icons.cloud_done) : Icons.cloud_off, 
                color: statusColor, 
                size: 28
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.h3.copyWith(color: statusColor)),
                  Text(sub, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "Last Sync: ${service.lastSyncTime != null ? _timeAgo(service.lastSyncTime!) : 'Never'}",
                    style: AppTypography.bodySmall.copyWith(fontSize: 10, color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
            if (totalPending > 0 || hasMismatch)
              AppButton(
                label: "Fix Now",
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                onPressed: (isOnline && canSync) ? () => _handleSyncAction(context, () => service.syncUp(forceManual: true), "Sync") : null,
              )
          ],
        ),
      );
  }

  Widget _buildStatusChip(String status, Color baseColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderXs,
        border: Border.all(color: baseColor.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        status,
        style: AppTypography.labelSmall.copyWith(
          color: baseColor,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, SyncService service, String label, IconData icon, Color color, int local, int cloud, int pending, DashboardProvider provider, {bool isSettings = false, bool isList = false}) {
      String moduleKey = label.toLowerCase();
      bool isSyncing = service.isSyncingModule(moduleKey);
      bool mismatch = local != cloud && pending == 0;
      bool isSynced = !mismatch && pending == 0;

      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      if (isSyncing)
                        _buildStatusChip(AppLocalizations.t(context, 'Syncing...'), color)
                      else if (pending > 0)
                        _buildStatusChip("$pending Pending", AppColors.warning)
                      else 
                        _buildStatusChip(isSynced ? "Synced" : "Mismatch", isSynced ? AppColors.success : AppColors.error),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context).withValues(alpha: 0.3),
                borderRadius: AppRadius.borderSm,
                border: Border.all(color: AppColors.surfaceVariant(context).withValues(alpha: 0.2), width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem("Local Records", local.toString()),
                  Container(width: 1, height: 28, color: AppColors.surfaceVariant(context)),
                  _statItem("Cloud Records", cloud.toString()),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: isSyncing ? "Syncing..." : (mismatch ? "Fix Mismatch" : (pending > 0 ? "Sync Pending" : "Force Sync")),
                variant: (mismatch || pending > 0) ? AppButtonVariant.primary : AppButtonVariant.ghost,
                size: AppButtonSize.small,
                isLoading: isSyncing,
                onPressed: isSyncing ? null : () => _handleSyncAction(context, () => service.syncModule(moduleKey, forceManual: true), "Sync $label"),
              ),
            ),
          ],
        ),
      );
  }

  Widget _statItem(String label, String value) {
    return Column(
       mainAxisSize: MainAxisSize.min,
       children: [
         Text(
           label.toUpperCase(), 
           style: AppTypography.labelSmall.copyWith(
             fontSize: 9, 
             color: AppColors.textSecondary(context),
             fontWeight: FontWeight.bold,
             letterSpacing: 0.5,
           )
         ),
         const SizedBox(height: 4),
         Text(
           value, 
           style: AppTypography.titleLarge.copyWith(
             fontWeight: FontWeight.bold,
             color: AppColors.textPrimary(context),
           )
         ),
       ],
    );
  }

  Widget _buildGlobalActions(BuildContext context, SyncService service, bool isOnline, Map<String, dynamic> stats, DashboardProvider provider) {
    int ordersLocal = stats['orders'] ?? 0;
    int ordersCloud = stats['cloudOrders'] ?? 0;
    int invLocal = stats['inventory'] ?? 0;
    int invCloud = stats['cloudInventory'] ?? 0;
    int setsLocal = stats['settings'] ?? 0;
    int setsCloud = stats['cloudSettings'] ?? 0;

    String plan = provider.activeStore?.subscriptionPlan ?? 'Basic';
    bool isOfflineMode = (plan == 'Basic' || plan == 'Starting');
    bool isSuper = provider.userProfile?.role == 'Super Admin';
    final hasAddon = provider.activeStore?.addons.contains('data_center') ?? false;
    bool canSync = !isOfflineMode || isSuper || hasAddon;

    return Column(
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: service.retrievePlatformLimits(),
          builder: (context, snapshot) {
            final limits = snapshot.data;
            final syncFreqObj = limits?['sync_frequency_str'];
            final freq = (syncFreqObj is String) ? syncFreqObj.replaceAll('_', ' ') : '1 DAY';
            final retention = limits?['cloud_retention_days'] ?? 30;
            
            return AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              backgroundColor: hasAddon ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
              borderColor: (hasAddon ? AppColors.success : AppColors.warning).withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(hasAddon ? Icons.verified_user : Icons.offline_bolt, color: hasAddon ? AppColors.success : AppColors.warning),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        hasAddon 
                          ? "Data Center Addon Active"
                          : "Basic Plan: Offline Mode", 
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)
                      )
                    ),
                    if (isSuper) 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: AppRadius.borderXs,
                          border: Border.all(color: AppColors.surfaceVariant(context), width: 0.5),
                        ),
                        child: Text(AppLocalizations.t(context, 'Super Override'), style: AppTypography.labelSmall),
                      ),
                  ]),
                  const SizedBox(height: AppSpacing.sm),
                  Text("• Sync Frequency: $freq", style: AppTypography.bodySmall),
                  Text("• Cloud Retention: $retention Days", style: AppTypography.bodySmall),
                ],
              ),
            );
          }
        ),
          
        if (plan == 'Starting')
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Row(children: [
              const Icon(Icons.check_circle, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(AppLocalizations.t(context, 'Starting Plan: Offline Mode. Unlimited Orders.'), style: AppTypography.bodyMedium.copyWith(color: AppColors.primary))),
            ]),
          ),

        AppButton(
          label: isOfflineMode && isSuper ? "Force Backup (Super Admin)" : "Sync All Up",
          variant: AppButtonVariant.primary,
          size: AppButtonSize.large,
          onPressed: (isOnline && canSync) ? () => _handleSyncAction(context, () => service.syncUp(forceManual: hasAddon || isSuper), "Upload") : null,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: "Sync All Down",
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.large,
          onPressed: (isOnline && canSync) ? () => _handleSyncAction(context, () => service.forceSyncDown(), "Download") : null,
        ),
        
        if (ordersLocal != ordersCloud || invLocal != invCloud || setsLocal != setsCloud) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: "Heal / Fix Mismatches",
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.large,
            onPressed: (isOnline && canSync) ? () async {
              _handleSyncAction(context, () => service.resolveMismatches(
                inventoryCollection: (provider.debugCollectionFound != "None") ? provider.debugCollectionFound : null
              ), "Repairing");
            } : null,
          ),
        ],
      ],
    );
  }

  Widget _buildSyncConfigSection(BuildContext context, SyncService service) {
    return AppCard(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.borderSm),
          child: const Icon(Icons.timer, color: AppColors.primary, size: 20),
        ),
        title: Text(AppLocalizations.t(context, 'Sync Frequency'), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(AppLocalizations.t(context, 'Control cloud synchronization interval'), style: AppTypography.bodySmall),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant(context).withValues(alpha: 0.5),
            borderRadius: AppRadius.borderSm
          ),
          child: Builder(
            builder: (context) {
              final activeStore = Provider.of<DashboardProvider>(context, listen: false).activeStore;
              final hasAddon = activeStore?.addons.contains('data_center') ?? false;
              bool isDisabled = !hasAddon;
              
              if (isDisabled) {
                return Text(service.syncFrequency, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary(context)));
              }

              return DropdownButton<String>(
                value: service.syncFrequency,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                items: ['LIVE', 'DAILY', 'WEEKLY', 'MANUAL'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (val) {
                  if (val != null) service.setSyncFrequency(val);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBackupSection(BuildContext context, DashboardProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(AppLocalizations.t(context, 'Auto Backup'), style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                subtitle: Text(provider.autoBackupEnabled 
                    ? "Running ${provider.backupFrequency.toLowerCase()} at ${provider.backupTime.format(context)}" 
                    : "Automatically save local backups",
                    style: AppTypography.bodySmall),
                value: provider.autoBackupEnabled,
                onChanged: (val) => provider.toggleAutoBackup(val),
                secondary: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: AppRadius.borderSm),
                  child: const Icon(Icons.access_time, color: AppColors.secondary, size: 20),
                ),
              ),
              if (provider.autoBackupEnabled) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: "Frequency", 
                            labelStyle: AppTypography.bodySmall,
                            border: InputBorder.none, 
                            contentPadding: EdgeInsets.zero
                          ),
                          value: provider.backupFrequency,
                          items: ['Daily', 'Weekly', 'Monthly'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                          onChanged: (val) {
                            if (val != null) provider.setBackupFrequency(val);
                          }
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(context: context, initialTime: provider.backupTime);
                            if (time != null) provider.setBackupTime(time);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: "Time", 
                              labelStyle: AppTypography.bodySmall,
                              border: InputBorder.none, 
                              contentPadding: EdgeInsets.zero
                            ),
                            child: Text(provider.backupTime.format(context), style: AppTypography.bodyMedium),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
        
        const SizedBox(height: AppSpacing.md),
        _backupTile(context, "Export Backup (JSON)", "Save local data to file", Icons.download, AppColors.warning, () => provider.exportLocalBackup()),
        const SizedBox(height: AppSpacing.sm),
        _backupTile(context, "Import Backup", "Restore from file", Icons.upload_file, AppColors.success, () => provider.restoreLocalBackup()),

        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.t(context, 'Backup History'), style: AppTypography.headlineSmall.copyWith(fontSize: 18)),
            if (provider.isFetchingBackups)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                onPressed: () => provider.refreshAvailableBackups(),
                tooltip: 'Refresh List',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        
        if (provider.availableBackups.isEmpty && !provider.isFetchingBackups)
          Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Center(child: Text(AppLocalizations.t(context, 'No backups found'), style: TextStyle(color: AppColors.textSecondary(context)))))
        else if (provider.availableBackups.isEmpty && provider.isFetchingBackups)
          const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator()))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: provider.availableBackups.length,
            separatorBuilder: (_,__) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final backup = provider.availableBackups[index];
              final date = backup['date'] as DateTime;
              final size = backup['size'] as String;
              final name = backup['name'] as String;
              
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.history, color: AppColors.textSecondary(context)),
                title: Text(name, style: AppTypography.bodyMedium),
                subtitle: Text("${_timeAgo(date)} • $size KB", style: AppTypography.bodySmall),
                trailing: AppButton(
                  label: "Restore",
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: () {
                    AppDialog.show(
                      context: context,
                      title: "Confirm Restore",
                      icon: Icons.history_edu_outlined,
                      content: Text("Are you sure you want to restore from $name? Current local data will be overwritten and replaced with this backup content."),
                      primaryButtonText: "Restore Now",
                      onPrimaryPressed: () {
                        Navigator.pop(context);
                        provider.restoreLocalBackup(file: backup['file'], webKey: backup['isWeb'] ? backup['key'] : null);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Restoring Backup...')), backgroundColor: AppColors.primary));
                      },
                      secondaryButtonText: "Cancel",
                    );
                  },
                ),
              );
            },
          )
      ],
    );
  }

  Widget _backupTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: AppRadius.borderSm),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTypography.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textSecondary(context), size: 20),
        ],
      ),
    );
  }

  String _timeAgo(DateTime d) {
    Duration diff = DateTime.now().difference(d);
    if (diff.inDays > 365) return "${(diff.inDays / 365).floor()}y ago";
    if (diff.inDays > 30) return "${(diff.inDays / 30).floor()}mo ago";
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}



