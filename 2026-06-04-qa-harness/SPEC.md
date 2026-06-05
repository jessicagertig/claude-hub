# QA Verification Harness — Spec

## Summary

A QA verification phase (Phase 8) for the feature development lifecycle. After implementation passes adversarial code review (Phase 6), a series of fresh QA agents verify the feature actually works by exercising it in a running test environment. The harness is infrastructure code that lives in claude-hub and handles the pipeline-specific mechanics (starting servers, seeding data, authenticating) so QA agents can focus on judgment — what to check, what's broken, what to do next.

Browser automation is handled entirely by the Playwright MCP, not by harness code. The harness owns only the things the MCP can't do: server lifecycle, data seeding, authentication flows, and cleanup.

## Stack scope

- **Harness code:** Python, lives in `~/claude-hub/qa-harness/`
- **Browser automation:** Playwright MCP (`mcp__playwright__*` tools) — click, fill, navigate, snapshot, screenshot, evaluate, network inspection
- **Test server:** Pipeline-specific. For inflow-ats: Rails + Sidekiq in `RAILS_ENV=test` on port 5007
- **Data seeding:** Pipeline-specific. For inflow-ats: `/cypress/*` HTTP endpoints
- **Auth:** Pipeline-specific. For inflow-ats: magic-link dev workaround

## Architecture

### What the harness does (pipeline-specific mechanics)

The harness is a Python CLI (`qa-harness`) that QA agents invoke via Bash. It handles three categories of work that vary per pipeline and that the Playwright MCP cannot do:

1. **Server lifecycle** — Start and stop the test server and any supporting processes. For inflow-ats: Rails + Sidekiq with nvm/Node version pinning.
2. **Data seeding and cleanup** — Create test data and reset between runs. For inflow-ats: POST/DELETE to `/cypress/*` endpoints.

Authentication is NOT a harness command. The harness is a Python CLI invoked via Bash — it cannot call Playwright MCP tools. Login is performed by the QA agent directly using MCP tools, following the auth instructions in the pipeline config.

### What the harness does NOT do

- **Browser automation.** No click, fill, navigate, screenshot code. That's the Playwright MCP, called by the agent directly.
- **Authentication.** The harness cannot call MCP tools (it's a subprocess, not an agent). Login flows are agent-driven using MCP tools.
- **Judgment.** No deciding what to test, what's broken, or what to do next. That's the QA agent.
- **Test writing.** No RSpec or Cypress additions. QA agents write temporary verification scripts to `/tmp`.

### What the QA agent does

The QA agent is a Claude Code sub-agent spawned by the Phase 8 orchestrator (via TaskCreate). Each agent runs as a separate sub-agent process with its own Playwright MCP browser session. Separate sessions are inherent to the sub-agent model (each TaskCreate gets its own tool context) and ensure each agent has completely fresh browser state. Each agent has access to the Playwright MCP tools and the harness CLI.

The orchestrator (not individual agents) owns server lifecycle: it calls `qa-harness start` once before dispatching the team, and `qa-harness stop` after all agents complete.

Agents execute sequentially within a round, not in parallel. They share the same server and database, so parallel execution would cause data conflicts (one agent's cleanup would destroy another's seeded data). The "team" concept provides diversity of independent perspectives (each agent has fresh context with no memory of how prior agents approached the problem), not parallelism. Each agent does cleanup + seed + test in isolation before the next agent begins.

Each agent's job:

1. Call `qa-harness seed --plan <path>` to create test data for its scenario
2. Authenticate using Playwright MCP tools directly (following the auth instructions in the pipeline config)
3. Use Playwright MCP tools to navigate, interact, and inspect the app
4. Use `mcp__playwright__browser_snapshot` to read page state (preferred over screenshots for structured element data)
5. Write temporary verification scripts to `/tmp` and run them via the configured `script_runner` command (e.g., `test_frr` for Rails pipelines)
6. Run existing RSpec/Cypress suites to check for regressions
7. Record findings with severity, evidence, and reproduction steps
8. Call `qa-harness cleanup` between test scenarios

## Pipeline configuration

Each pipeline provides a config file at `~/claude-hub/<pipeline>/qa-config.yml` declaring what's available. The harness reads this to know how to operate.

```yaml
# ~/claude-hub/inflow-ats/qa-config.yml
pipeline: inflow-ats
source_repo: /Users/jessica/wrk/wrk-corp/inflow-ats

server:
  start_command: |
    source ~/.nvm/nvm.sh && nvm use > /dev/null 2>&1 &&
    RAILS_ENV=test bundle exec rails s -p 5007
  sidekiq_command: |
    source ~/.nvm/nvm.sh && nvm use > /dev/null 2>&1 &&
    RAILS_ENV=test bundle exec sidekiq
  base_url: http://app.lvh.me:5007
  port: 5007
  health_check_path: /
  startup_timeout_seconds: 180

seed:
  cleanup_endpoint: DELETE /cypress/cleanup
  available_endpoints:
    - method: POST
      path: /cypress/users
      params: {setActivePaidSubscription: bool, setCancelledSubscription: bool, setGodAdmin: bool, setFreeV2Subscription: bool}
      creates: "Default user (Rezu May) + org (Acme Inc)"
    - method: POST
      path: /cypress/users/add_users
      requires: [/cypress/users]
      creates: "3 Faker users in the default org"
    - method: POST
      path: /cypress/users/add_second_org
      params: {setActivePaidSubscription: bool}
      requires: [/cypress/users]  # checks for god_admin role user
      creates: "Perry Anker + Patents LLC"
    - method: POST
      path: /cypress/users/create_member_and_assign_to_job
      requires: [/cypress/users, /cypress/jobs]
      creates: "Taylor Brooks, assigned to first job"
    - method: POST
      path: /cypress/jobs
      params: {published: bool, title: string}
      requires: [/cypress/users]
      creates: "A job in the default org"
    - method: POST
      path: /cypress/candidates
      params: {amount: int}
      requires: [/cypress/jobs]
      creates: "N candidates on the default job"
    - method: POST
      path: /cypress/organizations/create_paid_subscription
      requires: [/cypress/users]
      creates: "Active paid subscription on default org"
    - method: POST
      path: /cypress/organizations/create_active_free_subscription
      requires: [/cypress/users]
      creates: "Active free subscription on default org"
    - method: POST
      path: /cypress/organizations/cancel_subscription
      requires: [/cypress/users]
      creates: "Cancelled subscription on default org"
    - method: POST
      path: /cypress/organizations/create_complete_subscription
      requires: [/cypress/users]
      creates: "Complete subscription with real Stripe on default org"
    - method: POST
      path: /cypress/admin_users/create_god_admin
      creates: "God admin user"
    - method: GET
      path: /cypress/invites/{email_base64}
      returns: "{accept_url: string}"
    - method: GET
      path: /cypress/individual_app/careers_page_subscriptions/{id}
      returns: "Careers page subscription data"

auth:
  default_user: rezu.may@wrkhq.com
  instructions: |
    1. Navigate to {base_url}/auth
    2. Fill the email input (input[name="email"]) with the user's email
    3. Click "Continue with email"
    4. Wait for the dev workaround div containing a link with href matching "magic_links/validate"
    5. Extract that link's href and navigate to it
    6. Login is complete when the page redirects to the dashboard

script_runner:
  command: test_frr   # alias for RAILS_ENV=test foreman run rails runner
  file_extension: .rb # so agents know what language to write scripts in

verification_layers:
  - script_runner  # temporary verification scripts in /tmp, using the configured command
  - rspec          # existing suite, regression only
  - cypress        # existing suite, regression only
  - playwright_mcp # interactive browser verification via MCP
```

For a non-web pipeline, the config would omit `server`, `auth`, and the `playwright_mcp` layer — QA would only use `script_runner` and whatever regression suites exist.

## CLI interface

```
qa-harness start [--config path/to/qa-config.yml]
    Start the test server and supporting processes.
    Kills any existing processes on the configured port first.
    Polls health check until ready or timeout.
    Prints "READY" to stdout on success.

qa-harness stop
    Terminate all processes started by `qa-harness start`.
    Prints "STOPPED" to stdout.

qa-harness seed --plan path/to/seed-plan.json
    Execute a seed plan (a JSON array of endpoint calls).
    Calls cleanup first, then runs the endpoints in order.
    Prints each endpoint call and its result.

qa-harness seed-endpoints [--config path/to/qa-config.yml]
    List all available seed endpoints from the config, with params and descriptions.
    Used by the seed planner to know what's available.

qa-harness cleanup
    Call the cleanup endpoint (e.g., DELETE /cypress/cleanup).
    Resets the database to empty state.

qa-harness status
    Report whether the server is running, what port, what user is logged in.
```

## Convergence loop

The convergence loop is orchestrator logic (the Phase 8 prompt), not harness code. But the spec defines the protocol:

### Severity scale

- **BLOCKER** — Feature is broken, cannot be used at all
- **HIGH** — Significant bug, feature works but incorrectly in an important way
- **MED** — Minor bug or UX issue, feature mostly works
- **LOW** — Cosmetic, nitpick, or edge case unlikely to matter

### Convergence criteria

- Only HIGH and BLOCKER findings affect convergence
- Two consecutive QA rounds where:
  - No prior HIGH+ findings are invalidated (finding was wrong)
  - No new HIGH+ findings are discovered
- MED and LOW findings are collected and reported but don't reset the pass counter

### Round mechanics

1. **Seed planning.** Before the first round, the orchestrator spawns a seed planner agent. This agent reads the feature spec, the implementation diff, and the available seed endpoints (`qa-harness seed-endpoints`). It produces seed plans — JSON arrays of endpoint calls — for each data scenario the feature needs. Example: testing a "team permissions" feature requires scenarios like "solo user," "user with team members," "user with cancelled subscription." Each scenario becomes a seed plan file in the working directory (`reviews/seed-plans/`).

2. **Dispatch.** Orchestrator spawns a team of fresh QA agents sequentially (clean context, no memory of prior rounds). Default team size is 3 agents; this is configurable via `qa_team_size` in `qa-config.yml`. Each agent receives: the feature spec, the implementation diff, the seed plans, and consolidated findings from all prior rounds. Agents execute one at a time against the shared server — sequential execution prevents data conflicts from cleanup/seed operations.

3. **Execute.** Each agent independently: picks the relevant seed plan for what it's testing, runs `qa-harness seed --plan <path>`, validates or invalidates prior findings, and looks for new issues from its own angle. Agents may test different scenarios using different seed plans.

4. **Consolidate.** Orchestrator merges findings across the team — deduplicates, merges, resolves conflicts (if two agents disagree on a finding, it stays alive for the next round to re-examine).

5. **Evaluate.** Orchestrator compares consolidated HIGH+ findings to previous round. If stable → increment pass counter. If changed → reset to 0.

6. Two consecutive passes → converged. Report MEDs to Jessica.

### Round cap

5 rounds maximum. If convergence hasn't been reached by round 5, the orchestrator escalates to Jessica with all findings and the convergence history.

This matches the existing lifecycle pattern: Phase 2 (spec review) and Phase 6 (impl review) both use 5-round caps with 2-consecutive-clean-pass convergence.

## Findings report format

Each QA round produces a JSON findings file and a markdown summary in the feature working directory.

### Per-agent findings (`reviews/qa-round-N/agent-M.json`)

Each agent on the team writes its own findings file:

```json
{
  "round": 1,
  "agent_index": 2,
  "timestamp": "2026-06-04T18:30:00Z",
  "prior_findings_reviewed": [
    {
      "id": "finding-001",
      "original_round": 0,
      "verdict": "confirmed",
      "notes": "Reproduced exactly as described"
    }
  ],
  "new_findings": [
    {
      "id": "r1-a2-001",
      "severity": "HIGH",
      "title": "Job creation fails when title contains special characters",
      "description": "Entering a job title with an ampersand causes a 500 error on submit",
      "reproduction_steps": [
        "Navigate to /jobs/new",
        "Fill title with 'Sales & Marketing Lead'",
        "Click 'Create Job'",
        "Observe 500 error"
      ],
      "evidence": {
        "snapshots": ["/tmp/qa-round-1/agent-2/snapshot-003.md"],
        "screenshots": ["/tmp/qa-round-1/agent-2/screenshot-003.png"],
        "console_errors": ["Uncaught TypeError: ..."],
        "network_requests": ["POST /api/jobs -> 500"]
      },
      "verification_method": "playwright_mcp"
    }
  ],
  "regression_results": {
    "rspec": {"ran": true, "passed": true, "summary": "245 examples, 0 failures"},
    "cypress": {"ran": false, "reason": "not configured for this pipeline"}
  }
}
```

### Consolidated findings (`reviews/qa-round-N/consolidated.json`)

The orchestrator merges all agent findings into a single consolidated report. Deduplication is by reproduction steps — if two agents found the same bug, the finding with the most detailed evidence wins. If agents disagree on whether a prior finding is valid (one confirms, one invalidates), the finding stays alive for the next round to re-examine.

```json
{
  "round": 1,
  "agent_count": 3,
  "consolidated_findings": ["...merged from all agents..."],
  "convergence_state": {
    "high_plus_changed": true,
    "new_high_plus_count": 1,
    "invalidated_high_plus_count": 0,
    "consecutive_clean_passes": 0
  }
}
```

### Markdown summary (`reviews/qa-round-N/summary.md`)

Human-readable report for Jessica, generated from the consolidated findings. Lists all findings grouped by severity, with reproduction steps and evidence. Notes which findings multiple agents independently discovered (higher confidence), which agents disagreed on (needs another look), and the convergence state.

## How findings get back to the implementation agent

Same pattern as Phase 6. When QA finds HIGH+ issues:

1. Orchestrator writes `reviews/qa-round-N/FAILURE-REPORT.md` summarizing the confirmed HIGH+ findings
2. Orchestrator goes back to Phase 5 (implementation), skipping Phase 6 (impl review) on re-entry — QA already validates behavior, and the fix is typically small and targeted
3. A new impl agent receives the failure report and fixes the issues
4. After the fix, QA resumes (not restarts — the round counter continues)

When QA converges (two clean passes):

1. Orchestrator writes `reviews/QA-COMPLETE.md` with the final verdict
2. Any MED/LOW findings are listed for Jessica to review
3. Flow is complete (hardening already ran in Phase 7, before QA)

## Server lifecycle

The harness manages the test server as a subprocess pair, adapted from `inflow_bootstrap.py` in the help pipeline.

### Start sequence

1. Kill any existing processes on the configured port (`lsof -ti tcp:<port>`)
2. Kill any existing sidekiq processes (`pgrep -f sidekiq`)
3. Start the server command as a subprocess (with `bash -c` wrapper for nvm)
4. Start the sidekiq command as a subprocess (same wrapper)
5. Register atexit + signal handlers for cleanup
6. Poll health check endpoint until it returns < 500, with configured timeout
7. Print "READY" to stdout

### Stop sequence

1. SIGTERM both subprocesses
2. Wait up to 10 seconds for graceful shutdown
3. SIGKILL if they don't exit
4. Print "STOPPED" to stdout

### Health check

Poll `GET <base_url><health_check_path>` every second. Accept any status < 500 (the app may return 302 redirects before login). Timeout after `startup_timeout_seconds` (default 180s for Rails cold start with webpack compilation).

On each poll iteration, also check whether the server subprocess has exited (`proc.poll() is not None`). If the process has died, fail immediately with the exit code instead of waiting for the full timeout. This matches the analog's premature-exit detection in `inflow_bootstrap.py:_wait_for_health`.

## Authentication

Authentication is performed by the QA agent directly using Playwright MCP tools — NOT by the harness CLI. The harness is a subprocess and cannot call MCP tools.

The pipeline config includes auth instructions that tell the QA agent how to log in. For inflow-ats, the agent:

1. `mcp__playwright__browser_navigate` to `{base_url}/auth`
2. `mcp__playwright__browser_fill_form` the email field with the configured default user
3. `mcp__playwright__browser_click` "Continue with email"
4. `mcp__playwright__browser_snapshot` to find the magic link href in the dev workaround div
5. `mcp__playwright__browser_navigate` to the extracted magic link URL

The auth instructions in the config are documentation for the agent, not executable code. The agent reads them and drives the MCP tools accordingly. This means auth flows can be arbitrarily complex — the agent has judgment, not just a script.

## Data seeding

### Seed planning

Before QA rounds begin, a seed planner agent analyzes the feature and produces seed plans — JSON files that specify exactly which endpoints to call and with what parameters. The planner reads:

- The feature spec (what the feature does)
- The implementation diff (what changed)
- The available seed endpoints (`qa-harness seed-endpoints`)

It produces one seed plan per data scenario the feature needs to be tested against. Plans are written to `reviews/seed-plans/`.

Example seed plan (`reviews/seed-plans/team-with-candidates.json`):

```json
[
  {"method": "POST", "path": "/cypress/users", "body": {"setActivePaidSubscription": true}},
  {"method": "POST", "path": "/cypress/users/add_users"},
  {"method": "POST", "path": "/cypress/jobs", "body": {"published": true, "title": "Engineering Manager"}},
  {"method": "POST", "path": "/cypress/candidates", "body": {"amount": 15}}
]
```

### Seed execution

`qa-harness seed --plan <path>` reads the JSON plan file and executes the calls sequentially via `requests`. It always calls `DELETE /cypress/cleanup` first to ensure isolation. Each QA agent picks the seed plan appropriate for whatever scenario it's testing.

Before making any HTTP calls, `seed` and `cleanup` commands verify the server is alive by hitting the health check endpoint. If the server is not responding, they fail immediately with a clear error message (e.g., "Server not responding at http://app.lvh.me:5007 — run `qa-harness start` first or check `qa-harness status`") rather than letting `requests` time out opaquely.

## Three verification layers

### 1. Scripted verification (`script_runner`)

Each pipeline defines a `script_runner` command in its config. For inflow-ats, this is `test_frr` (alias for `RAILS_ENV=test foreman run rails runner`). For a Python pipeline, it might be `python -m pytest -xvs` or a custom script runner.

QA agents write targeted verification scripts to `/tmp` and run them via the configured `script_runner` command. For inflow-ats (Rails), these scripts:

- Build up ActiveRecord objects and exercise code paths
- Verify business logic, validations, associations, callbacks
- Are disposable — not added to the test suite
- Are the primary tool for non-visual verification

### 2. Regression suites (RSpec, Cypress)

QA agents run existing test suites to check for regressions introduced by the implementation. They do NOT add new tests to these suites. If a regression is found, it's reported as a finding.

### 3. Playwright MCP (interactive browser verification)

QA agents use the Playwright MCP tools directly to:

- Navigate to pages and verify they render correctly
- Fill forms and submit them, verifying the results
- Check that UI state matches expectations after actions
- Inspect network requests for correct API behavior
- Read console messages for JavaScript errors
- Verify accessibility via `browser_snapshot` (returns structured accessibility tree)

`browser_snapshot` is preferred over visual screenshots for assertions because it returns structured element data that the agent can reason about precisely. Screenshots are used for evidence in findings reports.

## Constraints and requirements

### Test environment safety (HARD RULES)

- `RAILS_ENV=test` always. Never dev, never production.
- Data seeding via Cypress endpoints only (they are gated on `Rails.env.test?`).
- Cleanup via `DELETE /cypress/cleanup` only.
- No permanent test suite additions without Jessica's review.
- Temporary scripts go in `/tmp` only.
- The harness must never modify `.env` files.
- The harness must never set `DATABASE_URL`.

### Playwright MCP constraints

- The MCP manages the browser session — the harness does not start or stop Chromium.
- `browser_snapshot` returns an accessibility tree, not a visual screenshot. Use it for structural assertions.
- The MCP's `browser_navigate` uses `domcontentloaded` by default, which is correct for inflow-ats (the app never reaches `networkidle` due to WebSocket polling).
- Default timeouts should be generous (60s) because Rails cold starts are slow.

### Pipeline scalability

- Every pipeline-specific detail is in `qa-config.yml`, not in harness code.
- The harness core is pipeline-agnostic: it reads the config, starts the server, calls seed endpoints, runs the auth flow.
- A new pipeline adds a config file. No harness code changes.
- Non-web pipelines omit `server`, `auth`, and `playwright_mcp` — only `script_runner` and regression layers apply.

## Existing patterns to follow

### From the help pipeline (`~/polymer-help-pipeline/src/help_pipeline/`)

| Pattern | Source file | How it applies |
|---|---|---|
| Server lifecycle (start, health poll, stop, signal handlers) | `inflow_bootstrap.py` | Direct adaptation for the harness `start`/`stop` commands |
| Cypress API wrapper (seed endpoints, cleanup) | `cypress_api.py` | Direct adaptation for `seed`/`cleanup` commands |
| Magic-link login flow | `login.py` | Same flow, but driven by the QA agent via Playwright MCP tools instead of Python Playwright bindings. Not a harness command — agent reads auth instructions from the config and executes directly |
| Process kill pattern (lsof, pgrep, SIGTERM) | `inflow_bootstrap.py:_kill_existing_processes` | Same pattern for the harness |
| Health check polling | `inflow_bootstrap.py:_wait_for_health` | Same pattern, accept < 500 |
| domcontentloaded wait strategy | `runner.py:_execute_navigation_phases` | Inflow-ats never reaches networkidle |
| Action primitives (click_text, fill_by_label, etc.) | `fallback_executor.py` | NOT used — Playwright MCP replaces these entirely |

### From the feature development lifecycle (`~/claude-hub/features/`)

| Pattern | Source | How it applies |
|---|---|---|
| 5-round cap with 2-consecutive-clean-pass convergence | Phase 2 (spec review), Phase 6 (impl review) | Same pattern for QA convergence |
| `FAILURE-REPORT.md` for sending issues back to impl | Phase 6 → Phase 5 loop | Same pattern for QA → impl loop |
| `*-COMPLETE.md` gate file | `SPEC-REVIEW-COMPLETE.md`, `IMPL-REVIEW-COMPLETE.md` | `QA-COMPLETE.md` follows the same convention |
| Fresh agent per round | Phase 2, Phase 6 | QA uses fresh agents to avoid confirmation bias |
| Findings in `reviews/` subdirectory | Phase 2, Phase 6 | QA findings go in `reviews/qa-round-N/` |

## Artifact trail

After Phase 8, the feature working directory gains:

```
reviews/
├── seed-plans/
│   ├── solo-user.json
│   ├── team-with-candidates.json
│   └── cancelled-subscription.json
├── qa-round-1/
│   ├── agent-1.json
│   ├── agent-2.json
│   ├── agent-3.json
│   ├── consolidated.json
│   └── summary.md
├── qa-round-2/
│   ├── agent-1.json
│   ├── agent-2.json
│   ├── agent-3.json
│   ├── consolidated.json
│   ├── summary.md
│   └── FAILURE-REPORT.md      (if HIGH+ issues found)
├── qa-round-3/
│   ├── agent-1.json
│   ├── agent-2.json
│   ├── agent-3.json
│   ├── consolidated.json
│   └── summary.md
└── QA-COMPLETE.md              (when converged)
```

## Data model changes

None. This is infrastructure tooling, not an application feature.

## API changes

None. The harness consumes existing Cypress endpoints; it does not create new ones.

## Frontend changes

None. The harness verifies existing frontend behavior; it does not modify it.

## Authorization requirements

None. The harness runs in `RAILS_ENV=test` using the dev magic-link workaround, which bypasses real authentication. The Cypress seed endpoints are test-only and gated on `Rails.env.test?`.

## Plain English summary

The QA harness is the final verification gate in the feature development lifecycle. After a feature has been spec'd, reviewed, planned, implemented, and code-reviewed, the QA phase answers the question: does it actually work?

First, a seed planner looks at the feature and figures out what test data scenarios are needed — a solo user, a full team with candidates, a cancelled subscription, whatever the feature requires. It produces concrete data setup commands for each scenario.

Then the harness boots a test version of the app, seeds it with data, logs in, and hands control to a team of QA agents. Each agent independently explores the feature from its own angle — clicking through the UI, filling out forms, running test scripts, checking for regressions. Because multiple agents work the same round independently, they catch things a single agent would miss, and when several agents find the same bug independently, confidence is high.

After the team finishes a round, the orchestrator consolidates their findings, deduplicates, and handles disagreements — if agents conflict on whether something is real, it stays alive for the next round to settle. Then a fresh team is dispatched. The new team gets the consolidated findings and their job is to verify whether each prior finding holds up and to look for anything the previous team missed. If two consecutive team rounds produce stable results — no new major bugs, no prior findings overturned — the feature is verified. If issues are found, they go back to the implementation agent for fixing, and QA picks up where it left off.

The harness itself is intentionally thin. It handles the pipeline-specific plumbing — starting servers, seeding databases, logging in — and delegates all browser interaction to the Playwright MCP, which is already available as a Claude Code tool. This means a new pipeline only needs a config file listing how to start its app, what seed endpoints exist, and how to log in. No harness code changes required.

## Blast radius analysis

- **Feature lifecycle (`~/claude-hub/features/`):** Phase 8 (QA verification) is added after Phase 7 (hardening). `LIFECYCLE.md` and the orchestrator prompt need a new section and a new prompt file (`qa-prompt.md`). No existing phases change — Phases 0-7 work exactly as before. Note: hardening (Phase 7) does not incorporate QA findings because it runs first. QA failure reports loop back to Phase 5 (impl) directly, skipping Phase 6 (impl review) on re-entry. `QA-COMPLETE.md` is the Phase 8 gate file.
- **Pipeline configs:** Each pipeline gains a `qa-config.yml` file. No existing pipeline files are modified.
- **Inflow-ats source repo:** Zero changes. The harness consumes existing Cypress endpoints and the magic-link login flow. Nothing is added, modified, or removed in the source repo.
- **Help pipeline:** Zero changes. Patterns are adapted into new code, not shared or linked. The help pipeline continues to work independently.
- **Playwright MCP:** The harness depends on it being configured in the Claude Code session. If the MCP is unavailable, the `playwright_mcp` verification layer is unusable but the other layers (`script_runner`, regression suites) still work.
- **If this is wrong:** The blast radius is contained to temporary files (`/tmp`) and findings reports in the feature working directory (`reviews/qa-round-N/`). No source code, no test suites, no databases, no `.env` files are modified by the harness. The worst case is wasted agent time, not broken code.
