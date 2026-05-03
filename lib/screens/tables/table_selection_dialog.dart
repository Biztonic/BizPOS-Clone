import '../../core/design/tokens/app_colors.dart';

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/table_provider.dart';
import '../../models/table_model.dart';

class TableSelectionDialog extends StatefulWidget {
  const TableSelectionDialog({super.key});

  @override
  State<TableSelectionDialog> createState() => _TableSelectionDialogState();
}

class _TableSelectionDialogState extends State<TableSelectionDialog> {
  String? _selectedFloorId;
  String? _selectedTableId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TableProvider>(context, listen: false);
      if (provider.floors.isNotEmpty) {
        setState(() => _selectedFloorId = provider.floors.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final tableProvider = Provider.of<TableProvider>(context);
    final floors = tableProvider.floors;
    final floorTables = tableProvider.tables.where((t) => t.floorId == _selectedFloorId).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 900,
            height: 700,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.85 * 255).toInt()),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withAlpha((0.3 * 255).toInt()), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.15 * 255).toInt()),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.textSecondary(context).withAlpha((0.1 * 255).toInt()))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Select Table",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Choose an available table to begin",
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.textSecondary(context),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Row(
                    children: [
                      // Floors Sidebar
                      Container(
                        width: 220,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary(context).withAlpha((0.05 * 255).toInt()),
                          border: Border(right: BorderSide(color: AppColors.textSecondary(context).withAlpha((0.1 * 255).toInt()))),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: floors.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final floor = floors[index];
                            final isSelected = floor.id == _selectedFloorId;
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() {
                                _selectedFloorId = floor.id;
                                _selectedTableId = null;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryLight : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primaryLight.withAlpha((0.3 * 255).toInt()),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.layers_outlined,
                                      size: 18,
                                      color: isSelected ? Colors.white : AppColors.textSecondary(context),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      floor.name,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? Colors.white : AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Tables Canvas area
                      Expanded(
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 1.2,
                              colors: [
                                Colors.white,
                                AppColors.textSecondary(context),
                                AppColors.textSecondary(context),
                              ],
                            ),
                          ),
                          child: InteractiveViewer(
                            boundaryMargin: const EdgeInsets.all(100),
                            minScale: 0.5,
                            maxScale: 2.0,
                            child: Stack(
                              children: floorTables.map((t) => _buildTableItem(t)).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.textSecondary(context).withAlpha((0.1 * 255).toInt()))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Cancel",
                          style: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E1E1E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _selectedTableId != null
                            ? () {
                                final table = tableProvider.tables.firstWhere((t) => t.id == _selectedTableId);
                                Navigator.pop(context, table);
                              }
                            : null,
                        child: const Text("Confirm Selection", style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableItem(TableModel table) {
    final isSelected = _selectedTableId == table.id;
    final isOccupied = table.status == 'Occupied';
    final isReserved = table.status == 'Reserved';

    Color baseColor;
    if (isOccupied) {
      baseColor = const Color(0xFFEF4444); // Red
    } else if (isReserved) {
      baseColor = const Color(0xFFF59E0B); // Amber
    } else {
      baseColor = const Color(0xFF10B981); // Emerald
    }

    if (isSelected) baseColor = AppColors.primaryLight;

    final size = table.shape == 'rectangular' ? const Size(120, 80) : const Size(90, 90);

    return Positioned(
      left: table.position.x,
      top: table.position.y,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTableId = table.id);
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withAlpha((isSelected ? 1.0 : 0.8 * 255).toInt()),
                  baseColor.withAlpha((isSelected ? 0.8 : 0.6 * 255).toInt()),
                ],
              ),
              borderRadius: table.shape == 'rectangular' || table.shape == 'square'
                  ? BorderRadius.circular(16)
                  : BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withAlpha((0.3 * 255).toInt()),
                  blurRadius: isSelected ? 15 : 8,
                  offset: const Offset(0, 4),
                  spreadRadius: isSelected ? 2 : 0,
                ),
                if (isSelected)
                  BoxShadow(
                    color: AppColors.primaryLight.withAlpha((0.5 * 255).toInt()),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
              ],
              border: Border.all(
                color: isSelected ? Colors.white : baseColor.withAlpha((0.2 * 255).toInt()),
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Stack(
              children: [
                // Gloss effect
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: size.height * 0.4,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withAlpha((0.2 * 255).toInt()),
                          Colors.white.withAlpha(0),
                        ],
                      ),
                      borderRadius: table.shape == 'rectangular' || table.shape == 'square'
                          ? const BorderRadius.vertical(top: Radius.circular(16))
                          : const BorderRadius.vertical(top: Radius.circular(100)),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        table.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha((0.1 * 255).toInt()),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          table.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
