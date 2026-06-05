# Spec Review Complete

**Final verdict: READY FOR PLANNING**

Two consecutive clean passes achieved (Rounds 4 and 5).

## Plain English Summary

The QA harness adds a final verification step to the feature development process. After a feature has been designed, coded, and code-reviewed, this step answers: "does it actually work when someone uses it?" The orchestrator boots a test copy of the application, seeds it with data, and then dispatches a team of independent AI agents sequentially. Each agent explores the feature from its own angle -- clicking through the UI, filling forms, running test scripts, checking for regressions -- and records what it finds. Multiple agents working the same round independently (each with fresh context and no memory of the others) catch things a single agent would miss, and when several agents find the same bug independently, confidence is high.

After the team finishes a round, the orchestrator consolidates their findings, deduplicates, and handles disagreements. Then a fresh team is dispatched. If two consecutive rounds produce stable results -- no new major bugs, no prior findings overturned -- the feature is verified. If issues are found, they go back to the implementation agent for fixing, then QA picks up where it left off.

The harness itself is intentionally thin infrastructure -- it handles starting the test server, seeding data via HTTP endpoints, and cleaning up between tests. All browser interaction is delegated to the Playwright MCP. Authentication is driven by the QA agent using MCP tools, not by harness code. Each pipeline provides a configuration file declaring how to start its app, what seed endpoints are available, and how to log in.

## Blast Radius Analysis

- **Feature lifecycle (`~/claude-hub/features/`):** Phase 8 (QA verification) added after Phase 7 (hardening). Needs new LIFECYCLE.md section and `qa-prompt.md` file. No existing phases change. Hardening does not incorporate QA findings (it runs first). QA failure reports loop back to Phase 5 (impl) directly, skipping Phase 6 (impl review).
- **Pipeline configs:** Each pipeline gains a `qa-config.yml`. No existing files modified.
- **Inflow-ats source repo:** Zero changes. Consumes existing Cypress endpoints and magic-link flow.
- **Help pipeline:** Zero changes. Patterns adapted, not shared.
- **Playwright MCP:** Consumed, not modified. If unavailable, only the playwright_mcp layer is lost.
- **If wrong:** Blast radius contained to `/tmp` files and `reviews/qa-round-N/` artifacts. No source code, databases, or `.env` files modified.

## Round Summary

| Round | Verdict | BLOCKER | HIGH | MED | LOW | Amendments |
|-------|---------|---------|------|-----|-----|------------|
| 1 | FAIL | 0 | 7 | 11 | 8 | 11 |
| 2 | FAIL | 0 | 3 | 4 | 1 | 4 |
| 3 | FAIL | 0 | 1 | 0 | 0 | 1 |
| 4 | PASS | 0 | 0 | 0 | 0 | 0 |
| 5 | PASS | 0 | 0 | 0 | 0 | 0 |

## Key Amendments Made

**Round 1 (7 HIGH findings):**
1. Seed/cleanup commands verify server alive before HTTP calls
2. Health check includes premature process exit detection
3. Added missing seed endpoints (`create_complete_subscription`, `individual_app/careers_page_subscriptions`) and `setFreeV2Subscription` param
4. Added `requires` field documenting endpoint ordering dependencies
5. Default team size of 3, configurable via `qa_team_size`
6. Each QA agent is a separate sub-agent with its own Playwright MCP session
7. Renamed `test_frr` concept to pipeline-agnostic `script_runner`; corrected `test_frr` definition from `bundle exec` to `foreman run`
8. Clarified Phase 8 position, QA-to-impl loop skips Phase 6, `QA-COMPLETE.md` is gate file

**Round 2 (3 HIGH findings):**
1. Orchestrator owns server lifecycle (start/stop), not individual agents
2. Agents execute sequentially within a round (shared database prevents parallelism)
3. Fixed stale `test_frr` references and Phase 7 reference

**Round 3 (1 HIGH finding):**
1. Fixed stale parallel-execution reference contradicting sequential model

## Remaining Open Questions (MED/LOW, not blocking)

1. **Disagreement semantics** (convergence-protocol): Should agent disagreement on a prior finding count as a "change" for convergence? Recommendation: only unanimous invalidation counts. Deferred to orchestrator prompt design.
2. **Agent diversity** (convergence-protocol): How agents get assigned different testing focuses. Deferred to orchestrator prompt design.
3. **Cost tracking** (analog-completeness): No equivalent of the analog's `CostTracker`. Implementation consideration.
4. **Screenshot file paths** (playwright-mcp-integration): How MCP screenshots get saved to specific paths for evidence. Implementation detail for agent instructions.
5. **`browser_snapshot` visual limitations** (playwright-mcp-integration): Cannot detect visual layout issues. Mitigated by using screenshots for visual evidence.
6. **Seed plan validation** (seed-data-design): Plans should be validated against the endpoint catalog at parse time, not at HTTP call time. Implementation detail.
7. **Non-web pipeline config example** (pipeline-scalability): A minimal config example for non-web pipelines would help implementers.
