import '../core/design/tokens/app_colors.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW
import 'package:go_router/go_router.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    
    // Basic email validation first to allow new customer check
    if (email.isEmpty || !email.contains('@')) {
      _formKey.currentState!.validate();
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      if (_isLogin) {
        // 1. Check if this is a new customer from the Sales App activation flow
        // We do this BEFORE full validation so password isn't required yet
        final needsActivation = await authProvider.checkIfNewCustomer(email);
        if (needsActivation) {
          if (mounted) {
            context.push('/set-password?email=$email');
          }
          return;
        }

        // 2. Proceed with normal login validation (now password IS required)
        if (!_formKey.currentState!.validate()) return;

        await authProvider.signInWithEmail(
          email,
          _passwordController.text.trim(),
        );
      } else {
        // Sign Up flow
        if (!_formKey.currentState!.validate()) return;
        await authProvider.signUpWithEmail(
          email,
          _passwordController.text.trim(),
          _mobileController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0D1B2A), Color(0xFF1B2838), Color(0xFF0D1B2A)]
                : const [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Threshold for desktop/tablet layout
            bool isWide = constraints.maxWidth >= 900;

            if (isWide) {
              return Row(
                children: [
                   // --- Left Branding Pane (Visible on Desktop/Tablet) ---
                  Expanded(
                    flex: 1,
                    child: _buildBrandingPane(isDark),
                  ),
                  // --- Right Auth Form Pane ---
                  Expanded(
                    flex: 1,
                    child: Container(
                      color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(48),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 450),
                            child: FadeTransition(
                              opacity: _fadeAnim,
                              child: _buildAuthForm(context, isLoading, isDark, size),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            // --- Mobile Layout (Vertical Stack) ---
            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildAuthForm(context, isLoading, isDark, size),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandingPane(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: ClipOval(
              child: Image.asset('assets/logo.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.storefront, size: 40, color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "BizTonic POS",
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
          ),
          const SizedBox(height: 16),
          Text(
            "The all-in-one platform for modern commerce. Manage sales, inventory, and staff with surgical precision.",
            style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.8), height: 1.5),
          ),
          const SizedBox(height: 48),
          
          // Feature List
          _buildFeatureItem(Icons.bolt, "Lightning Fast Billing", "Process transitions in seconds, even offline."),
          _buildFeatureItem(Icons.analytics_outlined, "Advanced Analytics", "Gain deep insights into your business performance."),
          _buildFeatureItem(Icons.cloud_sync, "Real-time Cloud Sync", "Your data is always backed up and accessible."),
          _buildFeatureItem(Icons.security, "Bank-grade Security", "Securing your business data with enterprise standards."),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm(BuildContext context, bool isLoading, bool isDark, Size size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Mobile Header (Hidden on Wide) ──
        if (MediaQuery.of(context).size.width < 900) ...[
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: ClipOval(
              child: Image.asset('assets/logo.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.storefront, size: 40, color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 16),
          const Text("BizTonic POS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
          const SizedBox(height: 32),
        ],

        // ── Auth Card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 40, offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isLogin ? "Welcome Back" : "Create Account",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: isDark ? Colors.white : AppColors.textSecondary(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLogin ? "Sign in to manage your store" : "Get started with BizTonic",
                  style: TextStyle(fontSize: 14, color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
                ),
                const SizedBox(height: 32),

                // Email
                _buildTextField(
                  key: const Key('email_input'),
                  controller: _emailController,
                  label: "Email Address",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                _buildTextField(
                  key: const Key('password_input'),
                  controller: _passwordController,
                  label: "Password",
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  isDark: isDark,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textSecondary(context), size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  _buildTextField(
                    key: const Key('mobile_input'),
                    controller: _mobileController,
                    label: "Mobile Number",
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    isDark: isDark,
                    prefix: "+91 ",
                    validator: (value) {
                      if (value == null || value.length < 10) {
                        return 'Please enter a valid mobile number';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    key: const Key('login_button'),
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: const Color(0xFF667eea).withValues(alpha: 0.5),
                    ),
                    child: isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(_isLogin ? "SIGN IN" : "CREATE ACCOUNT", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 20),

                // Toggle & Manual Activation
                Center(
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Sign In",
                          style: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_isLogin) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            final email = _emailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter your email address first')),
                              );
                              return;
                            }
                            context.push('/set-password?email=$email');
                          },
                          child: Text(
                            "Converted from Sales App? Activate Account",
                            style: TextStyle(
                              color: isDark ? AppColors.primaryLight : const Color(0xFF667eea),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Employee Login Link ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/employee-login'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.badge_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Employee PIN Login", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          SizedBox(height: 2),
                          Text("Quick access for store staff", style: TextStyle(color: Colors.white60, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
        prefixIcon: Icon(icon, color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context), size: 20),
        prefixText: prefix,
        prefixStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.textSecondary(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? AppColors.textSecondary(context) : AppColors.textSecondary(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}
