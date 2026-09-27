# BizPOS — Production QA Architecture & Repository Audit (`QA_ARCHITECTURE.md`)

**Generated:** 2026-09-24  
**Project:** `biztonic_pos` (`v1.0.4+12`)  
**Firebase Project Configured:** `biztonic-pos-v2` (`.firebaserc` — preserved untouched per Phase 0 Safety Rules)

---

## 1. Application Architecture Overview

BizPOS is an **Offline-First, Multi-Tenant Enterprise Point-of-Sale (POS) & ERP** built with Flutter (`>=3.0.0 <4.0.0`), targeting Android, Windows, Web, iOS, macOS, and Linux.

### Architectural Layers
1. **Presentation Layer (`lib/screens/`, `lib/widgets/`, `lib/core/design/`)**
   - Uses a hybrid state management model: `Provider` (`ChangeNotifierProvider` for `DashboardProvider`, `StoreProvider`, `OrderProvider`, `InventoryProvider`, `CustomerProvider`, `AuthProvider`) alongside `flutter_riverpod` (`^2.5.1`) for modular feature providers (`permissions_provider.dart`, `profile_provider.dart`, `store_provider.dart`).
   - Declarative routing via `go_router` (`lib/routes/app_router.dart`) with route-level authentication, role, and addon entitlement guards.
2. **Application / Orchestration Layer (`lib/features/*/application/`)**
   - `OrderOrchestrator`: Coordinates checkout validation, idempotency reservation, GST/CGST/SGST tax calculation, atomic SQLite order + movement persistence, and `OrderCreatedEvent` dispatch.
   - `InventoryOrchestrator`: Coordinates SKU/barcode validation, margin/expiry checks, idempotency, SQLite/Hive persistence, movement ledger seeding/adjustment, and `InventoryChangedEvent` dispatch.
   - `RefundOrchestrator` / `VoidOrchestrator`: Validates original sale quantities, enforces reversal ceilings, and appends immutable reversal movements (`REFUND`, `VOID_REVERSAL`).
3. **Domain Layer (`lib/features/*/domain/`)**
   - Pure Dart domain entities (`OrderEntity`, `InventoryEntity`, `InventoryMovement`, `StoreEntitlement`), policies (`OrderPolicy`, `InventoryPolicy`, `DiscountPolicy`), and use cases (`CalculateTaxUseCase`, `AdjustStockUseCase`).
4. **Data & Local Persistence Layer (`lib/services/`, `lib/features/*/data/`)**
   - **SQLite (`sqflite` / `sqflite_common_ffi`)**: Authoritative local relational store on native platforms (`DatabaseHelper` v19 schema) with tables: `orders`, `inventory`, `inventory_movements`, `cache_inventory_quantities`, `customers`, `business_ledger`, `sync_outbox`, `sync_conflicts`, `transaction_journals`, `audit_logs`, `idempotency_keys`.
   - **Hive (`hive_flutter`)**: Fast key-value cache and durable outbound queue (`sync_queue_v2`, `sync_failed_queue`, `entitlements_v1`, `cache_inventory`, `cache_orders_*`, `cache_customers_*`, `cache_stores`).
5. **Synchronization & Entitlement Kernel (`lib/sync/`, `lib/kernel/`)**
   - `SyncService` (`lib/sync/sync_engine.dart`) + `SyncOrchestrator`: Coordinates `OutboundManager` (durable outbox state machine: `PENDING -> IN_FLIGHT -> PUSHED -> CONFIRMED / FAILED -> DEAD_LETTER`), `PullEngine` (delta & full pulls per `SyncCollectionRegistry.pullModules`), `ConflictEngine` (LWW + pending-local-wins protection), `SyncMaintenanceEngine` (self-healing SQLite + Hive repair), and `EntitlementService` (server-authoritative plan & addon enforcement).
6. **Cloud Backend (`firestore.rules`, `functions/index.js`)**
   - Firebase Auth (`emailPassword`, Google Sign-In, and custom token Employee PIN auth via `verifyEmployeePin` Cloud Function).
   - Cloud Firestore with strict tenant isolation (`stores/{storeId}/members/{uid}`, `orders`, `inventory`, `inventory_movements`, `customers`, `business_events`, `subscription_requests`, `subscription_history`).

---

## 2. Dependencies Audit (`pubspec.yaml`)

| Category | Packages | QA / Testing Impact |
|---|---|---|
| **Core & State** | `provider: ^6.1.1`, `flutter_riverpod: ^2.5.1`, `go_router: ^14.3.0` | Requires provider/container harnesses for widget and integration testing. |
| **Local Persistence** | `sqflite: ^2.3.0`, `sqflite_common_ffi: ^2.3.0`, `hive: ^2.2.3`, `hive_flutter: ^1.1.0`, `flutter_secure_storage: ^9.0.0`, `shared_preferences: ^2.3.3` | `sqflite_common_ffi` enables real SQLite testing in headless Dart VM tests without mocking SQL queries. |
| **Cloud / Backend** | `firebase_core: ^4.5.0`, `cloud_firestore: ^6.1.3`, `firebase_auth: ^6.2.0`, `cloud_functions: ^6.0.7`, `firebase_app_check: ^0.4.0` | Requires Firebase Emulator Suite (`auth: 9099`, `firestore: 8085`, `functions: 5001`) and `@firebase/rules-unit-testing` for security rule verification. |
| **POS Hardware** | `flutter_blue_plus: ^1.36.0`, `usb_serial: ^0.5.2`, `esc_pos_utils_plus: ^2.0.4`, `flutter_thermal_printer`, `printing: ^5.11.1`, `pdf: ^3.10.8` | Physical Bluetooth/USB printers & scanners require connected hardware; ESC/POS byte generation and PDF generation can be tested in headless unit tests. |
| **Test Frameworks** | `flutter_test`, `integration_test`, `patrol: ^3.7.0`, `@firebase/rules-unit-testing: ^5.0.2`, `@playwright/test: ^1.60.0` | Full multi-layer test stack already declared in `pubspec.yaml` and `functions/package.json`. |

---

## 3. Testable Modules Inventory

1. **Tax, GST, Discount & Billing Engine**: `CalculateTaxUseCase`, `OrderPolicy`, `DiscountPolicy`, `OrderOrchestrator` (CGST/SGST split, inclusive vs exclusive tax, item-level + order-level discounts, round-off, multi-tender checkout).
2. **Immutable Inventory Ledger & Projections**: `InventoryMovementRepository`, `InventoryOrchestrator`, `AdjustStockUseCase` (`INITIAL_STOCK`, `SALE`, `REFUND`, `VOID_REVERSAL`, `ADJUSTMENT`, `TRANSFER_IN`, `TRANSFER_OUT`, `rebuildInventoryProjection`, `reconcileInventory`, negative stock blocking).
3. **Subscription & Addon Entitlements**: `EntitlementService`, `SubscriptionHistory`, `DashboardProvider.hasAddon`, `PermissionsHelper.hasAddon` (Basic/Standard/Enterprise plans, standalone addon purchases, unpurchased addon stripping, expiry/grace period).
4. **Role-Based Access Control (RBAC)**: `PermissionsHelper`, `DashboardProvider`, `EmployeePinDialog` (`Super Admin`, `Admin`, `Store Owner`, `Franchise Owner`, `Manager`, `Cashier`, `Kitchen Staff`, `Waiter`).
5. **Offline-First Outbox & Sync Engine**: `OutboxStore`, `OutboundManager`, `PullEngine`, `ConflictEngine`, `SyncMaintenanceEngine`, `RecoveryService` (`PENDING -> IN_FLIGHT -> PUSHED -> CONFIRMED` transitions, backoff/retry, SQLite + Hive self-healing, crash journal recovery).
6. **Firestore Security Rules (`firestore.rules`)**: Tenant isolation (`Store A` vs `Store B`), privilege escalation prevention (`role`, `accessibleStoreIds`, `subscriptionPlan`, `purchasedAddons`), append-only ledgers (`inventory_movements`, `business_events`, `activity_logs`), finalized order immutability.

---

## 4. External Dependencies & Hardware Boundaries

- **Firebase Services**: Auth, Firestore, Cloud Functions, Crashlytics, App Check.
- **Physical POS Peripherals**:
  - Bluetooth Thermal Printers (`flutter_blue_plus`, `flutter_thermal_printer`)
  - USB Serial Thermal Printers (`usb_serial`)
  - HID / USB / Camera Barcode Scanners
- **Connected Test Devices Detected (`flutter devices`)**:
  - `Windows (desktop) • windows-x64` (Available)
  - `Chrome (web) • web-javascript` (Available)
  - `Edge (web) • web-javascript` (Available)
  - *Physical Android Device / Physical Bluetooth Thermal Printer / Physical USB Barcode Scanner*: Not currently attached via USB/ADB (`NOT EXECUTED — HARDWARE REQUIRED` for physical peripheral I/O; ESC/POS payload & barcode logic verified in software).

---

## 5. High-Risk Areas Identified During Audit

1. **Entitlement & Addon Leakage Race Conditions (Fixed & Regression-Guarded)**:
   - Mixed-case `'Active'` vs `'ACTIVE'` in `SubscriptionHistory.isActive`.
   - `DashboardProvider._checkAndAutoActivateReadySubs` previously either wiped `addons` when `isAddonOnly == true` or merged stale unpurchased addons from `activeStore!.addons` / `Hive` cache.
   - `approveSubscriptionRequest` previously omitted `purchasedAddons` when constructing `StoreEntitlement`.
2. **Inventory Stock Resetting to Zero on Re-Login / Cloud Pull (Fixed & Regression-Guarded)**:
   - `SyncCollectionRegistry.pullModules` previously pulled `inventory` before `inventoryMovements`, causing `InventorySyncAdapter.onPullComplete` to run `rebuildInventoryProjection` against an empty `inventory_movements` table and overwrite every item's `quantity` with `0`.
   - `InventoryOrchestrator.upsertItem` and `AdjustStockUseCase` previously did not queue `inventory_movements` to `SyncService`.
3. **Data Center Stuck in `"Sync Pending"` (Fixed & Regression-Guarded)**:
   - `OutboxStore.markBatchConfirmed` previously left `'CONFIRMED'` operations inside `sync_queue_v2`, and `SyncService.pendingUploadCount` / `getDetailedStats` counted all records in `sync_queue_v2` regardless of state.
   - `SyncMaintenanceEngine.repairUnsyncedItems` previously scanned only Hive boxes and missed `PENDING` rows in native SQLite tables.

---

## 6. Current Test Coverage vs Missing Test Coverage

### Existing Test Suites (`test/` & `functions/test/`)
- **Unit (`test/unit/`, `test/domain/`)**: Tax calculation, discount validation, order/inventory/entitlement policies, idempotency, migrations, serialization, state machines, conflict resolution, audit service.
- **Application (`test/application/`)**: Checkout, customer updates, employee changes, refunds, voids, stock adjustments, subscription rules.
- **Repository (`test/repository/`)**: Outbox store, projection rebuild, recovery service, SQLite transaction rollback, uniqueness constraints.
- **Sync & Concurrency (`test/sync/`, `test/concurrency/`)**: Multi-device sync recovery, financial concurrency, durable outbox sync.
- **Security (`test/security/`, `functions/test/tenant_isolation.test.js`)**: Multi-tenant isolation, offline auth security, Firestore security rules.

### Gaps to Fill in Phase 2–Phase 10
1. **Dedicated Regression Suite (`test/qa_production_mission_test.dart`)** covering:
   - Issue 1: Standalone addon purchase on Basic/Standard plan, unpurchased addon stripping, case-insensitive `SubscriptionHistory`, role matrix (`Super Admin`, `Owner`, `Manager`, `Cashier`, `Waiter`, `Kitchen Staff`) ALLOW/DENY verification.
   - Issue 2: Inventory stock preservation across logout/re-login, `rebuildInventoryProjection` and `reconcileInventory` when `inventory_movements` has missing `INITIAL_STOCK`, `InventoryOrchestrator.upsertItem` delta movement queuing, `AdjustStockUseCase` cloud queuing, negative stock protection.
   - Issue 3: `OutboxStore` confirmation pruning from `sync_queue_v2`, `SyncService.pendingUploadCount` & `pendingBreakdown` filtering, `SyncMaintenanceEngine` SQLite + Hive self-healing, `OutboundManager.processQueue` multi-batch draining with `forceManual: true`.
   - Comprehensive GST (CGST + SGST, inclusive/exclusive, discounts, round-off), rapid double-checkout idempotency, partial/full returns, and large-dataset performance benchmarks (1,000 and 10,000 products + 100,000 ledger movements).
2. **Automated QA Runner (`scripts/run_qa.ps1` & `scripts/run_qa.sh`)** and QA Documentation (`docs/QA_TEST_PLAN.md`, `docs/QA_TEST_RESULTS.md`, `docs/QA_FAILURES.md`).
