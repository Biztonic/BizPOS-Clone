# BizPOS Requirements

## Functional Requirements (FR)

### 1. Order Management
- Support for multiple order types: Dine-In, Takeaway, and Delivery.
- Cart management with discounts, taxes, and price overrides.
- Table management with floor layout visualization and status tracking.
- Order history and receipt printing (USB, Bluetooth, Network).

### 2. Inventory Management
- Centralized SKU management across franchises.
- Store-specific stock levels and low-stock alerts.
- Support for categories, units, and expiring items.
- Event sourcing for inventory movements (Audit Trail).

### 3. User & Employee Management
- PIN-based quick login for employees.
- Role-based permissions (Super Admin, Owner, Manager, etc.).
- Store and franchise isolation for data security.

### 4. Customer Relationships
- Integrated CRM for tracking customer history and preferences.
- Tiered loyalty program (Bronze, Silver, Gold, Platinum).
- WhatsApp and email integration for receipts and marketing.

## Non-Functional Requirements (NFR)

### 1. Reliability & Performance
- **Offline-First**: Zero-interruption service during network outages.
- **Data Integrity**: Idempotent synchronization to prevent data duplicates.
- **Scalability**: Support for hundreds of nodes per store with eventual consistency.

### 2. Security
- Strict store isolation in Firestore rules.
- Authenticated-only access to business data.
- Audit logs for significant business events.

### 3. Portability
- Single codebase for Mobile (Android/iOS) and Desktop (Windows/macOS/Web).
