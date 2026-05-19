import 'package:biztonic_pos/core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_radius.dart';
import 'package:biztonic_pos/l10n/app_localizations.dart';

import '../../core/design/design_system.dart';
import '../../core/design/components/atoms/app_button.dart';


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
      backgroundColor: AppColors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ClipRRect(
        borderRadius: AppRadius.borderLg,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 900,
            height: 700,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withAlpha((0.85 * 255).toInt()),
              borderRadius: AppRadius.borderLg,
              border: Border.all(color: AppColors.surfaceLight.withAlpha((0.3 * 255).toInt()), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimaryLight.withAlpha((0.15 * 255).toInt()),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.textSecondary(context).withAlpha((0.1 * 255).toInt()))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.t(context, 'Select Table'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(AppLocalizations.t(context, 'Choose an available table to begin'),
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
                          padding: const EdgeInsets.all(AppSpacing.md),
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
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: floors.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final floor = floors[index];
                            final isSelected = floor.id == _selectedFloorId;
                            return InkWell(
                              borderRadius: AppRadius.borderMd,
                              onTap: () => setState(() {
                                _selectedFloorId = floor.id;
                                _selectedTableId = null;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryLight : AppColors.transparent,
                                  borderRadius: AppRadius.borderMd,
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
                                      color: isSelected ? AppColors.surfaceLight : AppColors.textSecondary(context),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Text(
                                      floor.name,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? AppColors.surfaceLight : AppColors.textSecondary(context),
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
                                AppColors.surfaceLight,
                                AppColors.textSecondary(context),
                                AppColors.textSecondary(context),
                              ],
                            ),
                          ),
                          child: InteractiveViewer(
                            boundaryMargin: const EdgeInsets.all(AppSpacing.xl),
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
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    border: Border(top: BorderSide(color: AppColors.textSecondary(context).withAlpha((0.1 * 255).toInt()))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppButton.ghost(
                        label: AppLocalizations.t(context, 'Cancel'),
                        onPressed: () => Navigator.pop(context),
                        foregroundColor: AppColors.textSecondary(context),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppButton(
                        label: AppLocalizations.t(context, 'Confirm Selection'),
                        onPressed: _selectedTableId != null
                            ? () {
                                final table = tableProvider.tables.firstWhere((t) => t.id == _selectedTableId);
                                Navigator.pop(context, table);
                              }
                            : null,
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
                  ? AppRadius.borderMd
                  : AppRadius.borderXl,
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
                color: isSelected ? AppColors.surfaceLight : baseColor.withAlpha((0.2 * 255).toInt()),
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
                          AppColors.surfaceLight.withAlpha((0.2 * 255).toInt()),
                          AppColors.surfaceLight.withAlpha(0),
                        ],
                      ),
                      borderRadius: table.shape == 'rectangular' || table.shape == 'square'
                          ? const BorderRadius.vertical(top: Radius.circular(AppRadius.md))
                          : const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                          color: AppColors.surfaceLight,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          shadows: [Shadow(color: Colors.black26, offset: Offset(0, 1), blurRadius: 2)],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimaryLight.withAlpha((0.1 * 255).toInt()),
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Text(
                          table.status,
                          style: const TextStyle(
                            color: AppColors.surfaceLight,
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




