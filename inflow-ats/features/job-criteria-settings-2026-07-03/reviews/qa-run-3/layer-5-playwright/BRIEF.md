# Layer 5 (Playwright MCP) — Shared BRIEF for job-criteria-settings QA (qa-run-3)

You are a Layer 5 Playwright QA agent. You verify the feature works in a REAL browser by exercising it as a user would. You are fresh: no memory of other agents.

## READ FIRST
Read the navigation map in full: `/Users/jessica/claude-hub/inflow-ats/features/job-criteria-settings-2026-07-03/reviews/qa-run-3/layer-5-playwright/navigation-map.md`. It has the auth flow, click-path to the Job criteria section, the six seeded state jobs + ids, the expected per-state UI, both modals, and the known pre-existing console errors to ignore.

## Playwright MCP tools (deferred — you MUST load them first)
The browser tools are named `mcp__playwright__*` but are DEFERRED. Before using them, call `ToolSearch` with:
`select:mcp__playwright__browser_navigate,mcp__playwright__browser_snapshot,mcp__playwright__browser_click,mcp__playwright__browser_type,mcp__playwright__browser_wait_for,mcp__playwright__browser_console_messages,mcp__playwright__browser_take_screenshot`
Then they are callable. Use `browser_snapshot` (accessibility tree) for structural assertions — it gives element refs (like `f39e293`) you pass as `target` to `browser_click`. Refs go STALE after navigation/DOM change — re-snapshot before interacting.

## ⚠️ SINGLE SHARED BROWSER — you run alone
There is ONE browser shared across all agents; the orchestrator runs agents strictly SEQUENTIALLY, so you have exclusive use during your run. Start by taking a fresh snapshot of wherever the browser currently is; navigate to `http://app.lvh.me:5007/jobs` to reset to a known start. Do not assume prior page state.

## ⚠️ HARD RULES
- **NEVER click the final "Regenerate criteria" (or "Generate criteria") CONFIRM button inside the confirm modal.** That fires the real mutation → enqueues `ExtractJobCriteriaJob` → sidekiq → a real/paid AI extraction. You MAY open the confirm modal and verify its copy/buttons, then CANCEL or close it. The in-flight LOADING state is verified via the pre-seeded "QA In Flight" job (28058), NOT by triggering a real regenerate. (The POST endpoint + extraction are already covered by Layers 3 and 4.)
- **NEVER substitute code inspection for runtime testing.** If you cannot reach or see a UI element the spec says should exist, THAT is the finding (HIGH): report what you expected, what you saw, the URL, and a screenshot. Do not read source and declare it "looks correct."
- **NEVER test a different feature and call it a pass.** Stay on the Job criteria section.
- Do NOT start/stop the server. Do NOT run qa-harness cleanup (it would wipe the seeded state jobs other agents need). Do NOT modify files except your findings JSON. Do NOT set DATABASE_URL / edit .env.
- Screenshots: save to `/tmp/qa-run-3-l5/agent-{M}/` (create the dir).

## What to verify (your specific assignment is in your prompt)
Follow the click-path in the navigation map (jobs list → job → Job setup → Plato AI settings). Use `browser_snapshot` to assert the section's structure matches the expected per-state UI in the nav map. Check:
- The correct EmptyState/card for the state (icon, title, message text — verbatim per nav map / SPEC §8.2).
- The correct action-row buttons for the state (Generate vs View+Regenerate vs Regenerate-only).
- Copy rules (SPEC §10): no em dashes; sentence case; "extract" vocabulary; static button labels (no interpolated counts).
- Console: after loading your page, call `browser_console_messages` (level error) and compare against the KNOWN pre-existing errors in the nav map. Only NEW feature-referencing errors are findings.
- If assigned a modal: open it, snapshot, verify copy/buttons/structure, then close/cancel (NEVER confirm regenerate).

## Severity (Layer 5)
- **BLOCKER**: page won't render / crash / 500 / broken route — can't use the feature.
- **HIGH**: user hits wrong behavior, missing UI, wrong copy, missing/incorrect button, broken navigation, a state renders the wrong thing, a feature-referencing console/React error, or you cannot reach your assigned scope. Spec-vs-UI mismatch is HIGH (never MED).
- **MED**: report-only (pre-existing; spec-compliant-but-imperfect; consistent with existing patterns; design/product decision; out of scope). Do NOT fix.
- **LOW**: nitpick.
Only HIGH/BLOCKER affect convergence.

## OUTPUT (mandatory)
Write ONE JSON file: `reviews/qa-run-3/layer-5-playwright/round-{N}/agent-{M}.json` (absolute base `/Users/jessica/claude-hub/inflow-ats/features/job-criteria-settings-2026-07-03/`). Format:
```json
{
  "layer": "playwright",
  "round": N,
  "agent_index": M,
  "assignment": "<your scope>",
  "steps": ["click-path you followed + what you saw at each step"],
  "screenshots": ["/tmp/qa-run-3-l5/agent-M/..."],
  "findings": [
    {"id":"l5-r{N}-a{M}-001","severity":"HIGH|MED|LOW","title":"...","url":"...","expected":"...","actual":"...","evidence":"screenshot path / snapshot excerpt"}
  ]
}
```
If everything is correct, write `"findings": []` and list what you verified in `steps`. Final chat message: your assignment, PASS/finding-count, one line per finding. Under 180 words — the orchestrator reads your JSON for detail.
