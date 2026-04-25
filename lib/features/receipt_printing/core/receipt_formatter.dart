class ReceiptFormatter {
  /// Aligns text to the center of the given width.
  static String alignCenter(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    int padding = (width - text.length) ~/ 2;
    return ' ' * padding + text + ' ' * (width - text.length - padding);
  }

  /// Aligns text to the right of the given width.
  static String alignRight(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return text.padLeft(width);
  }

  /// Aligns text to the left of the given width.
  static String alignLeft(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return text.padRight(width);
  }

  /// Creates a row with left and right text separated by spaces.
  static String pad(String left, String right, int width) {
    int available = width - left.length - right.length;
    if (available < 1) available = 1; // Ensure at least one space
    // If combined length exceeds width, strict truncation might be needed but for now we trust logic
    return left + (' ' * available) + right;
  }

  /// Creates a divider line.
  static String divider([int width = 48, String char = '-']) {
    return char * width;
  }

  /// Formats the header row to match item columns.
  static String formatItemHeader(int width) {
    bool isSmall = width <= 32;
    // Updated widths for better spacing
    int qtyW = 4; 
    int rateW = 7;
    int amtW = 10;
    int gap = 1;
    
    if (isSmall) {
       // 58mm: Item | Qty | Amount
       int curAmtW = 9; // Keep 9 for 58mm as space is tight
       int curQtyW = 4; // Update to 4 to match logic/plan
       int itemW = width - (curQtyW + gap + curAmtW + gap); 
       if (itemW < 5) itemW = 5;
       
       return alignLeft("Item", itemW) + 
              (' ' * gap) + 
              alignRight("Qty", curQtyW) + 
              (' ' * gap) + 
              alignRight("Amt", curAmtW);
    } else {
       // 80mm: Item | Qty | Rate | Amount
       int itemW = width - (qtyW + gap + rateW + gap + amtW + gap);
       if (itemW < 5) itemW = 5;
       
       return alignLeft("Item", itemW) + 
              (' ' * gap) + 
              alignRight("Qty", qtyW) + 
              (' ' * gap) + 
              alignRight("Rate", rateW) + 
              (' ' * gap) + 
              alignRight("Amount", amtW);
    }
  }

  static List<String> formatItemRow({
    required String name,
    required String qty,
    required String rate,
    required String amount,
    required int width,
  }) {
    List<String> lines = [];
    
    // Updated widths
    int qtyW = 4;
    int rateW = 7;
    int amtW = 10;
    int gap = 1;
    
    bool isSmall = width <= 32;
    int itemW;
    
    if (isSmall) {
       int curAmtW = 9;
       int curQtyW = 4; // Standardized to 4
       itemW = width - (curQtyW + gap + curAmtW + gap);
       if (itemW < 5) itemW = 5;
       
       List<String> nameLines = _wrapText(name, itemW);
       
       String colQty = alignRight(qty, curQtyW);
       String colAmt = alignRight(amount, curAmtW);
       
       String line1 = alignLeft(nameLines[0], itemW) + 
                      (' ' * gap) + colQty + 
                      (' ' * gap) + colAmt;
       lines.add(line1);
       
       for(int i=1; i< nameLines.length; i++) {
         lines.add(alignLeft(nameLines[i], itemW));
       }
    } else {
       itemW = width - (qtyW + gap + rateW + gap + amtW + gap);
       if (itemW < 5) itemW = 5;

       List<String> nameLines = _wrapText(name, itemW);
       
       String colQty = alignRight(qty, qtyW);
       String colRate = alignRight(rate, rateW);
       String colAmt = alignRight(amount, amtW);
       
       String line1 = alignLeft(nameLines[0], itemW) + 
                      (' ' * gap) + colQty + 
                      (' ' * gap) + colRate + 
                      (' ' * gap) + colAmt;
       lines.add(line1);
       
        for(int i=1; i< nameLines.length; i++) {
         lines.add(alignLeft(nameLines[i], itemW));
       }
    }
    
    return lines;
  }
  
  static List<String> _wrapText(String text, int width) {
    if (text.length <= width) return [text];
    
    List<String> result = [];
    String remaining = text;
    
    while(remaining.length > width) {
      result.add(remaining.substring(0, width));
      remaining = remaining.substring(width);
    }
    if (remaining.isNotEmpty) result.add(remaining);
    
    return result;
  }

  /// Formats currency to rounded integer string (for Items).
  static String formatNumber(double amount) {
    return amount.round().toString();
  }

  /// Formats currency to standard 2-decimal string (for Totals).
  static String formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }
}
