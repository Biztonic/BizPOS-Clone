# BizPOS — Comprehensive Production QA Test Plan (`QA_TEST_PLAN.md`)

**Version:** 1.0.4+12  
**Date:** 2026-09-24  

---

## 1. Testing Pyramid Strategy

| Level | Scope | Tools & Harnesses | Target |
|---|---|---|---|
| **Level 1: Static Analysis** | Type safety, lint rules, dead code, duplicate definitions | `dart analyze`, `flutter analyze --no-fatal-infos` | 0 Errors, 0 Warnings |
| **Level 2: Unit & Domain** | Tax (CGST/SGST), Discounts, Round-off, Entitlements, Policies, Idempotency | `flutter_test` (`test/unit/`, `test/domain/`, `test/qa_production_mission_test.dart`) | 100% pass rate on financial & policy invariants |
| **Level 3: Repository & SQLite Ledger** | `sqflite_common_ffi` in-memory/temp-dir SQLite + `hive` outbox, projections, transactions, rollbacks | `flutter_test` (`test/repository/`, `test/inventory_movement_ledger_test.dart`, `test/durable_outbox_sync_test.dart`) | Atomic ACID compliance, zero stock drift |
| **Level 4: Firebase & Security Rules** | Firestore Security Rules, Multi-Tenant Store Isolation, RBAC | `@firebase/rules-unit-testing` (`functions/test/tenant_isolation.test.js`) + `test/multi_tenant_security_test.dart` | Strict DENY on cross-store & privilege escalation |
| **Level 5: Application & E2E Scenarios** | Checkout, Refunds, Voids, Stock Adjustments, Subscription Upgrades, Offline-First Sync | `test/application/`, `test/e2e/`, `integration_test/` | Zero duplicate orders/movements, full offline-to-online recovery |

---

## 2. Master Test Scenario Catalog (Scenarios 1–82 + Offline + Chaos + Security)

### A. Authentication & Session (Scenarios 1–9)
- **TC-01..05**: User Registration, Login, Invalid Credentials rejection, Logout session cleanup, Offline cached session persistence (`test/hardened_auth_offline_test.dart`).
- **TC-06**: Google Sign-In token exchange (`AuthProvider`).
- **TC-07..08**: Employee PIN login (`SHA-256(pin + uid)`) & Incorrect PIN rejection (`test/offline_auth_security_test.dart`).
- **TC-09**: Unauthorized store access blocked at both client (`StoreProvider`) and Firestore rules (`isStoreMember`).

### B. Store Management & Multi-Tenant Isolation (Scenarios 10–15)
- **TC-10..12**: Store creation, active store selection, store switching with Hive/SQLite cache isolation.
- **TC-13..15**: Cross-store isolation (`Store A` user reading/writing `Store B` orders, inventory, or customers strictly denied in `test/multi_tenant_security_test.dart` and `functions/test/tenant_isolation.test.js`).

### C. Products & Catalog (Scenarios 16–25)
- **TC-16..25**: Product creation, edit, soft-delete (`deletedAt`), restore, indexed search by SKU/Barcode/Name/Category, unit/variant handling, and duplicate idempotency guard (`test/application/stock_adjustment_application_test.dart`, `test/qa_production_mission_test.dart`).

### D. Inventory & Immutable Ledger (Scenarios 26–34)
- **TC-26**: Opening stock (`INITIAL_STOCK`) creation and preservation across logout/re-login (`test/qa_production_mission_test.dart` Test 2.2).
- **TC-27..30**: Purchase stock (`PURCHASE`), Sales stock deduction (`SALE`), Stock adjustment (`ADJUSTMENT`), and Return stock restoration (`REFUND` / `VOID_REVERSAL`).
- **TC-31..32**: Low stock threshold detection and Negative Stock Protection (`InsufficientStockException` under `NegativeStockPolicy.block`, `test/qa_production_mission_test.dart` Test 2.3).
- **TC-33..34**: Offline stock change and outbound cloud synchronization (`inventory` + `inventory_movements`).

### E. Customers, Suppliers & Purchases (Scenarios 35–48)
- **TC-35..39**: Customer creation, edit, search, duplicate guard, and credit/order history (`test/application/customer_update_application_test.dart`).
- **TC-40..48**: Supplier CRUD, purchase order stock inwarding, purchase cancellation/return, and GST input calculations.

### F. Sales, Checkout, Returns & Reports (Scenarios 49–82)
- **TC-49..60**: Multi-item sale, quantity updates, item & order discounts, GST (`CGST` + `SGST` 50/50 split), round-off, cash/UPI/card/split/credit tender modes (`test/unit/tax_calculation_test.dart`, `test/qa_production_mission_test.dart` Test 4.1).
- **TC-61..69**: Normal checkout, rapid double-tap checkout idempotency (`IdempotencyService`), network/database interruption rollback, and verification of zero duplicate invoices or stock deductions (`test/application/checkout_application_test.dart`, `test/qa_production_mission_test.dart` Test 4.2).
- **TC-70..74**: Full return, partial return, invalid excess return quantity rejection (`InvalidRefundException`), and stock restoration (`test/application/refund_application_test.dart`).
- **TC-75..82**: Daily/monthly sales aggregation, product/customer/inventory/GST reports, profit calculation, and date range filtering.

### G. Offline-First & Sync State Machine (Scenarios A–K)
- **TC-SYNC-A..K**: `PENDING -> IN_FLIGHT -> PUSHED -> CONFIRMED` transitions, confirmation cleanup from `sync_queue_v2`, `SyncMaintenanceEngine` SQLite + Hive self-healing, exponential backoff + manual `ignoreBackoff` override (`test/durable_outbox_sync_test.dart`, `test/qa_production_mission_test.dart` Tests 3.1–3.2).
