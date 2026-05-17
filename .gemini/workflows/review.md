# Code Review & Impact Analysis

// turbo
Use this workflow to review the codebase and assess the impact of changes before making any modifications.

## Steps

1. **Graph Sync**: Run `build_or_update_graph_tool()` to ensure the structural map is up to date.
2. **Context Retrieval**: Run `get_minimal_context(task="Analyzing impact of upcoming changes")`.
3. **Change Detection**: Run `detect_changes()` to identify risks in the current diff.
4. **Impact Analysis**: Run `get_impact_radius()` and `get_affected_flows()` to see what could break.
5. **Report**: Summarize the findings and provide a risk-aware plan for the modifications.

## Rules
- NEVER skip impact analysis for high-risk modules.
- Check test coverage for all modified functions.
- Verify callers and callees for any signature changes.
