import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportUtils {
  /// Exports a list of rows to an Excel file (.xlsx)
  /// In Web: Triggers a browser download
  /// In Android/iOS: Triggers a Share dialog
  static Future<void> exportToExcel({
    required String fileName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    BuildContext? context,
  }) async {
    try {
      var excel = Excel.createExcel();
      // Rename default sheet to 'Report'
      excel.rename('Sheet1', 'Report');
      Sheet sheetObject = excel['Report'];

      // Add Headers
      sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Format Headers (Bold)
      for (int col = 0; col < headers.length; col++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.cellStyle = CellStyle(bold: true);
      }

      // Add Rows
      for (var row in rows) {
        final excelRow = row.map((val) {
          if (val is int) return IntCellValue(val);
          if (val is double) return DoubleCellValue(val);
          if (val is DateTime) return DateTimeCellValue.fromDateTime(val);
          if (val is bool) return BoolCellValue(val);
          return TextCellValue(val?.toString() ?? '');
        }).toList();
        sheetObject.appendRow(excelRow);
      }

      final fileBytes = excel.save();
      if (fileBytes == null) throw "Failed to generate Excel file";

      final finalFileName = '${fileName}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      if (kIsWeb) {
        // Trigger web download
        final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = finalFileName;
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        // Save to temp dir and share on mobile/desktop
        final tempDir = await getTemporaryDirectory();
        final file = io.File('${tempDir.path}/$finalFileName');
        await file.writeAsBytes(fileBytes);
        final box = context?.findRenderObject() as RenderBox?;
        final sharePositionOrigin = box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null;

        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: fileName,
            subject: fileName,
            sharePositionOrigin: sharePositionOrigin,
          ),
        );
      }
    } catch (e) {
      debugPrint("Excel Export Error: $e");
      rethrow;
    }
  }
}
