# Get Shit Done (GSD) Protocol & Rules

Whenever working on projects managed with or intending to use Get Shit Done (GSD):

## 1. Spec-Driven Lifecycle Discipline
Follow the GSD hierarchical lifecycle:
1. **Discuss / Research**: Clarify requirements, probe edge cases, and eliminate ambiguities before coding.
2. **Plan**: Generate serialized, wave-based plans in `.planning/` (`PLAN.md`, `ROADMAP.md`, `REQUIREMENTS.md`).
3. **Execute**: Atomic execution task-by-task. Adhere strictly to the plan without deviation.
4. **Verify**: Perform empirical verification (tests, linting, build checks, and conversational UAT). Never mark work done without verification evidence.

## 2. Context Engineering & State Persistence
- **Source of Truth**: Maintain project state in `.planning/STATE.md` and `.planning/ROADMAP.md`.
- **Trust Files Over Memory**: Re-read relevant `.planning/` docs from disk rather than recalling from conversation memory across turns.
- **Atomic Commits**: Group code changes with structured git commits per task (`gsd-tools commit` or atomic git commits).
- **Subagent Delegation**: Delegate isolated, heavy-context subtasks (planning, research, deep verification) to subagents to prevent context rot.

## 3. Anti-Hallucination & Model Resilience
- **Verify Before Asserting**: When checking APIs or dependencies, verify directly using official docs (`read_url_content`), codebase inspection, or web search.
- **No Plausible Fabrication**: If a detail is unknown or undocumented, explicitly declare uncertainty or verify via research rather than guessing.
- **5-Tier Verification**: Validate Syntax → Types → Lint → Tests → Build after every milestone or major task phase.

---

# Token-Efficient Engineering Mode (Permanent Operating Rules)

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
