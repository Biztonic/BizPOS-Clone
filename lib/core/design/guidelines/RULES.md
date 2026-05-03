# Enterprise UI Architecture Governance

## Core Philosophy
1. **Never hardcode values:** All styling must go through `AppColors`, `AppSpacing`, `AppTypography`, `AppRadius`, `AppDurations`, and `AppMotion`. 
2. **Never build one-off widgets:** Always look for a Component in `lib/core/design/components/` first. If it doesn't exist, build it there, then use it in your feature.
3. **Responsive by Layout, Not by Scale:** Use `PosScaffold` and `LayoutBuilder` instead of arbitrarily scaling sizes. POS systems require strict spatial constraints depending on device type (Mobile vs Tablet vs Desktop).

## Spacing & Padding
* **Bad**: `padding: EdgeInsets.all(12)`
* **Good**: `padding: EdgeInsets.all(AppSpacing.md)`

## Colors
* **Bad**: `color: Colors.blue`
* **Good**: `color: Theme.of(context).colorScheme.primary`
* Do not bypass the `Theme` engine unless strictly necessary. Ensure all colors are semantic (e.g. `primary`, `error`, `surface`) rather than literal (e.g. `blue`, `red`, `white`).

## Typography
* **Bad**: `Text("Total", style: TextStyle(fontSize: 14))`
* **Good**: `Text("Total", style: Theme.of(context).textTheme.labelLarge)`

## Buttons & Interaction
* **Bad**: Creating a custom `GestureDetector` with arbitrary feedback.
* **Good**: Use `AppButton` and specify the exact variant (`primary`, `secondary`, `ghost`, etc.) and size (`small`, `medium`, `large`). 

## Density Strategy
For lists, tables, and grids:
* Pass `AppDensity` to your data-heavy widgets. 
* Use `AppDensity.compact` for back-office and detailed reports.
* Use `AppDensity.touch` for fast-paced checkout lanes (Mobile/Tablet).

## Code Review Checklist
Before approving a PR that touches UI, verify:
- [ ] No hardcoded `EdgeInsets` values.
- [ ] No hardcoded `Color(...)` or `Colors.*`.
- [ ] No new components built inside the `features/` directory that belong in `core/design/components`.
- [ ] Variant patterns are respected (`AppButton` etc. handles its own states).
