import 'dart:math' as math;
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
import '../widgets/employee_pin_dialog.dart';

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
  bool _magicLinkChecked = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_magicLinkChecked) {
      _magicLinkChecked = true;
      _checkMagicLink();
    }
  }

  void _checkMagicLink() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final state = GoRouterState.of(context);
        final params = state.uri.queryParameters;
        if (params.containsKey('store') && params.containsKey('emp')) {
          final storeCode = params['store']!;
          final empId = params['emp']!;
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => EmployeePinDialog(
              storeCode: storeCode,
              empId: empId,
            ),
          );
        }
      } catch (e) {
        // Router state may not be ready or active
      }
    });
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
                              child: _buildAuthForm(context, isLoading, isDark, size, onGradient: false),
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
                    child: _buildAuthForm(context, isLoading, isDark, size, onGradient: true),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo with modern rounded square style
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/logo.jpg',
                fit: BoxFit.cover,
                cacheWidth: 400,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 36, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Main Headline
          Text(
            AppLocalizations.t(context, 'BizTonic POS'),
            style: AppTypography.displayMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Subtitle
          Text(
            AppLocalizations.t(context, 'The all-in-one platform for modern commerce. Manage sales, inventory, and staff with surgical precision.'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.85),
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          
          // Custom Lottie-type Vector Animation Graphic
          const LottieTypeGraphic(),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Features Section Header
          Text(
            AppLocalizations.t(context, 'TRUSTED BY ENTERPRISES WORLDWIDE'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Modern feature cards in a 2x2 grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildFeatureItem(Icons.bolt, "Lightning Fast Billing", "Process transactions in seconds, even offline."),
                    _buildFeatureItem(Icons.cloud_sync, "Real-time Cloud Sync", "Your data is always backed up and accessible."),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  children: [
                    _buildFeatureItem(Icons.analytics_outlined, "Advanced Analytics", "Gain deep insights into your business performance."),
                    _buildFeatureItem(Icons.security, "Bank-grade Security", "Securing your business data with enterprise standards."),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  desc, 
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.65),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthForm(BuildContext context, bool isLoading, bool isDark, Size size, {required bool onGradient}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Mobile Header (Hidden on Wide) ──
        if (MediaQuery.of(context).size.width < 900) ...[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/logo.jpg', 
                fit: BoxFit.cover, 
                cacheWidth: 400, 
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 36, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppLocalizations.t(context, 'BizTonic POS'), 
            style: AppTypography.headlineMedium.copyWith(
              color: Colors.white, 
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // ── Auth Card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.04),
                blurRadius: 36,
                offset: const Offset(0, 16),
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
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
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
                const SizedBox(height: AppSpacing.md),

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
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility, 
                      color: isDark ? Colors.white.withOpacity(0.38) : AppColors.primary.withOpacity(0.5), 
                      size: 20,
                    ),
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
                  height: 54,
                  child: ElevatedButton(
                    key: const Key('login_button'),
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: AppColors.primary.withOpacity(0.25),
                    ),
                    child: isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(_isLogin ? "SIGN IN" : "CREATE ACCOUNT", style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Toggle & Manual Activation
                Center(
                  child: Column(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Sign In",
                          style: TextStyle(
                            color: onGradient ? Colors.white.withOpacity(0.9) : AppColors.adaptivePrimary(context), 
                            fontSize: 13, 
                            fontWeight: FontWeight.w600,
                          ),
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
                              color: onGradient ? Colors.white : AppColors.adaptivePrimary(context),
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
    final Color fillColor = isDark 
        ? const Color(0xFF1E293B) // slate 800
        : const Color(0xFFF8FAFC); // slate 50
    final Color borderColor = isDark 
        ? Colors.white.withOpacity(0.08) 
        : const Color(0xFFE2E8F0); // slate 200
    final Color activeColor = AppColors.primary;

    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      autofillHints: autofillHints,
      style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.2),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(
          color: activeColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        prefixIcon: Icon(
          icon, 
          color: isDark 
              ? Colors.white.withOpacity(0.4) 
              : activeColor.withOpacity(0.7), 
          size: 20,
        ),
        prefixText: prefix,
        prefixStyle: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: activeColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}

class LottieTypeGraphic extends StatefulWidget {
  const LottieTypeGraphic({super.key});

  @override
  State<LottieTypeGraphic> createState() => _LottieTypeGraphicState();
}

class _LottieTypeGraphicState extends State<LottieTypeGraphic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _LottiePainter(_controller.value),
            );
          },
        ),
      ),
    );
  }
}

class _LottiePainter extends CustomPainter {
  final double progress;
  _LottiePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 15);

    // 1. Draw glowing radial background
    final double pulse = 1.0 + 0.1 * math.sin(progress * 2 * math.pi);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.cyanAccent.withOpacity(0.18 * (2.0 - pulse)),
          Colors.blueAccent.withOpacity(0.08 * (2.0 - pulse)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 120 * pulse));
    canvas.drawCircle(center, 130 * pulse, glowPaint);

    // 2. Draw Business grid lines (Dashboard background vibe)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;
    
    // Draw 5 horizontal lines
    for (int i = 0; i < 5; i++) {
      final double y = 30.0 + i * (size.height - 80) / 4;
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), gridPaint);
    }
    // Draw 6 vertical lines
    for (int i = 0; i < 6; i++) {
      final double x = 20.0 + i * (size.width - 40) / 5;
      canvas.drawLine(Offset(x, 20), Offset(x, size.height - 40), gridPaint);
    }

    // 3. Draw a glowing Rising Trend Line (Business Growth)
    final trendPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = const LinearGradient(
        colors: [Colors.blueAccent, Colors.cyanAccent, Colors.greenAccent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeCap = StrokeCap.round;

    final trendPath = Path();
    final List<Offset> trendPoints = [];
    
    // Generate trend points with sine wave oscillation
    for (double x = 30; x < size.width - 30; x += 5) {
      final double normX = (x - 30) / (size.width - 60);
      final double wave1 = 15 * math.sin(normX * 3 * math.pi - progress * 2 * math.pi);
      final double wave2 = 8 * math.sin(normX * 8 * math.pi + progress * 4 * math.pi);
      final double y = (size.height - 70) - normX * 100 + wave1 + wave2;
      trendPoints.add(Offset(x, y));
    }

    if (trendPoints.isNotEmpty) {
      trendPath.moveTo(trendPoints.first.dx, trendPoints.first.dy);
      for (int i = 1; i < trendPoints.length; i++) {
        trendPath.lineTo(trendPoints[i].dx, trendPoints[i].dy);
      }
      canvas.drawPath(trendPath, trendPaint);

      // Draw glowing end dot on the trend line
      final endPoint = trendPoints.last;
      final endGlowPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, 10.0 + 3.0 * math.sin(progress * 2 * math.pi * 2), endGlowPaint);
      
      final endDotPaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(endPoint, 5.0, endDotPaint);
    }

    // 4. Draw POS Terminal (Tablet Screen & Stand) in the Center
    // Stand
    final standPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.grey[700]!, Colors.grey[800]!, Colors.grey[900]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(center.dx - 20, center.dy + 15, 40, 50));
    
    final standPath = Path()
      ..moveTo(center.dx - 8, center.dy + 15)
      ..lineTo(center.dx + 8, center.dy + 15)
      ..lineTo(center.dx + 16, center.dy + 55)
      ..lineTo(center.dx - 16, center.dy + 55)
      ..close();
    canvas.drawPath(standPath, standPaint);

    // Screen Bezel
    final bezelPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    
    final screenRect = Rect.fromCenter(center: center, width: 106, height: 74);
    final rscreenRect = RRect.fromRectAndRadius(screenRect, const Radius.circular(10));
    canvas.drawRRect(rscreenRect, bezelPaint);

    // Inner Screen
    final screenInnerPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF1E293B), const Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: center, width: 98, height: 66));
    
    final innerScreenRect = Rect.fromCenter(center: center, width: 98, height: 66);
    final rinnerScreenRect = RRect.fromRectAndRadius(innerScreenRect, const Radius.circular(8));
    canvas.drawRRect(rinnerScreenRect, screenInnerPaint);

    // Screen Glare
    final glarePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    final glarePath = Path()
      ..moveTo(center.dx - 49, center.dy - 33)
      ..lineTo(center.dx + 20, center.dy - 33)
      ..lineTo(center.dx - 20, center.dy + 33)
      ..lineTo(center.dx - 49, center.dy + 33)
      ..close();
    canvas.drawPath(glarePath, glarePaint);

    // Screen Content
    final checkPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final checkPath = Path()
      ..moveTo(center.dx - 28, center.dy - 12)
      ..lineTo(center.dx - 22, center.dy - 6)
      ..lineTo(center.dx - 12, center.dy - 16);
    canvas.drawPath(checkPath, checkPaint);

    final barPaint = Paint()..style = PaintingStyle.fill;
    final double barY = center.dy + 15;
    for (int i = 0; i < 4; i++) {
      final double barHeight = 12.0 + (i * 6.0) + 4.0 * math.sin(progress * 2 * math.pi + i);
      final double barX = center.dx + 4 + (i * 9.0);
      barPaint.shader = LinearGradient(
        colors: [Colors.cyanAccent, Colors.blueAccent],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(barX, barY - barHeight, 6, barHeight));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY - barHeight, 6, barHeight), const Radius.circular(2)),
        barPaint,
      );
    }

    final textBackgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 32, center.dy + 3, 25, 10), const Radius.circular(2)),
      textBackgroundPaint,
    );

    // 5. Draw 3D Spinning Gold Coins
    final double coinCycle = progress * 2 * math.pi;
    final List<Offset> coinOffsets = [
      Offset(center.dx - 80, center.dy + 40 - (progress * 130) % 160),
      Offset(center.dx - 45, center.dy + 70 - ((progress + 0.3) * 130) % 160),
      Offset(center.dx + 65, center.dy + 80 - ((progress + 0.6) * 130) % 160),
    ];

    for (int i = 0; i < coinOffsets.length; i++) {
      final offset = coinOffsets[i];
      if (offset.dy < center.dy - 85 || offset.dy > center.dy + 85) continue;

      final double age = (offset.dy - (center.dy - 85)) / 170.0;
      final double opacity = math.sin(age * math.pi).clamp(0.0, 1.0);

      final double spinAngle = coinCycle * 2.5 + i * 2.0;
      final double widthRatio = math.cos(spinAngle).abs();

      final coinPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.amberAccent.withOpacity(opacity), Colors.orange.withOpacity(opacity * 0.9)],
        ).createShader(Rect.fromCircle(center: offset, radius: 9));
      
      canvas.drawOval(
        Rect.fromCenter(center: offset, width: 18 * widthRatio, height: 18),
        coinPaint,
      );

      final coinInnerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(opacity * 0.5);
      canvas.drawOval(
        Rect.fromCenter(center: offset, width: 12 * widthRatio, height: 12),
        coinInnerPaint,
      );
    }

    // 6. Draw floating Credit Card (Tapping Vibe)
    final double cardOsc = math.sin(progress * 2 * math.pi) * 8;
    final double cardRotation = 0.15 + math.sin(progress * 2 * math.pi + 1) * 0.05;
    final cardCenter = center + Offset(72, -15 + cardOsc);

    canvas.save();
    canvas.translate(cardCenter.dx, cardCenter.dy);
    canvas.rotate(cardRotation);

    final cardPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.indigoAccent.withOpacity(0.95), Colors.blueAccent.withOpacity(0.9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: Offset.zero, width: 48, height: 32));
    
    final cardBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withOpacity(0.35);

    final cardRRect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 48, height: 32), const Radius.circular(4));
    canvas.drawRRect(cardRRect, cardPaint);
    canvas.drawRRect(cardRRect, cardBorderPaint);

    final chipPaint = Paint()
      ..color = Colors.amberAccent.withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-18, -6, 10, 8), const Radius.circular(1.5)),
      chipPaint,
    );

    final whiteLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(10, 6), Offset(18, 6), whiteLinePaint);
    canvas.drawLine(Offset(6, 10), Offset(18, 10), whiteLinePaint);

    final double signalPulse = (progress * 3) % 1.0;
    final signalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.cyanAccent.withOpacity(1.0 - signalPulse)
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(-28, 0), radius: 10 + signalPulse * 10),
      -math.pi / 4,
      math.pi / 2,
      false,
      signalPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(-28, 0), radius: 15 + signalPulse * 10),
      -math.pi / 4,
      math.pi / 2,
      false,
      signalPaint,
    );

    canvas.restore();

    // 7. Draw floating Shopping Bag (Retail vibe)
    final double bagOsc = math.cos(progress * 2 * math.pi) * 6;
    final bagCenter = center + Offset(-65, -30 + bagOsc);

    final bagPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.cyanAccent.withOpacity(0.85), Colors.tealAccent.withOpacity(0.75)],
      ).createShader(Rect.fromCircle(center: bagCenter, radius: 15));

    final bagPath = Path()
      ..moveTo(bagCenter.dx - 12, bagCenter.dy - 6)
      ..lineTo(bagCenter.dx + 12, bagCenter.dy - 6)
      ..lineTo(bagCenter.dx + 15, bagCenter.dy + 16)
      ..lineTo(bagCenter.dx - 15, bagCenter.dy + 16)
      ..close();
    canvas.drawPath(bagPath, bagPaint);

    final handlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.white.withOpacity(0.7)
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromLTWH(bagCenter.dx - 6, bagCenter.dy - 12, 12, 12),
      math.pi,
      math.pi,
      false,
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LottiePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
