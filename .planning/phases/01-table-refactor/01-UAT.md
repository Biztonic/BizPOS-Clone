---
status: testing
phase: 01-table-refactor
source: [manual-refactor]
started: 2026-03-24T17:00:00Z
updated: 2026-03-24T17:00:00Z
---

## Current Test
number: 1
name: Table Occupancy Visuals
expected: |
  Occupying a table or a specific seat should trigger the appropriate animation on the chairs and update the table color. Verify that the "Occupied" status is correctly reflected in the UI.
awaiting: user response

## Tests

### 1. Table Occupancy Visuals
expected: Occupying a table or a specific seat should trigger the appropriate animation on the chairs and update the table color.
result: [pending]

### 2. Order Persistence (SAVE & KOT)
expected: Clicking "SAVE & KOT" should correctly create/update the order in DashboardProvider and occupy the table/seats in TableProvider. Verify that the snackbar "Order Saved & Updated" appears.
result: [pending]

### 3. Table Clearing
expected: Clicking "Clear" in the quick order dialog should reset the table state in TableProvider and return it to "Available" status.
result: [pending]

### 4. Active Store Sync
expected: The TableManagementScreen should correctly load tables for the current activeStoreId from DashboardProvider.
result: [pending]

## Summary
total: 4
passed: 0
issues: 0
pending: 4
skipped: 0

## Gaps
[none yet]
