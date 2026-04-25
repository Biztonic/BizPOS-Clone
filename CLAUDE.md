# Biztonic BizPOS - Claude Memory

## Project Overview
Biztonic BizPOS is a comprehensive POS (Point of Sale) system built with Flutter and Firebase. It supports multiple stores, inventory management, customer tracking, and offline capabilities.

- **Tech Stack**: Flutter (Dart), Firebase (Firestore, Auth, Functions, Crashlytics), Provider (State Management), Hive/Sqflite (Offline Data).
- **Core Modules**: POS Screen, Inventory, Orders, Table Management, Customers, Reports.
- **Backend**: Firebase Project `biztonic-pos-v2`.

## Coding Standards
- **Styling**: Vanilla CSS for web components (if applicable). Flutter uses standard Material Design.
- **State Management**: Use `provider` as the primary state management solution.
- **Database**: 
  - Firestore for cloud sync.
  - Hive/Sqflite for local caching and offline-first functionality.
- **Concurrency**: Ensure proper async/await handling, especially for hardware integration (printers, scanners).

## GSD Workflow Integration
The project uses a structured "Get Shit Done" (GSD) workflow located in `.agent/workflows`. 
- Follow `plan-phase.md`, `execute-phase.md`, and `verify-phase.md` patterns.
- Maintain planning artifacts in `.planning/`.

## Active Context
- **Current Task**: Demonstrating and adopting Claude Code capabilities.
- **Firebase Status**: Connected to `biztonic-pos-v2`.
- **Infrastructure**: Thermal printer integration via `packages/flutter_thermal_printer`.

## Guidelines
- Always check `.agent/workflows` before starting major tasks.
- Keep `ROADMAP.md` and `REQUIREMENTS.md` updated as part of the planning process.
- Use `firebase-mcp-server` for direct backend verification.
## QA & Debugging Mode (CRITICAL)

When analyzing or modifying this project:

### Priority Order (STRICT)
1. Data integrity (billing, transactions must NEVER be wrong)
2. Firebase security (no unauthorized access)
3. Offline-first sync correctness
4. App stability (no crashes, no freezes)
5. Performance (only after stability)

### Rules
- NEVER refactor working features unless required to fix a bug
- ALWAYS explain before applying fixes
- Fix ONLY one issue at a time
- Preserve existing architecture (Flutter + Provider + Firebase)
- Do NOT introduce unnecessary dependencies

### Critical Areas to Always Audit
- Billing calculations (totals, tax, rounding)
- Firestore writes (duplicate, overwrite, race conditions)
- Offline sync conflicts (Hive ↔ Firestore)
- Authentication & store isolation
- Printer/scanner hardware async handling

### Edge Case Simulation (MANDATORY)
Always test:
- Fast repeated clicks (duplicate billing)
- Offline → online sync conflicts
- App crash during transaction
- Multiple users using same store
- Slow network conditions

### Output Format
- Categorize issues: HIGH / MEDIUM / LOW
- Always include:
  - File name
  - Root cause
  - Fix approach
  - Risk of fix

### Fixing Rules
- Apply fixes in small steps
- After each fix, re-check for side effects
- Never apply bulk fixes
## Full System Validation Mode (CRITICAL BEFORE PRODUCTION)

When performing deep audits or testing:

### Objective
Ensure the application is 100% functionally correct, logically consistent, and production-ready across all modules.

### Mandatory Checks

#### 1. Feature Completeness
- Verify all modules:
  - POS (billing, checkout)
  - Inventory (stock add/update/deduct)
  - Customers
  - Orders
  - Reports
  - Table management
  - Subscription plans
  - Super admin controls
- Ensure each feature is fully connected to backend (no dummy UI)

#### 2. Frontend ↔ Backend Consistency
- Every UI action must:
  - Trigger correct backend logic
  - Persist correct data in Firestore/SQLite
- Detect mismatches:
  - UI shows success but DB not updated
  - DB updated but UI not reflecting

#### 3. Hardcoded / Temporary Logic Detection
- Identify:
  - Hardcoded values (storeId, prices, tax, user roles)
  - Mock data not connected to backend
  - Debug/test flags left in production
- Flag any logic bypassing real system flow

#### 4. Multi-Store Isolation
- Ensure:
  - No cross-store data leakage
  - Queries always filtered by storeId
  - Super admin vs store user separation works correctly

#### 5. Subscription & Access Control
- Verify:
  - Features restricted by plan
  - Expired subscription handling
  - Upgrade/downgrade effects

#### 6. Data Integrity
- Ensure:
  - No duplicate orders
  - Inventory always matches transactions
  - Reports match actual data

#### 7. Edge Case Simulation
Test:
- Empty data states
- Large data (1000+ records)
- Offline → online transitions
- Rapid user actions
- Invalid inputs

### Output Requirements
- Categorize issues:
  - CRITICAL (breaks business)
  - HIGH (major logic flaw)
  - MEDIUM (inconsistency)
  - LOW (minor issue)
- For each issue include:
  - Module name
  - File reference
  - Root cause
  - Real-world impact
  - Suggested fix

### Strict Rules
- Do NOT modify code in audit mode
- Focus on finding hidden logic issues
- Trace complete flow: UI → Provider → DB → Sync → UI