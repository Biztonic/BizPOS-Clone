import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import '../core/design/layouts/pos_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart';
import '../core/design/tokens/app_typography.dart';

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

    return PosScaffold(
      showSidebar: false,
      showGlobalActions: false,
      mainContent: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.authGradient(context),
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
                      decoration: BoxDecoration(
                         color: AppColors.surface(context),
                        boxShadow: [
                          if (!isDark) BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(-20, 0))
                        ],
                      ),
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
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
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.onPrimary,
                boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
              ),
            child: ClipOval(
              child: Image.asset('assets/logo.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 40, color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(AppLocalizations.t(context, 'BizTonic POS'),
            style: AppTypography.displayLarge,
          ),
          const SizedBox(height: AppSpacing.md),
            Text(AppLocalizations.t(context, 'The all-in-one platform for modern commerce. Manage sales, inventory, and staff with surgical precision.'),
              style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8), height: 1.5),
            ),
          const SizedBox(height: AppSpacing.xxl),
          
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
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), borderRadius: BorderRadius.zero),
              child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
                const SizedBox(height: AppSpacing.xxs),
                Text(desc, style: AppTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6))),
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
        // â”€â”€ Mobile Header (Hidden on Wide) â”€â”€
        if (MediaQuery.of(context).size.width < 900) ...[
          Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.onPrimary,
                boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
              ),
            child: ClipOval(
              child: Image.asset('assets/logo.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 40, color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(AppLocalizations.t(context, 'BizTonic POS'), style: AppTypography.headlineMedium.copyWith(color: Theme.of(context).colorScheme.onPrimary, letterSpacing: 1)),
          const SizedBox(height: AppSpacing.xl),
        ],

        // â”€â”€ Auth Card â”€â”€
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.outline(context)),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: isDark ? 0.4 : 0.08),
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
                  style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary(context)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _isLogin ? "Sign in to manage your store" : "Get started with BizTonic",
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Email
                _buildTextField(
                  key: const Key('email_input'),
                  controller: _emailController,
                  label: "Email Address",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: [AutofillHints.email],
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xxs),

                // Password
                _buildTextField(
                  key: const Key('password_input'),
                  controller: _passwordController,
                  label: "Password",
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  autofillHints: [AutofillHints.password],
                  isDark: isDark,
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: isDark ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.38) : Theme.of(context).shadowColor.withValues(alpha: 0.1), size: 20),
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
                  const SizedBox(height: AppSpacing.md),
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
                const SizedBox(height: AppSpacing.xl),

                // Submit Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    key: const Key('login_button'),
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      elevation: 8,
                      shadowColor: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    child: isLoading
                        ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2.5))
                        : Text(_isLogin ? "SIGN IN" : "CREATE ACCOUNT", style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),

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
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () {
                            final email = _emailController.text.trim();
                            if (email.isEmpty || !email.contains('@')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(AppLocalizations.t(context, 'Please enter your email address first'))),
                              );
                              return;
                            }
                            context.push('/set-password?email=$email');
                          },
                          child: Text(AppLocalizations.t(context, 'Converted from Sales App? Activate Account'),
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.adaptivePrimary(context),
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

        const SizedBox(height: AppSpacing.lg),

        // â”€â”€ Employee Login Link â”€â”€
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: isDark ? 0.08 : 0.15),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.zero,
              onTap: () => context.push('/employee-login'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.15), borderRadius: BorderRadius.zero),
                      child: Icon(Icons.badge_outlined, color: Theme.of(context).colorScheme.onPrimary, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.t(context, 'Employee PIN Login'), style: AppTypography.titleMedium.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(AppLocalizations.t(context, 'Quick access for store staff'), style: AppTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Color(0x8CFFFFFF), size: 16),
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
    Iterable<String>? autofillHints,
    Widget? suffixIcon,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    final Color textColor = AppColors.textPrimary(context);
    final Color labelColor = AppColors.textSecondary(context);
    final Color fillColor = AppColors.surfaceVariant(context);
    final Color borderColor = AppColors.border(context);
    const Color activeColor = AppColors.primary;

    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      autofillHints: autofillHints,
      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.2),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(
          color: activeColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        prefixIcon: Icon(icon, color: isDark ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.38) : activeColor.withValues(alpha: 0.8), size: 22),
        prefixText: prefix,
        prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxs),
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: activeColor, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}


