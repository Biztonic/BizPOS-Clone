# BizPOS Roadmap: Production Hardening

## Milestone: Production Hardening (v2.0-prod)
Goal: Make BizPOS safe for real-world retail operations and release-ready for Android APK distribution.

### Phase 1: Security and Access Control (Priority: Critical)
- Lock down Firestore rules by store, membership, role, and subscription status.
- Add server-side Cloud Functions for financial mutations (order creation, void/refund, stock adjustment, payment status).
- Enforce App Check + Firebase Auth token validation.
- **Criteria**: No unauthorized cross-store data access; all financial writes validated by server.

### Phase 2: POS Transaction Integrity (Priority: Critical)
- Implement atomic order creation transaction with cart total validation.
- Idempotency key tracking (`operationId` / `idempotencyKey`) on transactions and retries.
- Zero paise financial drift across discounts, taxes, items, and payments.
- Enforce immutable finalized orders; refunds/voids write reversing ledger entries.
- **Criteria**: Zero double-selling, zero negative stock under concurrency, zero financial drift.

### Phase 3: Offline-First Sync & Conflict Resolution (Priority: Critical)
- Strengthen sync queue with entity, version, timestamp, and operation type tracking.
- Conflict policy: LWW for non-financial metadata; server-authoritative merge for financial/stock records.
- Dead-letter queue (DLQ) for poisoned sync mutations after retry limits.
- **Criteria**: Offline sales sync exactly once without duplicates; concurrent edits resolve deterministically.

### Phase 4: Data Model Hardening (Priority: High)
- Enforce audit fields (`createdAt`, `updatedAt`, `createdBy`, `updatedBy`, `storeId`, `version`, `deletedAt`).
- Standardize domain-prefixed IDs (`ord_`, `inv_`, `tx_`, `mov_`) and anti-duplication constraints.
- Composite indexes for `storeId + createdAt` and `storeId + status`.
- **Criteria**: All transactional records auditable; anti-duplication enforced.

### Phase 5: Android Release Packaging & Signing (Priority: Critical)
- Remove fallback to debug signing in release build type in `android/app/build.gradle`.
- Require release keystore in all release builds; fail fast if missing.
- Split-per-ABI release packaging (`flutter build apk --release --split-per-abi`).
- **Criteria**: Release APKs guaranteed signed with production keystore; reproducible builds.

### Phase 6: GitHub Actions for APK Pipeline (Priority: Critical)
- Standardize `.github/workflows/build-apk.yml` with full quality gates.
- Stages: checkout -> Java 17 -> Flutter stable -> pub get -> format -> analyze -> test -> release build -> artifact upload.
- Secrets injection (`ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`).
- **Criteria**: Automated APK generation in GitHub Actions with artifact download.

### Phase 7: Quality Gates & Branch Protection (Priority: High)
- Pull request template enforcing release and security checklists.
- Branch protection rules requiring passing CI and review.
- **Criteria**: Protected main branch; zero unverified direct commits.

### Phase 8: QA & Production Validation (Priority: High)
- Multi-user concurrency simulations (simultaneous checkout of single-item inventory).
- Offline sale followed by reconnect reconciliation test suite.
- Idempotency retry and crash recovery test validation.
- **Criteria**: 100% test pass rate across all concurrency and failure scenarios.

### Phase 9: Observability & Support (Priority: Medium)
- Structured logging for transactions, sync events, and printer errors.
- Admin diagnostic tools for sync health, dead letters, and drift detection.
- **Criteria**: Comprehensive operational visibility for store administrators and support.
