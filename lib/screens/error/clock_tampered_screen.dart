import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_radius.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_button.dart';

class ClockTamperedScreen extends StatefulWidget {
  const ClockTamperedScreen({super.key});

  @override
  State<ClockTamperedScreen> createState() => _ClockTamperedScreenState();
}

class _ClockTamperedScreenState extends State<ClockTamperedScreen> {
  bool _isChecking = false;

  void _handleRetry(BuildContext context) async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(seconds: 1));
    
    if (context.mounted) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      provider.recheckClockStatus();
      if (context.mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.surfaceLight,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(AppSpacing.xl),
          margin: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: AppRadius.borderLg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.alarm_off_rounded,
                  color: AppColors.error,
                  size: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "Clock Tamper Detected",
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Your device's system time has been rolled back or manipulated. BizPOS requires correct system time to track offline transactions and subscription validity.",
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : AppColors.surfaceLight,
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        "Please correct your device settings to automatic network time and restart the app.",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  label: "Verify Time Settings",
                  isLoading: _isChecking,
                  onPressed: () => _handleRetry(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
