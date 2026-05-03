import 'package:flutter/material.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class SetPasswordScreen extends StatefulWidget {
  final String email;

  const SetPasswordScreen({super.key, required this.email});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _handleSetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // 1. Create the account in Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: _passwordController.text.trim(),
      );
      final uid = credential.user!.uid;

      // 2. Fetch data from email-keyed doc (pre-provisioned by Sales App)
      // Check both literal and lowercase doc IDs
      final inputEmail = widget.email.trim();
      final cleanEmail = inputEmail.toLowerCase();
      
      DocumentSnapshot? emailDoc;
      final docIdsToCheck = {inputEmail, cleanEmail};
      
      for (final docId in docIdsToCheck) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(docId).get();
        if (doc.exists) {
          emailDoc = doc;
          break;
        }
      }

      // If still not found by doc ID, try by email field
      if (emailDoc == null) {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('email', whereIn: [inputEmail, cleanEmail])
            .get();
        if (query.docs.isNotEmpty) {
          emailDoc = query.docs.first;
        }
      }
      
      final Map<String, dynamic> userData = (emailDoc != null && emailDoc.exists) ? (emailDoc.data() as Map<String, dynamic>? ?? {}) : {};
      
      // 3. Prepare data for the new UID-keyed doc (Standard for the app)
      userData['uid'] = uid;
      userData['email'] = widget.email.toLowerCase().trim();
      userData['needsInitialPassword'] = false;
      userData['updatedAt'] = FieldValue.serverTimestamp();
      
      // Ensure essential fields exist if doc was missing
      userData['role'] ??= 'Store Owner';
      userData['name'] ??= widget.email.split('@')[0];

      // 4. Save to UID-keyed doc
      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);

      // 5. Clean up the placeholder email-keyed doc
      if (emailDoc != null && emailDoc.exists) {
        await emailDoc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account activated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/create-store');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activate Account'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0D1B2A), Color(0xFF1B2838)]
                : const [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_reset, size: 64, color: Color(0xFF667eea)),
                        const SizedBox(height: 24),
                        Text(
                          'Welcome to BizPOS!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please set a password for ${widget.email} to continue.',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          obscureText: _obscurePassword,
                          validator: (val) => (val == null || val.length < 6)
                              ? 'Min 6 characters'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_reset),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          obscureText: _obscureConfirm,
                          validator: (val) => val != _passwordController.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSetPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Set Password & Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

