# BizPOS Automated Production QA Runner (Windows PowerShell)
# Usage: powershell -ExecutionPolicy Bypass -File scripts/run_qa.ps1

$ErrorActionPreference = "Continue"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " BizPOS — Autonomous Production QA & Regression Suite" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Static Analysis
Write-Host "`n[1/5] Running Static Analysis (dart analyze)..." -ForegroundColor Yellow
dart analyze --no-fatal-infos lib/ test/qa_production_mission_test.dart

# 2. Core Unit, Domain & Tax Tests
Write-Host "`n[2/5] Running Unit, Tax, Policy & Entitlement Tests..." -ForegroundColor Yellow
flutter test `
  test/qa_production_mission_test.dart `
  test/unit/tax_calculation_test.dart `
  test/unit/discount_validation_test.dart `
  test/unit/entitlement_policies_test.dart `
  test/unit/inventory_policies_test.dart `
  test/unit/order_policies_test.dart `
  test/unit/idempotency_test.dart

# 3. Repository, SQLite Ledger & Outbox Sync Tests
Write-Host "`n[3/5] Running Repository, SQLite Projection & Outbox Sync Tests..." -ForegroundColor Yellow
flutter test `
  test/inventory_movement_ledger_test.dart `
  test/durable_outbox_sync_test.dart `
  test/repository/projection_rebuild_test.dart `
  test/repository/outbox_store_test.dart `
  test/repository/sqlite_transaction_behavior_test.dart `
  test/repository/transaction_rollback_test.dart

# 4. Application, Security & Multi-Tenant Isolation Tests
Write-Host "`n[4/5] Running Application Orchestrator & Security Perimeter Tests..." -ForegroundColor Yellow
flutter test `
  test/application/checkout_application_test.dart `
  test/application/refund_application_test.dart `
  test/application/stock_adjustment_application_test.dart `
  test/application/subscription_rules_application_test.dart `
  test/security/security_perimeter_regression_test.dart `
  test/multi_tenant_security_test.dart

# 5. Build Verification
Write-Host "`n[5/5] Running Release APK Build Verification..." -ForegroundColor Yellow
flutter build apk --release

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " QA Suite Execution Complete" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
