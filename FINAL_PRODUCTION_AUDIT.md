# FINAL RED-TEAM PRODUCTION AUDIT REPORT
**Target System:** BizPOS-Clone  
**Date:** September 20, 2026  
**Audit Scope:** Full Codebase, Architecture, Security Rules, Financial Pipelines, Cryptography, Offline Synchronization, CI/CD, and Threat Model Simulation across 15 Attacker Profiles.  
**Auditor:** Red-Team Systems Security & Financial Integrity Audit Team  

---

## Executive Summary

A comprehensive adversarial red-team audit was performed against BizPOS-Clone across 15 realistic attacker profiles (malicious customer, rogue employee, dishonest store owner, anonymous public attacker, modified APK adversary, offline/online race attacker, concurrent multi-device user, and network MITM).

While recent refactorings have significantly improved the core architecture (consolidating checkout into `CheckoutOrchestrator`, adding atomic SQLite transaction journals, enforcing soft-delete tombstones, and establishing $O(1)$ keyset pagination), the system is **BLOCKED** from public production launch due to critical security and financial integrity vulnerabilities that can be exploited by modified clients, untrusted network traffic, or concurrent device interactions.

---

## Attacker Profile Simulation Matrix

| # | Attacker Persona | Exploitation Path Tested | Outcome | Risk Level |
| :--- | :--- | :--- | :--- | :--- |
| 1 | **Malicious Customer** | Inject arbitrary records into `central_catalog`; scrape unauthenticated users via `needsInitialPassword` | **VULNERABLE** | **HIGH** |
| 2 | **Malicious Employee** | Directly mutate existing orders in Firestore (change total, mark VOID, modify discounts) | **VULNERABLE** | **HIGH** |
| 3 | **Malicious Store Owner** | Elevate subscription plan or addons in Firestore; bypass order quota limits via direct API writes | **PARTIAL** (Firestore rules block plan update, but quotas are unenforced on cloud) | **HIGH** |
| 4 | **Malicious Anonymous User** | Query `/users/{uid}` where `needsInitialPassword == true`; spam `/leads` collection | **VULNERABLE** | **CRITICAL** |
| 5 | **Modified APK Adversary** | Connect to Firestore directly without Firebase App Check, bypassing all Dart client policies | **VULNERABLE** | **CRITICAL** |
| 6 | **Forged Local SQLite User** | Manipulate unencrypted SQLite ledger on rooted device to inject orders or alter cash balances | **VULNERABLE** (No SQLCipher/full-disk encryption) | **MEDIUM** |
| 7 | **Modified Hive Data User** | Inject forged employee with Owner role into unencrypted `cache_employees` to bypass offline PIN | **VULNERABLE** | **HIGH** |
| 8 | **Network Attacker** | Intercept hardcoded API key in `mcp_config_snippet.json`; target hardcoded admin emails | **VULNERABLE** | **CRITICAL** |
| 9 | **Duplicate-Request Attacker** | Double-tap checkout button rapidly to trigger duplicate order creation | **VULNERABLE** | **HIGH** |
| 10 | **Offline/Online Race Attacker** | Concurrently modify stock on two offline devices, producing negative inventory balance post-sync | **VULNERABLE** | **MEDIUM** |
| 11 | **Concurrent Multi-Device User**| Two cashiers sell the last unit of stock concurrently; both succeed, driving ledger negative | **VULNERABLE** (Eventual consistency oversell) | **MEDIUM** |
| 12 | **Subscription Bypass User** | Roll system clock back before 2025 to bypass clock tamper detection; exploit SQL args bug | **VULNERABLE** | **HIGH** |
| 13 | **Cross-Store Attacker** | Store A user accesses Store B data in Firestore and SQLite | **SAFE in Cloud, LEAK in SQLite** | **MEDIUM** |
| 14 | **Inventory Manipulator** | Repeated sync to duplicate stock deduction | **SAFE** (Inbox deduplication blocks duplicates) | **LOW** |
| 15 | **Financial Refund Abuser** | Repeated refund calls to extract multiple cash refunds | **SAFE** (Ledger limits refund to original sold quantity) | **LOW** |

---

## A. Security Findings

### 1. [CRITICAL / P0] Hardcoded Super Admin Email Addresses in Security Rules & Cloud Functions
- **Files:**
  - [`firestore.rules`](file:///d:/BizPOS_Clone/firestore.rules#L19-L21) (lines 19–21)
  - [`functions/index.js`](file:///d:/BizPOS_Clone/functions/index.js#L294-L295) (lines 294–295)
  - [`firebase_full_cleanup.js`](file:///d:/BizPOS_Clone/firebase_full_cleanup.js#L88)
  - [`initialize_production.js`](file:///d:/BizPOS_Clone/initialize_production.js#L28)
- **Evidence:**
  ```javascript
  // firestore.rules
  'email' in request.auth.token && 
  request.auth.token.email_verified == true && (
    request.auth.token.email.lower() == 'pthorat600@gmail.com'.lower() ||
    request.auth.token.email.lower() == 'biztonicautomation@gmail.com'.lower()
  )
  ```
  ```javascript
  // functions/index.js
  const callerEmailMatch = auth.token && auth.token.email && (
    auth.token.email.toLowerCase() === "pthorat600@gmail.com" ||
    auth.token.email.toLowerCase() === "biztonicautomation@gmail.com"
  );
  ```
- **Vulnerability:**
  Super Admin authorization is hardcoded to specific Gmail addresses in production security rules and backend Cloud Functions. If an attacker compromises or impersonates these email addresses, or if a provider verification bypass occurs, the attacker immediately gains unrestricted Super Admin access across the entire multi-tenant database.

### 2. [CRITICAL / P0] Unauthenticated Public Enumeration of User Documents
- **File:** [`firestore.rules`](file:///d:/BizPOS_Clone/firestore.rules#L83-L84) (lines 83–84)
- **Evidence:**
  ```javascript
  // 1. Users Collection (USER_PRIVATE)
  match /users/{uid} {
    // Allow unauthenticated read ONLY if the document is explicitly marked for initial password setup
    allow get: if (isAuthenticated() && (request.auth.uid == uid || isSuperAdmin())) || 
                  (resource.data.needsInitialPassword == true || resource.data.needsInitialPassword == 'true');
  ```
- **Vulnerability:**
  Any unauthenticated actor on the internet can read user profiles that have `needsInitialPassword == true`. This exposes user emails, phone numbers, roles, store assignments, and password reset metadata without authentication.

### 3. [CRITICAL / P0] Lack of Firebase App Check Protection
- **File:** [`lib/main.dart`](file:///d:/BizPOS_Clone/lib/main.dart), [`lib/firebase_options.dart`](file:///d:/BizPOS_Clone/lib/firebase_options.dart)
- **Evidence:**
  A search across `lib/` confirms that `FirebaseAppCheck` is not initialized or enforced.
- **Vulnerability:**
  Without App Check (Play Integrity on Android / DeviceCheck on iOS / reCAPTCHA on Web), an attacker with the publicly visible Firebase configuration (`projectId: bizpos-clone`) can run automated scripts or modified APKs to communicate directly with Firestore, bypassing all Flutter client-side validation logic (order limits, discount caps, negative stock policies).

### 4. [HIGH / P1] Public Item Creation in Central Catalog
- **File:** [`firestore.rules`](file:///d:/BizPOS_Clone/firestore.rules#L241-L245) (lines 241–245)
- **Evidence:**
  ```javascript
  // 8. Central Catalog (PLATFORM_ADMIN)
  match /central_catalog/{itemId} {
    allow read: if isAuthenticated();
    allow create: if isAuthenticated();
    allow update, delete: if isSuperAdmin();
  }
  ```
- **Vulnerability:**
  Any standard authenticated user (e.g. a cashier, staff member, or customer) can inject arbitrary records into the global `/central_catalog` collection.

### 5. [HIGH / P1] Hardcoded API Key in Repository Configuration
- **File:** [`mcp_config_snippet.json`](file:///d:/BizPOS_Clone/mcp_config_snippet.json#L10) (line 10)
- **Evidence:**
  ```json
  "env": {
    "API_KEY": "sk-user-WFfhjR2qK67GFkuyMVM"
  }
  ```
- **Vulnerability:**
  A live secret API key (`sk-user-WFfhjR2qK67GFkuyMVM`) is stored in plaintext in the repository, exposing the corresponding account and services to compromise.

### 6. [MEDIUM / P2] Unencrypted Offline Storage on Local Device
- **Files:**
  - [`lib/services/database_helper.dart`](file:///d:/BizPOS_Clone/lib/services/database_helper.dart#L71)
  - [`lib/widgets/employee_pin_dialog.dart`](file:///d:/BizPOS_Clone/lib/widgets/employee_pin_dialog.dart#L248-L260)
- **Evidence:**
  ```dart
  // DatabaseHelper.dart:71
  // Standard Open (No Encryption)
  return await openDatabase(path, ...);
  ```
- **Vulnerability:**
  SQLite databases and Hive boxes are stored without database encryption (SQLCipher / HiveCipher). On rooted or physical devices, an attacker can modify `cache_employees` to alter PIN hashes and roles, enabling local offline privilege escalation to Store Owner.

---

## B. Financial Integrity Findings

### 1. [HIGH / P1] Double-Tap Checkout Vulnerability (Idempotency Key Scope Failure)
- **Files:**
  - [`lib/providers/order_provider.dart`](file:///d:/BizPOS_Clone/lib/providers/order_provider.dart#L271) (line 271)
  - [`lib/features/billing/presentation/providers/billing_provider.dart`](file:///d:/BizPOS_Clone/lib/features/billing/presentation/providers/billing_provider.dart#L106-L135)
- **Evidence:**
  ```dart
  // OrderProvider.dart:271
  final idempotencyKey = const Uuid().v7();
  ```
  ```dart
  // BillingProvider.dart:115
  _setStatus(BillingStatus.loading);
  // No re-entrancy check if (isLoading) return;
  ```
- **Vulnerability:**
  `OrderProvider.placeOrder()` generates a brand new `Uuid().v7()` *inside* the method on every invocation. If a cashier or self-ordering kiosk user double-taps the checkout button, two concurrent calls execute with different idempotency keys. In addition, `BillingProvider.checkout()` does not reject re-entrant calls when `isLoading == true`. This results in two separate orders, double-charging the customer and deducting double inventory.

### 2. [HIGH / P1] SQL Parameter Alignment Bug in Subscription Limits Calculation
- **Files:**
  - [`lib/features/reporting/data/reporting_repository_mixin.dart`](file:///d:/BizPOS_Clone/lib/features/reporting/data/reporting_repository_mixin.dart#L24-L34) (lines 24–34)
  - [`lib/features/reporting/data/reporting_repository.dart`](file:///d:/BizPOS_Clone/lib/features/reporting/data/reporting_repository.dart#L24-L34) (lines 24–34)
- **Evidence:**
  ```dart
  Future<int> getOrderCountSince(String? storeId, DateTime since) async {
    final db = await dbHelper.database;
    String sql =
        "SELECT COUNT(*) FROM orders WHERE date >= ? AND (deletedAt IS NULL AND status NOT IN ('Cancelled', 'VOID', 'Refunded'))";
    List<dynamic> args = [since.toIso8601String()];
    if (storeId != null) {
      sql += ' AND storeId = ?';
      args.insert(0, storeId); // BUG: storeId inserted at index 0!
    }
    return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
  }
  ```
- **Vulnerability:**
  The query defines placeholder 1 as `date >= ?` and placeholder 2 as `storeId = ?`. However, line 31 prepends `storeId` to index 0 of `args`. The resulting execution tests `date >= storeId AND storeId = since`, which is type-incompatible and evaluates to false, consistently returning `0` orders. Consequently, subscription order limit enforcement based on `getOrderCountSince` is completely bypassed.

### 3. [HIGH / P1] Client-Side Clock Rollback Tamper Bypass
- **File:** [`lib/providers/dashboard_provider.dart`](file:///d:/BizPOS_Clone/lib/providers/dashboard_provider.dart#L3770-L3774) (lines 3770–3774)
- **Evidence:**
  ```dart
  if (nowMs < thresholdMs) {
    // System clock reset to default/epoch time (e.g. 1970/2020) due to offline boot.
    _isClockTampered = false;
    debugPrint('ℹ️ DashboardProvider: Clock reset detected (before 2025). Bypassing tamper check.');
  }
  ```
- **Vulnerability:**
  To bypass subscription expiration or tamper detection, an attacker can set the device clock to any date prior to January 1, 2025. The application treats this as an offline boot and explicitly resets `_isClockTampered = false`, allowing expired subscriptions to operate indefinitely.

### 4. [HIGH / P1] Firestore Rules Allow Arbitrary Modification of Orders by Store Staff
- **File:** [`firestore.rules`](file:///d:/BizPOS_Clone/firestore.rules#L252-L254) (lines 252–254)
- **Evidence:**
  ```javascript
  match /orders/{id} {
    allow update: if isSuperAdmin() || (resource.data.storeId != null && isStoreMember(resource.data.storeId) && 
                                         request.resource.data.storeId == resource.data.storeId);
  }
  ```
- **Vulnerability:**
  Any store member (including standard staff and cashiers) can update an existing order in Firestore. The rules contain no invariant checks to verify that `total`, `items`, `tax`, or `paymentMethod` remain immutable once finalized. A rogue employee can alter completed order totals to 0 or mark orders cancelled directly via Firestore.

---

## C. Offline/Sync Findings

### 1. [HIGH / P1] Cloud Quota Unenforced on Firestore Ingestion
- **File:** [`firestore.rules`](file:///d:/BizPOS_Clone/firestore.rules#L249-L255)
- **Evidence:**
  Orders synced to the cloud via `OutboundManager` (`batch.set(ref, payload)`) are accepted by Firestore solely based on `isStoreMember(storeId)`. There is no Firestore Cloud Function or rule constraint that evaluates `monthly_order_counter` or subscription plan limits. An attacker using a modified client can push unlimited orders directly to Firestore, bypassing the 50-order Basic plan limit.

### 2. [MEDIUM / P2] Negative Stock Drift from Concurrent Offline Checkouts
- **File:** [`lib/sync/inbound/pull_engine.dart`](file:///d:/BizPOS_Clone/lib/sync/inbound/pull_engine.dart#L155-L163)
- **Evidence:**
  When two offline devices concurrently sell the final remaining unit of an inventory item, both transactions succeed locally under `NegativeStockPolicy.block`. During sync, both distinct `inventory_movements` are pushed to Firestore and subsequently pulled into local SQLite ledgers. Because the ledger calculates stock via `SUM(delta)`, the final stock level drops to `-1`, violating the store's zero-negative-stock policy post-sync.

### 3. [MEDIUM / P2] Cross-Store Order Leakage in SQLite Multi-Store Devices
- **File:** [`lib/features/billing/data/order_repository_mixin.dart`](file:///d:/BizPOS_Clone/lib/features/billing/data/order_repository_mixin.dart#L302, #L384)
- **Evidence:**
  ```dart
  // Line 302:
  "SELECT * FROM orders WHERE isDeleted = 0 AND (deletedAt IS NULL OR status = 'Cancelled')"
  // Line 384:
  "SELECT * FROM orders WHERE synced = 0 AND (deletedAt IS NULL OR status = 'Cancelled')"
  ```
- **Vulnerability:**
  On devices where a single user manages multiple stores (Store A and Store B share the `biztonic_$uid.db` SQLite database), `getRecentOrders` and `getUnsyncedOrders` do not include a `WHERE storeId = ?` clause. Orders from Store B are returned when operating within Store A.

---

## D. Data Migration Findings

### 1. [RESOLVED IN PRE-AUDIT] SQLite Migration v1 -> v27 Test Invariant
- **File:** [`test/unit/migrations_test.dart`](file:///d:/BizPOS_Clone/test/unit/migrations_test.dart)
- **Status:** Verified and Passing.
- **Details:** The historical migration from schema v1 through v27 was verified. Table structures, unique composite indexes (`uq_employees_store_emp_id`, `uq_movements_store_operation`, `idx_orders_business_day`), and column additions (`isDeleted`, `version`, `businessDayId`) were validated without data loss.

---

## E. Performance Findings

### 1. [RESOLVED IN PRE-AUDIT] Performance Benchmarks
- **File:** [`PERFORMANCE_REPORT.md`](file:///d:/BizPOS_Clone/PERFORMANCE_REPORT.md), [`test/benchmark/workload_benchmark_test.dart`](file:///d:/BizPOS_Clone/test/benchmark/workload_benchmark_test.dart)
- **Status:** All 8 enterprise benchmarks pass:
  - 100,000 Orders History Keyset Page 1: **8.21 ms**
  - 10,000 Items Barcode Lookup: **5.83 ms**
  - 50,000 Customers Phone Search: **4.53 ms**
  - Atomic Checkout: **26.27 ms mean / 52.61 ms p95**
  - Sync Queue Processing Throughput: **10,309 ops/sec**

---

## F. Testing Gaps

1. **Firestore Emulator Rules Test Not Enforced Locally**:
   - `functions/test/tenant_isolation.test.js` requires an active Firebase emulator (`ECONNREFUSED 127.0.0.1:8085` when run standalone). Local developers running `npm test` fail unless the emulator suite is initialized.
2. **Missing Double-Tap Widget / Integration Test**:
   - No test exists in `test/widget/` or `test/integration/` that simulates two rapid consecutive taps on the POS checkout button to assert idempotency key reuse.
3. **No App Check Verification Test**:
   - Absence of automated tests verifying that requests without App Check tokens are rejected by Firestore.

---

## G. CI/CD Findings

1. **Fast PR Quality Gate Omits Firebase Rules Tests**:
   - `.github/workflows/flutter_ci.yml` runs Firebase emulator security tests only on `push` to `main` (lines 140–141). PRs do not execute emulator rules validation.
2. **Android Lint Failures Suppressed**:
   - `android/app/build.gradle` defines `lintOptions { abortOnError false; checkReleaseBuilds false; }`, allowing Android-level packaging and resource warnings into release binaries without failing the build.

---

## H. Comprehensive Issue Classification

| Priority | Issue ID | Title | Component |
| :--- | :--- | :--- | :--- |
| **P0** | SEC-01 | Hardcoded Super Admin Emails in Rules & Cloud Functions | `firestore.rules`, `functions/index.js` |
| **P0** | SEC-02 | Unauthenticated Public Enumeration of User Documents | `firestore.rules` |
| **P0** | SEC-03 | Missing Firebase App Check Enforcement | `main.dart`, GCP Console |
| **P1** | FIN-01 | Double-Tap Order Duplication (Internal UUID Generation) | `order_provider.dart`, `billing_provider.dart` |
| **P1** | FIN-02 | SQL Parameter Mismatch Bug in Order Count Calculation | `reporting_repository_mixin.dart` |
| **P1** | FIN-03 | Clock Rollback Tamper Check Bypass (< 2025) | `dashboard_provider.dart` |
| **P1** | SEC-04 | Mutable Orders in Firestore Rules (Staff Total Alteration) | `firestore.rules` |
| **P1** | SEC-05 | Public Item Creation in Central Catalog | `firestore.rules` |
| **P1** | SEC-06 | Hardcoded Secret API Key in Repository | `mcp_config_snippet.json` |
| **P1** | SYNC-01| Cloud Quota Unenforced on Direct Firestore Writes | `firestore.rules`, Cloud Functions |
| **P2** | SEC-07 | Unencrypted Local SQLite & Hive Storage (Offline PIN Bypass) | `database_helper.dart`, `employee_pin_dialog.dart` |
| **P2** | SYNC-02| Negative Stock Oversell on Concurrent Offline Checkouts | `pull_engine.dart`, `conflict_engine.dart` |
| **P2** | SYNC-03| Unfiltered Multi-Store Order Queries in SQLite | `order_repository_mixin.dart` |
| **P3** | CI-01  | PR Validation Omits Firebase Security Rules Suite | `flutter_ci.yml` |
| **P3** | BUILD-01| Android Release Lint Warnings Suppressed | `android/app/build.gradle` |

---

## I. Exact File Locations for Identified Vulnerabilities

1. **`SEC-01`**: [`firestore.rules:19-21`](file:///d:/BizPOS_Clone/firestore.rules#L19-L21), [`functions/index.js:294-295`](file:///d:/BizPOS_Clone/functions/index.js#L294-L295)
2. **`SEC-02`**: [`firestore.rules:83-84`](file:///d:/BizPOS_Clone/firestore.rules#L83-L84)
3. **`SEC-03`**: [`lib/main.dart:1-50`](file:///d:/BizPOS_Clone/lib/main.dart#L1-L50)
4. **`FIN-01`**: [`lib/providers/order_provider.dart:271`](file:///d:/BizPOS_Clone/lib/providers/order_provider.dart#L271), [`lib/features/billing/presentation/providers/billing_provider.dart:115`](file:///d:/BizPOS_Clone/lib/features/billing/presentation/providers/billing_provider.dart#L115)
5. **`FIN-02`**: [`lib/features/reporting/data/reporting_repository_mixin.dart:31`](file:///d:/BizPOS_Clone/lib/features/reporting/data/reporting_repository_mixin.dart#L31), [`lib/features/reporting/data/reporting_repository.dart:31`](file:///d:/BizPOS_Clone/lib/features/reporting/data/reporting_repository.dart#L31)
6. **`FIN-03`**: [`lib/providers/dashboard_provider.dart:3770-3774`](file:///d:/BizPOS_Clone/lib/providers/dashboard_provider.dart#L3770-L3774)
7. **`SEC-04`**: [`firestore.rules:252-254`](file:///d:/BizPOS_Clone/firestore.rules#L252-L254)
8. **`SEC-05`**: [`firestore.rules:241-245`](file:///d:/BizPOS_Clone/firestore.rules#L241-L245)
9. **`SEC-06`**: [`mcp_config_snippet.json:10`](file:///d:/BizPOS_Clone/mcp_config_snippet.json#L10)
10. **`SYNC-01`**: [`firestore.rules:249-255`](file:///d:/BizPOS_Clone/firestore.rules#L249-L255)
11. **`SEC-07`**: [`lib/services/database_helper.dart:71`](file:///d:/BizPOS_Clone/lib/services/database_helper.dart#L71)
12. **`SYNC-02`**: [`lib/sync/inbound/pull_engine.dart:155-163`](file:///d:/BizPOS_Clone/lib/sync/inbound/pull_engine.dart#L155-L163)
13. **`SYNC-03`**: [`lib/features/billing/data/order_repository_mixin.dart:302,384`](file:///d:/BizPOS_Clone/lib/features/billing/data/order_repository_mixin.dart#L302)

---

## J. Production Launch Blockers (Must Fix Prior to Launch)

1. **Eliminate Hardcoded Super Admin Emails**:
   Migrate all Super Admin checks to custom claims (`request.auth.token.role == 'super_admin'`) and the server-managed `/platform_admins/{uid}` collection. Purge hardcoded email literals.
2. **Close Unauthenticated User Read Hole**:
   Require authenticated user verification on `/users/{uid}`; replace public reads with a secure server-callable function (`verifyInitialPasswordToken`) that validates single-use tokens.
3. **Deploy Firebase App Check**:
   Enable App Check with Play Integrity (Android) and reCAPTCHA v3 / Enterprise (Web) across Firestore and Cloud Functions.
4. **Fix Idempotency Key Scoping & UI Debouncing**:
   Generate the `idempotencyKey` in the UI intent layer per customer action, pass it down through `BillingProvider` and `OrderProvider`, and enforce re-entrancy blocking (`if (_isProcessing) return;`).
5. **Fix SQL Parameter Alignment in `getOrderCountSince`**:
   Change `args.insert(0, storeId)` to `args.add(storeId)` to match the SQL statement (`WHERE date >= ? AND storeId = ?`).
6. **Enforce Order Immutability in Firestore Rules**:
   Add rule constraints preventing modification of `total`, `items`, `tax`, and `paymentMethod` on existing order documents.
7. **Purge Secret Key from Repository**:
   Rotate and revoke the exposed TestSprite API key in `mcp_config_snippet.json` and add the file to `.gitignore`.

---

## K. Recommended Post-Launch Hardening

1. **Implement SQLCipher Full-Database Encryption**:
   Encrypt SQLite databases using device-unique keys secured via Android KeyStore and iOS Keychain.
2. **Implement Server-Side Quota Enforcement (Cloud Run / Cloud Functions)**:
   Process cloud orders through a transactional Cloud Function that increments server-authoritative monthly quotas rather than permitting direct client `batch.set()` on root `/orders`.
3. **Cloud-Assisted Inventory Reconciliation**:
   Implement automated notification/alerts when inbound sync produces a negative stock balance due to concurrent offline sales.
4. **Add Double-Tap & Security Rules Gate to PR CI**:
   Run `firebase emulators:exec` inside PR workflows, not just on main branch push.

---

## Final Production Readiness Verdict

```
PRODUCTION_READINESS_STATUS: BLOCKED
```

**Reason:** Unresolved P0 security vulnerabilities (hardcoded Super Admin credentials in rules, unauthenticated user document exposure, absence of App Check) and P1 financial integrity bugs (double-tap order duplication and SQL argument mismatch in quota enforcement). Public rollout is blocked until these items are remediated.
