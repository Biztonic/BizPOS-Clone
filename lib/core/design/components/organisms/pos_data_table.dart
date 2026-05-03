import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:biztonic_pos/core/design/density/app_density.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';
import 'package:biztonic_pos/core/design/tokens/app_typography.dart';

class PosDataColumn {
  final String label;
  final bool numeric;
  final bool sortable;
  final Widget? icon;
  final double? flex; // If using flex layouts
  final double? fixedWidth; // If using fixed layouts

  const PosDataColumn({
    required this.label,
    this.numeric = false,
    this.sortable = false,
    this.icon,
    this.flex,
    this.fixedWidth,
  });
}

class PosDataRow {
  final List<Widget> cells;
  final VoidCallback? onTap;
  final bool selected;
  final ValueKey? key;

  const PosDataRow({
    required this.cells,
    this.onTap,
    this.selected = false,
    this.key,
  });
}

class PosDataTable extends StatefulWidget {
  final List<PosDataColumn> columns;
  final List<PosDataRow> rows;
  final bool isLoading;
  final int? sortColumnIndex;
  final bool sortAscending;
  final Function(int columnIndex, bool ascending)? onSort;
  
  // Pagination
  final int? currentPage;
  final int? totalPages;
  final VoidCallback? onNextPage;
  final VoidCallback? onPreviousPage;

  const PosDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.isLoading = false,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.currentPage,
    this.totalPages,
    this.onNextPage,
    this.onPreviousPage,
  });

  @override
  State<PosDataTable> createState() => _PosDataTableState();
}

class _PosDataTableState extends State<PosDataTable> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  int _focusedRowIndex = -1;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _focusedRowIndex = (_focusedRowIndex + 1).clamp(0, widget.rows.length - 1);
        });
        _scrollToFocusedRow();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _focusedRowIndex = (_focusedRowIndex - 1).clamp(0, widget.rows.length - 1);
        });
        _scrollToFocusedRow();
      } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space) {
        if (_focusedRowIndex >= 0 && _focusedRowIndex < widget.rows.length) {
          widget.rows[_focusedRowIndex].onTap?.call();
        }
      }
    }
  }

  void _scrollToFocusedRow() {
    final densityConfig = AppDensityProvider.configOf(context);
    final rowHeight = densityConfig.rowHeight;
    final offset = _focusedRowIndex * rowHeight;
    
    // Simplistic scroll alignment
    if (_verticalController.hasClients) {
      final currentOffset = _verticalController.offset;
      final viewportHeight = _verticalController.position.viewportDimension;
      
      if (offset < currentOffset) {
         _verticalController.animateTo(offset, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
      } else if (offset + rowHeight > currentOffset + viewportHeight) {
         _verticalController.animateTo((offset + rowHeight) - viewportHeight, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final densityConfig = AppDensityProvider.configOf(context);
    final theme = Theme.of(context);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sticky Header
          Container(
            height: densityConfig.rowHeight,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Scrollbar(
              controller: _horizontalController,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(), // Prevent bounce on header
                child: Row(
                  children: List.generate(widget.columns.length, (index) {
                    final col = widget.columns[index];
                    return _buildHeaderCell(col, index, densityConfig, theme);
                  }),
                ),
              ),
            ),
          ),
          
          // Body
          Expanded(
            child: widget.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : widget.rows.isEmpty 
                ? Center(child: Text('No data available', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)))
                : Scrollbar(
                  controller: _verticalController,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    child: SingleChildScrollView(
                      // Sync horizontal scroll with header if needed, but Flutter's native DataTable handles this better internally. 
                      // For this custom implementation, we'll keep it simple or require fixed flex columns.
                      // Note: In a true enterprise grid, you'd use a synchronized horizontal scroll or flex layouts.
                      // For POS, Flex layout is preferred so it always fills the screen width without horizontal scroll.
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: List.generate(widget.rows.length, (index) {
                          final row = widget.rows[index];
                          final isFocused = _focusedRowIndex == index;
                          return _buildRow(row, index, isFocused, densityConfig, theme);
                        }),
                      ),
                    ),
                  ),
                ),
          ),

          // Pagination Footer
          if (widget.totalPages != null && widget.totalPages! > 1)
            _buildPaginationFooter(densityConfig, theme),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(PosDataColumn col, int index, DensityConfig densityConfig, ThemeData theme) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: col.numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (col.icon != null) ...[col.icon!, const SizedBox(width: AppSpacing.xs)],
        Text(
          col.label,
          style: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (col.sortable) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(
            widget.sortColumnIndex == index
              ? (widget.sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
              : Icons.sort,
            size: 16,
            color: widget.sortColumnIndex == index ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ]
      ],
    );

    if (col.sortable) {
      content = InkWell(
        onTap: () {
           if (widget.onSort != null) {
              final isAscending = widget.sortColumnIndex == index ? !widget.sortAscending : true;
              widget.onSort!(index, isAscending);
           }
        },
        child: Padding(
          padding: densityConfig.contentPadding,
          child: content,
        ),
      );
    } else {
      content = Padding(
        padding: densityConfig.contentPadding,
        child: content,
      );
    }

    return SizedBox(
      width: col.fixedWidth ?? 150.0, // Fallback width
      child: content,
    );
  }

  Widget _buildRow(PosDataRow row, int index, bool isFocused, DensityConfig densityConfig, ThemeData theme) {
    return InkWell(
      onTap: () {
        setState(() {
          _focusedRowIndex = index;
        });
        row.onTap?.call();
        _focusNode.requestFocus();
      },
      child: Container(
        height: densityConfig.rowHeight,
        decoration: BoxDecoration(
          color: isFocused 
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5) 
              : (row.selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.2) : null),
          border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: List.generate(row.cells.length, (cellIndex) {
            final col = widget.columns[cellIndex];
            return SizedBox(
              width: col.fixedWidth ?? 150.0,
              child: Padding(
                padding: densityConfig.contentPadding,
                child: Align(
                  alignment: col.numeric ? Alignment.centerRight : Alignment.centerLeft,
                  child: row.cells[cellIndex],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(DensityConfig densityConfig, ThemeData theme) {
    return Container(
      height: densityConfig.buttonHeight + AppSpacing.md,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Page ${widget.currentPage ?? 1} of ${widget.totalPages ?? 1}'),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: widget.onPreviousPage,
            splashRadius: 24,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: widget.onNextPage,
            splashRadius: 24,
          ),
        ],
      ),
    );
  }
}
