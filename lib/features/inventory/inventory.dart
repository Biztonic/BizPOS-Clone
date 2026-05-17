/// Inventory Feature — Public API (Barrel Export)
///
/// This file defines what other features are ALLOWED to import
/// from the inventory module. This enforces feature contracts.
///
/// ─── ALLOWED IMPORTS ─────────────────────────────────────
///   import 'package:biztonic_pos/features/inventory/inventory.dart';
///
/// ─── FORBIDDEN IMPORTS ───────────────────────────────────
///   import 'package:biztonic_pos/features/inventory/data/...';
///   import 'package:biztonic_pos/features/inventory/application/...';
library;

// ─── Domain: Entities ────────────────────────────────────
export 'domain/entities/inventory_entity.dart';

// ─── Domain: Repository Interface ────────────────────────
export 'domain/repositories/inventory_repository_interface.dart';

// ─── Domain: Policies ────────────────────────────────────
export 'domain/policies/inventory_policy.dart';

// ─── Domain: Use Cases (legacy) ──────────────────────────
export 'domain/use_cases/adjust_stock.dart';

// ─── Application: Orchestrators ──────────────────────────
export 'application/inventory_orchestrator.dart';

// ─── Data: Repository Implementation ─────────────────────
export 'data/repositories/inventory_repository_impl.dart';

// ─── Presentation: Providers ─────────────────────────────
export 'presentation/providers/inventory_provider.dart';
