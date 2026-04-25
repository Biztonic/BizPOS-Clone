import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../utils/theme.dart';
// Ensure ReceiptSettings available

import '../../features/receipt_printing/screens/receipt_settings_screen.dart';

class DisplaySettingsSection extends StatelessWidget {
  const DisplaySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Appearance Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Color
          const Text('Theme Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppColorTheme.values.map((theme) {
              final color = themeColors[theme]!;
              final isSelected = provider.currentTheme == theme;
              return GestureDetector(
                onTap: () => provider.setAppTheme(theme),
                child: Container(
                  width: 45,
                  height: 45,
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
          
          const Divider(height: 30),
          
          // Interface Style
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Interface Style'),
                leading: const Icon(Icons.view_quilt),
                subtitle: Text(provider.uiStyle == UIStyle.car_dashboard ? 'Automotive HUD' : 'Standard POS'),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 56.0), // Align with text
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UIStyle>(
                      isExpanded: true,
                      value: provider.uiStyle,
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
              ),
            ],
          ),

          const Divider(height: 30),
          
          // Receipt Configuration
          const Text('Receipt Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.blue),
              title: const Text('Configure Receipt Layout'),
              subtitle: const Text('Customize header, footer, visibility & live preview'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
