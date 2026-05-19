import '../../../core/design/tokens/app_colors.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/settings.dart'; // Import Settings
import '../models/receipt_config.dart';
import '../models/receipt_content.dart';
import '../core/receipt_formatter.dart';

class ReceiptPreviewWidget extends StatelessWidget {
  final ReceiptContent content;
  final ReceiptConfig config;
  final ReceiptSettings settings; // Add settings

  const ReceiptPreviewWidget({
    super.key,
    required this.content,
    required this.config,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    // Physical width approx: 58mm ~ 200-240dp, 80mm ~ 300-350dp
    // We'll scale it to look reasonable on screen.
    // REMOVED fixed width to allow IntrinsicWidth to snap to text content
    
    return Center(
      child: IntrinsicWidth(
        child: Container(
          // width: previewWidth, // REMOVED
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            boxShadow: [
               BoxShadow(color: AppColors.textPrimaryLight.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
            ],
            border: Border.all(color: AppColors.textSecondary(context), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              _buildHeader(content.header),
              
              // 2. Bill Info
              const SizedBox(height: AppSpacing.md),
              _buildBillInfo(content.billInfo),
              
              // 3. Items
              const SizedBox(height: AppSpacing.md),
              _buildItems(content.items),
              
              // 4. Summary
              if (content.summary != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildSummary(content.summary!),
              ],
              
              // 5. Payment
              if (content.payment != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildPayment(content.payment!),
              ],
              
              // 6. Footer
              if (content.footer != null) ...[
                 const SizedBox(height: AppSpacing.md),
                 _buildFooter(content.footer!, context),
              ],
              
              const SizedBox(height: AppSpacing.xxs),
              Center(child: Icon(Icons.cut, color: AppColors.textSecondary(context).withValues(alpha: 0.5), size: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ReceiptHeader header) {
    return Column(
      children: [
         if (header.customMessage != null) Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(header.customMessage!, textAlign: TextAlign.center, style: _styleFrom(settings.prominentStyle)),
        ),
        Text(header.storeName, textAlign: TextAlign.center, style: _styleFrom(settings.prominentStyle)),
        if (header.address != null) Text(header.address!, textAlign: TextAlign.center, style: _styleFrom(settings.regularStyle)),
        if (header.phone != null) Text('Ph: ${header.phone}', textAlign: TextAlign.center, style: _styleFrom(settings.regularStyle)),
        if (header.gstin != null) Text('GSTIN: ${header.gstin}', textAlign: TextAlign.center, style: _styleFrom(settings.regularStyle)),
        _divider(),
      ],
    );
  }

  Widget _buildBillInfo(ReceiptBillInfo info) {
    final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
    final String dateStr = dateFormat.format(info.date);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ReceiptFormatter.pad('Bill No : ${info.billNo}', '', config.charsPerLine), style: _styleFrom(settings.regularStyle)),
        Text(ReceiptFormatter.pad('Date    : $dateStr', '', config.charsPerLine), style: _styleFrom(settings.regularStyle)),
        Text(ReceiptFormatter.pad('Cashier : ${info.cashierName}', '', config.charsPerLine), style: _styleFrom(settings.regularStyle)),
        if (info.tokenNo != null)
          Text(ReceiptFormatter.pad('Token No: ${info.tokenNo}', '', config.charsPerLine), style: _styleFrom(settings.prominentStyle)), // Token is prominent
        _divider(),
      ],
    );
  }

  Widget _buildItems(List<ReceiptItem> items) {
    bool is58mm = config.width == ReceiptWidth.mm58;
    
    // Ratios based on 80mm (48 chars) vs 58mm (32 chars) logic
    // 80mm: Qty 4, Rate 7, Amt 10 -> Total 21. Item ~27.
    // 58mm: Qty 4, Amt 9 -> Total 13. Item ~19.
    
    Map<int, TableColumnWidth> colWidths = is58mm 
      ? {
          0: const FlexColumnWidth(19), // Item
          1: const FlexColumnWidth(4),  // Qty
          2: const FlexColumnWidth(9),  // Amt
        }
      : {
          0: const FlexColumnWidth(27), // Item
          1: const FlexColumnWidth(4),  // Qty
          2: const FlexColumnWidth(7),  // Rate
          3: const FlexColumnWidth(10), // Amt
        };

    return Column(
       crossAxisAlignment: CrossAxisAlignment.stretch,
       children: [
         Table(
           columnWidths: colWidths,
           defaultVerticalAlignment: TableCellVerticalAlignment.top,
           children: [
             // Header Row
             TableRow(
               children: [
                 Text("Item", style: _styleFrom(settings.headerStyle)),
                 Text("Qty", style: _styleFrom(settings.headerStyle), textAlign: TextAlign.right),
                 if (!is58mm) Text("Rate", style: _styleFrom(settings.headerStyle), textAlign: TextAlign.right),
                 Text(is58mm ? "Amt" : "Amount", style: _styleFrom(settings.headerStyle), textAlign: TextAlign.right),
               ]
             ),
           ],
         ),
         
         _divider(),
         
         Table(
           columnWidths: colWidths,
           defaultVerticalAlignment: TableCellVerticalAlignment.top,
           children: items.map((item) {
             return TableRow(
               children: [
                 Text(item.name, style: _styleFrom(settings.regularStyle)), // Item Name Regular
                 Text(item.quantity.toString(), style: _styleFrom(settings.regularStyle), textAlign: TextAlign.right),
                 if (!is58mm) Text(ReceiptFormatter.formatNumber(item.price), style: _styleFrom(settings.regularStyle), textAlign: TextAlign.right),
                 Text(ReceiptFormatter.formatNumber(item.amount), style: _styleFrom(settings.regularStyle), textAlign: TextAlign.right),
               ]
             );
           }).toList(),
         ),

         _divider(),
       ],
     );
  }

  Widget _buildSummary(ReceiptKeyValSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         for (var row in summary.rows)
            Text(ReceiptFormatter.pad(row.label, row.value, config.charsPerLine), style: _styleFrom(row.isBold ? settings.headerStyle : settings.regularStyle)),
         
         _divider(),
         
         if (summary.grandTotal != null)
            Text(ReceiptFormatter.pad(summary.grandTotal!.label, summary.grandTotal!.value, config.charsPerLine), style: _styleFrom(settings.prominentStyle)),
            
         _divider(),
      ],
    );
  }

  Widget _buildPayment(ReceiptKeyValSummary payment) {
     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           for (var row in payment.rows)
              Text(ReceiptFormatter.pad(row.label, row.value, config.charsPerLine), style: _styleFrom(settings.regularStyle)),
           _divider(),
        ],
     );
  }

  Widget _buildFooter(ReceiptFooter footer, BuildContext context) {
    return Column(
      children: [
        Text(footer.message, textAlign: TextAlign.center, style: _styleFrom(settings.regularStyle)),
        if (footer.poweredBy != null) ...[
           const SizedBox(height: AppSpacing.xs),
           Text(footer.poweredBy!, textAlign: TextAlign.center, style: _styleFrom(settings.regularStyle, sizeOverride: 10).copyWith(color: AppColors.textSecondary(context))),
        ],
        if (footer.qrData != null && footer.qrData!.isNotEmpty) ...[
           const SizedBox(height: AppSpacing.sm),
           // Placeholder for QR Code (Mock visual)
           Container(
             padding: const EdgeInsets.all(AppSpacing.xs),
             decoration: BoxDecoration(border: Border.all(color: AppColors.textPrimaryLight)),
             child: const Column(
               children: [
                 Icon(Icons.qr_code_2, size: 48),
                 // Text(footer.qrData!, style: _styleFrom(settings.regularStyle, sizeOverride: 8)), // HIDDEN: Printer doesn't print specific text
               ],
             ),
           )
        ]
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: DashedLinePainter(),
      ),
    );
  }

  // Helper to map ReceiptTextStyle to TextStyle
  TextStyle _styleFrom(ReceiptTextStyle style, {double? sizeOverride, Color? color}) {
     // Map size int to double
     // 0 = Small (10), 1 = Normal (12), 2 = Large (16)
     double baseSize = 12.0;
     if (style.size == 0) baseSize = 10.0;
     if (style.size == 2) baseSize = 16.0;
     
     if (sizeOverride != null) baseSize = sizeOverride;

     return TextStyle(
       fontFamily: 'Courier New',
       fontSize: baseSize,
       fontWeight: style.isBold ? FontWeight.bold : FontWeight.normal,
       // fontStyle: style.isItalic ? FontStyle.italic : FontStyle.normal, // Removed
       color: color ?? AppColors.textPrimaryLight,
       height: 1.1,
     );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 3, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = AppColors.textPrimaryLight
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
