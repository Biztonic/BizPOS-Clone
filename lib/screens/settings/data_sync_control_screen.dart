// ignore_for_file: unused_local_variable, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import 'package:biztonic_pos/services/sync_service.dart';
import 'package:url_launcher/url_launcher.dart';


class DataSyncControlScreen extends StatefulWidget {
  const DataSyncControlScreen({super.key});

  @override
  State<DataSyncControlScreen> createState() => _DataSyncControlScreenState();
}

class _DataSyncControlScreenState extends State<DataSyncControlScreen> {
  // Removed local _isGridView

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final syncService = provider.syncService;
        final isGridView = provider.dataControlGridView;

        return Scaffold(
          appBar: AppBar(
            title: Text("Data Control Center - ${provider.activeStore?.name ?? 'Global'}"),
            elevation: 0,
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Cloud Stats',
                onPressed: () {
                   syncService.refreshCloudCounts();
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refreshing Cloud Stats...")));
                },
              )
            ],
          ),
          body: ListenableBuilder(
            listenable: syncService,
            builder: (context, child) {
              final stats = syncService.getDetailedStats();
              final isOnline = stats['isOnline'] as bool;
              final pendingBreakdown = stats['pendingBreakdown'] as Map<String, int>;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final horizontalPadding = isDesktop ? 24.0 : 16.0;

                  return Column(
                    children: [
                       // STICKY HEADER
                       Padding(
                         padding: EdgeInsets.fromLTRB(horizontalPadding, isDesktop ? 24.0 : 16.0, horizontalPadding, 0),
                         child: _buildHealthHeader(context, provider, syncService, stats),
                       ),
                       const SizedBox(height: 16),

                       Expanded(
                         child: Row(
                           crossAxisAlignment: CrossAxisAlignment.stretch,
                           children: [
                            // Main Content Area
                            Expanded(
                              flex: 3,
                              child: ListView(
                                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                                children: [
                                   // SYNC CONFIGURATION (Merged from Settings)
                                   _buildSyncConfigSection(context, syncService),
                                   const SizedBox(height: 24),

                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                       Row(
                                         children: [
                                           Icon(isGridView ? Icons.grid_view : Icons.view_list, size: 20, color: Colors.grey),
                                           const SizedBox(width: 8),
                                           Text("Module Control Matrix", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7))),
                                         ],
                                       ),
                                       
                                       // View Toggle
                                       Container(
                                         decoration: BoxDecoration(
                                           color: Theme.of(context).cardColor,
                                           borderRadius: BorderRadius.circular(8),
                                           border: Border.all(color: Colors.grey.withValues(alpha: 0.2))
                                         ),
                                         child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             IconButton(
                                               icon: const Icon(Icons.grid_view, size: 20),
                                               color: isGridView ? Colors.blue : Colors.grey,
                                               onPressed: () => provider.setDataControlGridView(true),
                                             ),
                                             Container(width: 1, height: 20, color: Colors.grey.withValues(alpha: 0.2)),
                                             IconButton(
                                               icon: const Icon(Icons.view_list, size: 20),
                                               color: !isGridView ? Colors.blue : Colors.grey,
                                               onPressed: () => provider.setDataControlGridView(false),
                                             ),
                                           ],
                                         ),
                                       )
                                     ],
                                   ),
                                   const SizedBox(height: 16),
                                   
                                   if (isGridView)
                                     // Responsive Grid for Modules
                                     LayoutBuilder(builder: (context, constraints) {
                                       int crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                                       double childAspectRatio = constraints.maxWidth > 900 ? 1.4 : (constraints.maxWidth > 400 ? 1.3 : 2.0);
                                       
                                       return GridView.count(
                                         crossAxisCount: crossAxisCount,
                                         childAspectRatio: childAspectRatio,
                                         crossAxisSpacing: 16,
                                         mainAxisSpacing: 16,
                                         shrinkWrap: true,
                                         physics: const NeverScrollableScrollPhysics(),
                                         children: _buildModuleList(context, syncService, stats, pendingBreakdown, provider),
                                       );
                                     })
                                   else
                                     // List View
                                     Column(
                                       crossAxisAlignment: CrossAxisAlignment.stretch,
                                       children: _buildModuleList(context, syncService, stats, pendingBreakdown, provider, isList: true),
                                     ),

                                   // MOBILE ONLY SECTIONS (Actions moved inside scrollable area for mobile)
                                   if (!isDesktop) ...[
                                      const Divider(height: 48),
                                      Text("Global Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7))),
                                      const SizedBox(height: 16),
                                      _buildGlobalActions(context, syncService, isOnline, stats, provider),
                                      
                                      const Divider(height: 48),
                                      
                                      Text("Backup & Restore", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7))),
                                      const SizedBox(height: 16),
                                      _buildBackupSection(context, provider),
                                      const SizedBox(height: 32),
                                   ]
                                ],
                              ),
                            ),
                            
                            // Right Sidebar (Actions & Backup) - On Desktop
                            if (isDesktop)
                              Container(
                                width: 350,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  border: Border(left: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
                                ),
                                child: ListView(
                                  padding: const EdgeInsets.all(24),
                                  children: [
                                     Text("Global Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7))),
                                     const SizedBox(height: 16),
                                     _buildGlobalActions(context, syncService, isOnline, stats, provider),
                                     
                                     const Divider(height: 48),
                                     
                                     Text("Backup & Restore", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7))),
                                     const SizedBox(height: 16),
                                     _buildBackupSection(context, provider),
                                  ],
                                ),
                              )
                           ],
                          ),
                        ),
                     ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  List<Widget> _buildModuleList(BuildContext context, SyncService syncService, Map<String, dynamic> stats, Map<String, int> pendingBreakdown, DashboardProvider provider, {bool isList = false}) {
     // Helper to safely convert stat values to int (handle null and -1 sentinel values)
     int safeInt(dynamic value) => (value is int && value >= 0) ? value : 0;
     
     final list = [
        _buildModuleCard(context, syncService, "Orders", Icons.receipt_long, Colors.blue, safeInt(stats['orders']), safeInt(stats['cloudOrders']), pendingBreakdown['orders'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Inventory", Icons.inventory_2, Colors.orange, safeInt(stats['inventory']), safeInt(stats['cloudInventory']), pendingBreakdown['inventory'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Customers", Icons.people, Colors.purple, safeInt(stats['customers']), safeInt(stats['cloudCustomers']), pendingBreakdown['customers'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Settings", Icons.settings, Colors.blueGrey, safeInt(stats['settings']), safeInt(stats['cloudSettings']), pendingBreakdown['settings'] ?? 0, provider, isSettings: true, isList: isList),
        _buildModuleCard(context, syncService, "Employees", Icons.badge, Colors.teal, safeInt(stats['employees']), safeInt(stats['cloudEmployees']), pendingBreakdown['employees'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Floors", Icons.layers, Colors.indigo, safeInt(stats['floors']), safeInt(stats['cloudFloors']), pendingBreakdown['floors'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Tables", Icons.table_restaurant, Colors.brown, safeInt(stats['tables']), safeInt(stats['cloudTables']), pendingBreakdown['tables'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Suppliers", Icons.local_shipping, Colors.deepOrange, safeInt(stats['suppliers']), safeInt(stats['cloudSuppliers']), pendingBreakdown['suppliers'] ?? 0, provider, isList: isList),
        _buildModuleCard(context, syncService, "Notes", Icons.note_alt, Colors.cyan, safeInt(stats['notes']), safeInt(stats['cloudNotes']), pendingBreakdown['notes'] ?? 0, provider, isList: isList),
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
               final indexUrl = service.lastIndexErrorUrl;
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text("Sync Error: ${service.lastSyncError}"), 
                 backgroundColor: Colors.red,
                 duration: const Duration(seconds: 10),
               ));
               service.lastSyncError = null; // Clear after showing
            } else if (service.lastSyncWarning != null && service.lastSyncWarning!.isNotEmpty) {
               final indexUrl = service.lastIndexErrorUrl;
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text(service.lastSyncWarning!), 
                 backgroundColor: Colors.orange,
                 duration: const Duration(seconds: 10),
                 action: indexUrl != null ? SnackBarAction(
                    label: "FIX INDEX", 
                    textColor: Colors.white,
                    onPressed: () async {
                       if (await canLaunchUrl(Uri.parse(indexUrl))) {
                          await launchUrl(Uri.parse(indexUrl), mode: LaunchMode.externalApplication);
                       }
                    }
                 ) : null,
               ));
               service.lastSyncWarning = null; // Clear after showing
            } else {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label Complete!"), backgroundColor: Colors.green));
            }
         }
      } catch (e) {
         if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
  }

  Widget _buildHealthHeader(BuildContext context, DashboardProvider provider, SyncService service, Map<String, dynamic> stats) {
      bool isOnline = stats['isOnline'] ?? false;
      int totalPending = stats['pending'] ?? 0;
      
      // Check Mismatches for Health Status - with null safety
      int safeInt(dynamic value) => (value is int && value >= 0) ? value : 0;
      int ordersLocal = safeInt(stats['orders']);
      int ordersCloud = safeInt(stats['cloudOrders']);
      int invLocal = safeInt(stats['inventory']);
      int invCloud = safeInt(stats['cloudInventory']);
      int custLocal = safeInt(stats['customers']);
      int custCloud = safeInt(stats['cloudCustomers']);
      int setsLocal = safeInt(stats['settings']); 
      int setsCloud = safeInt(stats['cloudSettings']);
      int empLocal = safeInt(stats['employees']);
      int empCloud = safeInt(stats['cloudEmployees']);
      int flrLocal = safeInt(stats['floors']);
      int flrCloud = safeInt(stats['cloudFloors']);
      int tblLocal = safeInt(stats['tables']);
      int tblCloud = safeInt(stats['cloudTables']);
      int supLocal = safeInt(stats['suppliers']);
      int supCloud = safeInt(stats['cloudSuppliers']);
      int noteLocal = safeInt(stats['notes']);
      int noteCloud = safeInt(stats['cloudNotes']);
      
      bool hasMismatch = (ordersLocal != ordersCloud) || 
                        (invLocal != invCloud) || 
                        (custLocal != custCloud) ||
                        (setsLocal != setsCloud) ||
                        (empLocal != empCloud) ||
                        (flrLocal != flrCloud) ||
                        (tblLocal != tblCloud) ||
                        (supLocal != supCloud) ||
                        (noteLocal != noteCloud);

      String title = "System Healthy";
      String sub = "All data is synchronized";
      Color bg1 = Colors.green.shade800; // Success Green
      Color bg2 = Colors.green.shade600;
      
      if (!isOnline) {
         title = "Offline Mode";
         sub = "Changes queued locally";
         bg1 = Colors.grey.shade800; bg2 = Colors.grey.shade700;
      } else if (totalPending > 0) {
         title = "Syncing...";
         sub = "$totalPending items waiting to upload";
         bg1 = Colors.orange.shade800; bg2 = Colors.orange.shade600;
      } else if (hasMismatch) {
         title = "Data Mismatch";
         sub = "Cloud and Local data differ. Run 'Sync All Down'.";
         bg1 = Colors.amber.shade900; bg2 = Colors.amber.shade700;
      }
      
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [bg1, bg2]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: bg2.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                 Container(
                   width: 60, height: 60,
                   decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                 ),
                 Icon(isOnline ? ((totalPending > 0 || hasMismatch) ? Icons.cloud_sync : Icons.cloud_done) : Icons.cloud_off, color: Colors.white, size: 32),
                 if (totalPending > 0 && isOnline)
                   const Positioned(
                     right: 0, top: 0,
                     child: CircleAvatar(backgroundColor: Colors.orange, radius: 8),
                   )
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, 
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(sub,
                     style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      "Last Sync: ${service.lastSyncTime != null ? _timeAgo(service.lastSyncTime!) : 'Never'}",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
            if (totalPending > 0 || hasMismatch)
              ElevatedButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text("Fix Now"),
                style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.white, 
                   foregroundColor: Colors.blue.shade800,
                   elevation: 0
                ),
                onPressed: isOnline ? () => _handleSyncAction(context, () => service.syncUp(forceManual: true), "Sync") : null,
              )
          ],
        ),
      );
  }

  Widget _buildModuleCard(BuildContext context, SyncService service, String label, IconData icon, Color color, int local, int cloud, int pending, DashboardProvider provider, {bool isSettings = false, bool isList = false}) {
      // ... existing code ...
      String moduleKey = label.toLowerCase();
      bool isSyncing = service.isSyncingModule(moduleKey);
      bool mismatch = local != cloud && pending == 0;
      bool isSynced = !mismatch && pending == 0;

      Widget content = Padding(
        padding: const EdgeInsets.all(16),
        child: isList 
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (isSyncing)
                              Text("Syncing...", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))
                          else if (pending > 0)
                              Text("$pending Pending", style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))
                          else 
                              Text(isSynced ? "Synced" : "Mismatch", style: TextStyle(color: isSynced ? Colors.green : Colors.red, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                            _statItem("Local", local.toString()),
                            const SizedBox(width: 16),
                            Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
                            const SizedBox(width: 16),
                            _statItem("Cloud", cloud.toString()),
                         ],
                      ),
                    ),
                    ElevatedButton.icon(
                       style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          backgroundColor: isSyncing 
                            ? Colors.orange.withValues(alpha: 0.1) 
                            : (mismatch ? Colors.red : (pending > 0 ? Colors.orange : Colors.blue.withValues(alpha: 0.1))),
                          foregroundColor: isSyncing 
                            ? Colors.orange 
                            : (mismatch || pending > 0 ? Colors.white : Colors.blue),
                          elevation: (mismatch || pending > 0) ? 2 : 0,
                       ),
                       icon: isSyncing 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)) 
                          : Icon(mismatch ? Icons.healing : (pending > 0 ? Icons.sync_problem : Icons.sync), size: 18), 
                       label: Text(
                          isSyncing ? "Syncing..." : (mismatch ? "Fix Mismatch" : (pending > 0 ? "Sync Pending" : "Sync")), 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                       ),
                       onPressed: isSyncing ? null : () => _handleSyncAction(context, () => service.syncModule(moduleKey, forceManual: true), "Sync $label")
                    )
                  ],
                )
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (isSyncing)
                             Text("Syncing...", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))
                          else if (pending > 0)
                             Text("$pending Pending", style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))
                          else 
                             Text(isSynced ? "Synced" : "Mismatch", style: TextStyle(color: isSynced ? Colors.green : Colors.red, fontSize: 11)),
                        ],
                      ),
                    )
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        _statItem("Local", local.toString()),
                        Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
                        _statItem("Cloud", cloud.toString()),
                     ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                   width: double.infinity,
                   child: ElevatedButton.icon(
                         icon: isSyncing 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : Icon(mismatch ? Icons.healing : (pending > 0 ? Icons.sync_problem : Icons.sync), size: 16),
                         label: Text(
                            isSyncing ? "Syncing..." : (mismatch ? "Fix Mismatch" : (pending > 0 ? "Sync Pending" : "Force Sync")),
                            style: const TextStyle(fontWeight: FontWeight.bold)
                         ),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: mismatch ? Colors.red : (pending > 0 ? Colors.orange : color.withValues(alpha: 0.1)),
                           foregroundColor: mismatch || pending > 0 ? Colors.white : color,
                           elevation: mismatch || pending > 0 ? 2 : 0,
                         ),
                         onPressed: isSyncing ? null : () => _handleSyncAction(context, () => service.syncModule(moduleKey, forceManual: true), "Sync $label")
                   ),
                )
              ],
            ),
      );

      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isList ? 12 : 16)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
             content, // Just using content variable
             if (isSyncing)
                Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(color: color, backgroundColor: color.withValues(alpha: 0.1))),
          ],
        ),
      );
  }

  Widget _statItem(String label, String value) {
    return Column(
       children: [
         Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
         Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
       ],
    );
  }

  Widget _buildGlobalActions(BuildContext context, SyncService service, bool isOnline, Map<String, dynamic> stats, DashboardProvider provider) {
    // Extract for Heal Mismatch
    int ordersLocal = stats['orders'] ?? 0;
    int ordersCloud = stats['cloudOrders'] ?? 0;
    int invLocal = stats['inventory'] ?? 0;
    int invCloud = stats['cloudInventory'] ?? 0;
    int setsLocal = stats['settings'] ?? 0;
    int setsCloud = stats['cloudSettings'] ?? 0;

    bool isBasic = provider.activeStore?.subscriptionPlan == 'Basic';
    String plan = provider.activeStore?.subscriptionPlan ?? 'Basic';
    bool isStarting = plan == 'Starting';
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
                  // Removed redundant hasAddon definition here
                  
                  return Container(
                     margin: const EdgeInsets.only(bottom: 16),
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                        color: hasAddon ? Colors.green.shade50 : Colors.amber.shade100, 
                        borderRadius: BorderRadius.circular(8), 
                        border: Border.all(color: hasAddon ? Colors.green : Colors.amber)
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(children: [
                            Icon(hasAddon ? Icons.verified_user : Icons.offline_bolt, color: hasAddon ? Colors.green : Colors.amber),
                            const SizedBox(width: 12),
                            Expanded(
                               child: Text(
                                  hasAddon 
                                     ? "Data Center Addon Active: Custom Sync Enabled."
                                     : "Basic Plan: Offline Mode. Sync Managed by System.", 
                                  style: TextStyle(color: hasAddon ? Colors.green.shade900 : Colors.brown, fontWeight: FontWeight.bold)
                               )
                            ),
                            if (isSuper) const Chip(label: Text("Super Override"), backgroundColor: Colors.white)
                         ]),
                         const SizedBox(height: 8),
                         if (!hasAddon) ...[
                            Text("• Default Sync Frequency: $freq", style: const TextStyle(color: Colors.brown, fontSize: 13)),
                            Text("• Cloud Retention: $retention Days (Local data is permanent)", style: const TextStyle(color: Colors.brown, fontSize: 13)),
                         ] else ...[
                            const Text("• You can now set your own sync frequency below.", style: TextStyle(color: Colors.green, fontSize: 13)),
                            Text("• Cloud Retention: $retention Days (Upgrade to Standard for Unlimited)", style: const TextStyle(color: Colors.green, fontSize: 13)),
                         ]
                       ],
                     ),
                  );
               }
            ),
         
         if (plan == 'Starting')
            Container(
               margin: const EdgeInsets.only(bottom: 16),
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue)),
               child: Row(children: [
                  const Icon(Icons.check_circle, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("Starting Plan: Offline Mode. Unlimited Orders.", style: TextStyle(color: Colors.blueAccent))),
                  if (isSuper) const Chip(label: Text("Super Override"), backgroundColor: Colors.white)
               ]),
            ),

         SizedBox(
           width: double.infinity,
           height: 50,
           child: ElevatedButton.icon(
               icon: const Icon(Icons.cloud_upload),
               label: Text(isOfflineMode && isSuper ? "Force Backup (Super Admin)" : "Sync All Up"),
               style: ElevatedButton.styleFrom(backgroundColor: canSync ? Colors.green.shade600 : Colors.grey, foregroundColor: Colors.white),
               onPressed: (isOnline && canSync) ? () => _handleSyncAction(context, () => service.syncUp(forceManual: hasAddon || isSuper), "Upload") : null,
           ),
         ),
         const SizedBox(height: 12),
         SizedBox(
           width: double.infinity,
           height: 50,
           child: ElevatedButton.icon(
               icon: const Icon(Icons.cloud_download),
               label: const Text("Sync All Down"),
               style: ElevatedButton.styleFrom(backgroundColor: canSync ? Colors.blue.shade600 : Colors.grey, foregroundColor: Colors.white),
               // Force Sync Down is always forced, but we might want to restrict it too? 
               // User said "store owner cant". So restrict.
               onPressed: (isOnline && canSync) ? () => _handleSyncAction(context, () => service.forceSyncDown(), "Download") : null,
           ),
         ),
         const SizedBox(height: 12),
         
         // HEAL MISMATCHES BUTTON (Kept as it is a vital repair tool, but hidden if healthy)
         if (ordersLocal != ordersCloud || invLocal != invCloud || setsLocal != setsCloud)
            OutlinedButton.icon(
              icon: const Icon(Icons.healing, color: Colors.orange),
              label: const Text("Heal / Fix Mismatches"),
              style: OutlinedButton.styleFrom(
                 foregroundColor: Colors.orange,
                 side: const BorderSide(color: Colors.orange)
              ),
              onPressed: () async {
                 _handleSyncAction(context, () => service.resolveMismatches(
                   inventoryCollection: (provider.debugCollectionFound != "None") ? provider.debugCollectionFound : null
                 ), "Repairing");
              }
            ),
      ],
    );
  }

  Widget _buildSyncConfigSection(BuildContext context, SyncService service) {
     return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        child: ListTile(
           leading: Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
             child: const Icon(Icons.timer, color: Colors.blue),
           ),
           title: const Text("Sync Frequency", style: TextStyle(fontWeight: FontWeight.bold)),
           subtitle: const Text("Control how often data syncs with cloud"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)
              ),
              child: Builder(
                builder: (context) {
                  final activeStore = Provider.of<DashboardProvider>(context, listen: false).activeStore;
                  final plan = activeStore?.subscriptionPlan ?? 'Basic';
                  final hasAddon = activeStore?.addons.contains('data_center') ?? false;
                  
                  // Disable ONLY if Basic AND NO Data Center Addon
                  bool isDisabled = (plan == 'Basic' && !hasAddon);
                  
                  if (isDisabled) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(service.syncFrequency, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    );
                  }

                  return DropdownButton<String>(
                    value: service.syncFrequency,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
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
          // 1. Auto Backup Toggle & Config
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2))
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Auto Backup", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(provider.autoBackupEnabled 
                      ? "Running ${provider.backupFrequency.toLowerCase()} at ${provider.backupTime.format(context)}" 
                      : "Automatically save local backups"),
                  value: provider.autoBackupEnabled,
                  onChanged: (val) => provider.toggleAutoBackup(val),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.access_time, color: Colors.purple),
                  ),
                ),
                if (provider.autoBackupEnabled) ...[
                   const Divider(height: 1),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     child: Row(
                       children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                               decoration: const InputDecoration(labelText: "Frequency", border: InputBorder.none, contentPadding: EdgeInsets.zero),
                               value: provider.backupFrequency,
                               items: ['Daily', 'Weekly', 'Monthly'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                               onChanged: (val) {
                                  if (val != null) provider.setBackupFrequency(val);
                               }
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                 final time = await showTimePicker(context: context, initialTime: provider.backupTime);
                                 if (time != null) provider.setBackupTime(time);
                               },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: "Time", border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                child: Text(provider.backupTime.format(context), style: const TextStyle(fontSize: 16)),
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
          
          const SizedBox(height: 16),
          _backupTile(context, "Export Backup (JSON)", "Save local data to file", Icons.download, Colors.orange, () => provider.exportLocalBackup()),
          const SizedBox(height: 12),
          _backupTile(context, "Import Backup", "Restore from file", Icons.upload_file, Colors.teal, () => provider.restoreLocalBackup()),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Backup History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (provider.isFetchingBackups)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () => provider.refreshAvailableBackups(),
                  tooltip: 'Refresh List',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Backup List - Using Cache from Provider
          if (provider.availableBackups.isEmpty && !provider.isFetchingBackups)
             const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No backups found", style: TextStyle(color: Colors.grey))))
          else if (provider.availableBackups.isEmpty && provider.isFetchingBackups)
             const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
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
                    leading: const Icon(Icons.history, color: Colors.grey),
                    title: Text(name),
                    subtitle: Text("${_timeAgo(date)} • $size KB"),
                    trailing: TextButton(
                      child: const Text("Restore"),
                      onPressed: () {
                         showDialog(context: context, builder: (c) => AlertDialog(
                            title: const Text("Confirm Restore"),
                            content: Text("Are you sure you want to restore from $name? Current data will be replaced."),
                            actions: [
                               TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
                               ElevatedButton(
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                 onPressed: () {
                                    Navigator.pop(c);
                                    provider.restoreLocalBackup(file: backup['file'], webKey: backup['isWeb'] ? backup['key'] : null);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restoring Backup...")));
                                 }, 
                                 child: const Text("Restore")
                               )
                            ],
                         ));
                      },
                    ),
                 );
              },
            )
       ],
     );
  }

  Widget _backupTile(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                 child: Icon(icon, color: color),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                   ],
                 ),
               ),
               const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
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
