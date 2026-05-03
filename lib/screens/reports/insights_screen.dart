import '../../core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/smart_insights_provider.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final insights = Provider.of<SmartInsightsProvider>(context);
    final list = insights.smartInsights;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Insights'),
      ),
      body: list.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.lightbulb_outline, size: 64, color: AppColors.textSecondary(context)),
                   const SizedBox(height: 16),
                   Text("No insights available yet.", style: TextStyle(color: AppColors.textSecondary(context))),
                   Text("Keep selling to generate data!", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final text = list[index];
                // Simple parsing for better UI (optional, but nice)
                // Strings are like "📈 Message"
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
