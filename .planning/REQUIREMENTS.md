# BizPOS Requirements: Production Hardening

## Milestone: Production Hardening
Goal: Make BizPOS safe for real-world retail operations and release-ready for Android APK distribution.

### 1. Security & Access Control (SEC)
- [ ] **SEC-01**: Firestore rules strictly deny reads/writes unless authenticated, active store member, and role requirements pass.
- [ ] **SEC-02**: All financial mutations (order creation, void/refund, stock adjustment, payment status) handled via server-authoritative Cloud Functions.
- [ ] **SEC-03**: No direct client-side writes allowed to finalize orders or modify stock levels without server transactional validation.
- [ ] **SEC-04**: Firebase App Check and auth token validation enforced for sensitive mutations.

### 2. POS Transaction Integrity (TX)
- [ ] **TX-01**: Order creation executes as an atomic transaction validating cart totals, locking/deducting inventory, and writing order record once.
- [ ] **TX-02**: Idempotency keys (`operationId` / `idempotencyKey`) prevent duplicate deductions and duplicate financial entries on network retries.
- [ ] **TX-03**: Immutable financial ledger tracks every sale, refund, void, discount, and tax adjustment with zero paise drift.
- [ ] **TX-04**: Finalized orders cannot be modified; voids/refunds create reversing ledger entries with audit logs.

### 3. Offline-First Sync & Conflict Resolution (SYNC)
- [ ] **SYNC-01**: Sync queue tracks `entity`, `storeId`, `recordId`, `localVersion`, `updatedAt`, `operationType`, and `syncStatus`.
- [ ] **SYNC-02**: Conflict policy: Last-Write-Wins strictly for non-financial metadata; server-authoritative merge for financial/stock records.
- [ ] **SYNC-03**: Poisoned sync items isolated to dead-letter queue (DLQ) after retry limit to prevent queue stall.

### 4. Data Model Hardening (DATA)
- [ ] **DATA-01**: Standard transactional schema: `createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `storeId`, `version`, `deletedAt`.
- [ ] **DATA-02**: Prefixed unique IDs (`ord_`, `inv_`, `tx_`, `mov_`) and anti-duplication constraints on receipt/order numbers.
- [ ] **DATA-03**: Composite indexes configured for `storeId + createdAt` and `storeId + status`.

### 5. Android Release Packaging & Signing (REL)
- [ ] **REL-01**: Android release builds strictly reject debug signing fallback; release signing requires valid keystore credentials.
- [ ] **REL-02**: Release build fails fast if keystore or `key.properties` is missing.
- [ ] **REL-03**: Release artifacts built with `flutter build apk --release --split-per-abi` and deterministic semantic versioning.

### 6. GitHub Actions CI/CD Pipeline (CI)
- [ ] **CI-01**: Workflow `.github/workflows/build-apk.yml` executes on push/PR to `main` and manual dispatch.
- [ ] **CI-02**: Quality gates enforced in pipeline: code formatting, `flutter analyze`, and `flutter test`.
- [ ] **CI-03**: Secure injection of repository secrets (`ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`) and release artifact upload.

### 7. Branch Protection & Quality Gates (GATE)
- [ ] **GATE-01**: Main branch protected with mandatory PR reviews and passing CI checks.
- [ ] **GATE-02**: PR template enforces release checklist and security verification.

### 8. QA & Production Validation (QA)
- [ ] **QA-01**: Concurrency test validates simultaneous sales of identical item cannot result in negative stock.
- [ ] **QA-02**: Offline sale + reconnect reconciliation test verifies exact single sync without duplication.
- [ ] **QA-03**: Mid-transaction crash and idempotency retry test suites pass with 100% assertions.

### 9. Observability & Support (OBS)
- [ ] **OBS-01**: Structured audit logs for logins, orders, sync attempts, failed writes, and printer events.
- [ ] **OBS-02**: Admin diagnostic dashboard for sync health, dead-letter items, and inventory reconciliation.
