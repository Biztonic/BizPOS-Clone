
import 'package:intl/intl.dart';
import '../../../../models/settings.dart'; // Import
import '../models/receipt_config.dart';
import '../models/receipt_content.dart';
import 'receipt_formatter.dart';

class ReceiptGenerator {
  final ReceiptConfig config;
  final ReceiptSettings? settings; // Optional settings for typography
  
  // ESC/POS Commands
  static const String esc = '\x1B';
  static const String gs = '\x1D';
  static const String reset = '$esc\x40';
  static const String alignLeft = '$esc\x61\x00';
  static const String alignCenter = '$esc\x61\x01';
  static const String alignRight = '$esc\x61\x02';
  static const String boldOn = '$esc\x45\x01';
  static const String boldOff = '$esc\x45\x00';
  static const String underlineOn = '$esc\x2D\x01';
  static const String underlineOff = '$esc\x2D\x00';
  static const String italicOn = '$esc\x34'; // Varies, but standard-ish
  static const String italicOff = '$esc\x35';
  static const String cut = '$gs\x56\x42';
  static const String textSizeNormal = '$gs\x21\x00';
  static const String textSizeDoubleHeight = '$gs\x21\x10'; // Double Height only
  static const String textSizeDoubleWidth = '$gs\x21\x01';  // Double Width only
  static const String textSizeDouble = '$gs\x21\x11'; // Double Width & Height

  ReceiptGenerator(this.config, {this.settings});

  /// Check if a string contains non-Latin1 characters (Unicode/Devanagari/Marathi etc.)
  static bool containsNonLatin1(String? s) {
    if (s == null || s.isEmpty) return false;
    for (int i = 0; i < s.length; i++) {
      if (s.codeUnitAt(i) > 0xFF) return true;
    }
    return false;
  }

  /// Generates the raw bytes for the receipt.
  List<int> generate(ReceiptContent content) {
    List<int> bytes = [];
    // Sanitize text for thermal printers: replace non-ASCII chars with '?'
    // ESC/POS control sequences (ESC=0x1B, GS=0x1D) must pass through unchanged.
    void add(String s) {
      for (int i = 0; i < s.length; i++) {
        int c = s.codeUnitAt(i);
        if (c <= 0xFF) {
          bytes.add(c); // ASCII + Latin1 range — safe for thermal printers
        } else {
          bytes.add(0x3F); // '?' replacement for non-Latin1 characters
        }
      }
    }
    void addBytes(List<int> b) => bytes += b;

    // 1. Reset
    add(reset);

    // 2. Header
    _buildHeader(content.header, add);

    // 3. Bill Info
    _buildBillInfo(content.billInfo, add);

    // 4. Items
    _buildItems(content.items, add);

    // 5. Summary & Totals
    if (content.summary != null) {
      _buildSummary(content.summary!, add);
    }
    
    // 6. Payment
    if (content.payment != null) {
      _buildPayment(content.payment!, add);
    }

    // 7. Footer
    if (content.footer != null) {
      _buildFooter(content.footer!, add, addBytes);
    }

    // Cut
    // Cut
    // add('\n\n\n'); // Manual feed removed. relying on Feed-to-Cut command.
    if (config.useCut) {
      // Feed paper sufficiently before cutting (prevents slicing last line)
      add('\n\n\n');
      // GS V 1 : Partial cut (more universally supported than GS V 66)
      addBytes([0x1D, 0x56, 0x01]); 
    } else {
       // If no cut, just feed enough to pull it out
       add('\n\n\n\n\n');
    }

    return bytes;
  }

  // --- Helper to apply styles ---
  void _applyStyle(Function(String) add, ReceiptTextStyle? style) {
    if (style == null) {
       add(textSizeNormal);
       add(boldOff);
       // add(italicOff); // COMMENTED OUT: Causes '5' artifact on some printers
       return;
    }
    
    // Size - Forced to normal (small) to maintain proper alignment and prevent abnormal printing
    add(textSizeNormal);

    // Bold - Forced to normal (not bold) as requested by the user
    add(boldOff);
    
    // Italic
    // add(style.isItalic ? italicOn : italicOff); // COMMENTED OUT
  }
  
  void _resetStyle(Function(String) add) {
     add(textSizeNormal);
     add(boldOff);
     // add(italicOff); // COMMENTED OUT
  }

  void _buildHeader(ReceiptHeader header, Function(String) add) {
    add(alignCenter);
    
    // Top Message (Custom)
    if (header.customMessage != null && header.customMessage!.isNotEmpty) {
       _applyStyle(add, settings?.prominentStyle);
       add('${header.customMessage!}\n');
       _resetStyle(add);
       add('\n'); // Spacer
    }

    _applyStyle(add, settings?.prominentStyle ?? const ReceiptTextStyle(isBold: true));
    add('${header.storeName}\n');
    _resetStyle(add);

    _applyStyle(add, settings?.regularStyle);
    if (header.address != null) {
      add('${header.address!}\n');
    }
    if (header.phone != null) {
      add('Ph: ${header.phone}\n');
    }
    if (header.gstin != null) {
      add('GSTIN: ${header.gstin}\n');
    }
    _resetStyle(add);
    
    add('${ReceiptFormatter.divider(config.charsPerLine)}\n');
  }

  void _buildBillInfo(ReceiptBillInfo info, Function(String) add) {
    add(alignLeft);
    _applyStyle(add, settings?.regularStyle);
    
    final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
    final String dateStr = dateFormat.format(info.date);

    add('${ReceiptFormatter.pad('Bill No : ${info.billNo}', '', config.charsPerLine)}\n');
    add('${ReceiptFormatter.pad('Date    : $dateStr', '', config.charsPerLine)}\n');
    add('${ReceiptFormatter.pad('Cashier : ${info.cashierName}', '', config.charsPerLine)}\n');
    
    if (info.tableName != null && info.tableName!.isNotEmpty) {
      add('${ReceiptFormatter.pad('Table   : ${info.tableName}', '', config.charsPerLine)}\n');
    }
    if (info.seatNumbers != null && info.seatNumbers!.isNotEmpty) {
      add('${ReceiptFormatter.pad('Seat(s) : ${info.seatNumbers}', '', config.charsPerLine)}\n');
    }
    
    if (info.tokenNo != null) {
      _applyStyle(add, settings?.prominentStyle); // Token prominent
      add('${ReceiptFormatter.pad('Token No: ${info.tokenNo}', '', config.charsPerLine)}\n');
      _resetStyle(add);
      _applyStyle(add, settings?.regularStyle); // Re-apply regular
    }

    _resetStyle(add);
    add('${ReceiptFormatter.divider(config.charsPerLine)}\n');
  }

  void _buildItems(List<ReceiptItem> items, Function(String) add) {
    add(alignLeft);
    
    // Header
    _applyStyle(add, settings?.headerStyle ?? const ReceiptTextStyle(isBold: true));
    add("${ReceiptFormatter.formatItemHeader(config.charsPerLine)}\n");
    _resetStyle(add);
    
    add('${ReceiptFormatter.divider(config.charsPerLine)}\n');

    _applyStyle(add, settings?.regularStyle);
    for (var item in items) {
       var lines = ReceiptFormatter.formatItemRow(
         name: item.name,
         qty: item.quantity.toString(),
         rate: ReceiptFormatter.formatNumber(item.price),
         amount: ReceiptFormatter.formatNumber(item.amount),
         width: config.charsPerLine
       );
       for (var line in lines) {
         add('$line\n');
       }
    }
    _resetStyle(add);
    
    add('${ReceiptFormatter.divider(config.charsPerLine)}\n');
  }

  void _buildSummary(ReceiptKeyValSummary summary, Function(String) add) {
    add(alignLeft);
    
    for (var row in summary.rows) {
      String line = ReceiptFormatter.pad(row.label, row.value, config.charsPerLine);
      // If row explicitly bold (from logic), follow it overrides or merges?
      // Logic: If Settings say Header Bold, and row is bold, sure.
      // Let's use HeaderStyle for bold rows, Regular for normal.
      
      ReceiptTextStyle rowStyle = row.isBold 
          ? (settings?.headerStyle ?? const ReceiptTextStyle(isBold: true))
          : (settings?.regularStyle ?? const ReceiptTextStyle());
          
      _applyStyle(add, rowStyle);
      add('$line\n');
      _resetStyle(add);
    }

    add('${ReceiptFormatter.divider(config.charsPerLine)}\n');

    if (summary.grandTotal != null) {
      _applyStyle(add, settings?.prominentStyle ?? const ReceiptTextStyle(size: 2, isBold: true));
      add(ReceiptFormatter.pad(summary.grandTotal!.label, summary.grandTotal!.value, config.charsPerLine));
      _resetStyle(add);
      add('\n'); 
    }
    
    add('${ReceiptFormatter.divider(config.charsPerLine)}\n');
  }

  void _buildPayment(ReceiptKeyValSummary payment, Function(String) add) {
     add(alignLeft);
     _applyStyle(add, settings?.regularStyle);
     for (var row in payment.rows) {
       add('${ReceiptFormatter.pad(row.label, row.value, config.charsPerLine)}\n');
     }
     _resetStyle(add);
     add('${ReceiptFormatter.divider(config.charsPerLine)}\n');
  }

  void _buildFooter(ReceiptFooter footer, Function(String) add, Function(List<int>) addBytes) {
    add(alignCenter);
    _applyStyle(add, settings?.regularStyle);
    add('${footer.message}\n');
    if (footer.poweredBy != null) {
      // Powered by usually small
      add(textSizeNormal); 
      add('${footer.poweredBy!}\n');
    }
    _resetStyle(add);
    
    // QR Code
    if (footer.qrData != null && footer.qrData!.isNotEmpty) {
       add('\n'); // Spacer
       _printQRCode(footer.qrData!, add, addBytes);
       add('\n');
    }
  }

  void _printQRCode(String data, Function(String) add, Function(List<int>) addBytes) {
      // ... (Same as before)
      // 1. Set QR Code Size (Module Size = 6)
      addBytes([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]);

      // 2. Set Error Correction Level (L)
      addBytes([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);

      // 3. Store Data in Symbol Storage Area
      int len = data.length + 3;
      int pL = len % 256;
      int pH = len ~/ 256;
      addBytes([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
      add(data);

      // 4. Print Symbol Data
      addBytes([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
  }
}

