## Production Hardening & Release Quality Gate Checklist

### 1. Invariant Checks
- [ ] **Multi-Tenant Isolation**: All queries and mutations are strictly scoped by `storeId` with no cross-store leakage.
- [ ] **Zero Monetary Drift**: All financial calculations use paise precision (integer or exact 2-decimal rounded cents), avoiding floating-point rounding errors.
- [ ] **Concurrency & Non-Negative Inventory**: Inventory deduction is atomic and transactional; stock is prevented from falling below zero under concurrent sales.
- [ ] **Offline Sync & Conflict Safety**: LWW is restricted to non-financial metadata; orders and financial ledgers use append-only or server-reconciled transactions.
- [ ] **Release Signing Enforced**: No release build falls back to debug keystore; release APKs are signed exclusively via CI GitHub secrets.

### 2. Code Quality & Static Analysis
- [ ] `dart format --output=none --set-exit-if-changed .` passes cleanly.
- [ ] `flutter analyze` reports zero errors and zero critical warnings.
- [ ] Targeted and regression unit tests pass (`flutter test`).

### 3. Change Description
- **Phase Addressed**: (e.g., Phase 1: Security, Phase 2: Transaction Integrity, etc.)
- **Summary of Changes**:
- **Risk Assessment & Rollback Plan**:

### 4. Reviewer Approval
- [ ] Mandatory peer review completed.
- [ ] Branch protection rules satisfied (direct pushes to `main` disabled).
