/// Typed event classes for cross-module communication via EventBus.
///
/// These events replace direct Provider-to-Provider calls, enabling
/// feature modules to communicate without import dependencies.
library;

// ─── Billing Events ──────────────────────────────────────────
class OrderCreatedEvent {
  final dynamic order;
  final String storeId;
  final dynamic event;
  final List<dynamic> movements;

  OrderCreatedEvent({
    required this.order,
    required this.storeId,
    required this.event,
    required this.movements,
  });
}

class OrderVoidedEvent {
  final String orderId;
  final String storeId;
  final String? reason;
  final String? voidedBy;

  OrderVoidedEvent({
    required this.orderId,
    required this.storeId,
    this.reason,
    this.voidedBy,
  });
}

class OrderRefundedEvent {
  final String orderId;
  final String storeId;
  final double refundAmount;
  final List<dynamic> items;

  OrderRefundedEvent({
    required this.orderId,
    required this.storeId,
    required this.refundAmount,
    this.items = const [],
  });
}

// ─── Inventory Events ────────────────────────────────────────
class InventoryAdjustedEvent {
  final String itemId;
  final String storeId;
  final int delta;
  final String reason;

  InventoryAdjustedEvent({
    required this.itemId,
    required this.storeId,
    required this.delta,
    required this.reason,
  });
}

class InventoryItemCreatedEvent {
  final String itemId;
  final String storeId;
  final String name;

  InventoryItemCreatedEvent({
    required this.itemId,
    required this.storeId,
    required this.name,
  });
}

class InventoryItemDeletedEvent {
  final String itemId;
  final String storeId;

  InventoryItemDeletedEvent({
    required this.itemId,
    required this.storeId,
  });
}

/// General inventory change event used by [InventoryOrchestrator].
/// changeType: 'UPSERT', 'DELETE', 'STOCK_ADJUST'
class InventoryChangedEvent {
  final String itemId;
  final String storeId;
  final String changeType;

  InventoryChangedEvent({
    required this.itemId,
    required this.storeId,
    required this.changeType,
  });
}

// ─── CRM Events ──────────────────────────────────────────────
class CustomerCreatedEvent {
  final String customerId;
  final String storeId;
  final String name;

  CustomerCreatedEvent({
    required this.customerId,
    required this.storeId,
    required this.name,
  });
}

class CustomerUpdatedEvent {
  final String customerId;
  final String storeId;

  CustomerUpdatedEvent({
    required this.customerId,
    required this.storeId,
  });
}

// ─── Store Events ────────────────────────────────────────────
class StoreChangedEvent {
  final String? previousStoreId;
  final String newStoreId;

  StoreChangedEvent({
    this.previousStoreId,
    required this.newStoreId,
  });
}

class StoreSettingsUpdatedEvent {
  final String storeId;

  StoreSettingsUpdatedEvent({required this.storeId});
}

// ─── Sync Events ─────────────────────────────────────────────
class SyncStartedEvent {
  final String storeId;
  SyncStartedEvent({required this.storeId});
}

class SyncCompletedEvent {
  final String storeId;
  final int itemsPushed;
  final int itemsPulled;
  final DateTime completedAt;

  SyncCompletedEvent({
    required this.storeId,
    this.itemsPushed = 0,
    this.itemsPulled = 0,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();
}

class SyncFailedEvent {
  final String storeId;
  final String error;

  SyncFailedEvent({
    required this.storeId,
    required this.error,
  });
}

class ConnectivityChangedEvent {
  final bool isOnline;
  ConnectivityChangedEvent({required this.isOnline});
}

// ─── Employee Events ─────────────────────────────────────────
class EmployeeLoggedInEvent {
  final String employeeId;
  final String storeId;
  final String name;

  EmployeeLoggedInEvent({
    required this.employeeId,
    required this.storeId,
    required this.name,
  });
}

class EmployeeLoggedOutEvent {
  final String employeeId;
  final String storeId;

  EmployeeLoggedOutEvent({
    required this.employeeId,
    required this.storeId,
  });
}

// ─── Hardware Events ─────────────────────────────────────────
class PrintRequestedEvent {
  final String documentType; // 'receipt', 'invoice', 'report'
  final Map<String, dynamic> data;

  PrintRequestedEvent({
    required this.documentType,
    required this.data,
  });
}

class PrintCompletedEvent {
  final bool success;
  final String? error;

  PrintCompletedEvent({required this.success, this.error});
}

// ─── Subscription Events ────────────────────────────────────
class PlanLimitReachedEvent {
  final String storeId;
  final String limitType; // 'orders', 'inventory', 'employees'
  final int currentCount;
  final int maxAllowed;

  PlanLimitReachedEvent({
    required this.storeId,
    required this.limitType,
    required this.currentCount,
    required this.maxAllowed,
  });
}

// ─── Custom Cart & POS Events ───────────────────────────────
class CartItemAddedEvent {
  final String itemId;
  final String? itemName;
  CartItemAddedEvent({required this.itemId, this.itemName});
}

class CartItemRemovedEvent {
  final String itemId;
  final String? itemName;
  CartItemRemovedEvent({required this.itemId, this.itemName});
}

class CartDiscountAppliedEvent {
  final double discountAmount;
  CartDiscountAppliedEvent({required this.discountAmount});
}

// ─── Custom Printer Connection Events ───────────────────────
class PrinterConnectedEvent {
  final String deviceName;
  final String purpose;
  PrinterConnectedEvent({required this.deviceName, required this.purpose});
}

class PrinterDisconnectedEvent {
  final String deviceName;
  final String purpose;
  PrinterDisconnectedEvent({required this.deviceName, required this.purpose});
}

// ─── Custom Table & QR Events ───────────────────────────────
class TableOccupiedEvent {
  final String tableId;
  final String tableName;
  TableOccupiedEvent({required this.tableId, required this.tableName});
}

class TableClearedEvent {
  final String tableId;
  final String tableName;
  TableClearedEvent({required this.tableId, required this.tableName});
}

class NewQrOrderEvent {
  final String orderId;
  final String tableName;
  NewQrOrderEvent({required this.orderId, required this.tableName});
}

class KitchenReadyEvent {
  final String orderId;
  final String tableName;
  KitchenReadyEvent({required this.orderId, required this.tableName});
}

