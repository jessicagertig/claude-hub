# analog-completeness -- Round 1

## Findings

Layer-by-layer comparison between help pipeline and QA harness:

| Help pipeline layer | File | QA harness equivalent | Status |
|---|---|---|---|
| Orchestration | `runner.py` | Phase 8 orchestrator prompt | Covered (convergence loop is orchestrator logic) |
| Server lifecycle | `inflow_bootstrap.py` | `qa-harness start/stop` | Covered (direct adaptation) |
| Data seeding | `cypress_api.py` + `seed_parser.py` | `qa-harness seed` + seed plan JSON | Covered (different format but same function) |
| Authentication | `login.py` | Agent-driven via MCP tools | Covered (intentional divergence -- MCP replaces Python Playwright bindings) |
| Browser actions | `fallback_executor.py` | Playwright MCP tools | Covered (intentional substitution -- MCP provides the same primitives: click, fill, navigate, wait, press_key) |
| Vision/judgment | `article_interpreter.py` + `recovery.py` | QA agent's own judgment | Covered (Claude Code agent reads snapshots directly vs. API calls with screenshots) |
| State machine | `coordinator.py` | Convergence protocol | Covered (different state model -- per-round pass counting vs. per-article state transitions -- but same concept) |
| Findings output | `findings_writer.py` | Per-agent JSON + consolidated JSON + markdown | Covered (more structured output format, appropriate for multi-agent QA) |
| Cost tracking | `cost_tracker.py` | Not covered | **Gap** |
| Error recovery | `recovery.py` | Not directly applicable | N/A (QA agents have their own judgment; the scripted recovery loop pattern does not apply to agents with MCP tools) |
| Slack notifications | `slack_notifier.py` | Not covered | **Gap** (minor -- orchestrator could add this) |
| S3 upload | `s3_uploader.py` | Not applicable | N/A (hub-local artifacts, not cloud pipeline) |

- F1 [MED] No cost tracking equivalent. The analog tracks Claude API costs via `CostTracker`. The QA harness has no mention of cost tracking, even though running teams of agents with Playwright MCP is potentially expensive. This was also noted in convergence-protocol F4. Not a BLOCKER because cost tracking is an operational concern, not a spec-level design issue, but the spec should at least acknowledge it as an implementation consideration.

- F2 [LOW] No notification mechanism. The analog posts to Slack at key milestones. The QA harness has no equivalent. The orchestrator could add notifications in the prompt, but it is not specified. This is a minor gap -- the orchestrator's Phase 8 output (QA-COMPLETE.md or escalation) serves as the notification.

- F3 [LOW] The `fallback_executor.py` supports 6 action kinds: `click_text`, `click_by_aria`, `fill_by_label`, `navigate`, `wait_for_selector`, `press_key`. The Playwright MCP provides: `browser_click` (covers click_text, click_by_aria), `browser_fill_form` (covers fill_by_label), `browser_navigate` (covers navigate), `browser_wait_for` (covers wait_for_selector), `browser_press_key` (covers press_key). Additionally, the MCP provides capabilities the analog does not: `browser_evaluate`, `browser_console_messages`, `browser_network_requests`, `browser_hover`, `browser_drag`, `browser_drop`, `browser_select_option`, `browser_file_upload`. The MCP is a strict superset.

## Amendments Applied

- None.
