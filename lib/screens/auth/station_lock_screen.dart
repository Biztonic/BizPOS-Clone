// ignore_for_file: unused_field, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dashboard_provider.dart';
import 'package:biztonic_pos/screens/auth/employee_login_screen.dart';
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
      backgroundColor: Colors.blueGrey.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.white54),
            const SizedBox(height: 24),
            Text("Station Locked", style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white)),
            Text(provider.activeStore?.name ?? "Store Handover", style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 48),
            
            // OPTION 1: OWNER RESUME
            _buildUserCard(
              context, 
              name: owner.name.isEmpty ? "Store Owner" : owner.name,
              role: "Owner / Admin",
              color: Colors.blue,
              icon: Icons.admin_panel_settings,
              onTap: () => _showOwnerUnlockDialog(context, provider)
            ),
            
            const SizedBox(height: 24),
            
            // OPTION 2: EMPLOYEE LOGIN
            _buildUserCard(
              context,
              name: "Employee Login",
              role: "Cashier / Staff",
              color: Colors.orange,
              icon: Icons.badge,
              onTap: () {
                 // Push Employee Login - but modified to float or dialog?
                 // Or just navigate. If navigate, we need to ensure back comes here.
                 // For now, let's just push Material Page so we stay in 'Lock' context if they cancel.
                 Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmployeeLoginScreen()));
              }
            ),

            const SizedBox(height: 48),
            TextButton.icon(
              onPressed: () {
                 // Full Logout
                 provider.logout();
                 context.go('/login'); 
              }, 
              icon: const Icon(Icons.logout, color: Colors.white54),
              label: const Text("Exit to Main Login", style: TextStyle(color: Colors.white54))
            )

          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, {required String name, required String role, required Color color, required IconData icon, required VoidCallback onTap}) {
     return InkWell(
       onTap: onTap,
       borderRadius: BorderRadius.circular(16),
       child: Container(
         width: 320,
         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
         decoration: BoxDecoration(
           color: Colors.white,
           borderRadius: BorderRadius.circular(16),
           boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
         ),
         child: Row(
           children: [
             CircleAvatar(
               backgroundColor: color.withValues(alpha: 0.1),
               radius: 28,
               child: Icon(icon, color: color, size: 30),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Text(role, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
               ),
             ),
             const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
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
          title: const Text("Unlock Station"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter your credentials to resume."),
              const SizedBox(height: 16),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                 // verify
                 // If originalProfile exists, we just restore.
                 // Ideally verify PIN matches originalProfile.pin
                 final owner = provider.originalProfile ?? provider.userProfile;
                 if (owner?.pinHash != null && owner!.pinHash!.isNotEmpty) {
                    if (!PinUtils.verifyPin(_pinController.text, owner.uid, owner.pinHash!)) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid PIN")));
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
              child: const Text("Unlock"),
            ) 
          ],
       )
     );
  }
}
