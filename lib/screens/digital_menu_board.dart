import '../core/design/tokens/app_colors.dart';
// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/inventory_image_widget.dart';

class DigitalMenuBoard extends StatelessWidget {
  const DigitalMenuBoard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final inventory = provider.storeInventory.where((i) => i.status == 'In Stock' && (!i.trackStock || provider.getItemStock(i.id) > 0)).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Digital Menu"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          // Sidebar / Categories (Optional)
          Expanded(
            flex: 2,
            child: Container(
              color: AppColors.textSecondary(context),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const CircleAvatar(radius: 40, backgroundColor: AppColors.warning, child: Icon(Icons.restaurant, size: 40, color: Colors.black)),
                  const SizedBox(height: 20),
                  Text(provider.activeStore?.name ?? "Menu", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  // Categories can go here
                  _buildCategoryItem("All Items", true),
                  _buildCategoryItem("Burgers", false),
                  _buildCategoryItem("Drinks", false),
                ],
              ),
            ),
          ),
          // Menu Grid
          Expanded(
            flex: 8,
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                childAspectRatio: 0.8,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                final item = inventory[index];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary(context),
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: InventoryImageWidget.getImageProvider(item),
                      fit: BoxFit.cover,
                      opacity: 0.4
                    )
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.black, Colors.black.withValues(alpha: 0.0)], begin: Alignment.bottomCenter, end: Alignment.topCenter)
                        ),
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name, 
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.category, 
                                    style: TextStyle(color: AppColors.textSecondary(context)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "₹${item.price}", 
                                  style: const TextStyle(color: AppColors.warning, fontSize: 24, fontWeight: FontWeight.bold)
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String title, bool isSelected) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: isSelected ? AppColors.warning : Colors.transparent,
      child: Text(
        title, 
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white, 
          fontWeight: FontWeight.bold, 
          fontSize: 18
        )
      ),
    );
  }
}
