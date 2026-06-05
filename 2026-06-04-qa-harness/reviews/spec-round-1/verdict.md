# Spec Review -- Round 1 Verdict
**Date:** 2026-06-04

## Counts
- BLOCKER: 0
- HIGH: 7
- MED: 11
- LOW: 8

## HIGH Findings

1. **server-lifecycle F1**: seed/cleanup commands do not verify server is alive before HTTP calls -- could time out opaquely. **Amended.**
2. **seed-data-design F1**: Missing seed endpoints from catalog (create_complete_subscription, individual_app/careers_page_subscriptions, setFreeV2Subscription param). **Amended.**
3. **seed-data-design F2**: Endpoint ordering dependencies not documented -- seed planner cannot produce valid ordering. **Amended.**
4. **convergence-protocol F1**: Team size unspecified -- affects cost, convergence, deduplication. **Amended** (default 3, configurable).
5. **playwright-mcp-integration F1**: Parallel agents sharing one browser session -- race conditions if not separate sub-agents. **Amended** (each agent is a separate sub-agent with own MCP session).
6. **pipeline-scalability F1**: `test_frr` is Rails-specific, wrong definition, and described as general. **Amended** (renamed to `script_runner`, corrected definition).
7. **lifecycle-integration F1 + F2**: Phase ordering inconsistency (spec says after Phase 7 but body implies after Phase 6), and unclear whether QA-to-impl loop goes through Phase 6. **Amended** (clarified Phase 8 after Phase 7, QA-to-impl skips Phase 6).

## Amendments Applied

1. Seed execution section: seed/cleanup verify server alive before HTTP calls.
2. Health check section: premature process exit detection added.
3. qa-config.yml: added setFreeV2Subscription param, create_complete_subscription endpoint, individual_app/careers_page_subscriptions endpoint.
4. qa-config.yml: added `requires` field to endpoints with ordering dependencies.
5. Round mechanics: default team size of 3, configurable via qa_team_size.
6. Architecture section: each QA agent runs as separate sub-agent with own Playwright MCP session.
7. Verification layers: `test_frr` renamed to `script_runner` concept, corrected definition, made pipeline-agnostic.
8. qa-config.yml: added `script_runner` config block.
9. QA agent steps: updated to reference `script_runner`.
10. Blast radius: clarified Phase 8 position, QA-to-impl loop skips Phase 6, QA-COMPLETE.md is gate file.
11. Failure report section: explicit that QA-to-impl skips Phase 6.

## Verdict: FAIL

7 HIGH findings required 11 amendments. Proceeding to Round 2.
