// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../services/device_manager_service.dart';
import '../customer_display_screen.dart';
import '../cfd_screen.dart';
import '../../core/design/tokens/app_typography.dart';
import '../../core/design/tokens/app_spacing.dart';
import '../../core/design/density/app_density.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import '../../core/design/components/atoms/app_button.dart';
import '../../core/design/components/atoms/app_card.dart';
import '../../core/design/components/atoms/app_text_field.dart';

class DisplayHardwareSettingsScreen extends StatefulWidget {
  const DisplayHardwareSettingsScreen({super.key});

  @override
  State<DisplayHardwareSettingsScreen> createState() => _DisplayHardwareSettingsScreenState();
}

class _DisplayHardwareSettingsScreenState extends State<DisplayHardwareSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ipController = TextEditingController(text: "192.168.1.50");
  
  // Mock State
  bool _isScanning = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Refresh UI after data might have loaded (though service init is async, this ensures rebuild if already loaded)
    DeviceManagerService().init().then((_) {
      if(mounted) setState((){});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  void _addDisplay(DisplayDevice device) async {
     await DeviceManagerService().addDisplay(device);
     setState(() {}); // Refresh list
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text("Added ${device.name}"),
         behavior: SnackBarBehavior.floating,
       )
     );
  }

  void _scan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isScanning = false);
    // Mock found device
    if(mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Device Found", style: AppTypography.titleMedium),
          content: const Text("Found 'Samsung TV' at 192.168.1.105", style: AppTypography.bodyMedium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel")
            ),
            AppButton(
              label: "Add",
              onPressed: () {
                Navigator.pop(context);
                _addDisplay(DisplayDevice(
                  name: "Samsung TV (Kitchen)", 
                  address: "192.168.1.105", 
                  type: DisplayType.order_board, 
                  connection: DisplayConnection.network
                ));
              },
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
            )
          ],
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final density = AppDensityProvider.configOf(context);

    return PosScaffold(
      title: "Display Management",
      mainContent: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            labelStyle: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
            unselectedLabelStyle: AppTypography.labelMedium,
            tabs: const [
               Tab(text: "Connected", icon: Icon(Icons.connected_tv_outlined)),
               Tab(text: "Discover", icon: Icon(Icons.search_outlined)),
               Tab(text: "This Device", icon: Icon(Icons.devices_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildConnectedList(density),
                _buildDiscoverTab(density),
                _buildLocalOptions(density),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedList(DensityConfig density) {
    final savedDisplays = DeviceManagerService().savedDisplays;
    if (savedDisplays.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_off_outlined, size: 64, color: Theme.of(context).disabledColor),
            SizedBox(height: AppSpacing.md),
            const Text(
              "No displays configured.\nGo to Discover to add one.", 
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: savedDisplays.length,
      padding: EdgeInsets.all(AppSpacing.lg),
      itemBuilder: (context, index) {
        final device = savedDisplays[index];
        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: AppCard(
             child: ListTile(
               leading: Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Icon(Icons.tv, color: Theme.of(context).colorScheme.primary),
               ),
               title: Text(device.name, style: AppTypography.titleSmall),
               subtitle: Text(
                 "${device.type.name.toUpperCase().replaceAll('_', ' ')} • ${device.connection.name.toUpperCase()}",
                 style: AppTypography.bodySmall,
               ),
               trailing: IconButton(
                 icon: const Icon(Icons.delete_outline),
                 onPressed: () async {
                     await DeviceManagerService().removeDisplay(index);
                     setState(() {}); // refresh
                 },
               ),
               onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Sending test signal..."), behavior: SnackBarBehavior.floating)
                  );
               },
             ),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverTab(DensityConfig density) {
    return ListView(
      padding: EdgeInsets.all(AppSpacing.lg),
      children: [
        SizedBox(
          width: double.infinity,
          child: AppButton(
            onPressed: _isScanning ? null : _scan, 
            label: _isScanning ? "Scanning Network..." : "Scan for Displays",
            icon: _isScanning ? null : Icons.wifi_find,
            isLoading: _isScanning,
            variant: AppButtonVariant.primary,
          ),
        ),
        SizedBox(height: AppSpacing.xl),
        const Text("Manual Connect", style: AppTypography.titleSmall),
        SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppTextField(
                controller: _ipController,
                labelText: "IP Address / URL",
                hintText: "e.g. 192.168.1.100",
              ),
            ),
            SizedBox(width: AppSpacing.md),
            AppButton(
              onPressed: () {
                 _addDisplay(DisplayDevice(
                    name: "Manual Display",
                    address: _ipController.text,
                    type: DisplayType.cfd,
                    connection: DisplayConnection.network
                 ));
              }, 
              label: "Connect",
              icon: Icons.add,
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.medium,
            )
          ],
        ),
      ],
    );
  }

  Widget _buildLocalOptions(DensityConfig density) {
    return ListView(
      padding: EdgeInsets.all(AppSpacing.lg),
      children: [
        AppCard(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
               children: [
                 Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                 SizedBox(width: 16),
                 const Expanded(
                   child: Text(
                     "Use this device as a dedicated display unit if connected via HDMI to a TV.",
                     style: AppTypography.bodySmall,
                   )
                 )
               ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xl),
        _buildLocalActionItem(
          title: "Launch Order Status Board",
          subtitle: "Open the public view for prepared/ready orders",
          icon: Icons.grid_view_outlined,
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerDisplayScreen()));
          },
        ),
        SizedBox(height: AppSpacing.md),
        _buildLocalActionItem(
          title: "Launch Customer Facing Display (CFD)",
          subtitle: "Show cart items and total (Mock)",
          icon: Icons.shopping_cart_checkout_outlined,
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const CFDScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildLocalActionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      child: ListTile(
        title: Text(title, style: AppTypography.titleSmall),
        subtitle: Text(subtitle, style: AppTypography.bodySmall),
        leading: Icon(icon),
        trailing: const Icon(Icons.launch, size: 16),
      ),
    );
  }
}

