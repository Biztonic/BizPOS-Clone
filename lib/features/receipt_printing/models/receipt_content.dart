class ReceiptContent {
  final ReceiptHeader header;
  final ReceiptBillInfo billInfo;
  final List<ReceiptItem> items;
  final ReceiptKeyValSummary? summary; // Subtotal, Tax, Discount
  final ReceiptKeyValSummary? payment; // Payment modes
  final ReceiptFooter? footer;

  ReceiptContent({
    required this.header,
    required this.billInfo,
    required this.items,
    this.summary,
    this.payment,
    this.footer,
  });
}

class ReceiptHeader {
  final String storeName;
  final String? address;
  final String? phone;
  final String? gstin;
  final String? email;
  final String? website;
  final String? customMessage;

  ReceiptHeader({
    required this.storeName,
    this.address,
    this.phone,
    this.gstin,
    this.email,
    this.website,
    this.customMessage,
  });
}

class ReceiptBillInfo {
  final String billNo;
  final DateTime date;
  final String cashierName;
  final String? tokenNo;
  final String invoiceType; // SALE, RETURN
  final String? tableName;
  final String? seatNumbers;

  ReceiptBillInfo({
    required this.billNo,
    required this.date,
    required this.cashierName,
    this.tokenNo,
    this.invoiceType = 'SALE',
    this.tableName,
    this.seatNumbers,
  });
}

class ReceiptItem {
  final String name;
  final double quantity;
  final double price;
  final double amount;
  final String? taxLabel; // e.g. "G" for GST

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.amount,
    this.taxLabel,
  });
}

class ReceiptKeyValSummary {
  final List<ReceiptKeyVal> rows;
  final ReceiptKeyVal? grandTotal;

  ReceiptKeyValSummary({required this.rows, this.grandTotal});
}

class ReceiptKeyVal {
  final String label;
  final String value;
  final bool isBold;
  final bool isLarge;

  ReceiptKeyVal({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isLarge = false,
  });
}

class ReceiptFooter {
  final String message;
  final String? poweredBy;
  final String? qrData;

  ReceiptFooter({
    this.message = 'Thank You! Visit Again',
    this.poweredBy = 'Powered by Biztonic POS',
    this.qrData,
  });
}
