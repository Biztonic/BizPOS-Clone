import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/receipt_config.dart';
import '../models/receipt_content.dart';

class ReceiptImageRenderer {
  /// Render standard customer receipt to a ui.Image
  static Future<ui.Image> renderCustomerReceipt({
    required ReceiptContent content,
    required ReceiptConfig config,
  }) async {
    final double width = config.width == ReceiptWidth.mm58 ? 384.0 : 576.0;
    const double scale = 2.0;
    final double scaledWidth = width * scale;

    // Pass 1: Measure height by doing a dry-run paint at 1x
    final recorder1 = ui.PictureRecorder();
    final canvas1 = ui.Canvas(recorder1);
    final double totalHeight = _paintCustomerReceipt(canvas1, content, width);
    recorder1.endRecording();

    final double scaledHeight = totalHeight * scale;

    // Pass 2: Actually draw the bitmap image with the correct height at 2.0x scale
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw white background
    final bgPaint = ui.Paint()..color = Colors.white;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, scaledWidth, scaledHeight), bgPaint);

    // Scale canvas operations
    canvas.scale(scale);

    // Paint receipt details
    _paintCustomerReceipt(canvas, content, width);

    final picture = recorder.endRecording();
    return await picture.toImage(scaledWidth.toInt(), scaledHeight.toInt());
  }

  /// Render Kitchen Order Ticket (KOT) receipt to a ui.Image
  static Future<ui.Image> renderKdsReceipt({
    required String counterName,
    required DateTime date,
    required String kotNumber,
    required String serviceType,
    required String billerName,
    required List<Map<String, dynamic>> items,
    String? tableName,
    String? seatNumbers,
    required int receiptWidth,
  }) async {
    final double width = receiptWidth == 58 ? 384.0 : 576.0;
    const double scale = 2.0;
    final double scaledWidth = width * scale;

    // Pass 1: Measure height at 1x
    final recorder1 = ui.PictureRecorder();
    final canvas1 = ui.Canvas(recorder1);
    final double totalHeight = _paintKdsReceipt(
      canvas: canvas1,
      counterName: counterName,
      date: date,
      kotNumber: kotNumber,
      serviceType: serviceType,
      billerName: billerName,
      items: items,
      tableName: tableName,
      seatNumbers: seatNumbers,
      width: width,
    );
    recorder1.endRecording();

    final double scaledHeight = totalHeight * scale;

    // Pass 2: Draw KOT at 2.0x scale
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final bgPaint = ui.Paint()..color = Colors.white;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, scaledWidth, scaledHeight), bgPaint);

    canvas.scale(scale);

    _paintKdsReceipt(
      canvas: canvas,
      counterName: counterName,
      date: date,
      kotNumber: kotNumber,
      serviceType: serviceType,
      billerName: billerName,
      items: items,
      tableName: tableName,
      seatNumbers: seatNumbers,
      width: width,
    );

    final picture = recorder.endRecording();
    return await picture.toImage(scaledWidth.toInt(), scaledHeight.toInt());
  }

  // --- Customer Receipt Painting Logic ---
  static double _paintCustomerReceipt(ui.Canvas canvas, ReceiptContent content, double width) {
    double y = 10.0;
    const double padding = 8.0;
    final contentWidth = width - (padding * 2);

    double drawTextLine({
      required String text,
      required double fontSize,
      bool bold = false,
      ui.TextAlign align = ui.TextAlign.left,
      double? xOverride,
    }) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      );
      textPainter.layout(maxWidth: contentWidth);

      final double x = xOverride ??
          (align == ui.TextAlign.center
              ? (width - textPainter.width) / 2
              : align == ui.TextAlign.right
                  ? width - padding - textPainter.width
                  : padding);

      textPainter.paint(canvas, Offset(x, y));
      return textPainter.height;
    }

    void drawDivider() {
      y += 4;
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(padding, y), Offset(width - padding, y), paint);
      y += 5;
    }

    // 1. Header Section
    if (content.header.customMessage != null && content.header.customMessage!.isNotEmpty) {
      y += drawTextLine(text: content.header.customMessage!, fontSize: 18, align: ui.TextAlign.center);
      y += 2;
    }

    if (content.header.storeName.isNotEmpty) {
      y += drawTextLine(text: content.header.storeName, fontSize: 22, bold: true, align: ui.TextAlign.center);
      y += 2;
    }

    if (content.header.address != null) {
      y += drawTextLine(text: content.header.address!, fontSize: 16, align: ui.TextAlign.center);
      y += 1;
    }

    if (content.header.phone != null) {
      y += drawTextLine(text: 'Ph: ${content.header.phone!}', fontSize: 16, align: ui.TextAlign.center);
      y += 1;
    }

    if (content.header.gstin != null) {
      y += drawTextLine(text: 'GSTIN: ${content.header.gstin!}', fontSize: 16, align: ui.TextAlign.center);
      y += 1;
    }

    drawDivider();

    // 2. Bill Info Section
    final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
    final String dateStr = dateFormat.format(content.billInfo.date);

    y += drawTextLine(text: 'Bill No : ${content.billInfo.billNo}', fontSize: 16);
    y += 1;
    y += drawTextLine(text: 'Date    : $dateStr', fontSize: 16);
    y += 1;
    y += drawTextLine(text: 'Cashier : ${content.billInfo.cashierName}', fontSize: 16);
    y += 1;

    if (content.billInfo.tableName != null && content.billInfo.tableName!.isNotEmpty) {
      y += drawTextLine(text: 'Table   : ${content.billInfo.tableName}', fontSize: 16);
      y += 1;
    }
    if (content.billInfo.seatNumbers != null && content.billInfo.seatNumbers!.isNotEmpty) {
      y += drawTextLine(text: 'Seat(s) : ${content.billInfo.seatNumbers}', fontSize: 16);
      y += 1;
    }
    if (content.billInfo.tokenNo != null) {
      y += drawTextLine(text: 'Token No: ${content.billInfo.tokenNo}', fontSize: 18, bold: true);
      y += 1;
    }

    drawDivider();

    // 3. Items Column Headers & Rows
    const double colQtyWidth = 60.0;
    const double colRateWidth = 90.0;
    const double colAmtWidth = 95.0;
    final double colNameWidth = contentWidth - colQtyWidth - colRateWidth - colAmtWidth;

    const nameX = padding;
    final qtyX = nameX + colNameWidth;
    final rateX = qtyX + colQtyWidth;
    final amtX = rateX + colRateWidth;

    double drawRow({
      required String name,
      required String qty,
      required String rate,
      required String amount,
      bool bold = false,
      double fontSize = 16,
    }) {
      final namePainter = TextPainter(
        text: TextSpan(text: name, style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colNameWidth);

      final qtyPainter = TextPainter(
        text: TextSpan(text: qty, style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
        textAlign: ui.TextAlign.right,
      )..layout(maxWidth: colQtyWidth);

      final ratePainter = TextPainter(
        text: TextSpan(text: rate, style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
        textAlign: ui.TextAlign.right,
      )..layout(maxWidth: colRateWidth);

      final amtPainter = TextPainter(
        text: TextSpan(text: amount, style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
        textAlign: ui.TextAlign.right,
      )..layout(maxWidth: colAmtWidth);

      final double maxHeight = [
        namePainter.height,
        qtyPainter.height,
        ratePainter.height,
        amtPainter.height
      ].reduce((a, b) => a > b ? a : b);

      namePainter.paint(canvas, Offset(nameX, y));
      qtyPainter.paint(canvas, Offset(qtyX + colQtyWidth - qtyPainter.width, y));
      ratePainter.paint(canvas, Offset(rateX + colRateWidth - ratePainter.width, y));
      amtPainter.paint(canvas, Offset(amtX + colAmtWidth - amtPainter.width, y));

      return maxHeight;
    }

    y += drawRow(name: 'Item', qty: 'Qty', rate: 'Rate', amount: 'Amount', bold: true);
    drawDivider();

    for (var item in content.items) {
      final itemHeight = drawRow(
        name: item.name,
        qty: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(1),
        rate: item.price.toStringAsFixed(2),
        amount: item.amount.toStringAsFixed(2),
      );
      y += itemHeight + 3;
    }

    drawDivider();

    // 4. Totals Summary
    if (content.summary != null) {
      for (var row in content.summary!.rows) {
        final double labelHeight = drawTextLine(text: row.label, fontSize: 16, bold: row.isBold);
        drawTextLine(text: row.value, fontSize: 16, bold: row.isBold, align: ui.TextAlign.right);
        y += labelHeight + 1.5;
      }

      drawDivider();

      if (content.summary!.grandTotal != null) {
        final gt = content.summary!.grandTotal!;
        final double labelHeight = drawTextLine(text: gt.label, fontSize: 20, bold: true);
        drawTextLine(text: gt.value, fontSize: 20, bold: true, align: ui.TextAlign.right);
        y += labelHeight + 3;
      }

      drawDivider();
    }

    // 5. Payment details
    if (content.payment != null) {
      for (var row in content.payment!.rows) {
        final double labelHeight = drawTextLine(text: row.label, fontSize: 16, bold: row.isBold);
        drawTextLine(text: row.value, fontSize: 16, bold: row.isBold, align: ui.TextAlign.right);
        y += labelHeight + 1.5;
      }
      drawDivider();
    }

    // 6. Footer message
    if (content.footer != null) {
      y += drawTextLine(text: content.footer!.message, fontSize: 16, align: ui.TextAlign.center);
      y += 2;
      if (content.footer!.poweredBy != null) {
        y += drawTextLine(text: content.footer!.poweredBy!, fontSize: 12, align: ui.TextAlign.center);
        y += 2;
      }
    }

    y += 8.0; // Margin at bottom
    return y;
  }

  // --- KOT Painting Logic ---
  static double _paintKdsReceipt({
    required ui.Canvas canvas,
    required String counterName,
    required DateTime date,
    required String kotNumber,
    required String serviceType,
    required String billerName,
    required List<Map<String, dynamic>> items,
    String? tableName,
    String? seatNumbers,
    required double width,
  }) {
    double y = 10.0;
    const double padding = 8.0;
    final contentWidth = width - (padding * 2);

    double drawTextLine({
      required String text,
      required double fontSize,
      bool bold = false,
      ui.TextAlign align = ui.TextAlign.left,
      double? xOverride,
    }) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.black,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      );
      textPainter.layout(maxWidth: contentWidth);

      final double x = xOverride ??
          (align == ui.TextAlign.center
              ? (width - textPainter.width) / 2
              : align == ui.TextAlign.right
                  ? width - padding - textPainter.width
                  : padding);

      textPainter.paint(canvas, Offset(x, y));
      return textPainter.height;
    }

    void drawDivider() {
      y += 4;
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(padding, y), Offset(width - padding, y), paint);
      y += 5;
    }

    // 1. KOT Header
    y += drawTextLine(text: counterName, fontSize: 22, bold: true, align: ui.TextAlign.center);
    y += 2;

    final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');
    y += drawTextLine(text: dateFormat.format(date), fontSize: 16, align: ui.TextAlign.center);
    y += 1;
    y += drawTextLine(text: 'KOT - $kotNumber', fontSize: 16, align: ui.TextAlign.center);
    y += 2;

    y += drawTextLine(text: serviceType, fontSize: 20, bold: true, align: ui.TextAlign.center);
    y += 2;

    drawDivider();

    // 2. KOT Details
    y += drawTextLine(text: 'Biller: $billerName', fontSize: 16);
    y += 1;
    if (tableName != null && tableName.isNotEmpty) {
      y += drawTextLine(text: 'Table: $tableName', fontSize: 16);
      y += 1;
    }
    if (seatNumbers != null && seatNumbers.isNotEmpty) {
      y += drawTextLine(text: 'Seats: $seatNumbers', fontSize: 16);
      y += 1;
    }

    drawDivider();

    // 3. Items Header
    const double colQtyWidth = 70.0;
    final double colNameWidth = contentWidth - colQtyWidth;

    double drawItemRow({
      required String name,
      required String qty,
      bool bold = false,
      double fontSize = 16,
    }) {
      final namePainter = TextPainter(
        text: TextSpan(text: name, style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: colNameWidth);

      final qtyPainter = TextPainter(
        text: TextSpan(text: qty, style: TextStyle(color: Colors.black, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        textDirection: TextDirection.ltr,
        textAlign: ui.TextAlign.right,
      )..layout(maxWidth: colQtyWidth);

      final double maxHeight = namePainter.height > qtyPainter.height ? namePainter.height : qtyPainter.height;

      namePainter.paint(canvas, Offset(padding, y));
      qtyPainter.paint(canvas, Offset(padding + colNameWidth + colQtyWidth - qtyPainter.width, y));

      return maxHeight;
    }

    y += drawItemRow(name: 'Item', qty: 'Qty', bold: true);
    drawDivider();

    for (var item in items) {
      final double rowHeight = drawItemRow(
        name: item['name'],
        qty: item['qty'].toString(),
        bold: true,
      );
      y += rowHeight + 2;

      if (item['note'] != null && item['note'].toString().isNotEmpty) {
        y += drawTextLine(text: '  (Note: ${item['note']})', fontSize: 14);
        y += 2;
      }
    }

    y += 8.0; // Margin at bottom
    return y;
  }
}
