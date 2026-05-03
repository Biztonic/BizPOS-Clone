import '../core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/auth_provider.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      await provider.updateUserProfile(phoneNumber: _mobileController.text.trim());
      
      if (mounted) {
         // Router redirect will handle navigation automatically once profile is updated
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Profile"),
        actions: [
          TextButton.icon(
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
            icon: const Icon(Icons.logout, size: 20),
            label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.perm_contact_calendar, size: 64, color: AppColors.primaryLight),
                const SizedBox(height: 24),
                const Text(
                  "One Last Step!", 
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 8),
                Text(
                  "Please provide your mobile number to complete your registration.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary(context))
                ),
                const SizedBox(height: 32),
                
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.length < 10) {
                      return 'Please enter a valid mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text("Save & Continue"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
