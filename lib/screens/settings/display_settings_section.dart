import 'package:flutter/material.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../utils/theme.dart';
import '../../utils/responsive.dart';
import '../../features/receipt_printing/screens/receipt_settings_screen.dart';
import '../../core/design/layouts/pos_scaffold.dart';

import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_card.dart';

class DisplaySettingsSection extends ConsumerWidget {
  final bool isSubView;
  const DisplaySettingsSection({super.key, this.isSubView = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final isMobile = Responsive.isMobile(context);

    final content = ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Theme Color
          Text(AppLocalizations.t(context, 'Theme Color'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppColorTheme.values.map((theme) {
                final color = themeColors[theme]!;
                final isSelected = themeState.currentTheme == theme;
                return GestureDetector(
                  onTap: () => themeNotifier.setAppTheme(theme),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.rectangle,
                      border: isSelected
                          ? Border.all(color: themeState.isDarkMode ? AppColors.surfaceLight : AppColors.textPrimaryLight, width: 3)
                          : null,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                      ],
                    ),
                    child: isSelected ? const Icon(Icons.check, color: AppColors.surfaceLight) : null,
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Interface Style
          Text(AppLocalizations.t(context, 'Interface Style'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppLocalizations.t(context, 'Interface Layout'), style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary(context))),
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      shape: BoxShape.rectangle,
                    ),
                    child: const Icon(Icons.view_quilt, color: AppColors.primaryLight, size: 20),
                  ),
                  subtitle: Text(
                    (isMobile ? UIStyle.standard : themeState.uiStyle) == UIStyle.car_dashboard ? 'Automotive HUD' : 'Standard POS',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border(context)),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UIStyle>(
                      isExpanded: true,
                      value: isMobile ? UIStyle.standard : themeState.uiStyle,
                      dropdownColor: AppColors.surface(context),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary(context)),
                      items: [
                        DropdownMenuItem(
                          value: UIStyle.standard, 
                          child: Text(AppLocalizations.t(context, 'Standard'), style: TextStyle(color: AppColors.textPrimary(context)))
                        ),
                        if (!isMobile)
                          DropdownMenuItem(
                            value: UIStyle.car_dashboard, 
                            child: Text(AppLocalizations.t(context, 'Automotive (Landscape)'), style: TextStyle(color: AppColors.textPrimary(context)))
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                           themeNotifier.setUIStyle(val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          
          // Theme Mode Toggle (Added this as it was in DashboardProvider but missing in UI?)
          Text(AppLocalizations.t(context, 'Theme Mode'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: SwitchListTile(
              title: Text(AppLocalizations.t(context, 'Dark Mode'), style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary(context))),
              subtitle: Text(AppLocalizations.t(context, 'Use a dark color scheme'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
              value: themeState.isDarkMode,
              onChanged: (val) => themeNotifier.toggleTheme(),
              secondary: Icon(themeState.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary),
              contentPadding: EdgeInsets.zero,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          
          // Receipt Configuration
          Text(AppLocalizations.t(context, 'Receipt Configuration'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
          const SizedBox(height: AppSpacing.md),
          
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.rectangle,
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
              ),
              title: Text(AppLocalizations.t(context, 'Configure Receipt Layout'), style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary(context))),
              subtitle: Text(AppLocalizations.t(context, 'Customize header, footer, visibility & live preview'), style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary(context))),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary(context)),
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const ReceiptSettingsScreen()),
                );
              },
            ),
          ),
        ],
      );

    if (isSubView) return content;

    return PosScaffold(
      title: "Appearance Settings",
      showSidebar: false,
      mainContent: content,
    );
  }
}



