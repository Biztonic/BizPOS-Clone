# BizPOS: Product Requirements Document (PRD) & Technical Specification

> **AI Context Optimization Notice**:  
> This file is the single, authoritative, high-density specification for Biztonic BizPOS. Future AI agents and developers should read this document first rather than scanning dozens of source files. Consulting this document prevents hallucinations, guarantees domain invariants, and saves significant token budget.

---

## 1. Product Overview & Architecture Summary

**Biztonic BizPOS** is an enterprise-grade, offline-first Point of Sale (POS) and Store Management system built with Flutter and Dart, backed by Firebase Firestore (`biztonic-pos-v2`) and local persistence (SQLite schema v27 and Hive NoSQL boxes).

### Core Stack
- **Framework**: Flutter 3.29.0 / Dart 3.7.0 (Web, Windows Desktop, Android, iOS)
- **State Management**: Dual architecture: Feature-driven DDD (Clean Architecture in `lib/features/`) & Central Providers (`lib/providers/`)
- **Cloud Backend**: Firebase Firestore, Firebase Auth, Cloud Storage, Firebase Functions
- **Local Persistence (Offline-First)**:
  - **SQLite (v27, WAL mode)**: Durable relational store for orders, movements, ledger, audit journal, offline auth.
  - **Hive (NoSQL Boxes)**: Ultra-fast key-value cache for UI reads (`cache_orders`, `cache_inventory`, `cache_stores`, `settings`).
- **Sync Architecture**: Outbox pattern with bi-directional sync engine (`lib/sync/sync_engine.dart`) and decoupled `EventBus`.

---

## 2. Strict Domain & Business Invariants (Zero Tolerance)

When creating or modifying features, these invariants must NEVER be violated:

### 2.1. Billing, Pricing & Taxes
1. **Paise Precision**: All monetary totals (`subtotal`, `cgst`, `sgst`, `igst`, `total`, `discount`, `roundOff`) must maintain strict 2-decimal precision. Floating point discrepancies are prohibited.
2. **Indian GST Rules**:
   - Intra-state orders: Tax rate is split into equal halves: `cgst = taxableAmount * (taxRate / 200)` and `sgst = taxableAmount * (taxRate / 200)`.
   - Inter-state orders: `igst = taxableAmount * (taxRate / 100)`.
   - Tax is calculated strictly on **net taxable amount after discount**: `taxableAmount = max(0.0, subtotal - discount)`.
3. **Discount Bounds**: Discounts cannot be negative and cannot exceed `subtotal`. Clamped strictly via `DiscountPolicy.validateAmount` and `DiscountPolicy.validatePercentage`.
4. **Order Status Lifecycle**:
   - States: `Pending` → `Completed` | `Voided` | `Refunded`.
   - Terminal states (`Voided`, `Refunded`) are immutable.

### 2.2. Inventory Tracking & Stock Persistence
1. **Stock Deductions**:
   - On checkout, stock must decrement immediately in `cache_inventory` (instant UI feedback) and persist to SQLite/Firestore via `InventoryRepositoryInterface` and `SyncBridge`.
   - On refund, stock must increment back by the refunded quantity.
   - If `Store.trackInventory == false` or `item.trackStock == false`, stock is not deducted.
2. **Negative Stock Policy**:
   - `block`: Throws `InsufficientStockException` if stock goes below zero.
   - `allowWithWarning`: Logs warning but completes checkout.
   - `allow`: Allows negative projection without warning.
3. **Ledger Immutability**: Every stock change creates an `InventoryMovement` entry with unique `operationId` (`sale_{orderId}_{itemId}`).

### 2.3. Multi-Store & Role Boundaries
1. **Three System Roles**:
   - `Super Admin`: Global access across all stores and system settings.
   - `Franchise Owner`: Eligible for multi-store management **only when the `franchise_management` add-on is active**.
   - `Store Owner`: Strictly limited to **1 store**. Adding additional stores is blocked at both UI and Provider layer (`DashboardProvider.canCreateAdditionalStore`).
2. **System Role Safeguard**: System roles (`Super Admin`, `Franchise Owner`, `Store Owner`) cannot be deleted or renamed.

### 2.4. Customer CRM & Khata (Udhari)
1. **Udhari Transactions**:
   - Types: `'borrow'` (credit debit/increase) and `'payment'` (settlement credit/decrease).
   - Balance tracking: `balanceAfter = previousBalance +/- amount`.
2. **Date Flexibility**: Dates must parse dynamically from `Timestamp`, `DateTime`, `int` (epoch ms), or ISO8601 `String` via `_parseDate`.

---

## 3. High-Density Codebase File Map

| Functional Subsystem | Primary Application / Domain Files | Persistence / State Layer |
| :--- | :--- | :--- |
| **Billing & POS** | `lib/features/billing/application/checkout_orchestrator.dart`<br>`lib/features/billing/domain/use_cases/calculate_tax.dart`<br>`lib/features/billing/domain/policies/order_policy.dart` | `lib/features/billing/data/repositories/billing_repository_impl.dart`<br>`lib/features/billing/presentation/providers/billing_provider.dart`<br>`lib/screens/pos_screen.dart` |
| **Inventory Management** | `lib/features/inventory/application/inventory_orchestrator.dart`<br>`lib/features/inventory/domain/policies/inventory_policy.dart` | `lib/features/inventory/presentation/providers/inventory_provider.dart`<br>`lib/services/inventory_movement_repository.dart`<br>`lib/screens/inventory_screen.dart` |
| **Store & Roles** | `lib/features/store/domain/entities/store.dart`<br>`lib/providers/store_provider.dart`<br>`lib/providers/dashboard_provider.dart` | `lib/screens/admin/franchise_screen.dart`<br>`lib/screens/admin/manage_roles_screen.dart` |
| **Customer CRM & Udhari** | `lib/models/customer_crm_models.dart`<br>`lib/providers/customer_provider.dart` | `lib/screens/customers_screen.dart`<br>`lib/screens/customer_detail_screen.dart` |
| **Offline Sync Engine** | `lib/sync/sync_engine.dart`<br>`lib/core/events/event_bus.dart`<br>`lib/core/events/app_events.dart` | `lib/sync/outbox/outbox_operation.dart`<br>`lib/sync/entitlements/entitlement_service.dart` |
| **Database & Caching** | `lib/services/database_helper.dart` (SQLite v27)<br>`lib/services/offline_service.dart` (Hive) | `Hive boxes`: `cache_orders`, `cache_inventory`, `cache_stores`, `settings`, `idempotency_keys_v1` |
| **Diagnostics & Auditing**| `lib/core/diagnostics/diagnostics_service.dart`<br>`lib/core/audit/audit_service.dart` | `lib/core/diagnostics/diagnostics_models.dart` |

---

## 4. End-to-End Data & Event Flows

### 4.1. Order Checkout Sequence
```
[PosScreen]
    │ User taps "Pay & Print"
    ▼
[BillingProvider / OrderProvider]
    │ execute checkout with idempotency key
    ▼
[CheckoutOrchestrator]
    ├── 1. OrderPolicy.canCreate() validation
    ├── 2. IdempotencyService.checkAndReserveKey() (prevents duplicate taps)
    ├── 3. CalculateTaxUseCase (calculates subtotal, CGST, SGST, IGST, roundOff)
    ├── 4. Decrement local Hive cache: Hive.box('cache_inventory')
    ├── 5. Atomic SQLite insert (Native) OR BillingRepository.insertOrder (Web)
    └── 6. EventBus.instance.fire(OrderCreatedEvent)
              │
              ├──► [SyncEngine / SyncBridge]
              │      ├── Queue 'orders' create
              │      ├── Queue 'business_events' create
              │      ├── Queue 'inventory_movements' create
              │      └── Queue 'inventory' update (persists new stock to cloud)
              │
              └──► [InventoryProvider]
                     ├── Decrements in-memory quantity
                     └── Updates stats & notifies UI listeners
```

---

## 5. Verification & Testing Standards

To verify the entire system with zero hallucination and complete reproducibility:

```bash
# 1. Run all unit tests (103 passing tests, 19 test files)
flutter test --concurrency=1 test/unit/

# 2. Run static analysis across entire lib directory (0 errors, 0 warnings)
dart analyze lib/

# 3. Targeted test execution examples:
flutter test test/unit/tax_calculation_test.dart
flutter test test/unit/inventory_stock_persistence_test.dart
flutter test test/unit/udhari_billing_test.dart
flutter test test/unit/franchise_owner_system_role_test.dart
flutter test test/unit/idempotency_test.dart
```

### Test Isolation Guard
Every unit test that accesses SQLite or Hive **must**:
1. Use isolated temp folders: `Directory.systemTemp.createTempSync(...)`.
2. Clean up in `tearDownAll`:
   ```dart
   tearDownAll(() async {
     await DatabaseHelper().close();
     DatabaseHelper.setDbName(null);
     await Hive.close();
     if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
   });
   ```

---

## 6. Feature Completion Matrix

| Feature Module | Implementation Status | Test Coverage |
| :--- | :--- | :--- |
| **POS Billing & Multi-Slab GST** | **Complete** (100%) | `test/unit/tax_calculation_test.dart`, `order_policies_test.dart` |
| **Inventory Tracking & Movement Ledger** | **Complete** (100%) | `test/unit/inventory_policies_test.dart`, `inventory_stock_persistence_test.dart` |
| **Offline Sync Outbox & Idempotency** | **Complete** (100%) | `test/unit/idempotency_test.dart`, `state_machines_test.dart` |
| **Customer CRM, Khata (Udhari), Coupons** | **Complete** (100%) | `test/unit/customer_crm_test.dart`, `udhari_billing_test.dart` |
| **Franchise / Multi-Store Role Restrictions**| **Complete** (100%) | `test/unit/franchise_owner_system_role_test.dart`, `multi_store_role_restriction_test.dart` |
| **Deterministic DB Migrations (v1 to v27)** | **Complete** (100%) | `test/unit/migrations_test.dart` |
| **Audit Service & Diagnostics** | **Complete** (100%) | `test/unit/audit_service_test.dart`, `diagnostics_service_test.dart` |
