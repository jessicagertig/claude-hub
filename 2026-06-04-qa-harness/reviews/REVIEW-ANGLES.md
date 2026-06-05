# Review Angles — QA Verification Harness

Generated from: SPEC.md
Date: 2026-06-04

## Subsystems touched

- `~/claude-hub/qa-harness/` — new Python package (the harness CLI)
- `~/claude-hub/features/LIFECYCLE.md` — Phase 8 addition
- `~/claude-hub/<pipeline>/qa-config.yml` — new per-pipeline config format
- `~/claude-hub/features/` — new Phase 8 orchestrator prompt and QA agent prompt
- Playwright MCP (`mcp__playwright__*`) — consumed, not modified
- Inflow-ats Cypress endpoints (`/cypress/*`) — consumed, not modified
- Inflow-ats magic-link login flow — consumed, not modified

## Closest analog

The help pipeline (`~/polymer-help-pipeline/src/help_pipeline/`) is the closest analog. It solves the same problem — boot Rails in test mode, seed data, log in, drive a browser, capture findings — in a different context (drift detection for help articles vs. QA verification for implemented features).

Layer-by-layer trace:

| Layer | Help pipeline file | QA harness equivalent |
|---|---|---|
| Orchestration | `runner.py` (boot → iterate articles → teardown) | Phase 8 orchestrator prompt (boot → iterate rounds → teardown) |
| Server lifecycle | `inflow_bootstrap.py` (start/stop Rails+Sidekiq, health poll) | `qa-harness start`/`stop` commands |
| Data seeding | `cypress_api.py` + `seed_parser.py` (endpoint wrapper + shorthand parser) | `qa-harness seed` command + seed plan JSON |
| Authentication | `login.py` (magic-link via Playwright Python bindings) | `qa-harness login` (magic-link via Playwright MCP) |
| Browser actions | `fallback_executor.py` (action primitives) | **Not used** — Playwright MCP replaces this |
| Vision/judgment | `article_interpreter.py` + `recovery.py` (Claude API calls with screenshots) | QA agent's own judgment (Claude Code agent reads snapshots/screenshots) |
| State machine | `coordinator.py` (per-article state transitions, halt reasons) | Convergence protocol (per-round findings, severity scale, pass counting) |
| Findings output | `findings_writer.py` (JSON bundle per article) | Per-agent JSON + consolidated JSON + markdown summary |

**Priority rule:** Where the analog deviates from convention, the analog wins. Key deviations to preserve:
- `domcontentloaded` instead of `networkidle` (inflow-ats never settles)
- 60s default timeouts (Rails cold start is slow)
- `bash -c` wrapper for nvm in subprocess commands
- Health check accepts < 500, not just 200 (app returns 302 before login)

## Angles

### server-lifecycle

**What this covers:** The start/stop/health-check design and its handling of process management edge cases — zombie processes, port conflicts, startup timeouts, signal handlers, nvm/Node version pinning, atexit cleanup.

**Files across all layers:**
- SPEC.md §§ Server lifecycle, CLI interface (`start`, `stop`, `status`)
- SPEC.md § Pipeline configuration (`server:` block in `qa-config.yml`)

**Analog files for comparison:**
- `~/polymer-help-pipeline/src/help_pipeline/inflow_bootstrap.py` — the full lifecycle implementation
- `~/polymer-help-pipeline/src/help_pipeline/runner.py:_check_rails_health` — mid-run health checks

**Key questions:**
- Does the spec handle the case where Rails exits during a QA round (not just at startup)?
- Does the spec handle Sidekiq dying independently of Rails?
- The analog uses `os.system` with temp-file redirection for process kills (to avoid interfering with mocked subprocess.Popen in tests). Is this pattern needed here?
- The analog has a 180s startup timeout. Is this sufficient given that QA might run after a fresh `db:migrate`?

### seed-data-design

**What this covers:** The seed planning step, the seed plan JSON format, the execution flow, cleanup isolation between scenarios, and whether the available endpoint catalog is complete.

**Files across all layers:**
- SPEC.md §§ Data seeding, Round mechanics (step 1), Pipeline configuration (`seed:` block)
- SPEC.md § Findings report format (seed plan references in evidence)

**Analog files for comparison:**
- `~/polymer-help-pipeline/src/help_pipeline/cypress_api.py` — endpoint wrapper with typed methods
- `~/polymer-help-pipeline/src/help_pipeline/seed_parser.py` — shorthand-to-method dispatch

**Key questions:**
- Can the seed planner agent actually produce correct seed plans without knowing endpoint ordering dependencies? (e.g., `POST /cypress/jobs` requires a user to exist first — must users be seeded before jobs)
- Is the JSON plan format expressive enough? Can it express conditional seeding, or assertions ("verify the user exists before proceeding")?
- Does cleanup between scenarios within a single agent's run need to be explicit in the spec? (Agent tests scenario A, needs to reset before scenario B)
- The analog's `seed_parser.py` validates seed commands at parse time (unknown endpoints raise `SeedParseError`). Does the harness need equivalent strictness for plan files?

### convergence-protocol

**What this covers:** The multi-agent team-per-round convergence logic — whether the severity scale, pass counting, deduplication, disagreement handling, and round cap produce reliable results.

**Files across all layers:**
- SPEC.md §§ Convergence criteria, Round mechanics, Convergence loop, Round cap
- SPEC.md § Findings report format (convergence_state in consolidated.json)

**Analog files for comparison:**
- `~/claude-hub/features/spec-review-prompt.md` — 5-round, 2-clean-pass convergence for spec review
- `~/claude-hub/features/impl-review-prompt.md` — same pattern for impl review

**Key questions:**
- With a team of agents, how many agents per team? Is this fixed or configurable? The spec doesn't say.
- When agents disagree on a prior finding (one confirms, one invalidates), the spec says it "stays alive." Does this count as a change for convergence purposes? If yes, disagreements can prevent convergence indefinitely.
- The severity scale has four levels but only two affect convergence. Is MED really non-blocking? A feature with 20 MED findings might still be broken in practice.
- The 5-round cap with teams of agents is significantly more expensive than single-agent rounds. Is there a cost consideration or token budget?
- What prevents the same agent from being spawned with the same "angle" twice across teams? Is diversity of approach enforced or emergent?

### playwright-mcp-integration

**What this covers:** Whether the spec correctly accounts for how the Playwright MCP works — session persistence, tool capabilities, limitations, and whether the auth flow can actually be driven via MCP tools.

**Files across all layers:**
- SPEC.md §§ Architecture (what the harness does NOT do), Authentication, Three verification layers (§3 Playwright MCP), Playwright MCP constraints
- Available MCP tools: `mcp__playwright__browser_navigate`, `browser_click`, `browser_fill_form`, `browser_snapshot`, `browser_evaluate`, `browser_console_messages`, `browser_network_requests`, etc.

**Key questions:**
- `browser_snapshot` returns an accessibility tree. Is this sufficient for verifying visual layout issues (e.g., overlapping elements, wrong colors, missing icons)?
- The MCP maintains one browser session. If multiple QA agents run in parallel, do they share the session or each get their own? Parallel agents with one browser is a race condition.
- Does the MCP's `browser_navigate` handle the `domcontentloaded` wait strategy, or does it use its own default?
- Can the MCP take screenshots and save them to a path, or only return them inline? The spec references screenshot paths in evidence.

### pipeline-scalability

**What this covers:** Whether the `qa-config.yml` format and the harness architecture genuinely support non-inflow-ats pipelines, and what breaks when you try.

**Files across all layers:**
- SPEC.md §§ Pipeline configuration, Pipeline scalability constraints, Architecture
- `~/claude-hub/CLAUDE.md` — pipeline list (7 pipelines, each would need a config)

**Key questions:**
- For non-web pipelines (e.g., `thought-leadership-automation`, `polymer-prospecting-pipeline`), the spec says only `test_frr` applies. But `test_frr` is `RAILS_ENV=test bundle exec rails runner` — that's Rails-specific. What's the equivalent for a Python pipeline?
- The auth flow is defined declaratively with steps like `navigate`, `fill`, `click_text`. Is this mini-DSL expressive enough for auth flows that aren't magic-link? (OAuth, API key, session cookie?)
- The seed endpoint catalog is entirely Cypress-specific. Non-Rails pipelines won't have `/cypress/*` endpoints. The spec should address how seeding works when there are no HTTP seed endpoints.
- Is `qa-config.yml` the right format? YAML has footguns (implicit type coercion, indentation sensitivity). JSON would be safer for a config that includes endpoint bodies.

### lifecycle-integration

**What this covers:** Whether Phase 8 fits correctly into the existing Phase 0-7 lifecycle — gate files, artifact trail, failure-report loop, and the orchestrator's control flow.

**Files across all layers:**
- SPEC.md §§ How findings get back to impl, Artifact trail
- `~/claude-hub/features/LIFECYCLE.md` — the existing Phase 0-7 flow
- SPEC.md § Convergence loop (relationship to Phase 5 and Phase 6)

**Key questions:**
- The spec says QA happens after Phase 7 (hardening). But hardening extracts lessons from failure reports. Should QA happen before hardening, so QA findings feed into hardening too?
- The failure-report loop sends issues back to Phase 5 (impl). But Phase 6 (impl review) is between Phase 5 and Phase 8. After QA sends a fix back to Phase 5, does it go through Phase 6 again before returning to QA? Or does it skip Phase 6 on the re-entry?
- The spec defines `QA-COMPLETE.md` as the gate file. The lifecycle uses `SPEC-REVIEW-COMPLETE.md` and `IMPL-REVIEW-COMPLETE.md`. Is the naming consistent?
- Does the orchestrator need a new prompt file (e.g., `qa-prompt.md`)? The spec doesn't mention one, but every other phase has one.

## Always-on checks

### Source accuracy
Verify every file path, class, method, endpoint, and MCP tool name the spec references against the current source and available tools.

### Reinventing the wheel / pattern compliance
The help pipeline is the primary analog. Verify the harness design follows the analog's patterns where applicable (server lifecycle, seed execution, health checks) rather than inventing new approaches. Where the design intentionally diverges (MCP instead of Python Playwright bindings, team-per-round instead of single-agent), verify the divergence is justified.

### Analog completeness
Verify the QA harness has a corresponding piece for every functional layer of the help pipeline analog. A missing layer is a potential gap. The replacement of `fallback_executor.py` with Playwright MCP is an intentional substitution, not a missing layer — verify it covers the same capabilities.
