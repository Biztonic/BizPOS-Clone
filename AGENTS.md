# BizPOS Project AI Operating Rules: Token-Efficient Engineering Mode

Apply these rules to every task to minimize token consumption and context reloading without sacrificing quality, security, or test correctness.

## 1. Context & Exploration Discipline
- Treat `PRD.md` as primary requirements authority; do not duplicate, rewrite, or unnecessarily summarize it.
- Check `docs/AI_WORKING_STATE.md` at session start before exploring files.
- Never scan the entire repository or load large docs for generic background knowledge.
- Target exact symbols, callers, and dependencies; expand scope only when required.
- Do not repeat completed investigations without specific contradictory evidence.

## 2. Minimal Safe Changes & Change Control
- Understand the outcome, locate the smallest safe change, and implement only the requested scope.
- Preserve existing behavior and public interfaces; prefer backward-compatible patches.
- Never perform unrequested refactoring, architecture migration, dependency replacements, or schema changes.
- Never silently drop functionality.

## 3. Strict Quality & Invariant Protection
- High token efficiency never excuses guessing or skipping validation.
- Financial, inventory, sync, and security logic requires complete execution path inspection.
- Invariants: Zero monetary drift / paise precision, durable offline persistence, idempotent checkout, multi-tenant role enforcement, and PRD consistency.
- Run targeted tests for changed modules before concluding.

## 4. Concise Output Format
- Keep responses concise (<200 words for routine tasks), actionable, and diff-focused.
- Default output structure:
  1. Result
  2. Files changed
  3. Tests executed
  4. Remaining issues / risks (if any)

## 5. Working State Maintenance
- Maintain `docs/AI_WORKING_STATE.md` across task boundaries (Objective, Completed, Verified Findings, Files Changed, Tests Executed, Unresolved, Next Step).
