/// Billing Feature — Public API (Barrel Export)
///
/// This file defines what other features are ALLOWED to import
/// from the billing module. This enforces feature contracts.
///
/// ─── ALLOWED IMPORTS ─────────────────────────────────────
///   import 'package:biztonic_pos/features/billing/billing.dart';
///
/// ─── FORBIDDEN IMPORTS ───────────────────────────────────
///   import 'package:biztonic_pos/features/billing/data/...';
///   import 'package:biztonic_pos/features/billing/application/...';
///
/// Only domain entities, repository interfaces, and the
/// application orchestrator are part of the public contract.

// ─── Domain: Entities ────────────────────────────────────
export 'domain/entities/order_entity.dart';

// ─── Domain: Repository Interface ────────────────────────
export 'domain/repositories/billing_repository.dart';

// ─── Domain: Policies ────────────────────────────────────
export 'domain/policies/order_policy.dart';

// ─── Domain: Use Cases ───────────────────────────────────
export 'domain/use_cases/calculate_tax.dart';

// ─── Application: Orchestrators ──────────────────────────
export 'application/checkout_orchestrator.dart';
