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
