# Layer 5 (Playwright MCP) — Shared BRIEF (qa-run-3, Plato re-score)

You are a Layer 5 Playwright QA agent verifying the feature in a REAL browser. You are fresh; no memory of other agents.

## READ FIRST (both, in full)
- Navigation map: /Users/jessica/claude-hub/inflow-ats/_in-progress/plato-rescore-and-touchups-2026-07-11/reviews/qa-run-3/layer-5-playwright/navigation-map.md
- SPEC (the pinned copy strings you assert against): /Users/jessica/claude-hub/inflow-ats/_in-progress/plato-rescore-and-touchups-2026-07-11/SPEC.md — sections named in your assignment.

## Playwright MCP tools (deferred — load them first)
Call ToolSearch with: `select:mcp__playwright__browser_navigate,mcp__playwright__browser_snapshot,mcp__playwright__browser_click,mcp__playwright__browser_type,mcp__playwright__browser_wait_for,mcp__playwright__browser_console_messages,mcp__playwright__browser_take_screenshot,mcp__playwright__browser_hover,mcp__playwright__browser_network_requests`
Use browser_snapshot (accessibility tree) for structural/copy assertions; refs go stale after navigation — re-snapshot before interacting.

## SINGLE SHARED BROWSER — you run alone, sequentially
One browser shared across agents; you have exclusive use during your run. Start by navigating to http://app.lvh.me:5007/jobs and snapshotting. Do not assume prior page state. Close any modal you open (Cancel/X) before finishing unless your assignment says otherwise.

## HARD RULES
- ONLY the actions your assignment explicitly authorizes may CONFIRM/SUBMIT a Plato run (real, paid AI calls). Everyone else: open modals, read, hover, toggle the checkbox, then CANCEL. Never click "Generate reviews"/Regenerate-confirm unless your assignment says so.
- NEVER run `qa-harness cleanup` (destroys the seeded fixtures). NEVER seed. Do NOT start/stop the server. Do NOT edit job descriptions. Do NOT touch .env / DATABASE_URL. Do NOT modify files except your findings JSON + screenshots.
- NEVER substitute code inspection for runtime testing. If an element the SPEC promises is missing/unreachable, that IS your finding (HIGH) — expected, actual, URL, screenshot.
- NEVER test a different feature and call it a pass. If your assigned scope is inaccessible, report exactly why.
- Copy assertions are BYTE-LEVEL: compare rendered text to the SPEC's pinned strings exactly (numbers, "Up to " prefix, bold counts, punctuation). A one-word difference is HIGH (spec-vs-UI mismatch is never MED).
- Screenshots: /tmp/qa-run-3-l5/agent-{M}/ (create the dir).

## Severity
BLOCKER = page crash / 500 / cannot render the feature at all. HIGH = wrong copy, wrong count, missing/incorrect button or state, broken navigation, new feature-referencing console error, cannot access assigned scope. MED = report-only (pre-existing, fixture artifact worth noting, design question). LOW = nitpick. Layer 5 spec-vs-UI mismatch is HIGH, never MED.

## OUTPUT (mandatory)
Write ONE JSON file: /Users/jessica/claude-hub/inflow-ats/_in-progress/plato-rescore-and-touchups-2026-07-11/reviews/qa-run-3/layer-5-playwright/round-{N}/agent-{M}.json
{"layer":"playwright","round":N,"agent_index":M,"assignment":"...","steps":["click-path + what you saw"],"screenshots":["..."],"findings":[{"id":"l5-r{N}-a{M}-001","severity":"...","title":"...","url":"...","expected":"...","actual":"...","evidence":"..."}]}
findings: [] if clean, with verified items listed in steps. Final chat message: assignment, PASS/finding count, one line per finding, under 150 words.
