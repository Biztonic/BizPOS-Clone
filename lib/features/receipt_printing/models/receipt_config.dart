enum ReceiptWidth { mm58, mm80 }

class ReceiptConfig {
  final ReceiptWidth width;
  final int charsPerLine;
  final bool useCut;
  final bool openDrawer;
  final bool printBitmap; // For future logo support

  const ReceiptConfig({
    this.width = ReceiptWidth.mm80,
    this.charsPerLine = 48, // Default for 80mm
    this.useCut = true,
    this.openDrawer = false,
    this.printBitmap = false,
  });

  factory ReceiptConfig.mm58() {
    return const ReceiptConfig(
      width: ReceiptWidth.mm58,
      charsPerLine: 32,
    );
  }

  factory ReceiptConfig.mm80() {
    return const ReceiptConfig(
      width: ReceiptWidth.mm80,
      charsPerLine: 48,
    );
  }
}
