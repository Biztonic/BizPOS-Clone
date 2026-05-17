import '../core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../core/design/layouts/pos_scaffold.dart';
import '../core/design/components/atoms/app_button.dart';
import '../core/design/tokens/app_spacing.dart';
import '../core/design/tokens/app_typography.dart';

class SupplierScreen extends StatelessWidget {
  const SupplierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PosScaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'suppliers')),
        actions: [
          AppButton.primary(
            onPressed: () {},
            icon: Icons.add,
            label: AppLocalizations.t(context, 'add'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      mainContent: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined, size: 80, color: AppColors.textHint(context)),
            const SizedBox(height: AppSpacing.lg),
            Text(AppLocalizations.t(context, 'No Suppliers Found'),
              style: AppTypography.titleLarge.copyWith(color: AppColors.textHint(context)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(AppLocalizations.t(context, 'Add your first supplier to start tracking purchases.'),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton.secondary(
              onPressed: () {},
              label: 'Learn More about Suppliers',
            ),
          ],
        ),
      ),
    );
  }
}

