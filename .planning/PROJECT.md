# BizPOS Project Overview

Biztonic Point-Of-Sale (BizPOS) is a multi-platform POS system designed with an offline-first architecture, leveraging Flutter for the frontend and Firebase for the backend.

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
