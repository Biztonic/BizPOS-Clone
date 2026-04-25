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
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "External Displays",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              Colors.blue,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CFDScreen()))),
          _buildDisplayCard(
              context,
              "Order Ready Screen",
              "Status board (Preparing/Ready)",
              Icons.tv,
              Colors.green,
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
              Colors.purple,
              () => _showMenuModeDialog(context)),
            _buildDisplayCard(
              context,
              "Promotional Signage",
              "Ads & Offers slideshow",
              Icons.campaign,
              Colors.red,
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PromotionalSignage()))),
            _buildDisplayCard(
              context,
              "Waiter Calling System",
              "Staff alert board",
              Icons.notifications_active,
              Colors.teal,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.grey),
                onPressed: () => _showDisplaySettingsDialog(context, title),
                tooltip: 'Configure Physical Display',
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
        title: const Text("Select Display Mode"),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DigitalMenuBoard()));
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.tv, color: Colors.purple),
                  SizedBox(width: 12),
                  Text("Digital Display Mode (View Only)", style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SelfOrderingScreen()));
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(Icons.touch_app, color: Colors.green),
                  SizedBox(width: 12),
                  Text("Self-Ordering Kiosk (Interactive)", style: TextStyle(fontSize: 16)),
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
                   const Text("Target Physical Display:", style: TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   DropdownButton<String>(
                     isExpanded: true,
                     value: selectedDisplay,
                     items: physicalDisplays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(), 
                     onChanged: (val) {
                       setState(() => selectedDisplay = val!);
                     }
                   ),
                   const SizedBox(height: 16),
                   const Text("Note: Connecting to a physical display requires 'desktop_multi_window' package support. This setting is currently saved but will not actively move the window until the package is integrated.", style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic))
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    // Start saving preference logic here (e.g., SharedPreferences)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Display mapped to $selectedDisplay")));
                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                )
              ],
            );
          }
        );
      }
    );
  }
}
