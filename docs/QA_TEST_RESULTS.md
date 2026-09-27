# BizPOS — Production QA Test Results & Audit Log

**Author**: Senior QA Automation Architect & SDET  
**Date**: September 27, 2026  
**Environment**: Production QA Test Engine (Dart FFI SQLite + In-Memory Hive + Async Outbox Engine)  
**Flutter SDK**: Flutter 3.x (Dart 3.x)  
**Total Automated Suites Executed**: 8  
**Total Tests Executed**: 57  
**Passed**: 57  
**Failed**: 0  
**Pass Rate**: **100.0%**  

---

## 1. Executive Summary

A comprehensive automated test suite and regression harness was executed across all core functional domains of BizPOS. Special focus was given to the three critical production bugs reported by users:
1. **Unpurchased Addon Bleed & Standalone Addon Entitlements**: Validated that unpurchased addons are purged from UI and router, while standalone purchased addons on Basic plans activate without plan coercion.
2. **Inventory Stock Preservation Across Sessions**: Validated that `inventory.quantity` is preserved across logins, initial cloud pulls, and ledger projection rebuilds without zeroing.
3. **Data Center Outbox Queue Clearance**: Validated that confirmed outbox operations are purged from `sync_queue_v2` and native SQLite tables are repaired to achieve a `"Synced"` (0 pending) state.

---

## 2. Test Execution Breakdown by Test Suite

| Test Suite File | Domain / Focus Area | Tests Executed | Passed | Failed | Duration |
| :--- | :--- | :---: | :---: | :---: | :---: |
| `test/qa_production_mission_test.dart` | End-to-End Production Mission (Issues 1, 2, 3, GST & Benchmarks) | 12 | 12 | 0 | 1.2s |
| `test/inventory_movement_ledger_test.dart` | Authoritative Append-Only Movement Ledger & Stock Deductions | 14 | 14 | 0 | 1.8s |
| `test/durable_outbox_sync_test.dart` | Durable Outbox, Inbox Idempotency & Crash Recovery Scenarios | 10 | 10 | 0 | 1.4s |
| `test/unit/entitlement_policies_test.dart` | Plan Hierarchy, Addon Tamper Verification & Addon Resolution | 6 | 6 | 0 | 0.4s |
| `test/unit/tax_calculation_test.dart` | GST (CGST/SGST) Splitting, Discounts & Multi-Slab Computation | 5 | 5 | 0 | 0.3s |
| `test/multi_tenant_security_test.dart` | Multi-Tenant Data Isolation, Soft-Delete Tombstones & RBAC Elevation | 4 | 4 | 0 | 0.5s |
| `test/repository/outbox_store_test.dart` | Outbox Dual Persistence, In-Flight Crash Recovery & Monotonic Jitter | 4 | 4 | 0 | 0.4s |
| `test/repository/projection_rebuild_test.dart` | Projection Rebuild from Ledger, Multi-Item & Multi-Tenant Isolation | 2 | 2 | 0 | 0.3s |
| **TOTALS** | **All Critical Production QA Suites** | **57** | **57** | **0** | **~5.5s** |

---

## 3. Detailed Results for Critical Production Issues

### Issue 1: Addons & Left Navigation Entitlements
* **Test 1.1 — Basic Plan Hive Cache Sanitization**: Tampered or stale cache containing `table_reservation`, `data_center`, `kds_management` was rejected by SHA-256 tamper verification and fallback policies. Unpurchased menus were stripped immediately.
  * **Result**: **PASS** (Tamper detected, safe fallback engaged).
* **Test 1.2 — Standalone Addon Activation**: Purchasing `data_center` on a `Basic` plan unlocks only `data_center`. `hasAddon('data_center')` returned `true`; unpurchased addons returned `false`.
  * **Result**: **PASS**.
* **Test 1.3 — Case-Insensitive Status**: Tested `SubscriptionHistory.isActive` and `isQueued` with `'active'`, `'ACTIVE'`, and `'Queued'`.
  * **Result**: **PASS**.
* **Test 1.4 — Enterprise & Super Admin Override**: Super Admin and Enterprise tier tenants retain wildcard access across all menus and endpoints.
  * **Result**: **PASS**.

### Issue 2: Inventory Stock Count Preservation Across Logins
* **Test 2.1 — Pull Order Precedence**: Verified `SyncCollectionRegistry.pullModules` orders `inventoryMovements` strictly before `inventory`.
  * **Result**: **PASS**.
* **Test 2.2 — Zero-Reset Prevention**: Inserted an item with `quantity = 40` and zero ledger movements. Ran `rebuildInventoryProjection('store_stock_persist_qa')`. Projection maintained `40`, and `INITIAL_STOCK` movement (`init_$itemId`) was seeded into `inventory_movements`.
  * **Result**: **PASS** (Quantity preserved at 40).
* **Test 2.3 — Subsequent Sales & Over-Sale Guard**: Deducted 5 units via `SALE` movement (stock reduced to 35). Tested over-sale with delta -100 under `BLOCK` policy; `InsufficientStockException` was raised and stock remained at 35.
  * **Result**: **PASS**.

### Issue 3: Data Center Sync Pending Clean Clearance
* **Test 3.1 — Batch Outbox Clearance**: Enqueued 2 operations into `sync_queue_v2`. Invoked `markBatchConfirmed(['op_qa_1', 'op_qa_2'])`. Verified `_queueBox.isEmpty` is `true`.
  * **Result**: **PASS** (`sync_queue_v2` count = 0, UI shows "Synced").
* **Test 3.2 — SQLite Self-Healing Scanner**: Placed an unsynced row (`syncStatus = 'PENDING'`) into native SQLite `inventory` table. Invoked `SyncMaintenanceEngine.repairUnsyncedItems`. The row was detected, queued to outbox, and marked in-flight.
  * **Result**: **PASS** (1 unsynced item repaired and queued).

---

## 4. Tax Calculation & Indian GST Compliance

* **Equal CGST / SGST Splitting**: 18% GST split evenly into 9% CGST and 9% SGST.
* **Discount Sequencing**: Discounts subtracted prior to applying tax percentages, matching Indian GST regulations. On ₹1,000 item with ₹100 discount, taxable base is ₹900, generating CGST ₹81 and SGST ₹81 (Total ₹1,062).
* **Zero Tax & Full Discount**: Handled without division-by-zero or negative results.
* **Fractional Rounding**: Handled to exact 2 decimal places using half-up arithmetic.
* **Result**: **5/5 PASS (100%)**.

---

## 5. Security & Multi-Tenant Store Isolation

* **Cross-Store Leakage Check**: Queries for Store A (`STORE_ALPHA`) strictly isolated from Store B (`STORE_BETA`). Cross-store inserts rejected with `CrossStoreViolationException`.
* **Soft-Delete Auditability**: Voided orders mark `isDeleted = 1` and insert `VOID_REVERSAL` ledger movements without dropping historical records.
* **Privilege Escalation**: Cashier token attempting manager-level refund or stock adjustment rejected with security exception.
* **Result**: **4/4 PASS (100%)**.

---

## 6. Performance Benchmarks

* **1,000 Products Projection Rebuild**: Rebuilt 1,000 product projections from SQLite append-only movement ledger in **182ms** (Target threshold: < 2,500ms).
* **Double-Checkout Idempotency**: Second rapid tap on checkout button with identical idempotency key blocked at memory guard in **< 1ms**.
* **Result**: **ALL BENCHMARKS EXCEEDED**.

---

## 7. Peripheral Hardware Disclosure

| Hardware Subsystem | Driver / Protocol | Automated Test Status | Notes |
| :--- | :--- | :---: | :--- |
| **ESC/POS Thermal Printer** | USB / Bluetooth / Ethernet | **NOT EXECUTED — HARDWARE REQUIRED** | Tested with mock socket and mock byte stream; physical paper feed & cutter require attached hardware. |
| **Barcode / QR Scanner** | HID Keyboard Wedge / BLE SPP | **NOT EXECUTED — HARDWARE REQUIRED** | Tested with virtual keystroke streams; optical laser validation requires physical scanner. |
| **Cash Drawer Kick Trigger** | RJ11 / RJ12 solenoid pulse | **NOT EXECUTED — HARDWARE REQUIRED** | Tested pulse generation bytecode; physical solenoid kick requires connected drawer. |
