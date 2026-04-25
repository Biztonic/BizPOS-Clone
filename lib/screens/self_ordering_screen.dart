// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/dashboard_provider.dart';
import '../models/inventory_item.dart';
import '../widgets/inventory_image_widget.dart';

class SelfOrderingScreen extends StatefulWidget {
  const SelfOrderingScreen({super.key});

  @override
  State<SelfOrderingScreen> createState() => _SelfOrderingScreenState();
}

class _SelfOrderingScreenState extends State<SelfOrderingScreen> {
  // Local cart for the kiosk session to avoid conflicting with the main POS user's suspended cart if any
  final Map<String, int> _kioskCart = {}; 

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final inventory = provider.storeInventory.where((i) => i.status == 'In Stock' && (!i.trackStock || provider.getItemStock(i.id) > 0)).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Self-Ordering Kiosk"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
           if (_kioskCart.isNotEmpty)
             Container(
               margin: const EdgeInsets.only(right: 16),
               child: ElevatedButton.icon(
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                 icon: const Icon(Icons.shopping_cart),
                 label: Text("Checkout (${_kioskCart.length})"),
                 onPressed: () => _showCheckoutDialog(context, provider, inventory),
               ),
             )
        ],
      ),
      body: Row(
        children: [
          // Sidebar / Categories
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              child: ListView(
                children: [
                   const SizedBox(height: 20),
                   const Icon(Icons.fastfood, size: 60, color: Colors.orange),
                   const SizedBox(height: 10),
                   const Text("Yummy Burger", textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                   const Divider(),
                   _buildCategoryItem("All Items", true),
                   _buildCategoryItem("Burgers", false),
                   _buildCategoryItem("Beverages", false),
                   _buildCategoryItem("Desserts", false),
                ],
              ),
            ),
          ),
          // Items Grid
          Expanded(
            flex: 8,
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: inventory.length,
              itemBuilder: (context, index) {
                final item = inventory[index];
                final qty = _kioskCart[item.id] ?? 0;
                
                return GestureDetector(
                  onTap: () {
                     setState(() {
                       _kioskCart[item.id] = qty + 1;
                     });
                     ScaffoldMessenger.of(context).hideCurrentSnackBar();
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${item.name} added!"), duration: const Duration(milliseconds: 600)));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5)],
                      border: qty > 0 ? Border.all(color: Colors.green, width: 2) : null
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: item.image != null
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: InventoryImageWidget(
                                      item: item,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  )
                                : const Icon(Icons.image, size: 50, color: Colors.grey),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("₹${item.price}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                                  if (qty > 0)
                                    CircleAvatar(
                                      radius: 12, 
                                      backgroundColor: Colors.green, 
                                      child: Text("$qty", style: const TextStyle(fontSize: 12, color: Colors.white))
                                    )
                                  else 
                                    const Icon(Icons.add_circle_outline, color: Colors.orange)
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
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
    return ListTile(
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.orange : Colors.black)),
      leading: isSelected ? const Icon(Icons.arrow_right, color: Colors.orange) : null,
      onTap: () {},
    );
  }

  void _showCheckoutDialog(BuildContext context, DashboardProvider provider, List<InventoryItem> inventory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Order"),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               ..._kioskCart.entries.map((e) {
                  final item = inventory.firstWhere((i) => i.id == e.key);
                  return ListTile(
                    title: Text(item.name),
                    trailing: Text("${e.value} x ₹${item.price}"),
                  );
               }),
               const Divider(),
               Padding(
                 padding: const EdgeInsets.all(8.0),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                      const Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                      Text("₹${_calculateTotal(inventory).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
                   ],
                 ),
               )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => _placeOrder(context, provider, inventory), 
            child: const Text("Place Order")
          ),
        ],
      ),
    );
  }

  double _calculateTotal(List<InventoryItem> inventory) {
    double total = 0;
    _kioskCart.forEach((id, qty) {
       final item = inventory.firstWhere((i) => i.id == id);
       total += item.price * qty;
    });
    return total;
  }

  Future<void> _placeOrder(BuildContext context, DashboardProvider provider, List<InventoryItem> inventory) async {
     Navigator.pop(context); // Close dialog

     if (provider.activeStoreId == null) return;

     final orderData = {
       'storeId': provider.activeStoreId,
       'date': FieldValue.serverTimestamp(),
       'status': 'New',
       'total': _calculateTotal(inventory),
       'paymentMethod': 'Kiosk/Pay at Counter',
       'items': _kioskCart.entries.map((e) {
          final item = inventory.firstWhere((i) => i.id == e.key);
          return {
            'id': item.id,
            'name': item.name,
            'price': item.price,
            'quantity': e.value,
          };
       }).toList()
     };

     await FirebaseFirestore.instance.collection('orders').add(orderData);

     setState(() {
       _kioskCart.clear();
     });

     if (context.mounted) {
       showDialog(
         context: context, 
         builder: (_) => AlertDialog(
           title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
           content: const Text("Order Placed Successfully!\nPlease pay at the counter.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
           actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
         )
       );
     }
  }
}
