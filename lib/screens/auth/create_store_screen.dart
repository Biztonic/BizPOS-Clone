
import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/design/tokens/app_colors.dart';

class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboard = Provider.of<DashboardProvider>(context, listen: false);
      if (dashboard.hasAnyStore && dashboard.activeStoreId == null) {
        debugPrint('ðŸ†• CreateStoreScreen: Stores exist but none active, redirecting to /select-store');
        context.go('/select-store');
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user == null || user.email == null) {
        throw Exception("User not authenticated correctly.");
      }

      // Create the store
      final newStoreId = await provider.addStore(
        _nameController.text.trim(), 
        user.email!,
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      
      // Explicitly set as active to ensure immediate selection
      await provider.setActiveStoreId(newStoreId);

      // The provider.addStore implementation is expected to:
      // 1. Create the store doc in Firestore
      // 2. Link the user to the store
      // 3. Set the active store ID
      // 4. Notify listeners

      // We rely on main.dart redirect to detect the state change (hasStore + activeStore)
      // and redirect to dashboard. But we can also force it here.
      if (mounted) {
         context.go('/dashboard');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error creating store: ${e.toString()}"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);
    
    // Reactive Redirect: If stores are found while on this screen AND no store is active
    if (dashboard.hasAnyStore && dashboard.activeStoreId == null) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) context.go('/select-store');
       });
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'Setup Your Store')),
        backgroundColor: AppColors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {
               Provider.of<AuthProvider>(context, listen: false).signOut();
            },
            icon: const Icon(Icons.logout),
            label: Text(AppLocalizations.t(context, 'Logout')),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Container(
            width: isDesktop ? 500 : double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.zero,
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimaryLight.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const Icon(Icons.store_rounded, size: 64, color: AppColors.primary),
                   const SizedBox(height: AppSpacing.lg),
                   Text(AppLocalizations.t(context, 'Welcome to BizPOS!'),
                     textAlign: TextAlign.center,
                     style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: AppSpacing.sm),
                   Text(AppLocalizations.t(context, 'To get started, please create your first store.'),
                     textAlign: TextAlign.center,
                     style: TextStyle(color: AppColors.textSecondary(context)),
                   ),
                   const SizedBox(height: AppSpacing.xl),

                   TextFormField(
                     controller: _nameController,
                     decoration: const InputDecoration(
                       labelText: "Store Name",
                       hintText: "e.g., Downtown Cafe",
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.business),
                     ),
                     validator: (value) {
                       if (value == null || value.trim().isEmpty) {
                         return "Please enter a store name";
                       }
                       return null;
                     },
                   ),
                   const SizedBox(height: AppSpacing.md),
                   
                   TextFormField(
                     controller: _addressController,
                     decoration: const InputDecoration(
                       labelText: "Address (Optional)",
                       hintText: "City, Street",
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.location_on_outlined),
                     ),
                   ),
                   const SizedBox(height: AppSpacing.md),
                   
                   TextFormField(
                     controller: _phoneController,
                     keyboardType: TextInputType.phone,
                     decoration: const InputDecoration(
                       labelText: "Phone (Optional)",
                       border: OutlineInputBorder(),
                       prefixIcon: Icon(Icons.phone),
                     ),
                   ),
                   const SizedBox(height: AppSpacing.xl),

                   SizedBox(
                     height: 50,
                     child: ElevatedButton(
                       onPressed: _isSubmitting ? null : _submit,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppColors.primary,
                         foregroundColor: AppColors.surfaceLight,
                         shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                       ),
                       child: _isSubmitting 
                         ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.surfaceLight, strokeWidth: 2))
                         : Text(AppLocalizations.t(context, 'Create Store'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                     ),
                   ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}




