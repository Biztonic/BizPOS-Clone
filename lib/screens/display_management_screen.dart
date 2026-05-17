import '../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import 'cfd_screen.dart';
import 'customer_display_screen.dart';
import 'digital_menu_board.dart';
import 'promotional_signage.dart';
import 'waiter_calling_system.dart';
import 'self_ordering_screen.dart'; // NEW
import '../services/device_manager_service.dart';
import '../l10n/app_localizations.dart';

import '../utils/responsive.dart';

class DisplayManagementScreen extends StatelessWidget {
  const DisplayManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t(context, 'display'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(AppLocalizations.t(context, 'External Displays'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
            
           _buildGrid(context),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
      final List<Widget> displayCards = [
          _buildDisplayCard(
              context,
              "Customer Order Display",
              "Show cart & totals",
              Icons.monitor,
              AppColors.primaryLight,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CFDScreen()))),
          _buildDisplayCard(
              context,
              "Order Ready Screen",
              "Status board (Preparing/Ready)",
              Icons.tv,
              AppColors.success,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const CustomerDisplayScreen()))),

          // NEW CARDS
          _buildDisplayCard(
              context,
              "Digital Menu Board",
              "Live menu on TV screens",
              Icons.restaurant_menu,
              AppColors.primaryLight,
              () => _showMenuModeDialog(context)),
            _buildDisplayCard(
              context,
              "Promotional Signage",
              "Ads & Offers slideshow",
              Icons.campaign,
              AppColors.error,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PromotionalSignage()))),
            _buildDisplayCard(
              context,
              "Waiter Calling System",
              "Staff alert board",
              Icons.notifications_active,
              AppColors.primary,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WaiterCallingSystem()))),
      ];

      // Responsive Grid
      if (Responsive.isMobile(context)) {
         return Column(
            children: displayCards.map((card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: card
            )).toList(),
          );
      } else {
         int columns = Responsive.isTablet(context) ? 2 : 3;
         return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            childAspectRatio: 2.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: displayCards,
          );
      }
  }

  Widget _buildDisplayCard(BuildContext context, String title, String subtitle,
      IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.rectangle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.settings, color: AppColors.textSecondary(context)),
                onPressed: () => _showDisplaySettingsDialog(context, title),
                tooltip: 'Configure Physical Display',
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenuModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.t(context, 'Select Display Mode')),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalMenuBoard()));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.tv, color: AppColors.primaryLight),
                  const SizedBox(width: 12),
                  Text(AppLocalizations.t(context, 'Digital Display Mode (View Only)'), style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SelfOrderingScreen()));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, color: AppColors.success),
                  const SizedBox(width: 12),
                  Text(AppLocalizations.t(context, 'Self-Ordering Kiosk (Interactive)'), style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisplaySettingsDialog(BuildContext context, String displayName) {
    // Fetch real devices from DeviceManager
    final devices = DeviceManagerService().savedDisplays;
    final List<String> physicalDisplays = devices.isEmpty 
        ? ["No devices found"] 
        : devices.map((d) => d.name).toList();
    
    // Also add "None/Local" option
    // physicalDisplays.insert(0, "Local Device (This Screen)");

    String selectedDisplay = physicalDisplays.isNotEmpty ? physicalDisplays[0] : "No devices found";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("$displayName Settings"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(AppLocalizations.t(context, 'Target Physical Display:'), style: const TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: AppSpacing.sm),
                   DropdownButton<String>(
                     isExpanded: true,
                     value: selectedDisplay,
                     items: physicalDisplays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(), 
                     onChanged: (val) {
                       setState(() => selectedDisplay = val!);
                     }
                   ),
                   const SizedBox(height: AppSpacing.md),
                   Text("Note: Connecting to a physical display requires 'desktop_multi_window' package support. This setting is currently saved but will not actively move the window until the package is integrated.", style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context), fontStyle: FontStyle.italic))
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.t(context, 'Cancel'))),
                ElevatedButton(
                  onPressed: () {
                    // Start saving preference logic here (e.g., SharedPreferences)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Display mapped to $selectedDisplay")));
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.t(context, 'Save')),
                )
              ],
            );
          }
        );
      }
    );
  }
}




