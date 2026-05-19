import '../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import '../../utils/responsive.dart';

class IntegrationHubScreen extends StatefulWidget {
  const IntegrationHubScreen({super.key});

  @override
  State<IntegrationHubScreen> createState() => _IntegrationHubScreenState();
}

class _IntegrationHubScreenState extends State<IntegrationHubScreen> {
  // Mock State for now - in production this would persist to backend/hive
  final Map<String, bool> _connections = {
    'swiggy': false,
    'zomato': false,
    'ubereats': false,
    'talabat': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t(context, 'Integration Hub')),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.history), tooltip: "Sync Logs"),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.t(context, 'Manage Third-Party Connections'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(AppLocalizations.t(context, 'Connect your POS to external platforms for seamless order synchronization.'),
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: GridView.count(
                crossAxisCount: Responsive.isMobile(context) ? 1 : 3,
                childAspectRatio: 1.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildIntegrationCard(
                    id: 'swiggy',
                    name: 'Swiggy',
                    icon: Icons.delivery_dining,
                    color: AppColors.warning,
                    description: "Receive orders directly from Swiggy.",
                  ),
                  _buildIntegrationCard(
                    id: 'zomato',
                    name: 'Zomato',
                    icon: Icons.restaurant,
                    color: AppColors.error,
                    description: "Sync menu and orders with Zomato.",
                  ),
                  _buildIntegrationCard(
                    id: 'ubereats',
                    name: 'Uber Eats',
                    icon: Icons.directions_bike,
                    color: AppColors.success,
                    description: "Global delivery platform integration.",
                  ),
                   _buildIntegrationCard(
                    id: 'talabat',
                    name: 'Talabat',
                    icon: Icons.fastfood,
                    color: AppColors.warning,
                    description: "Middle-east delivery aggregator.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrationCard({
    required String id,
    required String name,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    final isConnected = _connections[id] ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: isConnected ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Switch(
                  value: isConnected,
                  activeColor: color,
                  onChanged: (val) {
                    setState(() {
                      _connections[id] = val;
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val ? "Connected to $name" : "Disconnected from $name"),
                        backgroundColor: val ? AppColors.success : AppColors.textSecondary(context),
                        behavior: SnackBarBehavior.floating,
                        width: 400,
                      ),
                    );
                  },
                )
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              description,
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            if (isConnected)
               Row(
                 children: [
                   const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                   const SizedBox(width: AppSpacing.xs),
                   Text(AppLocalizations.t(context, 'Online'), style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                   const Spacer(),
                   TextButton(
                     onPressed: () {}, 
                     style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                     child: Text(AppLocalizations.t(context, 'Settings'))
                   )
                 ],
               )
            else
               Row(
                 children: [
                   Icon(Icons.circle, size: 14, color: AppColors.textSecondary(context)),
                   const SizedBox(width: AppSpacing.xs),
                   Text(AppLocalizations.t(context, 'Offline'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                 ],
               )
          ],
        ),
      ),
    );
  }
}



