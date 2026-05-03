import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/dashboard_provider.dart';
import '../../models/user_profile.dart';
import '../../models/store.dart';
import 'role_configuration_screen.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_colors.dart';

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
  
  final int _limit = 20; 
  final List<dynamic> _lastDocs = []; 
  dynamic _currentLastDoc; 
  int _currentPage = 1;
  bool _hasMore = true;

  bool _isListView = true;

  Timer? _debounce;
  String _selectedRoleFilter = 'All';

  List<String> get _filterOptions {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final roles = provider.roles.map((r) => r.name).toList();
    return {'All', ...roles, 'Unauthorized'}.toList(); 
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
    _debounce = Timer(const Duration(milliseconds: 500), () => _loadUsers());
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
        List<UserProfile> filtered = results;
        if (_selectedRoleFilter != 'All') {
          filtered = results.where((u) => u.role == _selectedRoleFilter).toList();
        }
        if (mounted) setState(() { _users = filtered; _isLoading = false; _hasMore = false; _currentPage = 1; });
        return;
      }
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
      final result = await provider.fetchPaginatedUsers(limit: _limit, startAfter: startAfter, filterRole: _selectedRoleFilter);
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
    return PosScaffold(
      title: "User Management",
      actions: [
        if (provider.activeRole == 'Super Admin')
          IconButton(
            icon: const Icon(Icons.settings_suggest_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleConfigurationScreen())),
            tooltip: "Roles",
          ),
        IconButton(
          icon: Icon(_isListView ? Icons.grid_view_outlined : Icons.view_headline_outlined),
          onPressed: () => setState(() => _isListView = !_isListView),
          tooltip: _isListView ? "Grid View" : "List View",
        ),
      ],
      mainContent: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsHeader(),
            const SizedBox(height: AppSpacing.lg),
            _buildSearchAndFilters(),
            const SizedBox(height: AppSpacing.lg),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_users.isEmpty)
              Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No users found.", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)))))
            else if (_isListView)
              _buildListView(provider)
            else
              _buildGridView(provider),
            const SizedBox(height: AppSpacing.lg),
            _buildPaginationControls(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _buildStatCard("Total Users", "${_stats['total']}", Icons.people_outline, AppColors.primary),
        _buildStatCard("Active Admins", "${_stats['admins']}", Icons.admin_panel_settings_outlined, AppColors.warning),
        _buildStatCard("Active Users", "${_stats['active']}", Icons.check_circle_outline, AppColors.success),
        _buildStatCard("Subscriptions", "${_stats['subscriptions']}", Icons.subscriptions_outlined, AppColors.primary),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppTypography.headlineMedium),
          Text(title, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Search by email or name...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: AppColors.textSecondary(context).withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filterOptions.map((role) {
              final isSelected = _selectedRoleFilter == role;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(role, style: AppTypography.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary(context))),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedRoleFilter = role;
                        _currentPage = 1;
                        _loadUsers();
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(DashboardProvider provider) {
    return Column(
      children: _users.map((user) => _buildUserListItem(user, provider)).toList(),
    );
  }

  Widget _buildGridView(DashboardProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : (constraints.maxWidth > 500 ? 2 : 1));
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.5,
          ),
          itemCount: _users.length,
          itemBuilder: (context, index) => _buildUserGridCard(_users[index], provider),
        );
      },
    );
  }

  Widget _buildUserListItem(UserProfile user, DashboardProvider provider) {
    String storeName = 'Unassigned';
    if (user.storeId != null) {
      try { storeName = provider.stores.firstWhere((s) => s.id == user.storeId).name; } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  Text(user.email, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context))),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _buildRoleBadge(user.role),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(storeName, style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w500)),
                  if (user.storeId != null) _buildPlanBadge(_userStorePlans[user.storeId] ?? 'Basic'),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _buildActions(user, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGridCard(UserProfile user, DashboardProvider provider) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(user.name, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              _buildActions(user, provider),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(user.email, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context)), overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRoleBadge(user.role),
              if (user.storeId != null) _buildPlanBadge(_userStorePlans[user.storeId] ?? 'Basic'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(UserProfile user, DashboardProvider provider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user.demoStatus == 'pending' && provider.activeRole == 'Super Admin')
          IconButton(
            onPressed: () => _confirmApproveDemo(user, provider),
            icon: const Icon(Icons.verified_user, size: 20, color: AppColors.success),
            tooltip: "Approve Demo",
          ),
        IconButton(
          onPressed: () => _showEditUserDialog(user, provider), 
          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryLight),
        ),
        if (provider.activeRole == 'Super Admin')
          IconButton(
            onPressed: () => _confirmDeleteUser(user, provider),
            icon: const Icon(Icons.delete_forever, size: 20, color: AppColors.error),
          ),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color = AppColors.textSecondary(context);
    if (role.contains('Admin')) color = AppColors.primary;
    if (role.contains('Owner')) color = AppColors.warning;
    if (role == 'Super Admin') color = AppColors.error;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(role.toUpperCase(), style: AppTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPlanBadge(String plan) {
    return Text(plan, style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary(context), fontStyle: FontStyle.italic));
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppButton(
          label: "Previous",
          onPressed: (_currentPage > 1) ? () => _loadUsers(prev: true) : null,
          variant: AppButtonVariant.outline,
        ),
        const SizedBox(width: AppSpacing.lg),
        Text("Page $_currentPage", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context))),
        const SizedBox(width: AppSpacing.lg),
        AppButton(
          label: "Next",
          onPressed: _hasMore ? () => _loadUsers(next: true) : null,
          variant: AppButtonVariant.outline,
        ),
      ],
    );
  }

  void _confirmApproveDemo(UserProfile user, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Approve Demo Access?", style: AppTypography.titleLarge),
        content: Text("This enables the user to access the interactive demo dashboard.", style: AppTypography.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)))),
          AppButton(
            label: "APPROVE",
            onPressed: () async {
               await provider.approveDemoRequest(user.uid);
               if (mounted) Navigator.pop(ctx);
               _loadUsers();
            },
          )
        ],
      )
    );
  }

  void _confirmDeleteUser(UserProfile user, DashboardProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete User?", style: AppTypography.titleLarge),
        content: Text("Are you sure you want to delete ${user.name}?\nThis action is PERMANENT.", style: AppTypography.bodyMedium),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)))),
          AppButton(
            label: "DELETE",
            variant: AppButtonVariant.outline,
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteUser(user.uid);
              _loadUsers();
            },
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
            title: Text("Edit ${user.name}", style: AppTypography.titleLarge),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                   value: provider.roles.any((r) => r.name == selectedRole) || selectedRole == 'Unauthorized' ? selectedRole : 'Unauthorized',
                   decoration: const InputDecoration(labelText: "Role", border: OutlineInputBorder()),
                   items: {'Unauthorized', ...provider.roles.map((r) => r.name)}
                      .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                   onChanged: (val) { if (val != null) setDialogState(() => selectedRole = val); },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String?>(
                   value: provider.stores.any((s) => s.id == selectedStoreId) ? selectedStoreId : null,
                   decoration: const InputDecoration(labelText: "Store", border: OutlineInputBorder()),
                   items: [
                      const DropdownMenuItem(value: null, child: Text("Unassigned")),
                      ...provider.stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                   ],
                   onChanged: (val) { setDialogState(() => selectedStoreId = val); },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text("CANCEL", style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)))),
              AppButton(
                label: "SAVE CHANGES",
                onPressed: () async {
                  if (selectedRole != user.role) await provider.updateUserRole(user.uid, selectedRole);
                  if (selectedStoreId != user.storeId) await provider.updateUserStores(user.uid, selectedStoreId != null ? [selectedStoreId!] : []);
                  if (mounted) Navigator.pop(ctx);
                  _loadUsers();
                  _loadStats();
                },
              )
            ],
          );
        }
      ),
    );
  }
}
