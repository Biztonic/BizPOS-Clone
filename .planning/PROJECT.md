# BizPOS Project Overview

## What This Is
Biztonic Point-Of-Sale (BizPOS) is a multi-platform retail point-of-sale system engineered for high-concurrency offline-first retail operations, leveraging Flutter for cross-platform clients and Firebase with Cloud Functions for backend synchronization.

## Core Value
- Zero monetary drift and paise precision across all orders, taxes, and ledgers.
- Non-negative stock guarantee under concurrent checkout across multiple registers.
- Authoritative multi-tenant isolation enforcing store boundaries and role restrictions.
- Reliable offline operation with transactional conflict reconciliation.
- Secure, reproducible signed Android APK distribution built via automated CI/CD.

## Requirements
- Enforce storeId boundary checks on every Firestore query and security rule.
- Cloud Functions handle authoritative financial mutations and stock deduction transactions.
- Offline sync uses Outbox architecture with dead-letter queue and conflict engine.
- Release APK builds strictly require release keystore; debug signing fallback is prohibited.
- CI quality gates enforce static analysis, format verification, and unit test execution.

## Technical Stack

- **Frontend**: Flutter (>=3.0.0 <4.0.0)
- **State Management**: Provider (v6.1.1)
- **Local Storage**: 
  - SQLite (sqflite) for relational data (Orders, Inventory, Customers)
  - Hive for key-value pairs (Settings, Cache)
- **Backend/Cloud**:
  - Firebase Firestore (Auth, Database)
  - Firebase Storage (Media)
  - Firebase Cloud Functions (Business logic & Materialization)
  - Firebase Crashlytics (Error tracking)

## Core Architecture

### Pattern: Provider Pattern (Service-Repository)
The application uses a structured layer approach:
1. **Presentation**: Flutter Widgets & Screens.
2. **Business Logic**: Providers (ChangeNotifier) and Services.
3. **Data**: Repository Pattern for local storage abstraction.
4. **Storage**: Authoritative Cloud (Firebase) with local caching (SQLite/Hive).

### Strategy: Offline-First with Ledger-Based Sync
- **Strict Ledger-Based Event Sourcing**: All state changes are driven by authoritative atomic events (Ledger).
- **Idempotency**: Atomic BusinessEvents with IdempotencyKeys ensure reliable sync between devices.
- **Event Flow**:
  1. Local Write (SQL + Local Business Event)
  2. Ledger PUSH (Atomic BusinessEvents)
  3. Cloud Materialization (Background functions build docs)
  4. State Sync (Pull materialized docs)

## Roles & Access Control
- **Super Admin**: Global oversight across all stores.
- **Admin/Owner**: Full control over specific stores/franchises.
- **Manager/Cashier/Staff**: Tiered permissions for day-to-day operations.
- **Store Isolation**: Strict data segregation between different `storeId` values.
