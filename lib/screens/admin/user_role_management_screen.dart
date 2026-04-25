// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/dashboard_provider.dart';
import '../../models/user_profile.dart';
import '../../models/store.dart';
import 'package:google_fonts/google_fonts.dart';
import 'role_configuration_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserRoleManagementScreen extends StatefulWidget {
  const UserRoleManagementScreen({super.key});

  @override
  State<UserRoleManagementScreen> createState() => _UserRoleManagementScreenState();
}

class _UserRoleManagementScreenState extends State<UserRoleManagementScreen> {
  final _searchController = TextEditingController();
   List<UserProfile> _users = [];
  bool _isLoading = false;
  Map<String, int> _stats = {'total': 0, 'admins': 0, 'active': 0, 'subscriptions': 0};
  Map<String, String> _userStorePlans = {};
  
  // Pagination
  final int _limit = 20; 
  final List<dynamic> _lastDocs = []; 
  dynamic _currentLastDoc; 
  int _currentPage = 1;
  bool _hasMore = true;

  // View Mode
  bool _isListView = false;

  // Filter & Search
  Timer? _debounce;
  String _selectedRoleFilter = 'All';
  List<String> get _filterOptions {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final roles = provider.roles.map((r) => r.name).toList();
    // STRICT MODE: Only show roles that actually exist in the DB, plus 'All' and 'Unauthorized'
    final allRoles = {'All', ...roles, 'Unauthorized'}.toList(); 
    return allRoles;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
      _loadStats();
      Provider.of<DashboardProvider>(context, listen: false).fetchRoles();
    });
    
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
       _loadUsers();
    });
  }

  Future<void> _loadStats() async {
    final stats = await Provider.of<DashboardProvider>(context, listen: false).getUserStats();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _loadUsers({bool next = false, bool prev = false}) async {
    setState(() => _isLoading = true);
    final provider = Provider.of<DashboardProvider>(context, listen: false);

    try {
      if (_searchController.text.isNotEmpty) {
        final results = await provider.searchUsers(_searchController.text);
        
        // Apply Filter Locally on Search Results
        List<UserProfile> filtered = results;
        if (_selectedRoleFilter != 'All') {
          filtered = results.where((u) => u.role == _selectedRoleFilter).toList();
        }

        if (mounted) {
          setState(() {
            _users = filtered;
            _isLoading = false;
            _hasMore = false; 
            _currentPage = 1; 
          });
        }
        return;
      }

      // Normal Pagination
      dynamic startAfter;
      if (next) {
        startAfter = _currentLastDoc;
        _lastDocs.add(_currentLastDoc);
      } else if (prev && _lastDocs.isNotEmpty) {
        _lastDocs.removeLast();
        startAfter = _lastDocs.isNotEmpty ? _lastDocs.last : null;
      } else {
        _lastDocs.clear();
        startAfter = null;
        _currentPage = 1;
      }

      final result = await provider.fetchPaginatedUsers(
        limit: _limit, 
        startAfter: startAfter, 
        filterRole: _selectedRoleFilter
      );
      
      if (mounted) {
         setState(() {
            _users = result['users'] as List<UserProfile>;
            _userStorePlans = result['storePlans'] as Map<String, String>;
            _currentLastDoc = result['lastDoc'];
            _isLoading = false;
            _hasMore = _users.length == _limit;
            if (next) _currentPage++;
            if (prev) _currentPage--;
         });
      }

    } catch (e) {
      if (mounted) setState(() => _isLoading = false);

    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600];
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: scaffoldColor, 
      body: CustomScrollView(
        slivers: [
           SliverAppBar(
             title: Text('User Management', style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
             centerTitle: false,
             backgroundColor: cardColor,
             foregroundColor: textColor,
             floating: true,
             snap: true,
             elevation: 0, 
             actions: [
                if (Provider.of<DashboardProvider>(context, listen: false).activeRole == 'Super Admin')
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
                    child: OutlinedButton.icon(
                       icon: const Icon(Icons.settings_suggest_outlined, size: 16),
                       label: const Text("Roles"),
                       onPressed: () {
                           Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleConfigurationScreen()));
                       },
                       style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: borderColor),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                       ),
                    ),
                  )
             ],
             bottom: PreferredSize(
               preferredSize: const Size.fromHeight(1),
               child: Container(color: borderColor, height: 1),
             ),
           ),
           
           SliverToBoxAdapter(
             child: Padding(
               padding: const EdgeInsets.all(16.0), // Reduced Padding
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    // Stats
                    LayoutBuilder(builder: (ctx, constraints) {
                       return Wrap(
                         spacing: 12,
                         runSpacing: 12,
                         children: [
                            _buildStatCard("Total Users", "${_stats['total']}", Icons.people_outline, Colors.blue, constraints.maxWidth),
                            _buildStatCard("Active Admins", "${_stats['admins']}", Icons.admin_panel_settings_outlined, Colors.orange, constraints.maxWidth),
                            _buildStatCard("Active Users", "${_stats['active']}", Icons.check_circle_outline, Colors.green, constraints.maxWidth),
                            _buildStatCard("Subscriptions", "${_stats['subscriptions']}", Icons.subscriptions_outlined, Colors.indigo, constraints.maxWidth),
                         ],
                       );
                    }),
                    const SizedBox(height: 20),
                    
                    // Search & View Toggle
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(fontSize: 14, color: textColor),
                              decoration: InputDecoration(
                                hintText: 'Search by email or name...',
                                hintStyle: TextStyle(color: subtitleColor),
                                prefixIcon: Icon(Icons.search, color: subtitleColor),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.blue),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // View Toggle
                        IconButton(
                          icon: Icon(_isListView ? Icons.grid_view_outlined : Icons.grid_view_rounded, 
                                     color: !_isListView ? Colors.blue : subtitleColor),
                          onPressed: () => setState(() => _isListView = false),
                          tooltip: "Grid View",
                        ),
                        IconButton(
                          icon: Icon(_isListView ? Icons.view_headline_rounded : Icons.view_headline_outlined,
                                     color: _isListView ? Colors.blue : subtitleColor),
                          onPressed: () => setState(() => _isListView = true),
                          tooltip: "List View",
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Filters
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filterOptions.map((role) {
                          final isSelected = _selectedRoleFilter == role;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedRoleFilter = role;
                                  _currentPage = 1;
                                  _loadUsers();
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? (isDark ? Colors.white : Colors.black) : cardColor,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: isSelected ? (isDark ? Colors.white : Colors.black) : borderColor, width: 1.5),
                                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset:const Offset(0,2))] : [],
                                ),
                                child: Text(
                                  role,
                                  style: TextStyle(
                                    color: isSelected ? (isDark ? Colors.black : Colors.white) : textColor,
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                 ],
               ),
             ),
           ),
           
           if (_isListView && _users.isNotEmpty)
             SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor, width: 0.5))
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text("USER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: subtitleColor, letterSpacing: 1.0))),
                        Expanded(flex: 2, child: Text("ROLE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: subtitleColor, letterSpacing: 1.0))),
                        Expanded(flex: 2, child: Text("STORE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: subtitleColor, letterSpacing: 1.0))),
                        Expanded(flex: 2, child: Text("FRANCHISE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: subtitleColor, letterSpacing: 1.0))),
                        const SizedBox(width: 80), // Actions Spacer
                      ],
                    ),
                  ),
                ),
             ),

           if (_isLoading)
               const SliverFillRemaining(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
           else if (_users.isEmpty)
               const SliverFillRemaining(child: Center(child: Text("No users found.", style: TextStyle(color: Colors.grey))))
           else if (_isListView)
               SliverPadding(
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                   sliver: SliverList(
                     delegate: SliverChildBuilderDelegate(
                       (ctx, i) => _buildUserListItem(_users[i], provider),
                       childCount: _users.length,
                     ),
                   ),
               )
           else
               SliverPadding(
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 sliver: SliverLayoutBuilder(
                   builder: (context, constraints) {
                     // Flexible Grid
                     int crossAxisCount = constraints.crossAxisExtent > 1200 ? 4 : (constraints.crossAxisExtent > 900 ? 3 : (constraints.crossAxisExtent > 600 ? 2 : 1));
                     return SliverGrid(
                       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: crossAxisCount,
                         mainAxisSpacing: 12,
                         crossAxisSpacing: 12,
                         childAspectRatio: 2.2, // Very Compact
                       ),
                       delegate: SliverChildBuilderDelegate(
                         (ctx, i) => _buildUserCard(_users[i], provider),
                         childCount: _users.length,
                       ),
                     );
                   }
                 ),
               ),
               
           SliverToBoxAdapter(
             child: Padding(
               padding: const EdgeInsets.all(24.0),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    TextButton(onPressed: (_currentPage > 1) ? () => _loadUsers(prev: true) : null, child: const Text('Previous')),
                    const SizedBox(width: 16),
                    Text("Page $_currentPage", style: const TextStyle(color: Colors.grey)),
                    const SizedBox(width: 16),
                    TextButton(onPressed: _hasMore ? () => _loadUsers(next: true) : null, child: const Text('Next')),
                 ],
               ),
             ),
           )
        ],
      ),
    );
  }

   Widget _buildStatCard(String title, String value, IconData icon, Color color, double parentWidth) {
    int cardsPerRow = parentWidth > 1100 ? 4 : (parentWidth > 700 ? 2 : 1);
    double gap = 12.0;
    double width = (parentWidth - (gap * (cardsPerRow - 1))) / cardsPerRow;
    if (parentWidth < 500) width = parentWidth; 
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600];

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        // No Shadow
      ),
      child: Row(
        children: [
           Container(
             padding: const EdgeInsets.all(10), 
             decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle), 
             child: Icon(icon, color: color, size: 22)
           ),
           const SizedBox(width: 12),
           Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
             Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
             Text(title, style: GoogleFonts.inter(fontSize: 12, color: subtitleColor)),
           ])
        ],
      ),
    );
  }

  Widget _buildUserCard(UserProfile user, DashboardProvider provider) {
    Store? store;
    try {
      if (user.storeId != null) store = provider.stores.firstWhere((s) => s.id == user.storeId);
    } catch (_) { /* Error ignored */ }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? (isDark ? const Color(0xFF1E1E1E) : Colors.white);
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[700];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // Store Image - Very subtle
            if (store != null && store.image != null && store.image!.isNotEmpty)
               Positioned(
                 right: 0, top: 0, bottom: 0, width: 60,
                 child: Opacity(
                   opacity: 0.1,
                   child: CachedNetworkImage(imageUrl: store.image!, fit: BoxFit.cover, errorWidget: (c,e,s) => const SizedBox()),
                 )
               ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                   CircleAvatar(
                     radius: 20,
                     backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100], 
                     child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', 
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16))
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, 
                             style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)), // Larger Font
                         Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, 
                             style: TextStyle(color: subtitleColor, fontSize: 13)),
                         const SizedBox(height: 8),
                         Wrap(
                           crossAxisAlignment: WrapCrossAlignment.center,
                           spacing: 6,
                           children: [
                             _buildRoleBadge(user.role),
                             if (user.demoStatus == 'pending')
                               Container(
                                 margin: const EdgeInsets.only(left: 6),
                                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                 decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2), 
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.5))
                                 ),
                                 child: const Text("DEMO PENDING", style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange
                                 )),
                               ),
                             if (store != null) ...[
                               Container(width: 1, height: 14, color: Colors.grey[400]), 
                               Text(
                                 store.name, 
                                 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)
                               ),
                               const SizedBox(width: 6),
                               _buildPlanBadge(_userStorePlans[store.id] ?? 'Basic'),
                             ]
                           ],
                         )
                       ],
                     ),
                   ),
                   Column(
                     children: [
                       IconButton(
                         icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 24),
                         onPressed: () => _showEditUserDialog(user, provider),
                         tooltip: "Edit",
                       ),
                       if (provider.activeRole == 'Super Admin')
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.red, size: 24),
                            onPressed: () => _confirmDeleteUser(user, provider),
                            tooltip: "Delete",
                           ),
                      ],
                    )
                 ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserListItem(UserProfile user, DashboardProvider provider) {
     String storeName = '-';
     String franchiseName = '-';
     if (user.storeId != null) {
       try {storeName = provider.stores.firstWhere((s) => s.id == user.storeId).name;} catch (_) { /* Error ignored */ }
     }
     if (user.franchiseId != null) {
        try {franchiseName = provider.franchises.firstWhere((f) => f.id == user.franchiseId).name;} catch (_) { /* Error ignored */ }
     }
  
     // User List Item Style fixes
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade100;
     final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
     final subtitleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey[600];

      return Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor))
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
           children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                       radius: 24,
                       backgroundColor: isDark ? Colors.blueGrey[900] : Colors.blueGrey[50], 
                       child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', 
                          style: TextStyle(color: isDark ? Colors.blueGrey[100] : Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 20))
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                          const SizedBox(height: 4),
                          Text(user.email, style: TextStyle(color: subtitleColor, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Row(
                   children: [
                      _buildRoleBadge(user.role),
                      if (user.demoStatus == 'pending')
                         Container(
                           margin: const EdgeInsets.only(left: 8),
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                           decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                           child: const Text("PENDING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                         )
                   ],
              ))),
              Expanded(flex: 2, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text(storeName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor), overflow: TextOverflow.ellipsis),
                   if (user.storeId != null) _buildPlanBadge(_userStorePlans[user.storeId] ?? 'Basic'),
                ],
              )),
              Expanded(flex: 2, child: Text(franchiseName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor))),
             
             // Actions
             Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 if (user.demoStatus == 'pending' && provider.activeRole == 'Super Admin')
                   Padding(
                     padding: const EdgeInsets.only(right: 8.0),
                     child: IconButton(
                       onPressed: () => _confirmApproveDemo(user, provider),
                       icon: const Icon(Icons.verified_user, size: 24, color: Colors.green),
                       tooltip: "Approve Demo Request",
                     ),
                   ),

                 IconButton(
                   onPressed: () => _showEditUserDialog(user, provider), 
                   icon: const Icon(Icons.edit_outlined, size: 24, color: Colors.blue),
                   tooltip: "Edit User",
                 ),
                 if (provider.activeRole == 'Super Admin')
                   IconButton(
                     onPressed: () => _confirmDeleteUser(user, provider),
                     icon: const Icon(Icons.delete_forever, size: 24, color: Colors.red),
                     tooltip: "Delete User",
                   ),
               ],
             )
          ],
        ),
      );
   }

  void _confirmApproveDemo(UserProfile user, DashboardProvider provider) {
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text("Approve Demo Access?"),
         content: const Text("This enables the user to access the interactive demo dashboard."),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
           ElevatedButton(
             onPressed: () async {
                await provider.approveDemoRequest(user.uid);
                if (mounted) Navigator.pop(ctx);
                _loadUsers();
             },
             child: const Text("Approve"),
           )
         ],
       )
     );
  }

  void _confirmDeleteUser(UserProfile user, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete User?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete ${user.name} (${user.email})?\nThis action cannot be undone."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
             style: TextButton.styleFrom(foregroundColor: Colors.red),
             child: const Text("Proceed"),
             onPressed: () {
                Navigator.pop(ctx);
                // Second Confirmation
                showDialog(
                   context: context,
                   builder: (ctx2) => AlertDialog(
                      title: const Text("⚠ FINAL CONFIRMATION", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      content: const Text("This user will be PERMANENTLY DELETED from the database.\n\nAre you absolutely sure?"),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text("Cancel")),
                        ElevatedButton(
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                           child: const Text("YES, DELETE PERMANENTLY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                           onPressed: () async {
                              Navigator.pop(ctx2);
                              try {
                                 await provider.deleteUser(user.uid);
                                 _loadUsers(); // Refresh
                                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Deleted Successfully"), backgroundColor: Colors.red));
                              } catch(e) {
                                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                              }
                           }
                        )
                      ]
                   )
                );
             }
          )
        ],
      )
    );
  }

  void _showEditUserDialog(UserProfile user, DashboardProvider provider) {
    String selectedRole = user.role;
    String? selectedStoreId = user.storeId;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Edit ${user.name}", style: const TextStyle(fontSize: 16)),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                   // Fallback: If user has a legacy role not in list, show it temporarily or default to Unauthorized
                   value: provider.roles.any((r) => r.name == selectedRole) || selectedRole == 'Unauthorized' ? selectedRole : 'Unauthorized',
                   decoration: const InputDecoration(
                     labelText: "Role",
                     border: OutlineInputBorder(), 
                     isDense: true
                   ),
                   items: {'Unauthorized', ...provider.roles.map((r) => r.name)} // Deduplicate
                      .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                   onChanged: (val) {
                     if (val != null) setDialogState(() => selectedRole = val);
                   },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                   value: provider.stores.any((s) => s.id == selectedStoreId) ? selectedStoreId : null,
                   decoration: const InputDecoration(
                     labelText: "Store",
                     border: OutlineInputBorder(), 
                     isDense: true
                   ),
                   items: [
                      const DropdownMenuItem(value: null, child: Text("Unassigned")),
                      ...provider.stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)))
                   ],
                   onChanged: (val) {
                     setDialogState(() => selectedStoreId = val);
                   },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
              TextButton(
                onPressed: () async {
                   if (selectedRole != user.role) {
                      await provider.updateUserRole(user.uid, selectedRole);
                   }
                   if (selectedStoreId != user.storeId) {
                      await provider.updateUserStores(user.uid, selectedStoreId != null ? [selectedStoreId!] : []);
                   }
                   if (mounted) Navigator.pop(ctx);
                   _loadUsers();
                   _loadStats();
                },
                child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        }
      ),
    );
  }

   Widget _buildPlanBadge(String plan) {
    Color color = Colors.grey;
    if (plan == 'Starting') color = Colors.blue;
    if (plan == 'Standard') color = Colors.green;
    if (plan == 'Premium') color = Colors.purple;
    if (plan == 'Elite') color = Colors.orange;
    if (plan == 'Enterprise') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        plan.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color = Colors.grey;
    if (role.contains('Admin')) color = Colors.blue;
    if (role.contains('Owner')) color = Colors.orange;
    if (role == 'Super Admin') color = Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(role.split(" ").last.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }
}
