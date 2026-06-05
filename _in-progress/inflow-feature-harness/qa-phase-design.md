# Phase 8: QA — Design Notes

## Core mechanics

- Multiple fresh QA agents, iterative
- Each agent validates/invalidates prior findings AND finds new issues
- Convergence: two consecutive runs where no HIGH+ findings change and no new HIGH+ found
- MEDs collected, reported to Jessica after HIGH+ issues resolved
- Consolidated report at the end — Jessica decides what happens next

## Hard rules

- Test env only — `RAILS_ENV=test`, `test_frr`, `test_frc`, never dev
- No permanent test suite additions (RSpec, Cypress) without Jessica's review
- Temp verification scripts go in `/tmp`

## Three verification layers

### 1. `test_frr` scripts
- Write temporary Ruby verification scripts to `/tmp`
- Build up the objects needed, exercise code paths, verify results
- Targeted checks — not test suite additions
- Like RSpec but temporary and more targeted

### 2. RSpec/Cypress regression
- Run existing suites to check for regressions
- QA agent does NOT add to these suites

### 3. Playwright with screenshots — visual/interactive verification
- Agent drives Playwright via Bash commands
- Screenshots save to `/tmp`, agent reads them with the Read tool
- Screenshot → analyze → decide next action → act → screenshot → verify
- No selectors needed — agent looks at the screenshot and figures out what to click/enter
- Adapted from polymer-help-pipeline patterns

## Playwright flow (from help pipeline)

- Start test server (`test_fs` or equivalent)
- Seed data via Cypress endpoints (`/cypress/users`, `/cypress/jobs`, `/cypress/candidates`, etc.)
- Login via magic-link dev workaround (navigate to `/auth`, enter email, extract magic link from dev workaround div)
- Cleanup between runs via `DELETE /cypress/cleanup`
- Default seeded user: `rezu.may@wrkhq.com`
- Port: 5007, base URL: `http://app.lvh.me:5007`
- Help pipeline reference: `/Users/jessica/polymer-help-pipeline/src/help_pipeline/`
  - `runner.py` — orchestration, navigation
  - `login.py` — magic-link auth
  - `cypress_api.py` — seeding/cleanup endpoints
  - `inflow_bootstrap.py` — Rails/Sidekiq process lifecycle
  - `recovery.py` — screenshot analysis, drift detection
  - `article_interpreter.py` — vision → action primitives

## Convergence criteria

- Scale: BLOCKER / HIGH / MED / LOW
- Cutoff: HIGH — only HIGH+ findings affect convergence
- Two consecutive runs where:
  - No HIGH+ findings invalidated
  - No new HIGH+ findings added
- MEDs noted but don't reset the pass counter

## Playwright harness — CODE, not a prompt

This is actual infrastructure that lives in claude-hub. NOT a prompt telling agents to figure out Playwright. NOT part of the help pipeline repo.

The harness handles browser mechanics:
- Start/stop test server
- Seed data via Cypress endpoints
- Login via magic link
- Take screenshots and return them
- Execute action primitives (click, fill, navigate, etc.)

The QA agent handles judgment:
- What to check
- What's wrong
- What to do next
- Whether findings are real

Agent calls the harness via Bash. Harness returns screenshots. Agent reads them and decides.

## Not decided yet

- Language for the harness (Python like help pipeline? Node since Playwright is JS-native?)
- Round cap (5 like adversarial review?)
- Report format
- How findings get back to impl agent
- Whether the QA agent starts the test server or assumes it's running
- How this works for non-inflow-ats pipelines (generic version)
- Action primitive set (help pipeline uses: click_text, click_by_aria, fill_by_label, navigate, wait_for_selector, press_key)

## Relationship to help pipeline

The help pipeline is a Python app calling Claude's API for vision. The QA phase is a Claude Code agent. The patterns translate:
- Vision: Read tool reads screenshots (no API calls needed)
- Cypress endpoints: same ones, hit with curl or test_frr
- Magic-link login: same flow
- Playwright: agent drives via Bash
- The orchestration moves from Python into the agent itself
