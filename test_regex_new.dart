// ignore_for_file: avoid_print
void main() {
  final priceRegex = RegExp(r'(?:Rs\.?|INR|\$|₹)?\s*(\d[\d.,\s]*\d|\d+)\s*(?:Rs\.?|INR|\$|₹|\/-)?\s*$', caseSensitive: false);
  final noiseWords = ['menu', 'items', 'price', 'cost', 'tax', 'total', 'page', 'gst', 'cgst', 'sgst', 'rate'];

  final lines = [
    "Cabernet Franc \$ 5.50",
    "Onion Dosa", // no price
    "Breakfast", // header
    "Total", // noise
    "150", // just number
    "088/ 445 45 451",
    "Special Items", // header
    "Mushroom Biryani (Half) ..... 30",
  ];

  String currentCategory = 'General';

  for (var line in lines) {
    final cleanLine = line.trim();
    if (cleanLine.length < 2) continue;
    
    String name = '';
    double price = 0.0;
    
    final match = priceRegex.firstMatch(cleanLine);
    if (match != null) {
      final priceString = match.group(1)!.replaceAll(RegExp(r'[,\s]'), '');
      price = double.tryParse(priceString) ?? 0.0;
      name = cleanLine.substring(0, match.start).trim();
    } else {
      name = cleanLine;
    }
    
    name = name.replaceAll(RegExp(r'[-=.:_]+\s*$'), '').trim();
    name = name.replaceAll(RegExp(r'^(Rs|INR|\$|₹)\s*', caseSensitive: false), '').trim();
    
    if (match == null && name.length >= 3 && name.length <= 25 && !RegExp(r'\d').hasMatch(name)) {
        String possibleCategory = name.replaceAll(RegExp(r'[^A-Za-z\s]'), '').trim();
        if (possibleCategory.isNotEmpty) {
             possibleCategory = possibleCategory.split(' ')
                .where((str) => str.isNotEmpty)
                .map((str) => '\${str[0].toUpperCase()}\${str.substring(1).toLowerCase()}')
                .join(' ');
             
             if (!noiseWords.contains(possibleCategory.toLowerCase())) {
                currentCategory = possibleCategory;
                print("SET CATEGORY: '$currentCategory'");
                continue; 
             }
        }
    }

    if (name.isNotEmpty && name.length > 2) {
       if (name.replaceAll(RegExp(r'[^A-Za-z]'), '').isEmpty) {
          print("REJECT NUMBERS ONLY: '$name'");
          continue;
       }
       if (noiseWords.contains(name.toLowerCase())) {
          print("REJECT NOISE WORD: '$name'");
          continue;
       }
       
       print("MATCHED ITEM: Name: '$name', Price: $price, Category: $currentCategory");
    }
  }
}
