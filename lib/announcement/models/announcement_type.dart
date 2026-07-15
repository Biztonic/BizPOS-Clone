enum AnnouncementType {
  // Billing
  itemAdded,
  itemRemoved,
  discountApplied,
  paymentSuccess,
  paymentFailed,
  receiptPrinted,
  refund,

  // Inventory
  stockLow,
  outOfStock,
  itemRestored,

  // Printer
  printerConnected,
  printerDisconnected,
  printStarted,
  printCompleted,

  // Sync
  syncStarted,
  syncCompleted,

  // Connectivity
  online,
  offline,
  pendingUploads,

  // Restaurant
  tableOccupied,
  tableFree,
  newQrOrder,
  kitchenReady,

  // Auth
  loginSuccess,
  logout,
  storeChanged,
}
