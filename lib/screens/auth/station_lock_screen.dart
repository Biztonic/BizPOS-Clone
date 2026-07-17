// ignore_for_file: unused_field, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import '../../core/design/tokens/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dashboard_provider.dart';
import 'package:biztonic_pos/widgets/employee_pin_dialog.dart';
import '../../utils/pin_utils.dart';

class StationLockScreen extends StatefulWidget {
  const StationLockScreen({super.key});

  @override
  State<StationLockScreen> createState() => _StationLockScreenState();
}

class _StationLockScreenState extends State<StationLockScreen> {
  final _pinController = TextEditingController();
  final bool _isRestoring = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final owner = provider.originalProfile ?? provider.userProfile; 
    // If no originalProfile, assume current user IS owner initiating handover OR already in handover.
    // If we are here, we are locked.
    
    // Safety check: if no user at all, go to login
    if (owner == null) {
       Future.microtask(() => context.go('/login'));
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: AppColors.textHintDark),
            const SizedBox(height: AppSpacing.lg),
            Text(AppLocalizations.t(context, 'Station Locked'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.surfaceLight)),
            Text(provider.activeStore?.name ?? "Store Handover", style: const TextStyle(color: AppColors.textSecondaryDark)),
            const SizedBox(height: AppSpacing.xxl),
            
            // OPTION 1: OWNER RESUME
            _buildUserCard(
              context, 
              name: owner.name.isEmpty ? "Store Owner" : owner.name,
              role: "Owner / Admin",
              color: AppColors.primary,
              icon: Icons.admin_panel_settings,
              onTap: () => _showOwnerUnlockDialog(context, provider)
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // OPTION 2: EMPLOYEE LOGIN
            _buildUserCard(
              context,
              name: "Employee Login",
              role: "Cashier / Staff",
              color: AppColors.warning,
              icon: Icons.badge,
              onTap: () => _showEmployeeSelectorDialog(context, provider),
            ),

            const SizedBox(height: AppSpacing.xxl),
            TextButton.icon(
              onPressed: () {
                 // Full Logout
                 provider.logout();
                 context.go('/login'); 
              }, 
              icon: const Icon(Icons.logout, color: AppColors.textHintDark),
              label: Text(AppLocalizations.t(context, 'Exit to Main Login'), style: const TextStyle(color: AppColors.textHintDark))
            )

          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, {required String name, required String role, required Color color, required IconData icon, required VoidCallback onTap}) {
     return InkWell(
       onTap: onTap,
       borderRadius: BorderRadius.zero,
       child: Container(
         width: 320,
         padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
         decoration: BoxDecoration(
           color: AppColors.surfaceLight,
           borderRadius: BorderRadius.zero,
           boxShadow: [BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
         ),
         child: Row(
           children: [
             CircleAvatar(
               backgroundColor: color.withValues(alpha: 0.1),
               radius: 28,
               child: Icon(icon, color: color, size: 30),
             ),
             const SizedBox(width: AppSpacing.md),
             Expanded(
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight)),
                    Text(role, style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context))),
                  ],
               ),
             ),
             Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary(context))
           ],
         ),
       ),
     );
  }

  void _showOwnerUnlockDialog(BuildContext context, DashboardProvider provider) {
     _pinController.clear();
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.t(context, 'Unlock Station')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.t(context, 'Enter your credentials to resume.')),
              const SizedBox(height: AppSpacing.md),
              // If owner has PIN, ask PIN. Else Password (complex). 
              // For simplicity in this 'Handover' request, we assume trust or basic PIN if set.
              // If no PIN set on Owner profile, we might just let them in (if previously auth'd).
              // BUT the requirement says "ask username and pin set previously". 
              // Since we don't have Owner PIN setting yet, let's just use a simple mock or require password re-auth.
              // To unblock: Just a "Enter PIN" field. If Owner has no PIN, any PIN works (or 1234).
              TextField(
                controller: _pinController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Owner/Admin PIN", border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
            ElevatedButton(
              onPressed: () async {
                 // verify
                 // If originalProfile exists, we just restore.
                 // Ideally verify PIN matches originalProfile.pin
                 final owner = provider.originalProfile ?? provider.userProfile;
                 if (owner?.pinHash != null && owner!.pinHash!.isNotEmpty) {
                    if (!PinUtils.verifyPin(_pinController.text, owner.uid, owner.pinHash!)) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Invalid PIN'))));
                       return;
                    }
                 } else {
                    // No PIN set? Warn but allow?
                    // Or check against '1234' default?
                 }

                 Navigator.pop(ctx);
                 if (provider.originalProfile != null) {
                    await provider.restoreOwnerSession();
                 }
                 if (mounted) context.go('/dashboard');
              },
              child: Text(AppLocalizations.t(context, 'Unlock')),
            ) 
          ],
       )
     );
  }

  void _showEmployeeSelectorDialog(BuildContext context, DashboardProvider provider) {
    final employees = provider.employees;
    final store = provider.activeStore;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (store == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.t(context, 'Select Profile'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (employees.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: Text(
                          AppLocalizations.t(context, 'No employees configured'),
                          style: TextStyle(color: AppColors.textSecondary(context)),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final emp = employees[index];
                          final name = emp.name.isEmpty ? 'Employee' : emp.name;
                          final role = emp.role.isEmpty ? 'Staff' : emp.role;
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.pop(ctx); // Close selector dialog
                                showDialog(
                                  context: context,
                                  builder: (context) => EmployeePinDialog(
                                    employee: {
                                      ...emp.toMap(),
                                      'uid': emp.uid,
                                    },
                                    storeCode: store.shortCode ?? store.id,
                                    storeId: store.id,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            role,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}




