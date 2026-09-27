#!/usr/bin/env bash
# BizPOS Automated Production QA Runner (Bash)
# Usage: ./scripts/run_qa.sh

set -e

echo "=========================================================="
echo " BizPOS — Autonomous Production QA & Regression Suite"
echo "=========================================================="

echo "[1/5] Running Static Analysis (dart analyze)..."
dart analyze --no-fatal-infos lib/ test/qa_production_mission_test.dart

echo "[2/5] Running Unit, Tax, Policy & Entitlement Tests..."
flutter test \
  test/qa_production_mission_test.dart \
  test/unit/tax_calculation_test.dart \
  test/unit/discount_validation_test.dart \
  test/unit/entitlement_policies_test.dart \
  test/unit/inventory_policies_test.dart \
  test/unit/order_policies_test.dart \
  test/unit/idempotency_test.dart

echo "[3/5] Running Repository, SQLite Projection & Outbox Sync Tests..."
flutter test \
  test/inventory_movement_ledger_test.dart \
  test/durable_outbox_sync_test.dart \
  test/repository/projection_rebuild_test.dart \
  test/repository/outbox_store_test.dart \
  test/repository/sqlite_transaction_behavior_test.dart \
  test/repository/transaction_rollback_test.dart

echo "[4/5] Running Application Orchestrator & Security Perimeter Tests..."
flutter test \
  test/application/checkout_application_test.dart \
  test/application/refund_application_test.dart \
  test/application/stock_adjustment_application_test.dart \
  test/application/subscription_rules_application_test.dart \
  test/security/security_perimeter_regression_test.dart \
  test/multi_tenant_security_test.dart

echo "[5/5] Running Release APK Build Verification..."
flutter build apk --release

echo "=========================================================="
echo " QA Suite Execution Complete"
echo "=========================================================="
