import '../core/design/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/inventory_item.dart';
// Assuming theme is here, or use standard Colors if not found.
// Actually let's stick to standard high-quality styling to ensure no missing deps, or check path.
// Checking previous file... path was utils/car_dashboard_theme.dart. using that.
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/inventory_image_widget.dart';

class CFDScreen extends StatelessWidget {
  const CFDScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final cart = provider.cart;
    final inventory = provider.storeInventory;
    final activeStore = provider.activeStore;
    
    // 1. Determine State (Idle vs Active)
    final bool isIdle = cart.isEmpty;
    
    // 2. Determine "Hero" Item (Last Added)
    InventoryItem? heroItem;
    if (!isIdle) {
       try {
          // Dart Map preserves insertion order. Last key = Last active.
          final lastKey = cart.keys.last;
          heroItem = inventory.firstWhere((i) => i.id == lastKey);
       } catch (_) { /* Error ignored */ }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Row(
        children: [
          // --- LEFT PANEL: HERO VIEW (60%) ---
          Expanded(
             flex: 6,
             child: AnimatedSwitcher(
               duration: const Duration(milliseconds: 500),
               child: _buildLeftPanel(context, isIdle, heroItem, activeStore?.name, provider),
             ),
          ),

          // --- RIGHT PANEL: RECEIPT (40%) ---
          Expanded(
             flex: 4,
             child: Container(
                decoration: const BoxDecoration(
                   color: Colors.white,
                   boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)]
                ),
                child: Column(
                   children: [
                      // Header
                      Container(
                         padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                         color: AppColors.textSecondary(context),
                         child: const Row(
                            children: [
                               Icon(Icons.shopping_bag_outlined, size: 32, color: Colors.black87),
                               SizedBox(width: 16),
                               Text("Your Order", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                            ],
                         ),
                      ),
                      const Divider(height: 1),
                      
                      // List
                      Expanded(
                         child: ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: cart.length,
                            separatorBuilder: (_,__) => const Divider(height: 32),
                            itemBuilder: (context, index) {
                               // Reverse order to show newest at top? Or standard bill order? 
                               // Standard bill order (FIFO) usually expected regardless of entry.
                               final itemId = cart.keys.elementAt(index);
                               final qty = cart[itemId]!;
                               final item = inventory.firstWhere((i) => i.id == itemId, orElse: () => InventoryItem(id: '', name: 'Unknown Item', quantity: 0, price: 0, category: '', trackStock: false, status: ''));
                               
                               if (item.id.isEmpty) return const SizedBox.shrink();

                               return _buildLineItem(context, item, qty);
                            },
                         ),
                      ),
                      
                      // Footer
                      _buildFooter(context, provider, inventory),
                   ],
                ),
             ),
          ),
        ],
      ),
    );
  }
  
  // --- LEFT PANEL LOGIC ---
  
  Widget _buildLeftPanel(BuildContext context, bool isIdle, InventoryItem? heroItem, String? storeName, DashboardProvider provider) {
     if (isIdle || heroItem == null) {
        // IDLE STATE
        return Container(
           key: const ValueKey('idle'),
           color: Colors.black,
           child: Stack(
              fit: StackFit.expand,
              children: [
                 // Background (Video or Image)
                 Opacity(
                    opacity: 0.5,
                    child: CachedNetworkImage(
                       imageUrl: provider.dashboardBgSource.isNotEmpty && provider.dashboardBgSource.endsWith('.jpg') // Basic check, use fallback if video
                          ? provider.dashboardBgSource 
                          : "https://images.unsplash.com/photo-1554118811-1e0d58224f24?q=80&w=2047&auto=format&fit=crop", // Elegant cafe bg
                       fit: BoxFit.cover,
                       errorWidget: (_,__,___) => Container(color: AppColors.textSecondary(context)),
                    ),
                 ),
                 // Content
                 Center(
                    child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                          Icon(Icons.storefront, size: 100, color: Colors.white.withValues(alpha: 0.9)),
                          const SizedBox(height: 24),
                          Text(
                             storeName ?? "Welcome", 
                             style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                             textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                             "Next Customer Please",
                             style: TextStyle(color: Colors.white70, fontSize: 24, fontStyle: FontStyle.italic),
                          ),
                       ],
                    ),
                 )
              ],
           ),
        );
     } else {
        // ACTIVE HERO STATE
        return Container(
           key: ValueKey('hero_${heroItem.id}'), // Animate when item changes
           color: Colors.white,
           child: Stack(
             children: [
               // Store Name (Top Left)
               Positioned(
                 top: 24,
                 left: 24,
                 child: Row(
                   children: [
                     Icon(Icons.store, color: AppColors.textSecondary(context), size: 28),
                     const SizedBox(width: 8),
                     Text(
                       storeName ?? "Store",
                       style: TextStyle(color: AppColors.textSecondary(context), fontSize: 24, fontWeight: FontWeight.bold),
                     ),
                   ],
                 ),
               ),
               
               // Content
               Padding(
                 padding: const EdgeInsets.fromLTRB(32, 80, 32, 32), // Top padding accounts for Store Name
                 child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       // Hero Image
                       Expanded(
                          flex: 4, // Give image more space
                          child: Container(
                             decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 40, offset: const Offset(0, 10))],
                             ),
                             clipBehavior: Clip.antiAlias,
                              child: InventoryImageWidget(
                                item: heroItem,
                                fit: BoxFit.contain,
                              ),
                          ),
                       ),
                       const SizedBox(height: 32),
                       
                       // Hero Details (Flexible to prevent overflow)
                       Flexible(
                          flex: 2,
                          child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                     heroItem.name, 
                                     style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.black87),
                                     textAlign: TextAlign.center,
                                     maxLines: 2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                     decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(50)
                                     ),
                                     child: Text(
                                        "₹${heroItem.price.toStringAsFixed(2)}",
                                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                                     ),
                                  ),
                                )
                             ],
                          ),
                       )
                    ],
                 ),
               ),
             ],
           ),
        );
     }
  }

  // --- RIGHT PANEL WIDGETS ---

  Widget _buildLineItem(BuildContext context, InventoryItem item, int qty) {
     return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.textSecondary(context), borderRadius: BorderRadius.circular(8)),
              child: Text("${qty}x", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
           ),
           const SizedBox(width: 16),
           Expanded(
              child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(item.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
                    if (item.category.isNotEmpty)
                      Text(item.category, style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context))),
                 ],
              ),
           ),
           Text("₹${(item.price * qty).toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
     );
  }

  Widget _buildFooter(BuildContext context, DashboardProvider provider, List<InventoryItem> inventory) {
     final subtotal = provider.calculateCartTotal(inventory);
     final tax = subtotal * 0.05; // Mock logic, ideally from provider
     final total = subtotal + tax;
     
     return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
           color: AppColors.textSecondary(context),
           border: Border(top: BorderSide(color: AppColors.textSecondary(context)))
        ),
        child: Column(
           children: [
              _row("Subtotal", subtotal),
              const SizedBox(height: 8),
              _row("Tax (5%)", tax),
              const Divider(height: 32),
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    const Text("TOTAL", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black)),
                    Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.success)),
                 ],
              )
           ],
        ),
     );
  }
  
  Widget _row(String label, double val) {
     return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Text(label, style: const TextStyle(fontSize: 18, color: Colors.black54)),
           Text("₹${val.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
     );
  }
}
