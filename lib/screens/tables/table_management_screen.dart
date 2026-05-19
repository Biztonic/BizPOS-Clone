import '../../core/design/design_system.dart';
import '../../core/design/layouts/pos_scaffold.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/table_provider.dart';
import '../../models/floor.dart';
import '../../models/table_model.dart';
import '../../models/inventory_item.dart'; // Added
import '../../models/order_model.dart'; // Added
import 'package:uuid/uuid.dart';
import 'dart:math' as dart_math;
// Ensure correct ReceiptSettings import
// Keep for KOT if needed, but Manager handles it
import '../../services/printer_manager_service.dart'; // Added for Standard Print
import 'package:collection/collection.dart';




class TableManagementScreen extends StatefulWidget {
  const TableManagementScreen({super.key});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}


class _TableManagementScreenState extends State<TableManagementScreen> {
  String? _selectedFloorId;
  String? _selectedTableId;
  bool _isEditMode = false;
  final GlobalKey _canvasKey = GlobalKey(); // NEW: Key for Canvas

  // Grid snap constants
  static const double _gridCellWidth = 160.0;
  static const double _gridCellHeight = 160.0;
  static const int _gridColumns = 18; // max columns in 3000px canvas
  static const double _gridPadding = 40.0; // padding from canvas edge

  /// Snaps a raw coordinate to the nearest grid cell origin.
  double _snapToGrid(double value, double cellSize) {
    final snapped = ((value - _gridPadding) / cellSize).round() * cellSize + _gridPadding;
    return snapped < _gridPadding ? _gridPadding : snapped;
  }

  /// Finds the next unoccupied grid cell for auto-placing a new table.
  TablePosition _findNextOpenGridPosition() {
    final provider = Provider.of<TableProvider>(context, listen: false);
    final floorTables = provider.tables.where((t) => t.floorId == _selectedFloorId).toList();

    // Build set of occupied grid cells (col, row)
    final occupied = <String>{};
    for (final t in floorTables) {
      final col = ((t.position.x - _gridPadding) / _gridCellWidth).round();
      final row = ((t.position.y - _gridPadding) / _gridCellHeight).round();
      occupied.add('$col,$row');
    }

    // Scan row-by-row, left-to-right for first open cell
    for (int row = 0; row < 100; row++) {
      for (int col = 0; col < _gridColumns; col++) {
        if (!occupied.contains('$col,$row')) {
          return TablePosition(
            x: _gridPadding + col * _gridCellWidth,
            y: _gridPadding + row * _gridCellHeight,
          );
        }
      }
    }
    // Fallback (should never happen with 100 rows × 18 cols)
    return TablePosition(x: _gridPadding, y: _gridPadding);
  }

  // Dragging State (Not strictly needed with DragTarget but kept if we want fine tuning)
  // Offset? _dragStartOffset;

  @override
  void initState() {
    super.initState();
    // Auto-select first floor if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TableProvider>(context, listen: false);
      if (provider.floors.isNotEmpty) {
        setState(() => _selectedFloorId = provider.floors.firstOrNull?.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {

    final tableProvider = Provider.of<TableProvider>(context);
    
    // Syncing activeStoreId is handled by ProxyProvider in main.dart

    final floors = tableProvider.floors;
    
    // Auto-Select Logic (Reactive)
    if (_selectedFloorId == null && floors.isNotEmpty && !_isEditMode) {
       // Defer state update to avoid build cycle
       // Or just set it locally if using a State variable that determines view
       // But _selectedFloorId is state. Better to schedule frame? 
       // Actually simpler: just use local variable for VIEW, but we need it in State for dropdown.
       // Safe pattern:
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedFloorId == null) {
             setState(() => _selectedFloorId = floors.firstOrNull?.id);
          }
       });
    }

    final activeFloor = floors.where((f) => f.id == _selectedFloorId).firstOrNull;
    
    // Filter tables for current floor
    final floorTables = tableProvider.tables.where((t) => t.floorId == _selectedFloorId).toList();

    final isMobileView = MediaQuery.of(context).size.width < 600;

    return PosScaffold(
      appBar: AppBar(
        title: isMobileView ? Text(AppLocalizations.t(context, 'Tables'), style: const TextStyle(fontWeight: FontWeight.bold)) : Text(AppLocalizations.t(context, 'Table Management'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          // PREMIUM FLOOR SELECTOR
          if (floors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(context).withAlpha((0.05 * 255).toInt()),
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: AppColors.textSecondary(context).withAlpha((0.1 * 255).toInt())),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: floors.map((f) {
                      final isSelected = f.id == _selectedFloorId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedFloorId = f.id;
                            _selectedTableId = null;
                          }),
                          borderRadius: AppRadius.borderMd,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryLight : AppColors.transparent,
                              borderRadius: AppRadius.borderMd,
                              boxShadow: isSelected 
                                ? [BoxShadow(color: AppColors.primaryLight.withAlpha((0.3 * 255).toInt()), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.layers_outlined,
                                  size: 14,
                                       color: isSelected ? Theme.of(context).colorScheme.onPrimary : AppColors.textSecondary(context),
                                ),
                                if (!isMobileView || floors.length < 3) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    f.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Theme.of(context).colorScheme.onPrimary : AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
            
          SizedBox(width: isMobileView ? 8 : 16),
          
          // MODE TOGGLE
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobileView ? 4.0 : 16.0, vertical: AppSpacing.sm),
            child: ToggleButtons(
              isSelected: [!_isEditMode, _isEditMode],
              onPressed: (index) => setState(() {
                 _isEditMode = index == 1;
                 _selectedTableId = null; // Clear selection on mode switch
              }),
              borderRadius: AppRadius.borderMd,
              fillColor: Theme.of(context).primaryColor,
               selectedColor: Theme.of(context).colorScheme.onPrimary,
              color: Theme.of(context).iconTheme.color,
              children: [
                 Padding(padding: EdgeInsets.symmetric(horizontal: isMobileView ? 8 : 12), child: Row(children: [const Icon(Icons.visibility, size: 16), if (!isMobileView) const SizedBox(width: AppSpacing.xs), if (!isMobileView) Text(AppLocalizations.t(context, 'View'))])),
                 Padding(padding: EdgeInsets.symmetric(horizontal: isMobileView ? 8 : 12), child: Row(children: [const Icon(Icons.edit, size: 16), if (!isMobileView) const SizedBox(width: AppSpacing.xs), if (!isMobileView) Text(AppLocalizations.t(context, 'Edit Layout'))])),
              ],
            ),
          ),
          
          if (_isEditMode) ...[
             IconButton(
                icon: const Icon(Icons.add_business),
                tooltip: "Add Floor",
                onPressed: _showAddFloorDialog,
             ),
             if (_selectedFloorId != null)
                IconButton(
                  icon: const Icon(Icons.edit_note),
                  tooltip: "Rename Floor",
                  onPressed: () => _showEditFloorDialog(activeFloor!),
                ),
          ] else ...[
             // View Mode Actions
             if (isMobileView)
                IconButton(
                   icon: const Icon(Icons.calendar_today),
                   onPressed: () => _showBookTableDialog(null),
                   color: Theme.of(context).primaryColor,
                )
             else
                ElevatedButton.icon(
                   onPressed: () => _showBookTableDialog(null), // General Booking
                   icon: const Icon(Icons.calendar_today, size: 16),
                   label: Text(AppLocalizations.t(context, 'Book Table')),
                   style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).cardColor, 
                      foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                      elevation: 0,
                      side: BorderSide(color: Theme.of(context).dividerColor)
                   ),
                ),
             SizedBox(width: isMobileView ? 4 : 16),
          ]
        ],
      ),
      mainContent: _selectedFloorId == null 
         ? Center(child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
                Icon(Icons.layers_clear, size: 64, color: AppColors.textSecondary(context)),
                const SizedBox(height: AppSpacing.md),
                Text(AppLocalizations.t(context, 'No Floor Selected'), style: TextStyle(color: AppColors.textSecondary(context), fontSize: 18)),
                if (_isEditMode) TextButton(onPressed: _showAddFloorDialog, child: Text(AppLocalizations.t(context, 'Create a Floor')))
             ],
         ))
         : Stack(
           children: [
              // DROP AREA - InteractiveViewer for scroll + zoom
              InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(AppSpacing.xl),
                minScale: 0.3,
                maxScale: 2.0,
                child: DragTarget<String>(
                onAcceptWithDetails: (details) {
                  if (!_isEditMode) return;
                   // Logic handled in Draggable onDragEnd
                },
                builder: (context, candidateData, rejectedData) {
                   return Container(
                     key: _canvasKey,
                     decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor, // Replaced heavy RadialGradient with solid color to fix crashing
                     ),
                     width: 3000,
                     height: 3000,
                     child: Stack(
                        children: [
                           // Visual grid lines (Edit mode only)
                           if (_isEditMode)
                             Positioned.fill(
                               child: CustomPaint(
                                 painter: _GridPainter(
                                   cellWidth: _gridCellWidth,
                                   cellHeight: _gridCellHeight,
                                   padding: _gridPadding,
                                   color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                 ),
                               ),
                             ),
                           ...floorTables.map((table) => _buildTableWidget(table)),
                        ],
                     ),
                   );
                },
               ),
              ),  // InteractiveViewer
               
               // EDIT TOOLBAR (Bottom Center)
               if (_isEditMode)                Positioned(
                  bottom: 30,
                  left: 0, 
                  right: 0,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: AppRadius.borderLg,
                      child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                             color: Theme.of(context).cardColor.withValues(alpha: 0.7),
                             borderRadius: AppRadius.borderLg,
                             border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.2)),
                             boxShadow: [BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]
                          ),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _AddTableButton(label: "Square", icon: Icons.crop_square, onTap: () => _addTable('square')),
                                Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm), color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                                _AddTableButton(label: "Round", icon: Icons.circle_outlined, onTap: () => _addTable('circle')),
                                Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm), color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                                _AddTableButton(label: "Rect", icon: Icons.rectangle_outlined, onTap: () => _addTable('rectangular')),
                              ],
                          ),
                      ),
                    ),
                  ),
                ),
               
               // EDIT PROPERTIES PANEL (Right Overlay)                if (_isEditMode && _selectedTableId != null)
                   Positioned(
                     top: AppSpacing.md, bottom: AppSpacing.md, right: AppSpacing.md, left: isMobileView ? 16 : null,
                     child: ClipRRect(
                       borderRadius: AppRadius.borderLg,
                       child: Container(
                           decoration: BoxDecoration(
                             color: Theme.of(context).cardColor.withValues(alpha: 0.85),
                             borderRadius: AppRadius.borderLg,
                             border: Border.all(color: AppColors.surfaceLight.withValues(alpha: 0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).shadowColor.withValues(alpha: 0.2),
                                 blurRadius: 20,
                                 offset: const Offset(0, 10),
                               )
                             ],
                           ),
                           child: (_selectedTableId != null && floorTables.any((t) => t.id == _selectedTableId))
                               ? (_selectedTableId == null ? const SizedBox() : _buildPropertiesPanel(floorTables.where((t) => t.id == _selectedTableId).firstOrNull ?? floorTables.first, isMobileView))
                               : const SizedBox.shrink(),
                       ),
                     ),
                   )
           ],
         ),
    );
  }
  
  // --- WIDGET BUILDERS ---

  Widget _buildTableWidget(TableModel table) {
    final isSelected = table.id == _selectedTableId;
    // Determine visual size based on shape and seats
    // Base size 80x80 for 2-4 seats. Larger for more.
    double baseSize = 80;
    if (table.seats.length > 4) baseSize = 100;
    
    final size = table.shape == 'rectangular' ? Size(baseSize * 1.5, baseSize) : Size(baseSize, baseSize);
    
    // Position handling
    return Positioned(
       left: table.position.x,
       top: table.position.y,
       child: GestureDetector(
         onTap: () {
            if (_isEditMode) {
               setState(() => _selectedTableId = table.id);
            } else {
               // VIEW MODE ACTION: Open Options
               _showTableOptionsDialog(table);
            }
         },
         // Only enable Drag in Edit Mode
         child: _isEditMode 
            ? Draggable<String>(
                data: table.id,
                feedback: Transform.scale(scale: 1.1, child: Opacity(opacity: 0.9, child: _tableVisual(table, size, true))),
                childWhenDragging: Opacity(opacity: 0.3, child: _tableVisual(table, size, isSelected)),
                onDragEnd: (details) {
                   final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                   if (renderBox == null) return;
                   final localPos = renderBox.globalToLocal(details.offset);
                   
                   // Snap to grid
                   double offsetX = _snapToGrid(localPos.dx, _gridCellWidth);
                   double offsetY = _snapToGrid(localPos.dy, _gridCellHeight);
                   
                   _updateTable(table, position: TablePosition(x: offsetX, y: offsetY));
                },
                child: _tableVisual(table, size, isSelected),
              )
            : _tableVisual(table, size, false), // Non-draggable in View Mode
       ),
    );
  }
  
   Widget _tableVisual(TableModel table, Size size, bool isSelected) {
     Color bgColor;
     Color borderColor;
     Color statusTextColor;
     
     // Normalize status for case-insensitive check
     final statusLower = table.status.toLowerCase();
     
     // Use TableModel business logic for reservation status
     bool effectiveIsReserved = table.isBooked || table.isImpendingReservation;
     
     final isDark = Theme.of(context).brightness == Brightness.dark;

     if (statusLower == 'occupied') {
         bgColor = isDark ? AppColors.error.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.1);
         borderColor = AppColors.error;
         statusTextColor = isDark ? AppColors.error : const Color(0xFFC62828);
     } else if (effectiveIsReserved) {
         bgColor = isDark ? AppColors.warning.withValues(alpha: 0.15) : AppColors.warning.withValues(alpha: 0.1);
         borderColor = AppColors.warning;
         statusTextColor = isDark ? AppColors.warning : const Color(0xFFE65100);
     } else {
         bgColor = Theme.of(context).cardColor;
         borderColor = isDark ? Colors.white24 : AppColors.textSecondaryLight;
         statusTextColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimaryLight;
     }

     if (isSelected) {
        borderColor = AppColors.primaryLight;
        bgColor = isDark ? AppColors.primaryLight.withValues(alpha: 0.2) : AppColors.primaryLight.withValues(alpha: 0.1);
     }

     const double chairSize = 24.0;
     const double chairDistance = 8.0; // Distance from table edge

     return SizedBox(
       width: size.width + (chairSize * 2) + (chairDistance * 2), 
       height: size.height + (chairSize * 2) + (chairDistance * 2), 
       child: Stack(
         alignment: Alignment.center,
         children: [
            // CHAIRS RENDERING
            for (int i = 0; i < table.seats.length; i++) ...[
               Builder(
                 builder: (context) {
                     bool isSeatOccupied = table.seats[i].orderId != null;
                     bool isOccupied = isSeatOccupied || table.isOccupied; // Use isOccupied from TableModel
                     bool shouldAnimate = false;
                     
                     int bookedCount = table.bookedSeats ?? table.seats.length;
                     
                     if (table.isOccupied && table.orderId != null) {
                           if (i < bookedCount) shouldAnimate = true;
                     } else if (isSeatOccupied) {
                           shouldAnimate = true;
                     } else if (effectiveIsReserved) {
                        if (i < bookedCount) {
                           shouldAnimate = true;
                        }
                     }
                    
                    return _buildChair(i, table.seats.length, table.shape, size, chairSize, chairDistance, isOccupied, shouldAnimate, table.isOccupied);
                 }
               )
            ],

            // TABLE TOP
            Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                  color: bgColor,
                  shape: table.shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: table.shape == 'rectangular' || table.shape == 'square' ? AppRadius.borderLg : null,
                  border: Border.all(
                    color: borderColor, 
                    width: isSelected ? 2.5 : 1.5
                  ),
                  boxShadow: [
                    BoxShadow(
                       color: AppColors.textPrimaryLight.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: isSelected ? 16 : 8, 
                      offset: Offset(0, isSelected ? 8 : 4),
                    )
                  ]
               ),
               child: Center(
                 child: Column(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Text(
                        table.name, 
                        style: TextStyle(
                           fontWeight: FontWeight.w700, 
                           color: statusTextColor,
                           fontSize: 18,
                        )
                     ),
                     if (statusLower == 'occupied' && table.orderId != null)
                       Container(
                         margin: const EdgeInsets.only(top: AppSpacing.xs),
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                         decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                           borderRadius: AppRadius.borderSm,
                         ),
                         child: Text(AppLocalizations.t(context, 'ACTIVE'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.error))
                       )
                     else if (effectiveIsReserved)
                       Column(
                         children: [
                           Container(
                              margin: const EdgeInsets.only(top: AppSpacing.xs),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1), 
                                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                                borderRadius: AppRadius.borderSm,
                              ),
                              child: Text(AppLocalizations.t(context, 'BOOKED'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.warning))
                           ),
                           if (table.bookedTime != null)
                             Padding(
                               padding: const EdgeInsets.only(top: AppSpacing.xs),
                               child: Text(
                                  TimeOfDay.fromDateTime(table.bookedTime!).format(context), 
                                  style: TextStyle(fontSize: 11, color: statusTextColor, fontWeight: FontWeight.w600)
                               ),
                             )
                         ]
                       )
                     else
                       Text(
                          "${table.seats.length} Seats", 
                          style: TextStyle(fontSize: 11, color: statusTextColor.withValues(alpha: 0.6), fontWeight: FontWeight.w500)
                       ),
                   ],
                 ),
               ),
             ),
         ],
       ),
     );
   }

  Widget _buildChair(int index, int totalSeats, String shape, Size tableSize, double chairSize, double distance, bool isOccupied, bool shouldAnimate, bool isTableOccupied) {
      double angle = 0;
      double dx = 0;
      double dy = 0;
      
      if (shape == 'circle') {
         // Radial distribution
         angle = (2 * 3.14159 * index) / totalSeats;
         double radius = (tableSize.width / 2) + distance + (chairSize / 2);
         dx = radius * dart_math.cos(angle - 3.14159 / 2); // Start from top (-90 deg)
         dy = radius * dart_math.sin(angle - 3.14159 / 2);
      } else {
         // Rectangular/Square distribution (Perimeter)
         // Fallback to optimized radial for visual consistency as 'professional' often means uniform.
         angle = (2 * 3.14159 * index) / totalSeats;
         double w = tableSize.width / 2 + distance + chairSize/2;
         double h = tableSize.height / 2 + distance + chairSize/2;
         
         // Elliptical projection for positioning
         dx = w * dart_math.cos(angle - 3.14159 / 2);
         dy = h * dart_math.sin(angle - 3.14159 / 2);
      }
      
      return Transform.translate(
         offset: Offset(dx, dy),
         child: _PulsingChair(
            size: chairSize,
            isOccupied: isOccupied,
            shouldAnimate: shouldAnimate,
            isTableOccupied: isTableOccupied,
         ),
      );
  }

  Widget _buildPropertiesPanel(TableModel table, bool isMobileView) {
     // State Controller for Name Input to avoid rebuilding on every char
     final nameController = TextEditingController(text: table.name);
     // Helper for duplication check
     final provider = Provider.of<TableProvider>(context, listen: false);
     
     return StatefulBuilder(builder: (context, setPanelState) {
        return Container(
          width: isMobileView ? null : 280,
          height: 600, // Constrained height
          decoration: BoxDecoration(
             color: Theme.of(context).cardColor,
             borderRadius: AppRadius.borderLg,
          ),
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text(AppLocalizations.t(context, 'Edit Table'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedTableId = null))
                 ],
               ),
               const Divider(),
               const SizedBox(height: AppSpacing.md),
               
               TextField(
                  decoration: InputDecoration(
                     labelText: "Name / Number",
                     border: const OutlineInputBorder(borderRadius: AppRadius.borderMd),
                     filled: true,
                     fillColor: Theme.of(context).canvasColor
                  ),
                  controller: nameController, 
                  // onSubmitted removed, use Save Button
               ),
               const SizedBox(height: AppSpacing.md),
               
               Text(AppLocalizations.t(context, 'Seats'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary(context))),
               const SizedBox(height: AppSpacing.sm),
               Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.xs),
                   decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: AppRadius.borderMd),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () {
                         if (table.seats.isNotEmpty) _updateTable(table, seats: table.seats.length - 1);
                      }),
                      Text("${table.seats.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {
                         _updateTable(table, seats: table.seats.length + 1);
                      }),
                    ],
                  ),
               ),
               
               const SizedBox(height: AppSpacing.xxs),
                Text(AppLocalizations.t(context, 'Billing Mode'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary(context))),
                const SizedBox(height: AppSpacing.sm),
               DropdownButtonFormField<String>(
                  value: table.billingMode,
                   decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: AppRadius.borderMd), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
                  items: [
                     DropdownMenuItem(value: 'per-table', child: Text(AppLocalizations.t(context, 'Per Table (One Bill)'))),
                     DropdownMenuItem(value: 'per-seat', child: Text(AppLocalizations.t(context, 'Per Seat (Split Bill)'))),
                  ],
                  onChanged: (val) {
                     if (val != null) _updateTable(table, billingMode: val);
                  },
               ),
                const SizedBox(height: AppSpacing.xxs),
               
               // SAVE BUTTON
               SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                     onPressed: () {
                        // DUPLICATE CHECK
                        final newName = nameController.text.trim();
                        if (newName.isEmpty) return;
                        
                        // Check if other tables on SAME floor have this name
                        final isDuplicate = provider.tables.any((t) => 
                           t.floorId == table.floorId && 
                           t.id != table.id && 
                           t.name.toLowerCase() == newName.toLowerCase()
                        );
                        
                        if (isDuplicate) {
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Table name '$newName' already exists on this floor."), backgroundColor: AppColors.error));
                           return;
                        }
                        
                        _updateTable(table, name: newName);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Table Saved'))));
                        setState(() => _selectedTableId = null); // Close panel? Or keep open? User said "Add save option", implying manual save.
                     },
                                                                         style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Theme.of(context).colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 12)),
                     child: Text(AppLocalizations.t(context, 'Save Changes')),
                  ),
               ),
               
               const Spacer(),
               
               SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                     style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error, 
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0
                     ),
                     icon: const Icon(Icons.delete_outline),
                     label: Text(AppLocalizations.t(context, 'Delete Table')),
                     onPressed: () {
                        provider.deleteTable(table.id);
                        setState(() => _selectedTableId = null);
                     },
                  ),
               )
            ],
          ),
        );
     });
  }
  
  // --- DIALOGS (VIEW MODE) ---
  
  void _showTableOptionsDialog(TableModel table) {
      // Wrapper to redirect to new Quick Order Logic immediately as per user request
      _showQuickOrderDialog(table);
  }

   void _showQuickOrderDialog(TableModel table) {
      final tableProvider = Provider.of<TableProvider>(context, listen: false);
      final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
      
      // Initialize Draft Order State
      List<InventoryItem> menuItems = List.from(dashboardProvider.storeInventory);
      List<OrderItem> currentOrderItems = [];
      String searchQuery = "";
      String selectedCategory = "All"; 
      
      int? selectedSeatIndex = -1; 
      List<int> billSelectedSeats = []; 
      
      OrderModel? existingOrder;
      
      void loadExistingOrders() {
          currentOrderItems.clear(); 
          
          if (table.orderId != null) {
              existingOrder = dashboardProvider.orders.where((o) => o.id == table.orderId).firstOrNull;
              if (existingOrder != null) {
                 currentOrderItems.addAll(existingOrder!.items);
              }
          }
          
          for (int i = 0; i < table.seats.length; i++) {
              final s = table.seats[i];
              if (s.orderId != null && s.orderId != table.orderId) {
                  try {
                      final sOrder = dashboardProvider.orders.where((o) => o.id == s.orderId).firstOrNull;
                      if (sOrder != null) {
                          for (var item in sOrder.items) {
                              currentOrderItems.add(item.copyWith(seatIndex: i));
                          }
                      }
                  } catch (_) { }
              }
          }
      }

      loadExistingOrders();

      

      
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(
         builder: (context, setDialogState) {
             var filteredMenu = menuItems.where((i) => i.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
             if (selectedCategory != 'All') {
                filteredMenu = filteredMenu.where((i) => i.category == selectedCategory).toList();
             }



            final categories = ['All', ...menuItems.map((e) => e.category).toSet().toList()..sort()];
            
            final double total = currentOrderItems.fold(0, (sum, i) => sum + (i.item.price * i.quantity));
            final isMobileDialog = MediaQuery.of(context).size.width < 800;

            return Dialog(
               shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
               insetPadding: isMobileDialog ? const EdgeInsets.all(AppSpacing.md) : const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.lg),
               child: Container(
                  width: isMobileDialog ? MediaQuery.of(context).size.width : 900,
                  height: isMobileDialog ? MediaQuery.of(context).size.height : 700,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: AppRadius.borderLg, color: Theme.of(context).cardColor),
                  child: LayoutBuilder(
                     builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 800;
                                               final orderPanel = Container(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Column(
                                 children: [
                                    // Header
                                    Container(
                                       padding: const EdgeInsets.all(AppSpacing.lg),
                                       decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)))),
                                       child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [                                              Row(
                                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                 children: [
                                                    Text("Table ${table.name}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                                    Row(
                                                      children: [                                                        if (billSelectedSeats.length > 1)
                                                          Padding(
                                                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                                                            child: ElevatedButton.icon(
                                                              onPressed: () {
                                                                // MERGE LOGIC: Group all items of selected seats into the primary seat's order
                                                                setDialogState(() {
                                                                    final mainSeatIdx = billSelectedSeats.isNotEmpty ? billSelectedSeats.first : null;
                                                                    if (mainSeatIdx == null) return;
                                                                    for (var i = 0; i < currentOrderItems.length; i++) {
                                                                       if (currentOrderItems[i].seatIndex != null && billSelectedSeats.contains(currentOrderItems[i].seatIndex)) {
                                                                           // Move item to the main seat
                                                                          currentOrderItems[i] = currentOrderItems[i].copyWith(seatIndex: mainSeatIdx);
                                                                       }
                                                                    }
                                                                    selectedSeatIndex = mainSeatIdx;
                                                                });
                                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Seats merged in draft'))));
                                                              }, 
                                                              icon: const Icon(Icons.merge_type, size: 16),
                                                              label: Text(AppLocalizations.t(context, 'MERGE'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: AppColors.warning,
                                                                 foregroundColor: AppColors.surfaceLight,
                                                                elevation: 0,
                                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                                                minimumSize: const Size(0, 36),
                                                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg)
                                                              ),
                                                            ),
                                                          ),
                                                        Container(
                                                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                           decoration: BoxDecoration(
                                                              color: table.status == 'Occupied' ? AppColors.error.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                                                              borderRadius: AppRadius.borderLg,
                                                              border: Border.all(color: table.status == 'Occupied' ? AppColors.error.withValues(alpha: 0.3) : AppColors.success.withValues(alpha: 0.3))
                                                           ),
                                                           child: Text(table.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: table.status == 'Occupied' ? AppColors.error : AppColors.success))
                                                        ),
                                                      ],
                                                    )
                                                  ],
                                               ),
                                               if (table.seats.isNotEmpty) ...[
                                                   const SizedBox(height: AppSpacing.md),
                                                   Text(AppLocalizations.t(context, 'Select Seat / Table:'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodySmall?.color)),
                                                   const SizedBox(height: AppSpacing.sm),
                                                   SingleChildScrollView(
                                                     scrollDirection: Axis.horizontal,
                                                     child: Row(
                                                       children: [
                                                         // WHOLE TABLE TILE
                                                         Padding(
                                                           padding: const EdgeInsets.only(right: AppSpacing.sm),
                                                           child: ChoiceChip(
                                                             label: Text(AppLocalizations.t(context, 'Whole Table')),
                                                             selected: selectedSeatIndex == -1,
                                                             onSelected: (val) {
                                                               setDialogState(() {
                                                                 selectedSeatIndex = -1;
                                                                 billSelectedSeats.clear();
                                                               });
                                                             },
                                                             selectedColor: Theme.of(context).primaryColor,
                                                             labelStyle: TextStyle(
                                                               color: selectedSeatIndex == -1 ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).textTheme.bodyLarge?.color,
                                                               fontWeight: selectedSeatIndex == -1 ? FontWeight.bold : FontWeight.w500,
                                                             ),
                                                             shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
                                                             side: BorderSide(color: selectedSeatIndex == -1 ? AppColors.transparent : Theme.of(context).dividerColor),
                                                             showCheckmark: false,
                                                           ),
                                                         ),
                                                         // SEAT TILES
                                                         ...List.generate(table.seats.length, (i) {
                                                           final seat = table.seats[i];
                                                           final isSel = selectedSeatIndex == i;
                                                           final isBillSelected = billSelectedSeats.contains(i);
                                                           
                                                           return Padding(
                                                             padding: const EdgeInsets.only(right: AppSpacing.sm),
                                                             child: ChoiceChip(
                                                               label: Row(
                                                                 mainAxisSize: MainAxisSize.min,
                                                                 children: [
                                                                   Text("Seat ${seat.number}"),
                                                                   if (isBillSelected || isSel) ...[
                                                                     const SizedBox(width: AppSpacing.xs),
                                                                     Icon(isSel ? Icons.radio_button_checked : Icons.check_circle, size: 14, color: isSel ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).primaryColor),
                                                                   ]
                                                                 ],
                                                               ),
                                                               selected: isSel || isBillSelected,
                                                               onSelected: (val) {
                                                                 setDialogState(() {
                                                                   if (selectedSeatIndex == i) {
                                                                      if (isBillSelected) {
                                                                         billSelectedSeats.remove(i);
                                                                      } else {
                                                                         billSelectedSeats.add(i);
                                                                      }
                                                                   } else {
                                                                     selectedSeatIndex = i;
                                                                     if (!billSelectedSeats.contains(i)) billSelectedSeats.add(i);
                                                                   }
                                                                 });
                                                               },
                                                               selectedColor: isSel ? Theme.of(context).primaryColor : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                                               labelStyle: TextStyle(
                                                                 color: isSel ? Theme.of(context).colorScheme.onPrimary : (isBillSelected ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyLarge?.color),
                                                                 fontWeight: (isBillSelected || isSel) ? FontWeight.bold : FontWeight.w500,
                                                               ),
                                                               shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
                                                               side: BorderSide(color: isSel || isBillSelected ? AppColors.transparent : Theme.of(context).dividerColor),
                                                               showCheckmark: false,
                                                             ),
                                                           );
                                                         }),
                                                       ],
                                                     ),
                                                   ),
                                                   const SizedBox(height: AppSpacing.md),
                                                   Container(
                                                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                     decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.05), borderRadius: AppRadius.borderSm),
                                                     child: Row(
                                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                       children: [
                                                         Text(selectedSeatIndex == -1 ? "Ordering for Whole Table" : "Ordering for Seat ${table.seats[selectedSeatIndex!].number}", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
                                                         Text(existingOrder != null ? "Order #${existingOrder!.id.substring(0,6)}" : "New Order", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w500))
                                                       ],
                                                     ),
                                                   ),
                                                ],
                                          ],
                                       ),
                                    ),
                                    
                                    // List
                                    Expanded(
                                       child: Container(
                                          color: Theme.of(context).scaffoldBackgroundColor,
                                          child: () {
                                             final filteredItems = selectedSeatIndex == -1 
                                                ? currentOrderItems 
                                                : currentOrderItems.where((i) => i.seatIndex == selectedSeatIndex).toList();
                                                
                                             return filteredItems.isEmpty 
                                                ? Center(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                            padding: const EdgeInsets.all(AppSpacing.lg),
                                                            decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle),
                                                            child: Icon(Icons.shopping_basket_outlined, size: 48, color: Theme.of(context).dividerColor),
                                                        ),
                                                        const SizedBox(height: AppSpacing.md),
                                                        Text("No items added yet", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16, fontWeight: FontWeight.w500)),
                                                      ]
                                                    )
                                                  )
                                                : ListView.builder(
                                                   padding: const EdgeInsets.all(AppSpacing.md),
                                                   itemCount: filteredItems.length,
                                                   itemBuilder: (c, idx) {
                                                      final orderItem = filteredItems[idx];
                                                      // Find original index for removal
                                                      final originalIdx = currentOrderItems.indexOf(orderItem);
                                                      
                                                      return Container(
                                                         margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                                         decoration: BoxDecoration(
                                                            color: Theme.of(context).cardColor,
                                                            borderRadius: AppRadius.borderSm,
                                                            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                                                            boxShadow: [BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))]
                                                         ),
                                                         child: ListTile(
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                                                            title: Text(orderItem.item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                            subtitle: Padding(
                                                              padding: const EdgeInsets.only(top: 4.0),
                                                              child: Column(
                                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                                 children: [
                                                                    Text("x${orderItem.quantity}  @ ₹${orderItem.item.price}", style: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.w500)),
                                                                    if (orderItem.seatIndex != null)
                                                                       Container(
                                                                          margin: const EdgeInsets.only(top: AppSpacing.xs),
                                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), borderRadius: AppRadius.borderXs),
                                                                          child: Text("Seat ${table.seats[orderItem.seatIndex!].number}", style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))
                                                                       )
                                                                 ],
                                                              ),
                                                            ),
                                                            trailing: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Text("₹${(orderItem.quantity * orderItem.item.price).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                                const SizedBox(width: AppSpacing.sm),
                                                                IconButton(
                                                                   icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                                                                   onPressed: () {
                                                                      setDialogState(() {
                                                                         if (orderItem.quantity > 1) {
                                                                            currentOrderItems[originalIdx] = orderItem.copyWith(quantity: orderItem.quantity - 1);
                                                                         } else {
                                                                            currentOrderItems.removeAt(originalIdx);
                                                                         }
                                                                      });
                                                                   },
                                                                ),
                                                              ]
                                                            )
                                                         ),
                                                      );
                                                   },
                                                );
                                          }()
                                       )
                                    ),
                                    
                                    // Footer Actions
                                    Container(
                                       padding: const EdgeInsets.all(AppSpacing.lg),
                                       decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))]),
                                       child: Column(
                                          children: [
                                             Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                   Text(AppLocalizations.t(context, 'Total Amount:'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textSecondary(context))),
                                                   Text("₹${total.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: Theme.of(context).primaryColor)),
                                                ],
                                             ),
                                             const SizedBox(height: AppSpacing.md),
                                             // Action Buttons
                                             Row(
                                                children: [
                                                   Expanded(
                                                      child: Column(
                                                         children: [
                                                            Row(
                                                               children: [
                                                                  Expanded(
                                                                     child: ElevatedButton.icon(
                                                                        onPressed: () async {
                                                                            // PROCESS CASH PAYMENT
                                                                            if (currentOrderItems.isEmpty) return;
                                                                            
                                                                            List<OrderItem> itemsToBill;
                                                                            List<int> billedSeatNumbers = [];
                                                                            
                                                                            if (billSelectedSeats.isNotEmpty) {
                                                                               itemsToBill = currentOrderItems.where((i) => i.seatIndex != null && billSelectedSeats.contains(i.seatIndex)).toList();
                                                                               billedSeatNumbers = billSelectedSeats.map((idx) => table.seats[idx].number).toList()..sort();
                                                                            } else if (selectedSeatIndex != -1) {
                                                                               itemsToBill = currentOrderItems.where((i) => i.seatIndex == selectedSeatIndex).toList();
                                                                               billedSeatNumbers = [table.seats[selectedSeatIndex!].number];
                                                                            } else {
                                                                               itemsToBill = List.from(currentOrderItems);
                                                                               billedSeatNumbers = currentOrderItems.where((i) => i.seatIndex != null).map((i) => table.seats[i.seatIndex!].number).toSet().toList()..sort();
                                                                            }
                                                                            
                                                                            if (itemsToBill.isEmpty) {
                                                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'No items for selected seat(s)'))));
                                                                                return;
                                                                            }

                                                                            final sub = itemsToBill.fold(0.0, (s, i) => s + (i.item.price * i.quantity));
                                                                            final tax = (dashboardProvider.activeStore?.isTaxEnabled ?? false) ? ((dashboardProvider.activeStore?.taxRate ?? 0) / 100) : 0.0;
                                                                            final totalBill = sub * (1 + tax);

                                                                            final order = OrderModel(
                                                                               id: dashboardProvider.syncService.generateUniqueId('ORD'),
                                                                               storeId: dashboardProvider.activeStoreId!,
                                                                               items: itemsToBill,
                                                                               total: totalBill,
                                                                               date: DateTime.now(),
                                                                               status: 'Completed',
                                                                               type: 'Dine-In',
                                                                               paymentMethod: 'Cash',
                                                                               tableId: table.id,
                                                                               tableName: table.name,
                                                                               seatNumbers: billedSeatNumbers,
                                                                               taxRateSnapshot: tax * 100,
                                                                            );

                                                                            await dashboardProvider.placeOrder(order);
                                                                            
                                                                            // Print Receipt
                                                                            await PrinterManagerService().printOrderReceipt(order, dashboardProvider.activeStore, cashierName: dashboardProvider.userProfile?.name ?? "Cashier");

                                                                            final targetSeats = billSelectedSeats.isNotEmpty ? List<int>.from(billSelectedSeats) : (selectedSeatIndex != -1 ? [selectedSeatIndex!] : []);

                                                                            setDialogState(() {
                                                                               if (billSelectedSeats.isNotEmpty) {
                                                                                  currentOrderItems.removeWhere((i) => i.seatIndex != null && billSelectedSeats.contains(i.seatIndex));
                                                                               } else if (selectedSeatIndex == -1) {
                                                                                  currentOrderItems.clear();
                                                                               } else {
                                                                                  currentOrderItems.removeWhere((i) => i.seatIndex == selectedSeatIndex);
                                                                               }
                                                                               billSelectedSeats.clear();
                                                                            });

                                                                            if (currentOrderItems.isEmpty) {
                                                                               // Table fully cleared
                                                                               await tableProvider.clearTable(table.id);
                                                                               Navigator.pop(ctx);
                                                                            } else {
                                                                                // Table partially cleared, update seats status
                                                                                for (var seatIdx in targetSeats) {
                                                                                    await tableProvider.clearSeat(table.id, table.seats[seatIdx].number);
                                                                                }
                                                                                
                                                                                // Update active table order with remaining items
                                                                                 if (existingOrder != null) {
                                                                                     final upSub = currentOrderItems.fold(0.0, (s, i) => s + (i.item.price * i.quantity));
                                                                                     final updatedOrder = existingOrder!.copyWith(
                                                                                        items: currentOrderItems, 
                                                                                        total: upSub * (1 + tax)
                                                                                     );
                                                                                     await dashboardProvider.updateOrder(updatedOrder);
                                                                                 }
                                                                             }
                                                                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cash Payment Received: ₹${totalBill.toStringAsFixed(2)}")));
                                                                          },
                                                                        icon: const Icon(Icons.money),
                                                                        label: Text(AppLocalizations.t(context, 'CASH'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                                         style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: AppColors.surfaceLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm), elevation: 0),
                                                                     ),
                                                                  ),
                                                                  const SizedBox(width: AppSpacing.sm),
                                                                  Expanded(
                                                                     child: ElevatedButton.icon(
                                                                        onPressed: () async {
                                                                           // PROCESS UPI PAYMENT
                                                                           if (currentOrderItems.isEmpty) return;
                                                                           
                                                                           List<OrderItem> itemsToBill;
                                                                           List<int> billedSeatNumbers = [];
                                                                           
                                                                           if (billSelectedSeats.isNotEmpty) {
                                                                              itemsToBill = currentOrderItems.where((i) => i.seatIndex != null && billSelectedSeats.contains(i.seatIndex)).toList();
                                                                              billedSeatNumbers = billSelectedSeats.map((idx) => table.seats[idx].number).toList()..sort();
                                                                           } else if (selectedSeatIndex != -1) {
                                                                              itemsToBill = currentOrderItems.where((i) => i.seatIndex == selectedSeatIndex).toList();
                                                                              billedSeatNumbers = [table.seats[selectedSeatIndex!].number];
                                                                           } else {
                                                                              itemsToBill = List.from(currentOrderItems);
                                                                              billedSeatNumbers = currentOrderItems.where((i) => i.seatIndex != null).map((i) => table.seats[i.seatIndex!].number).toSet().toList()..sort();
                                                                           }
                                                                           
                                                                           if (itemsToBill.isEmpty) {
                                                                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'No items for selected seat(s)'))));
                                                                               return;
                                                                           }

                                                                           final sub = itemsToBill.fold(0.0, (s, i) => s + (i.item.price * i.quantity));
                                                                           final tax = (dashboardProvider.activeStore?.isTaxEnabled ?? false) ? ((dashboardProvider.activeStore?.taxRate ?? 0) / 100) : 0.0;
                                                                           final totalBill = sub * (1 + tax);

                                                                           final order = OrderModel(
                                                                              id: dashboardProvider.syncService.generateUniqueId('ORD'),
                                                                              storeId: dashboardProvider.activeStoreId!,
                                                                              items: itemsToBill,
                                                                              total: totalBill,
                                                                              date: DateTime.now(),
                                                                              status: 'Completed',
                                                                              type: 'Dine-In',
                                                                              paymentMethod: 'UPI',
                                                                              tableId: table.id,
                                                                              tableName: table.name,
                                                                              seatNumbers: billedSeatNumbers,
                                                                              taxRateSnapshot: tax * 100,
                                                                           );

                                                                           await dashboardProvider.placeOrder(order);
                                                                           
                                                                           // Print Receipt
                                                                           await PrinterManagerService().printOrderReceipt(order, dashboardProvider.activeStore, cashierName: dashboardProvider.userProfile?.name ?? "Cashier");

                                                                           final targetSeats = billSelectedSeats.isNotEmpty ? List<int>.from(billSelectedSeats) : (selectedSeatIndex != -1 ? [selectedSeatIndex!] : []);

                                                                           setDialogState(() {
                                                                              if (billSelectedSeats.isNotEmpty) {
                                                                                 currentOrderItems.removeWhere((i) => i.seatIndex != null && billSelectedSeats.contains(i.seatIndex));
                                                                              } else if (selectedSeatIndex == -1) {
                                                                                 currentOrderItems.clear();
                                                                              } else {
                                                                                 currentOrderItems.removeWhere((i) => i.seatIndex == selectedSeatIndex);
                                                                              }
                                                                              billSelectedSeats.clear();
                                                                           });

                                                                           if (currentOrderItems.isEmpty) {
                                                                              await tableProvider.clearTable(table.id);
                                                                              Navigator.pop(ctx);
                                                                           } else {
                                                                               // Update seats status
                                                                               for (var seatIdx in targetSeats) {
                                                                                   await tableProvider.clearSeat(table.id, table.seats[seatIdx].number);
                                                                               }
                                                                                
                                                                               // Update active table order with remaining items
                                                                               if (existingOrder != null) {
                                                                                   final upSub = currentOrderItems.fold(0.0, (s, i) => s + (i.item.price * i.quantity));
                                                                                    final updatedOrder = existingOrder!.copyWith(
                                                                                      items: currentOrderItems, 
                                                                                      total: upSub * (1 + tax)
                                                                                   );
                                                                                   await dashboardProvider.updateOrder(updatedOrder);
                                                                               }
                                                                            }
                                                                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("UPI Payment Received: ₹${totalBill.toStringAsFixed(2)}")));
                                                                        },
                                                                        icon: const Icon(Icons.qr_code_scanner),
                                                                        label: Text(AppLocalizations.t(context, 'UPI'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                                         style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: AppColors.surfaceLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm), elevation: 0),
                                                                     ),
                                                                  ),
                                                               ],
                                                            ),
                                                            const SizedBox(height: AppSpacing.md),
                                                            Row(
                                                               children: [
                                                                  Expanded(
                                                                     child: OutlinedButton.icon(
                                                                        onPressed: () async {
                                                                            // PRINT KOT
                                                                            List<OrderItem> itemsToPrint;
                                                                            List<int> kotSeatNumbers = [];
                                                                            
                                                                            if (billSelectedSeats.isNotEmpty) {
                                                                               itemsToPrint = currentOrderItems.where((i) => i.seatIndex != null && billSelectedSeats.contains(i.seatIndex)).toList();
                                                                               kotSeatNumbers = billSelectedSeats.map((idx) => table.seats[idx].number).toList()..sort();
                                                                            } else if (selectedSeatIndex != -1) {
                                                                               itemsToPrint = currentOrderItems.where((i) => i.seatIndex == selectedSeatIndex).toList();
                                                                               kotSeatNumbers = [table.seats[selectedSeatIndex!].number];
                                                                            } else {
                                                                               itemsToPrint = List.from(currentOrderItems);
                                                                               kotSeatNumbers = currentOrderItems.where((i) => i.seatIndex != null).map((i) => table.seats[i.seatIndex!].number).toSet().toList()..sort();
                                                                            }
                                                                            
                                                                            if (itemsToPrint.isEmpty) return;

                                                                            await PrinterManagerService().printOrderKDS(
                                                                               OrderModel(
                                                                                  id: existingOrder?.id ?? "KOT-${DateTime.now().millisecondsSinceEpoch}",
                                                                                  storeId: dashboardProvider.activeStoreId!,
                                                                                  items: itemsToPrint,
                                                                                  total: 0,
                                                                                  date: DateTime.now(),
                                                                                  status: 'New',
                                                                                  type: 'Dine-In',
                                                                                  paymentMethod: 'Pending',
                                                                                  tableName: table.name,
                                                                                  tableId: table.id,
                                                                                  seatNumbers: kotSeatNumbers,
                                                                               ),
                                                                               store: dashboardProvider.activeStore,
                                                                               billerName: dashboardProvider.userProfile?.name ?? "Server"
                                                                            );
                                                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'KOT Printed'))));
                                                                         },
                                                                        icon: const Icon(Icons.print),
                                                                        label: Text(AppLocalizations.t(context, 'PRINT KOT'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm))
                                                                     ),
                                                                  ),
                                                                  const SizedBox(width: AppSpacing.md),
                                                                  Expanded(
                                                                     child: ElevatedButton.icon(
                                                                        onPressed: () async {
                                                                           if (currentOrderItems.isEmpty) return;

                                                                           // Determine the context for saving (whole table, selected seat, or selected bill seats)
                                                                           List<OrderItem> contextItems;
                                                                           OrderModel? currentContextOrder;
                                                                           List<int> contextSeatNumbers = [];

                                                                           if (billSelectedSeats.isNotEmpty) {
                                                                              contextItems = currentOrderItems.where((i) => i.seatIndex != null && billSelectedSeats.contains(i.seatIndex)).toList();
                                                                              contextSeatNumbers = billSelectedSeats.map((idx) => table.seats[idx].number).toList()..sort();
                                                                              // For billSelectedSeats, we need to find an existing order that matches these seats
                                                                              // This logic might need to be more robust if multiple orders can exist for subsets of seats
                                                                              currentContextOrder = existingOrder; // Simplification, might need more specific lookup
                                                                           } else if (selectedSeatIndex != -1) {
                                                                              contextItems = currentOrderItems.where((i) => i.seatIndex == selectedSeatIndex).toList();
                                                                              contextSeatNumbers = [table.seats[selectedSeatIndex!].number];
                                                                              currentContextOrder = existingOrder?.items.any((item) => item.seatIndex == selectedSeatIndex) == true ? existingOrder : null;
                                                                           } else {
                                                                              contextItems = List.from(currentOrderItems);
                                                                              contextSeatNumbers = currentOrderItems.where((i) => i.seatIndex != null).map((i) => table.seats[i.seatIndex!].number).toSet().toList()..sort();
                                                                              currentContextOrder = existingOrder;
                                                                           }

                                                                           if (contextItems.isEmpty) {
                                                                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'No items to save for the current selection'))));
                                                                               return;
                                                                           }
                                                                           
                                                                            final orderId = currentContextOrder?.id ?? dashboardProvider.syncService.generateUniqueId('ORD');
                                                                           final upSub = contextItems.fold(0.0, (s, i) => s + (i.item.price * i.quantity));
                                                                           final tax = (dashboardProvider.activeStore?.isTaxEnabled ?? false) ? ((dashboardProvider.activeStore?.taxRate ?? 0) / 100) : 0.0;
                                                                           
                                                                           // Create order object with only items from this context
                                                                           final newOrder = OrderModel(
                                                                              id: orderId,
                                                                              storeId: dashboardProvider.activeStoreId!,
                                                                              items: contextItems,
                                                                              total: upSub * (1 + tax),
                                                                              date: DateTime.now(),
                                                                              status: 'New',
                                                                              type: 'Dine-In',
                                                                              paymentMethod: 'Unpaid',
                                                                              tableId: table.id,
                                                                              tableName: table.name,
                                                                              taxRateSnapshot: tax * 100,
                                                                              seatNumbers: contextSeatNumbers.isEmpty ? null : contextSeatNumbers,
                                                                           );
                                                                           
                                                                           if (currentContextOrder == null) {
                                                                              await dashboardProvider.addOrder(newOrder);
                                                                              if (selectedSeatIndex == -1 && billSelectedSeats.isEmpty) { // Whole table
                                                                                 await tableProvider.occupyTable(table.id, orderId);
                                                                              } else if (selectedSeatIndex != -1) { // Single seat
                                                                                 await tableProvider.occupySeat(table.id, table.seats[selectedSeatIndex!].number, orderId);
                                                                               } else if (billSelectedSeats.isNotEmpty) { // Multiple seats
                                                                                  for (var seatIdx in billSelectedSeats) {
                                                                                     await tableProvider.occupySeat(table.id, table.seats[seatIdx].number, orderId);
                                                                                  }
                                                                               }
                                                                           } else {
                                                                              await dashboardProvider.updateOrder(newOrder);
                                                                           }
                                                                           Navigator.pop(ctx);
                                                                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Order Saved & Updated'))));
                                                                        },
                                                                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: AppColors.surfaceLight, padding: const EdgeInsets.symmetric(vertical: 16), shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm), elevation: 0),
                                                                        icon: const Icon(Icons.save),
                                                                        label: Text(AppLocalizations.t(context, 'SAVE & KOT'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                                     ),
                                                                  ),
                                                               ],
                                                            ),
                                                            if (table.status.toLowerCase() == 'occupied') ...[
                                                               const SizedBox(height: AppSpacing.sm),
                                                               TextButton.icon(
                                                                  onPressed: () {
                                                                     showDialog(context: context, builder: (dCtx) => AlertDialog(
                                                                        title: Text(AppLocalizations.t(context, 'Clear Table?')),
                                                                        actions: [
                                                                           TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(AppLocalizations.t(context, 'Cancel'))),
                                                                           TextButton(onPressed: () {
                                                                              tableProvider.clearTable(table.id);
                                                                              Navigator.pop(dCtx);
                                                                              Navigator.pop(ctx);
                                                                           }, child: Text(AppLocalizations.t(context, 'Clear'), style: const TextStyle(color: AppColors.error))),
                                                                        ],
                                                                     ));
                                                                  },
                                                                  icon: const Icon(Icons.cleaning_services, color: AppColors.error, size: 18),
                                                                  label: Text(AppLocalizations.t(context, 'FORCE CLEAR TABLE'), style: const TextStyle(color: AppColors.error, fontSize: 12)),
                                                               )
                                                            ]
                                                         ],
                                                      ),
                                                   ),
                                                ],
                                             )
                                           ],
                                        ),
                                    )
                                 ],
                              ),
                        );
                        
                        final menuPanel = Container(
                           color: Theme.of(context).scaffoldBackgroundColor,
                           child: Column(
                              children: [
                                 // Search
                                 Container(
                                    color: Theme.of(context).cardColor,
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    child: TextField(
                                       decoration: InputDecoration(
                                          hintText: "Search Menu...",
                                          prefixIcon: const Icon(Icons.search),
                                          filled: true,
                                          fillColor: Theme.of(context).scaffoldBackgroundColor,
                                          border: OutlineInputBorder(borderRadius: AppRadius.borderSm, borderSide: BorderSide.none),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14)
                                       ),
                                       onChanged: (val) => setDialogState(() => searchQuery = val),
                                    ),
                                 ),
                                 
                                 // CATEGORY FILTERS (NEW)
                                 Container(
                                    color: Theme.of(context).cardColor,
                                    width: double.infinity,
                                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                    child: SizedBox(
                                       height: 40,
                                       child: ListView.separated(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                          scrollDirection: Axis.horizontal,
                                          itemCount: categories.length,
                                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                                          itemBuilder: (c, i) {
                                             final cat = categories[i];
                                             final isSel = selectedCategory == cat;
                                             return ChoiceChip(
                                                label: Text(cat),
                                                selected: isSel,
                                                onSelected: (val) => setDialogState(() => selectedCategory = cat),
                                                selectedColor: Theme.of(context).primaryColor,
                                                showCheckmark: false,
                                                labelStyle: TextStyle(color: isSel ? AppColors.surfaceLight : Theme.of(context).textTheme.bodyMedium?.color, fontWeight: isSel ? FontWeight.bold : FontWeight.w500),
                                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
                                                side: BorderSide(color: isSel ? AppColors.transparent : Theme.of(context).dividerColor),
                                             );
                                          },
                                       ),
                                    ),
                                 ),
                                 
                                 // Grid
                                 Expanded(
                                    child: GridView.builder(
                                       padding: const EdgeInsets.all(AppSpacing.lg),
                                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3, 
                                          childAspectRatio: 0.85,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16
                                       ),
                                       itemCount: filteredMenu.length,
                                       itemBuilder: (c, i) {
                                          final item = filteredMenu[i];
                                          // Check if in cart locally
                                          final inCartCount = currentOrderItems.where((x) => x.item.id == item.id).fold(0, (sum, x) => sum + x.quantity);
                                          
                                          return InkWell(
                                             onTap: () {
                                                setDialogState(() {
                                                   // Check if item exists (matching ID AND Seat)
                                                   // If seat is selected, we only group with same seat items
                                                   final idx = currentOrderItems.indexWhere((x) => 
                                                      x.item.id == item.id && x.seatIndex == selectedSeatIndex
                                                   );
                                                   
                                                   if (idx != -1) {
                                                       currentOrderItems[idx] = currentOrderItems[idx].copyWith(
                                                          quantity: currentOrderItems[idx].quantity + 1,
                                                       );
                                                    } else {
                                                       currentOrderItems.add(OrderItem(
                                                          item: item, 
                                                          quantity: 1,
                                                          seatIndex: selectedSeatIndex == -1 ? null : selectedSeatIndex
                                                       ));
                                                    }
                                                });
                                             },
                                             borderRadius: AppRadius.borderMd,
                                             child: Container(
                                                decoration: BoxDecoration(
                                                   color: Theme.of(context).cardColor,
                                                   borderRadius: AppRadius.borderMd,
                                                   border: Border.all(color: inCartCount > 0 ? Theme.of(context).primaryColor : Theme.of(context).dividerColor.withValues(alpha: 0.5), width: inCartCount > 0 ? 2 : 1),
                                                   boxShadow: [BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))]
                                                ),
                                                child: Column(
                                                   crossAxisAlignment: CrossAxisAlignment.stretch,
                                                   children: [
                                                      Expanded(
                                                         child: Container(
                                                            decoration: BoxDecoration(
                                                               color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                                                               borderRadius: const BorderRadius.vertical(top: Radius.circular(14))
                                                            ),
                                                            child: Icon(Icons.fastfood, size: 40, color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
                                                         ),
                                                      ),
                                                      Padding(
                                                         padding: const EdgeInsets.all(AppSpacing.md),
                                                         child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                               Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                               const SizedBox(height: AppSpacing.xs),
                                                               Row(
                                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                  children: [
                                                                     Text("₹${item.price.toStringAsFixed(2)}", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                                     if (inCartCount > 0) 
                                                                        CircleAvatar(radius: 12, backgroundColor: Theme.of(context).primaryColor, child: Text("$inCartCount", style: const TextStyle(color: AppColors.surfaceLight, fontSize: 11, fontWeight: FontWeight.bold)))
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

                        if (isMobile) {
                           return DefaultTabController(
                              length: 2,
                              child: Column(
                                 children: [
                                    Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                          Padding(
                                             padding: const EdgeInsets.only(left: AppSpacing.md),
                                             child: Text(AppLocalizations.t(context, 'Quick Order'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          ),
                                          IconButton(
                                             icon: const Icon(Icons.close),
                                             onPressed: () => Navigator.pop(ctx),
                                          ),
                                       ]
                                    ),
                                    TabBar(
                                                                      labelColor: Theme.of(context).textTheme.bodyLarge?.color,
                                       indicatorColor: AppColors.primaryLight,
                                       tabs: const [Tab(text: "Menu"), Tab(text: "Current Order")]
                                    ),
                                    Expanded(
                                       child: TabBarView(
                                          children: [
                                             menuPanel,
                                             orderPanel,
                                          ]
                                       )
                                    )
                                 ]
                              )
                           );
                        }

                        // Desktop Layout
                        return Row(
                           children: [
                              Expanded(flex: 2, child: orderPanel),
                              Expanded(flex: 3, child: menuPanel),
                              Container(
                                 width: 50,
                                 alignment: Alignment.topCenter,
                                 padding: const EdgeInsets.only(top: AppSpacing.md),
                                 child: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.pop(ctx),
                                 ),
                              )
                           ],
                        );
                     }
                  ),
               ),
            );
         }
      ));
  }
  
  void _showBookTableDialog(String? preSelectedTableId) {
      final provider = Provider.of<TableProvider>(context, listen: false);
      final tables = provider.tables; 
      
      String? selectedTable = preSelectedTableId;
      DateTime selectedDate = DateTime.now();
      TimeOfDay selectedTime = TimeOfDay.now();
      int numberOfSeats = 1;
      
      // If table is pre-selected, set initial seats
      if (selectedTable != null) {
         final t = tables.where((x) => x.id == selectedTable).firstOrNull ?? (tables.isNotEmpty ? tables.firstOrNull : null);
         if (t != null) numberOfSeats = t.seats.length;
      }
      
      showDialog(context: context, builder: (ctx) => StatefulBuilder(
         builder: (context, setDialogState) {
            final t = selectedTable != null ? tables.where((t) => t.id == selectedTable).firstOrNull : null;
            final maxSeats = t?.seats.length ?? 1;
            
            return AlertDialog(
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
              title: Text(AppLocalizations.t(context, 'Book a Table'), style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                 width: 400,
                 child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(AppLocalizations.t(context, 'Table'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                       const SizedBox(height: AppSpacing.sm),
                       DropdownButtonFormField<String>(
                          value: selectedTable,
                          decoration: const InputDecoration(
                             border: OutlineInputBorder(borderRadius: AppRadius.borderMd),
                             contentPadding: EdgeInsets.symmetric(horizontal: 12),
                             hintText: "Select a table"
                          ),
                          items: tables.map((t) {
                             final isDuplicate = tables.where((other) => other.name == t.name && other.floorId != t.floorId).isNotEmpty;
                             String displayName = t.name;
                             if (isDuplicate) {
                                final floor = provider.floors.where((f) => f.id == t.floorId).firstOrNull ?? Floor(id: '', storeId: '', name: 'Unknown');
                                displayName = "$displayName (${floor.name})";
                             }
                             return DropdownMenuItem(
                                value: t.id, 
                                child: Text("$displayName (${t.seats.length} seats)")
                             );
                          }).toList(),
                          onChanged: (val) {
                             if (val != null) {
                                final t = tables.where((x) => x.id == val).firstOrNull;
                                if (t != null) {
                                   setDialogState(() {
                                      selectedTable = val;
                                      numberOfSeats = t.seats.length; // Default to max seats
                                   });
                                }
                             }
                          },
                       ),
                       const SizedBox(height: AppSpacing.md),
                       
                       Text(AppLocalizations.t(context, 'Number of Seats'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                       const SizedBox(height: AppSpacing.sm),
                       Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.xs),
                          decoration: BoxDecoration(border: Border.all(color: AppColors.textSecondary(context)), borderRadius: AppRadius.borderSm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline), 
                                onPressed: selectedTable == null || numberOfSeats <= 1 ? null : () {
                                  setDialogState(() => numberOfSeats--);
                                }
                              ),
                              Text("$numberOfSeats", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline), 
                                onPressed: selectedTable == null || numberOfSeats >= maxSeats ? null : () {
                                  setDialogState(() => numberOfSeats++);
                                }
                              ),
                            ],
                          ),
                       ),
                       const SizedBox(height: AppSpacing.md),
                       
                       Text(AppLocalizations.t(context, 'Date'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                       const SizedBox(height: AppSpacing.sm),
                       InkWell(
                          onTap: () async {
                             final picked = await showDatePicker(
                                context: context, 
                                initialDate: selectedDate, 
                                firstDate: DateTime.now(), 
                                lastDate: DateTime.now().add(const Duration(days: 365))
                             );
                             if (picked != null) setDialogState(() => selectedDate = picked);
                          },
                          child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                             decoration: BoxDecoration(
                                border: Border.all(color: AppColors.textSecondary(context)), 
                                borderRadius: AppRadius.borderSm
                             ),
                             child: Row(
                                children: [
                                   const Icon(Icons.calendar_today, size: 16),
                                   const SizedBox(width: AppSpacing.sm),
                                   Text("${selectedDate.day}/${selectedDate.month}/${selectedDate.year}")
                                ],
                             ),
                          ),
                       ),
                       const SizedBox(height: AppSpacing.md),
                       
                       Text(AppLocalizations.t(context, 'Time'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                       const SizedBox(height: AppSpacing.sm),
                       InkWell(
                          onTap: () async {
                             final picked = await showTimePicker(context: context, initialTime: selectedTime);
                             if (picked != null) setDialogState(() => selectedTime = picked);
                          },
                          child: Container(
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                             decoration: BoxDecoration(
                                border: Border.all(color: AppColors.textSecondary(context)), 
                                borderRadius: AppRadius.borderSm
                             ),
                             child: Row(
                                children: [
                                   const Icon(Icons.access_time, size: 16),
                                   const SizedBox(width: AppSpacing.sm),
                                   Text(selectedTime.format(context))
                                ],
                             ),
                          ),
                       ),
                       const SizedBox(height: AppSpacing.lg),
                       
                       SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                             onPressed: selectedTable == null ? null : () {
                                final provider = Provider.of<TableProvider>(context, listen: false);
                                final t = tables.where((t) => t.id == selectedTable).firstOrNull; if (t == null) return; final table = t;

                                // Validation: Prevent double booking for overlapping times
                                final statusLower = table.status.toLowerCase();
                                final newBookedTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                                
                                if (statusLower == 'reserved' || statusLower == 'booked') {
                                   if (table.bookedTime != null) {
                                      // Check if new booking is within 2 hours of the existing booking
                                      final difference = table.bookedTime!.difference(newBookedTime).inMinutes.abs();
                                      if (difference < 120) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                             content: Text(AppLocalizations.t(context, 'Table is already booked around this time. Please choose a different time or table.')), 
                                             backgroundColor: AppColors.error
                                          ));
                                          return;
                                      }
                                   } else {
                                      // Legacy format or manual override reserving
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                         content: Text(AppLocalizations.t(context, 'Table is already booked. Clear existing booking first.')), 
                                         backgroundColor: AppColors.error
                                      ));
                                      return;
                                   }
                                }

                                provider.bookTable(selectedTable!, selectedDate, selectedTime, numberOfSeats);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.t(context, 'Table Marked as Reserved'))));
                             },
                             style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd)
                             ),
                             child: Text(AppLocalizations.t(context, 'Book Table')),
                          ),
                       )
                    ],
                 ),
              ),
            );
         }
      ));
  }


  // --- ACTIONS ---
  
  void _updateTable(TableModel table, {String? name, String? billingMode, int? seats, TablePosition? position}) {
     final provider = Provider.of<TableProvider>(context, listen: false);
     
     List<TableSeat> newSeats = table.seats;
     if (seats != null) {
        if (seats > table.seats.length) {
           // Add
           for (int i = table.seats.length; i < seats; i++) {
              newSeats.add(TableSeat(number: i + 1));
           }
        } else {
           // Remove
           newSeats = table.seats.sublist(0, seats);
        }
     }

     final updated = TableModel(
        id: table.id,
        storeId: table.storeId,
        floorId: table.floorId,
        name: name ?? table.name,
        seats: newSeats, // If unchanged, list ref is same but it's final so ok
        shape: table.shape,
        position: position ?? table.position,
        rotation: table.rotation,
        status: table.status,
        orderId: table.orderId,
        billingMode: billingMode ?? table.billingMode
     );
     
     provider.updateTable(updated);
  }

  void _addTable(String shape) {
     if (_selectedFloorId == null) return;
     final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
     final tableProvider = Provider.of<TableProvider>(context, listen: false);
     
     // Smart Name Generation
     final floorTables = tableProvider.tables.where((t) => t.floorId == _selectedFloorId).toList();
     int nextNum = 1;
     // Find first available gap or number
     while (floorTables.any((t) => t.name.toUpperCase() == "T$nextNum")) {
        nextNum++;
     }
     
     final newId = const Uuid().v4();
     
     final newTable = TableModel(
        id: newId,
        storeId: dashboardProvider.activeStoreId!,
        floorId: _selectedFloorId!,
        name: "T$nextNum",
        seats: List.generate(4, (i) => TableSeat(number: i + 1)),
        shape: shape,
         position: _findNextOpenGridPosition(),
        rotation: 0,
        status: 'Available',
        billingMode: 'per-table'
     );
     
     tableProvider.addTable(newTable);
  }

  void _showAddFloorDialog() {
     final controller = TextEditingController();
     showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'New Floor')),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: "E.g. Ground Floor")),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
           TextButton(onPressed: () {
              if (controller.text.isNotEmpty) {
                 final dashboardProvider = Provider.of<DashboardProvider>(context, listen: false);
                 final tableProvider = Provider.of<TableProvider>(context, listen: false);
                 final newFloor = Floor(
                    id: const Uuid().v4(),
                    storeId: dashboardProvider.activeStoreId!,
                    name: controller.text.trim()
                 );
                 tableProvider.addFloor(newFloor);
                 setState(() => _selectedFloorId = newFloor.id); // Auto switch
                 Navigator.pop(ctx);
              }
           }, child: Text(AppLocalizations.t(context, 'Create'))),
        ],
     ));
  }
  
   void _showEditFloorDialog(Floor floor) {
      final controller = TextEditingController(text: floor.name);
      showDialog(context: context, builder: (ctx) => AlertDialog(
         title: Text(AppLocalizations.t(context, 'Rename Floor')),
         content: TextField(controller: controller),
         actions: [
            TextButton(
               onPressed: () {
                  Navigator.pop(ctx);
                  _deleteFloor(floor.id);
               }, 
               style: TextButton.styleFrom(foregroundColor: AppColors.error),
               child: Text(AppLocalizations.t(context, 'Delete Floor'))
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
            TextButton(onPressed: () {
               if (controller.text.isNotEmpty) {
                  final provider = Provider.of<TableProvider>(context, listen: false);
                  provider.updateFloor(Floor(id: floor.id, storeId: floor.storeId, name: controller.text.trim()));
                  Navigator.pop(ctx);
               }
            }, child: Text(AppLocalizations.t(context, 'Save'))),
         ],
      ));
   }
  
  void _deleteFloor(String floorId) {
     showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.t(context, 'Delete Floor?')),
        content: Text(AppLocalizations.t(context, 'This will hide all tables on this floor. Are you sure?')),
        actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.t(context, 'Cancel'))),
           TextButton(onPressed: () {
              final provider = Provider.of<TableProvider>(context, listen: false);
              provider.deleteFloor(floorId);
              setState(() {
                 if (_selectedFloorId == floorId) _selectedFloorId = null;
              });
              Navigator.pop(ctx);
           }, style: TextButton.styleFrom(foregroundColor: AppColors.error), child: Text(AppLocalizations.t(context, 'Delete'))),
        ],
     ));
  }
}

class _AddTableButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  
  const _AddTableButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
              Icon(icon, size: 30, color: AppColors.primaryLight),
              Text(label, style: const TextStyle(fontSize: 12))
           ],
        ),
      ),
    );
  }
}

// Helper needed for Math


class _PulsingChair extends StatefulWidget {
  final double size;
  final bool isOccupied;
  final bool shouldAnimate; // If true, animate
  final bool isTableOccupied; // Adjust colors based on table status

  const _PulsingChair({
    required this.size,
    required this.isOccupied,
    required this.shouldAnimate,
    required this.isTableOccupied,
  });

  @override
  _PulsingChairState createState() => _PulsingChairState();
}

class _PulsingChairState extends State<_PulsingChair> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 1500),
    );
    
    _updateColorTween();

    if (widget.shouldAnimate) {
       _controller.repeat();
    }
  }

  void _updateColorTween() {
     if (widget.isTableOccupied) {
        _colorAnimation = ColorTween(
           begin: AppColors.error, 
           end: AppColors.error
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
     } else {
        _colorAnimation = ColorTween(
           begin: AppColors.warning, 
           end: AppColors.warning
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
     }
  }

  @override
  void didUpdateWidget(_PulsingChair oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isTableOccupied != oldWidget.isTableOccupied) {
       _updateColorTween();
    }
    
    if (widget.shouldAnimate && !oldWidget.shouldAnimate) {
       _controller.repeat();
    } else if (!widget.shouldAnimate && oldWidget.shouldAnimate) {
       _controller.stop();
       _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildRipple(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double value = (_controller.value + delay) % 1.0;
        // Scale grows from 1.0 to 2.5
        double scale = 1.0 + (value * 1.5); 
        // Opacity fades out from 0.8 to 0.0
        double opacity = 0.8 * (1.0 - value);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: (_colorAnimation.value ?? AppColors.warning).withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldAnimate) {
       return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
             color: widget.isOccupied ? AppColors.error : Theme.of(context).dividerColor.withValues(alpha: 0.5),
             shape: BoxShape.circle,
             border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.5),
             boxShadow: [
               BoxShadow(
                 color: AppColors.textPrimaryLight.withValues(alpha: 0.05),
                 blurRadius: 4,
                 offset: const Offset(0, 2),
               )
             ]
          ),
       );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ripple 1
        _buildRipple(0.0),
        // Ripple 2 (delayed)
        _buildRipple(0.5),
        // Core Center Dot
        AnimatedBuilder(
           animation: _controller,
           builder: (context, child) {
              // Add a slight pulse to the core dot itself for extra visual pop
              double coreScale = 1.0 + (_controller.value * 0.1);
              return Transform.scale(
                scale: coreScale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                     color: _colorAnimation.value,
                     shape: BoxShape.circle,
                     border: Border.all(color: AppColors.surfaceLight, width: 2.0),
                     boxShadow: [
                       BoxShadow(
                         color: (_colorAnimation.value ?? AppColors.error).withValues(alpha: 0.5), 
                         blurRadius: 4, 
                         spreadRadius: 1
                       )
                     ]
                  ),
                ),
              );
           },
        )
      ],
    );
  }
}

/// Paints subtle grid lines on the table canvas to guide placement.
class _GridPainter extends CustomPainter {
  final double cellWidth;
  final double cellHeight;
  final double padding;
  final Color color;

  _GridPainter({
    required this.cellWidth,
    required this.cellHeight,
    required this.padding,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = padding; x < size.width; x += cellWidth) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = padding; y < size.height; y += cellHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw small dot at each intersection for extra visual clarity
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    for (double x = padding; x < size.width; x += cellWidth) {
      for (double y = padding; y < size.height; y += cellHeight) {
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.cellHeight != cellHeight ||
      oldDelegate.color != color;
}




