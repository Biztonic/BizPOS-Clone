# BizPOS — Production Defect Log & Root Cause Analysis (`QA_FAILURES.md`)

**Generated:** 2026-09-24  

---

## Bug Classification Summary

| Severity | Definition | Discovered | Fixed & Verified | Open |
|---|---|---|---|---|
| **P0** | Data loss, stock corruption, security/entitlement bypass, or critical blocker | 3 | 3 | 0 |
| **P1** | Major business functionality broken (addon purchase reflection, sync pending lock) | 3 | 3 | 0 |
| **P2** | Important defect with workaround | 1 | 1 | 0 |
| **P3/P4** | Minor UI / lint / code-style improvements | 0 | 0 | 0 |

---

## Detailed Defect Records

### BUG-001 (P0 / P1) — Purchased Addons Not Reflected & Unpurchased Addons Shown in Sidebar
- **Test ID**: `qa_production_mission_test.dart` (`1.1`, `1.2`, `1.3`)
- **Feature**: Subscription & Addon Entitlements (`EntitlementService`, `DashboardProvider`, `StoreProvider`, `PermissionsHelper`, `AddonDetailScreen`)
- **Steps to Reproduce**:
  1. Log in with a `Basic` or `Standard` plan store that had historical/cached addons in Hive (`entitlements_v1`) or purchase a standalone addon (`isAddonOnly: true`).
  2. Observe the left sidebar menu and `BizStoreScreen`.
- **Expected Result**:
  - Only verified, paid addons (`purchasedAddons ∩ addons`) appear in the sidebar and are accessible.
  - Standalone purchased addons (`isAddonOnly: true`) immediately activate and appear in the user's account.
  - Zero unpurchased addons appear on `Basic` or `Standard` plans.
- **Actual Result (Before Fix)**:
  1. `SubscriptionHistory.isActive` checked `status != 'ACTIVE'` (case-sensitive), while `StoreProvider.addStore` wrote `'status': 'Active'`, causing `isActive` to evaluate to `false`.
  2. `DashboardProvider._checkAndAutoActivateReadySubs` filtered `activeBaseSub = activeSubs.where((h) => !h.isAddonOnly && ...)`. When a user bought a standalone addon (`isAddonOnly == true`), `activeBaseSub` was empty, so it skipped activating `selectedAddons` and fell through to line 889 where it wiped `addons` to `[]`!
  3. Conversely, when `activeBaseSub` was non-empty, lines 820–823 unioned `...activeStore!.addons` and `...activeStore!.purchasedAddons` (re-injecting unpurchased legacy addons), and `EntitlementService.syncFromStore` merged `...current.purchasedAddons` from Hive cache.
  4. `DashboardProvider.approveSubscriptionRequest` omitted `purchasedAddons` when calling `StoreEntitlement.create(...)`.
- **Affected Files**:
  - `lib/sync/entitlements/entitlement_service.dart`
  - `lib/features/store/domain/entities/subscription_history.dart`
  - `lib/providers/dashboard_provider.dart`
  - `lib/providers/store_provider.dart`
  - `lib/features/auth/providers/permissions_provider.dart`
  - `lib/screens/settings/addon_detail_screen.dart`
- **Fix Implemented**:
  - Made `SubscriptionHistory.isActive` and `isQueued` case-insensitive.
  - Updated `EntitlementService.syncFromStore` and `hasAddon` so `effectivePurchased` never merges stale Hive cache entries and requires an addon to be both installed (`addons`) and purchased (`purchasedAddons`).
  - Updated `DashboardProvider._checkAndAutoActivateReadySubs` and `approveSubscriptionRequest` to compute `verifiedPurchased` strictly from active `subscription_history` + approved `subscription_requests`, stripping any unpurchased addons while activating standalone addon purchases (`isAddonOnly`).
- **Final Status**: **FIXED & VERIFIED** (`test/qa_production_mission_test.dart` group 1).

---

### BUG-002 (P0) — Inventory Stock Count Resets to Zero (`0`) on Next Login
- **Test ID**: `qa_production_mission_test.dart` (`2.1`, `2.2`, `2.3`)
- **Feature**: Inventory Ledger & Cloud Pull Projection Rebuild (`InventoryMovementRepository`, `SyncCollectionRegistry`, `InventoryOrchestrator`, `AdjustStockUseCase`, `InventoryRepositoryImpl`)
- **Steps to Reproduce**:
  1. Create or edit inventory items with positive stock (`quantity > 0`), then log out and log back in (or trigger cloud pull).
  2. Open the Inventory screen.
- **Expected Result**:
  - All inventory item quantities are preserved accurately across logout and re-login.
- **Actual Result (Before Fix)**:
  1. `SyncCollectionRegistry.pullModules` pulled `inventory` (index 1) BEFORE `inventoryMovements` (index 9). When `inventory` finished pulling, `InventorySyncAdapter.onPullComplete` called `rebuildInventoryProjection(storeId)` before `inventory_movements` were even downloaded!
  2. Furthermore, `InventoryOrchestrator.upsertItem` and `AdjustStockUseCase` inserted movements only into local SQLite `inventory_movements` and never called `SyncService().queueOperation(collection: 'inventory_movements', ...)`, so Firestore `inventory_movements` had 0 rows for those items!
  3. `rebuildInventoryProjection` executed `final quantity = ledgerSums[itemId] ?? 0;`, overwriting every item's `inventory.quantity` in SQLite and Hive with `0`!
- **Affected Files**:
  - `lib/sync/registry/sync_collection_registry.dart`
  - `lib/services/inventory_movement_repository.dart`
  - `lib/features/inventory/application/inventory_orchestrator.dart`
  - `lib/features/inventory/domain/use_cases/adjust_stock.dart`
  - `lib/features/inventory/data/repositories/inventory_repository_impl.dart`
  - `lib/sync/sync_engine.dart`
- **Fix Implemented**:
  - Moved `inventoryMovements` before `inventory` in `SyncCollectionRegistry.pullModules`.
  - Updated `InventoryMovementRepository.rebuildInventoryProjection`, `reconcileInventory`, and `_getItemQuantityWithTxn` to preserve `currentQty` (`inventory.quantity`) and automatically seed the missing `init_$itemId` (`INITIAL_STOCK`) movement into `inventory_movements` whenever an item has no `INITIAL_STOCK` ledger entry.
  - Updated `InventoryOrchestrator.upsertItem`, `AdjustStockUseCase`, and `SyncService` (`OrderCreatedEvent`) to queue all `INITIAL_STOCK` / `ADJUSTMENT` movements and updated `inventory` items to Firestore.
- **Final Status**: **FIXED & VERIFIED** (`test/qa_production_mission_test.dart` group 2).

---

### BUG-003 (P1) — Data Control Center Stuck Showing `"Sync Pending"`
- **Test ID**: `qa_production_mission_test.dart` (`3.1`, `3.2`)
- **Feature**: Outbox Store, Outbound Manager & Data Sync Control Screen (`OutboxStore`, `OutboundManager`, `SyncService`, `SyncMaintenanceEngine`, `DataSyncControlScreen`)
- **Steps to Reproduce**:
  1. Perform local POS operations (add item, create order) while online and open **Data Center** (`DataSyncControlScreen`).
- **Expected Result**:
  - All pending items flush to Firestore and Data Center transitions to `"Synced"` (`0 Pending`).
- **Actual Result (Before Fix)**:
  1. `OutboxStore.markBatchConfirmed` updated `state: 'CONFIRMED'` inside Hive `sync_queue_v2` without deleting the entries from `sync_queue_v2`.
  2. `SyncService.pendingUploadCount` and `getDetailedStats()['pendingBreakdown']` iterated over `_queueBox!.values` without filtering by `val['state']`, counting every `'CONFIRMED'` and `'PUSHED'` entry as `"Pending"` forever!
  3. `SyncMaintenanceEngine.repairUnsyncedItems` only scanned Hive boxes and ignored `PENDING` rows in native SQLite tables (`inventory`, `orders`, `customers`, `inventory_movements`).
  4. `SyncService.refreshLocalCounts` called `unawaited(refreshCloudCounts(notify: false))`, so UI listeners were never notified when cloud counts finished loading.
- **Affected Files**:
  - `lib/sync/outbox/outbox_store.dart`
  - `lib/sync/outbound/outbound_manager.dart`
  - `lib/sync/orchestrator/sync_orchestrator.dart`
  - `lib/sync/maintenance/sync_maintenance.dart`
  - `lib/sync/sync_engine.dart`
  - `lib/screens/settings/data_sync_control_screen.dart`
- **Fix Implemented**:
  - Updated `OutboxStore.markConfirmed` and `markBatchConfirmed` to delete confirmed entries from `sync_queue_v2`, and added automatic purging of `'CONFIRMED'` / `'PUSHED'` entries in `getReadyOperations`.
  - Filtered `SyncService.pendingUploadCount` and `pendingBreakdown` to count only `PENDING`, `IN_FLIGHT`, and `FAILED` entries.
  - Added native SQLite table scanning (`inventory`, `orders`, `customers`, `inventory_movements`) to `SyncMaintenanceEngine.repairUnsyncedItems`.
  - Updated `OutboundManager.processQueue` to drain all ready batches in a loop and honor `ignoreBackoff: forceManual`, and updated `DataSyncControlScreen.initState` to auto-trigger `processSync(forceManual: true)` when opened online.
- **Final Status**: **FIXED & VERIFIED** (`test/qa_production_mission_test.dart` group 3).
