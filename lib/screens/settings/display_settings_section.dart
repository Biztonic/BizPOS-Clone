import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../utils/theme.dart';
import '../../features/receipt_printing/screens/receipt_settings_screen.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/tokens/app_colors.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/components/atoms/app_card.dart';

class DisplaySettingsSection extends StatelessWidget {
  const DisplaySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final density = AppDensityProvider.configOf(context);

    return PosScaffold(
      title: "Appearance Settings",
      mainContent: ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
        children: [
          // Theme Color
          Text('Theme Color', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppColorTheme.values.map((theme) {
                final color = themeColors[theme]!;
                final isSelected = provider.currentTheme == theme;
                return GestureDetector(
                  onTap: () => provider.setAppTheme(theme),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: provider.isDarkMode ? Colors.white : Colors.black, width: 3)
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
                    child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: AppSpacing.xl),
          
          // Interface Style
          Text('Interface Style', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Interface Layout', style: AppTypography.bodyLarge),
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.view_quilt, color: AppColors.primaryLight, size: 20),
                  ),
                  subtitle: Text(
                    provider.uiStyle == UIStyle.car_dashboard ? 'Automotive HUD' : 'Standard POS',
                    style: AppTypography.bodySmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border(context)),
                    borderRadius: BorderRadius.circular(density.buttonRadius),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UIStyle>(
                      isExpanded: true,
                      value: provider.uiStyle,
                      style: AppTypography.bodyMedium,
                      items: const [
                        DropdownMenuItem(
                          value: UIStyle.standard, 
                          child: Text("Standard")
                        ),
                        DropdownMenuItem(value: UIStyle.car_dashboard, child: Text("Automotive (Landscape)")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                           provider.setUIStyle(val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          
          // Receipt Configuration
          Text('Receipt Configuration', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.md),
          
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
              ),
              title: const Text('Configure Receipt Layout', style: AppTypography.bodyLarge),
              subtitle: const Text('Customize header, footer, visibility & live preview', style: AppTypography.bodySmall),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const ReceiptSettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
