// ignore_for_file: deprecated_member_use_from_same_package, curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/inventory_item.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../utils/car_dashboard_theme.dart';
import '../../../../widgets/inventory_image_widget.dart';


class DashboardProductTile extends StatefulWidget {
  final InventoryItem item;
  final VoidCallback onTap;
  final bool isEditMode;
  final Function(int)? onStockChanged;
  final VoidCallback? onLongPress;


  const DashboardProductTile({
    super.key,
    required this.item,
    required this.onTap,
    this.isEditMode = false,
    this.showImage = true,
    this.cardStyle = 'image',
    this.onStockChanged,
    this.onLongPress,
  });

  final bool showImage;
  final String cardStyle;

  @override
  State<DashboardProductTile> createState() => _DashboardProductTileState();
}

class _DashboardProductTileState extends State<DashboardProductTile> {


  @override
  Widget build(BuildContext context) {
    // Stock Logic
    final bool trackStock = widget.item.trackStock;
    final int qty = Provider.of<DashboardProvider>(context).getItemStock(widget.item.id);
    final bool isOutOfStock = trackStock && qty <= 0;
    final bool isLowStock = trackStock && qty > 0 && qty < 10;
    
    Color stockColor = CarDashboardTheme.electricGreen; 
    if (isOutOfStock) {
      stockColor = CarDashboardTheme.alertRed;
    } else if (isLowStock) stockColor = Colors.orangeAccent;
    if (!trackStock) stockColor = CarDashboardTheme.electricGreen;

    final isDarkMode = Provider.of<DashboardProvider>(context, listen: false).isDarkMode;

    // --- CONTENT BUILDER ---
    Widget tileContent;
    
    final effectiveStyle = widget.cardStyle;

    if (effectiveStyle == 'label') {
      // ---------------- LABEL ONLY STYLE ----------------
      Widget labelContent = Padding(
         padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
         child: Row(
           children: [
             Expanded(
               child: Text(
                 widget.item.name,
                 style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: CarDashboardTheme.textColor(isDarkMode)
                 ),
                 maxLines: 2,
                 overflow: TextOverflow.ellipsis,
               ),
             ),
             const SizedBox(width: 8),
             Text(
                "₹${widget.item.price.toStringAsFixed(0)}",
                style: TextStyle(
                   fontSize: 20,
                   fontWeight: FontWeight.bold,
                   color: CarDashboardTheme.primaryColor(isDarkMode)
                ),
             ),
           ],
         ),
      );

      // Apply Grayscale to content if Out of Stock
      if (isOutOfStock && !widget.isEditMode) {
         labelContent = ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
            child: Opacity(opacity: 0.7, child: labelContent),
         );
      }

      tileContent = AspectRatio(
        aspectRatio: 2.2, // Consistent Wide Ratio
        child: Container(
          decoration: BoxDecoration(
            color: widget.isEditMode ? Colors.white : _getDeterminsticColor(widget.item.name, isDarkMode), // Colored BG
            borderRadius: BorderRadius.zero, // Sharp Corners
            border: Border(
                bottom: BorderSide(color: stockColor, width: 4), // Status Stripe
                left: const BorderSide(color: Colors.white10, width: 1),
                top: const BorderSide(color: Colors.white10, width: 1),
                right: const BorderSide(color: Colors.white10, width: 1),
            ),
            boxShadow: [
               if (!widget.isEditMode)
                 const BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
            ]
          ),
          child: Column(
             children: [
               Expanded(child: Center(child: labelContent)),
               // Stock Indicator Line (Always Colored)
               if (trackStock)
               Container(
                 height: 4,
                 width: double.infinity,
                 decoration: BoxDecoration(
                   color: stockColor, // Remains Red/Green/Orange
                   borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))
                 ),
               )
             ],
          ),
        ),
      );
    } else if (effectiveStyle == 'minimal_rect') {
       // ---------------- MINIMAL RECT STYLE ----------------
       Widget rectContent = Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 12.0),
                 child: Row(
                   children: [
                     // Left: Stock
                     if (trackStock)
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         margin: const EdgeInsets.only(right: 8),
                         decoration: BoxDecoration(
                           color: stockColor.withValues(alpha: 0.1),
                           borderRadius: BorderRadius.circular(4),
                           border: Border.all(color: stockColor.withValues(alpha: 0.5))
                         ),
                         child: Text("x$qty", style: TextStyle(color: stockColor, fontSize: 12, fontWeight: FontWeight.bold)),
                       ),
                     
                     // Center: Name
                     Expanded(
                        child: Text(
                          widget.item.name, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: CarDashboardTheme.textColor(isDarkMode), fontWeight: FontWeight.w600, fontSize: 16) // Increased from 14
                        ),
                     ),
                     
                     // Right: Price
                     Text("₹${widget.item.price.toStringAsFixed(0)}", style: TextStyle(color: CarDashboardTheme.primaryColor(isDarkMode), fontWeight: FontWeight.bold, fontSize: 16)), // Increased from 14
                   ],
                 ),
               );

       if (isOutOfStock && !widget.isEditMode) {
          rectContent = ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
            child: Opacity(opacity: 0.7, child: rectContent),
          );
       }

       tileContent = SizedBox(
        height: 56, // Fixed Height for consistency
        child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: CarDashboardTheme.panelColor(isDarkMode),
          border: Border.all(
            color: widget.isEditMode ? CarDashboardTheme.primaryColor(isDarkMode) : CarDashboardTheme.borderColor(isDarkMode).withValues(alpha: 0.5),
            width: 1.0,
          ),
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Column(
           children: [
             Expanded(child: rectContent),
             // Bottom Line
             if (trackStock)
             Container(
               height: 3,
               width: double.infinity,
               decoration: BoxDecoration(
                 color: stockColor,
                 borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))
               ),
             )
           ],
        ),
       ),
       );
    } else {
      // ---------------- IMAGE STYLE (Premium Flat) ----------------
      // Generate consistent color index
      final colorIndex = widget.item.id.hashCode.abs();
      final cardBgColor = CarDashboardTheme.getCardColor(colorIndex, isDarkMode);
      
      // Wrap in AspectRatio to prevent infinite height in Grid
      tileContent = AspectRatio(
        aspectRatio: 0.85, 
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8), 
            color: cardBgColor, 
            border: Border.all(
              color: widget.isEditMode 
                  ? CarDashboardTheme.primaryColor(isDarkMode)
                  : CarDashboardTheme.borderColor(isDarkMode),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
              // 1. Full Bleed Image
              if (widget.showImage && widget.item.image != null && widget.item.image!.isNotEmpty)
              Positioned.fill(
                child: InventoryImageWidget(
                  item: widget.item,
                  fit: BoxFit.cover,
                ),
              ),

              // 2. Placeholder if no image (Solid Color)
              if (widget.item.image == null || widget.item.image!.isEmpty)
              Positioned.fill(
                child: _buildPlaceholder(cardBgColor, isDarkMode),
              ),

              // 3. Name/Price Tag 
              if (widget.item.image != null && widget.item.image!.isNotEmpty && !widget.isEditMode)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    color: isDarkMode ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.9),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool hidePrice = constraints.maxWidth < 150; 
                        return Row( 
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                 widget.item.name, 
                                 style: CarDashboardTheme.productTitle.copyWith(color: CarDashboardTheme.textColor(isDarkMode), fontSize: 22),
                                 maxLines: 2, 
                                 overflow: TextOverflow.ellipsis
                              ),
                            ),
                            if (!hidePrice) ...[
                              const SizedBox(width: 4),
                              Text(
                                 "₹${widget.item.price.toStringAsFixed(0)}", 
                                 style: CarDashboardTheme.priceStyle.copyWith(color: CarDashboardTheme.primaryColor(isDarkMode), fontSize: 24)
                              ), 
                            ]
                          ],
                        );
                      }
                    ),
                  )
                ),

              // 4. Normal Overlay (If No Image)
              if ((widget.item.image == null || widget.item.image!.isEmpty) && !widget.isEditMode)
                 _buildNormalOverlay(isDarkMode),

              // 5. EDIT MODE OVERLAY
              if (widget.isEditMode)
                 Container(color: CarDashboardTheme.primaryColor(isDarkMode).withValues(alpha: 0.9), child: _buildEditOverlay(qty)),

              // 6. Stock Badge
              if (!widget.isEditMode && trackStock) 
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildStockBadge(qty, stockColor, trackStock, isDarkMode)
                ),
            ],
          ),
        ),
      ),
      );

       // Image style uses Global Filter behavior because it doesn't have a separate stock line at bottom
       if (isOutOfStock && !widget.isEditMode) {
          tileContent = ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
            child: Opacity(opacity: 0.5, child: tileContent),
          );
       }
    }

    return GestureDetector(
        onTap: widget.isEditMode ? null : widget.onTap, 
        onLongPress: widget.onLongPress,
        child: tileContent,
    );
  }

  Widget _buildEditOverlay(num qty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                widget.item.name,
                textAlign: TextAlign.center,
                style: CarDashboardTheme.productTitle.copyWith(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                  _buildStockBtn(Icons.remove, () {
                    if (widget.onStockChanged != null) widget.onStockChanged!(-1);
                  }),
                  Text(
                    qty.toString(),
                    style: CarDashboardTheme.priceStyle.copyWith(color: Colors.white),
                  ),
                  _buildStockBtn(Icons.add, () {
                    if (widget.onStockChanged != null) widget.onStockChanged!(1);
                  }),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildNormalOverlay(bool isDarkMode) {
     return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            // Name 
            Text(
              widget.item.name,
              textAlign: TextAlign.left,
              style: CarDashboardTheme.productTitle.copyWith(
                color: CarDashboardTheme.textColor(isDarkMode),
              ),
              maxLines: 3, 
              overflow: TextOverflow.ellipsis,
            ),
            // Price 
            Text(
              "₹${widget.item.price.toStringAsFixed(0)}",
              style: CarDashboardTheme.priceStyle.copyWith(
                color: CarDashboardTheme.primaryColor(isDarkMode),
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildStockBadge(num qty, Color color, bool trackStock, bool isDarkMode) {
       return Container(
          width: 28, 
          height: 28,
          decoration: BoxDecoration(
            color: color, 
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.0),
          ),
          alignment: Alignment.center,
          child: trackStock && qty > 0
              ? Text(
                  qty > 99 ? "99+" : qty.toString(),
                  style: CarDashboardTheme.quantityStyle.copyWith(
                    color: Colors.white, 
                    fontSize: 10,
                  ),
                )
              : null, 
        );
  }

  Widget _buildStockBtn(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildPlaceholder(Color bgColor, bool isDarkMode) {
    return Container(
      color: bgColor,
      child: Center(
        child: Text(
          widget.item.name.isNotEmpty ? widget.item.name[0].toUpperCase() : "?",
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: CarDashboardTheme.borderColor(isDarkMode), // Subtle text
          ),
        ),
      ),
    );
  }
  Color _getDeterminsticColor(String key, bool isDarkMode) {
    if (isDarkMode) {
      // Dark Mode Palette (Neon/Vibrant) - Standout Aesthetics
      final colors = [
        const Color(0xFF0F3460), // Deep Blue
        const Color(0xFF16213E), // Dark Navy
        const Color(0xFF1A1A2E), // Night
        const Color(0xFF2C061F), // Dark Claret
        const Color(0xFF374045), // Graphite
        const Color(0xFF222831), // Asphalt
      ];
      return colors[key.hashCode.abs() % colors.length];
    } else {
      // Light Mode Palette (Pastel/Light) - High Visibility for Labels
      final colors = [
        const Color(0xFFE0F2FE), // Sky Blue
        const Color(0xFFF0FDF4), // Mint Green
        const Color(0xFFFEF9C3), // Lemon Yellow
        const Color(0xFFFEE2E2), // Rose Red
        const Color(0xFFF3E8FF), // Lilac
        const Color(0xFFFFEDD5), // Peach
        const Color(0xFFF1F5F9), // Slate White
      ];
      return colors[key.hashCode.abs() % colors.length];
    }
  }
}
