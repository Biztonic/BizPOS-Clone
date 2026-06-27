import '../../core/design/tokens/app_radius.dart';
import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import 'package:provider/provider.dart';
import '../../providers/smart_insights_provider.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final insights = Provider.of<SmartInsightsProvider>(context);
    final list = insights.smartInsights;

    return PosScaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'Smart Insights')),
      ),
      mainContent: list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.lightbulb_outline, size: 64, color: AppColors.textSecondary(context)),
                   const SizedBox(height: AppSpacing.md),
                   Text(AppLocalizations.t(context, 'No insights available yet.'), style: TextStyle(color: AppColors.textSecondary(context))),
                   Text(AppLocalizations.t(context, 'Keep selling to generate data!'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final text = list[index];
                // Simple parsing for better UI (optional, but nice)
                // Strings are like "ðŸ“ˆ Message"
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // If we want to extract the emoji/icon, we can, or just display text
                         Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}




