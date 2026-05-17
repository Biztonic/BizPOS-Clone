// ignore_for_file: avoid_print
void main() {
  final priceRegex = RegExp(
      r'(?:Rs\.?|INR|\$|₹)?\s*(\d[\d.,\s]*\d|\d+)\s*(?:Rs\.?|INR|\$|₹|\/-)?\s*$',
      caseSensitive: false);

  final lines = [
    "Cabernet Franc \$ 5.50",
    "Cabernet Sauvignon \$ 5.50",
    "Chianti \$ 5.50",
    "Dornfelder \$ 2.60",
    "Merlot \$ 3.90",
    "088/ 445 45 451",
    "Item Name ......... 20",
    "Dosa - \$2",
    "Tea Rs 10",
  ];

  for (var line in lines) {
    final cleanLine = line.trim();
    if (cleanLine.length < 2) continue;

    final match = priceRegex.firstMatch(cleanLine);
    if (match != null) {
      final priceString = match.group(1)!.replaceAll(RegExp(r'[,\s]'), '');
      final price = double.tryParse(priceString) ?? 0.0;

      String name = cleanLine.substring(0, match.start).trim();
      name = name.replaceAll(RegExp(r'[-=.:_]+\s*$'), '').trim();
      name = name
          .replaceAll(RegExp(r'^(Rs|INR|\$|₹)\s*', caseSensitive: false), '')
          .trim();

      if (name.isNotEmpty && name.length > 2 && price > 0) {
        print("MATCHED: Name: '$name', Price: $price");
      } else {
        print("REJECTED: Name: '$name', Price: $price, original: '$cleanLine'");
      }
    } else {
      print("NO MATCH: original: '$cleanLine'");
    }
  }
}
