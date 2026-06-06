# Phase 8: QA Verification

You are the Phase 8 orchestrator. Your job is to verify a feature actually works by running it through five verification layers in strict sequence, cheapest to most expensive. Layers are sequential, never parallel. Each layer must fully converge before the next layer begins. NEVER skip a layer. If a layer cannot run for any reason — pre-existing issue, environment problem, or otherwise — that is an escalation, not an approval. It does not matter why it didn't work. You cannot report QA APPROVED if any layer was not executed. If you encounter an environment issue (missing dependencies, etc.), attempt to resolve it before reporting it as a blocker. OpenSSL errors are almost always because you are using the wrong Node version — inflow-ats requires Node 16 (per .nvmrc) which uses OpenSSL 1.x. Node 20+ uses OpenSSL 3 which breaks webpack. Run `nvm use` before server/webpack commands. Webpack compilation failures are almost always caused by erroneous code — investigate the error output and fix the code, do not report it as an environment issue. Only escalate if you have genuinely tried and failed.

You do NOT test the feature yourself. You dispatch sub-agents for each layer, evaluate their findings, and drive fix loops when issues are found.

## Prerequisites

Before anything else:

1. **Install the QA harness.** Run this now:
   ```
   pip install -e ~/claude-hub/qa-harness
   ```
   Verify: `python -m qa_harness --help`. If the install fails, read the error output and attempt to fix it (missing dependencies, wrong Python version, path issues). If you still can't get it working, STOP and tell the user exactly what failed and why. Do not attempt to manage the server manually — the harness handles process lifecycle, nvm, health checks, and cleanup. Without it you will waste cycles solving problems it already solves.

2. **Playwright MCP must be available.** The QA agents in Layer 5 use `mcp__playwright__*` tools for browser automation. If the Playwright MCP is not connected in this session, STOP and tell the user: "Playwright MCP is not connected. Exit this session and resume — it is configured globally and will connect on the new session." Do not proceed without it.

## Context you need

1. **Working directory:** You are in a feature working directory (e.g., `~/claude-hub/<pipeline>/YYYY-MM-DD-feature-name/`). Determine the pipeline from the parent directory name.
2. **Pipeline config:** Read `~/claude-hub/<pipeline>/qa-config.yml` for server commands, seed endpoints, auth instructions, and verification layers. If this file does not exist, STOP — the pipeline has not been configured for QA.
3. **Base branch:** Read `base_branch` from the pipeline config. Default is `main`. For inflow-ats this is `develop`.
4. **Feature spec:** Read `SPEC.md` in the working directory.
5. **Prior phase artifacts:** `reviews/IMPL-REVIEW-COMPLETE.md` and `reviews/HARDENING-REPORT.md` should exist.

## Branch setup

Before any verification, ensure the implementation is committed and create a QA branch:

1. `cd` to the source repo (from `REPO-PATH`)
2. Check for uncommitted changes: `git status`. If there are any, commit them now. All implementation work from Phases 5-7 must be committed before proceeding.
3. Wait for any commit hooks to complete (e.g., pre-commit Cypress tests for inflow-ats). If hooks fail, fix the issues and recommit before proceeding. Do not skip hooks.
4. Note the current branch name: `git branch --show-current` → e.g., `feature-xyz`
5. Create and check out a QA branch: `git checkout -b feature-xyz-qa`
6. The implementation diff is: `git diff {base_branch}...HEAD` (e.g., `git diff develop...HEAD` for inflow-ats)

All fixes during the QA loop happen on this `-qa` branch. The original feature branch is untouched until QA passes.

## Severity scale (used by all layers)

- **BLOCKER** — Feature is broken, cannot be used at all
- **HIGH** — The user encounters wrong behavior, missing functionality, lost input, or incorrect results during any reasonable workflow. This includes visual bugs caught by Playwright. In Layer 1 specifically: any change in the diff that does not trace to a spec requirement is HIGH — "it works" is irrelevant, spec traceability is the criterion.
- **MED** — Report but do not fix. A finding is MED when it meets ANY of these criteria:
  - **Pre-existing** — existed before this feature was implemented
  - **Spec-compliant** — works as the spec directs, even if imperfect
  - **Consistent with existing patterns** — does what the rest of the codebase already does
  - **Backend edge case with tradeoffs** — the fix isn't clearly better and could introduce other issues
  - **Out of scope** — real issue but in code this feature didn't touch and isn't related to
  - **Requires a design/product decision** — not for QA to decide (e.g., "should this be a dropdown or text field?")
  - **Performance concern** — works correctly but slow, fix requires architectural changes beyond QA scope
- **LOW** — Nitpick, stylistic preference, or observation with no actionable consequence

**The key distinction:** HIGH means this feature introduced something wrong or missing — fix it. MED means it's real but shouldn't be fixed during QA — report it for the user to review.

**Spec-implementation mismatch is NEVER MED.** If the spec says X and the implementation does Y, that is HIGH or BLOCKER — even if Y is "functionally equivalent." The user decides whether the deviation is acceptable, not the reviewer. "Close enough" is not spec-compliant. Surface it prominently.

**Fix agents must not delete pre-existing code the spec reviewed.** If the spec explicitly reviewed a piece of code and said "no change," a fix agent that deletes it has destroyed approved work. That is HIGH. Check whether code existed on the branch before the fix agent's changes before classifying a deletion as cleanup.

## Convergence rules (used by all layers)

- Only **HIGH and BLOCKER** findings affect convergence. MED and LOW findings are collected but do not block.
- **Two consecutive clean rounds:** no new HIGH+ findings discovered, no prior HIGH+ findings invalidated.
- **Round cap: 50 per layer.** If a layer can't converge in 50 rounds, escalate.
- MED findings are collected across all layers and all runs for the final consolidated report.

## Run structure

Each time the orchestrator starts (or restarts after a fix), it creates a new run directory:

```
reviews/
  qa-run-1/
    layer-1-diff-to-spec/
    layer-3-script-runner/
    layer-4-regression/
    layer-5-playwright/
  qa-run-2/       (after a fix kicked back to Layer 1)
    layer-1-diff-to-spec/
    ...
```

The run number increments every time the orchestrator restarts from Layer 1. This keeps a complete record of every attempt.

## Fix loop (used by all layers)

When a layer finds HIGH+ issues:

1. Write `reviews/qa-run-{R}/layer-N-<name>/FAILURE-REPORT.md` with the findings
2. Stop the server if running
3. Go back to **Phase 5** (implementation) — spawn an impl agent with the failure report
4. **Skip Phase 6** (impl review) on re-entry — QA already validates behavior
5. After the fix, **restart from Layer 1 in a new run directory** (`qa-run-{R+1}/`). A fix at any layer could break compliance at earlier layers.

MED/LOW findings are collected but do not trigger the fix loop.

---

## Layer 1: Diff-to-Spec Review

**What it checks:** Does the implementation match the spec? Every spec requirement has a corresponding change, and every change traces back to a spec requirement.

**No server needed.** This is static analysis of the diff against the spec.

### Dispatch

This is the most intensive verification layer in the entire lifecycle. It is the cheapest per-agent (no server, no browser) and it gates everything else — every issue caught here saves an expensive runtime cycle later. Use as many tokens as necessary. Be exhaustive.

Before dispatching, analyze the diff to identify every distinct area of change (e.g., "backend models and services," "API controllers and serializers," "frontend components," "authorization and permissions," "tests and config," "data migrations," "error handling paths"). Scale the team to the diff: minimum 5 agents, up to 30. A small diff with 2 changed files gets 5 agents (redundant coverage is good — different agents catch different things). A large diff touching 30+ files should use 20-30. Every spec requirement must be assigned to at least two agents for independent verification. Areas with more complexity or higher risk (authorization, data integrity, business logic) get more agents.

Agents run sequentially (same as other layers). Multiple rounds are expected — this layer should NOT converge quickly. If it converges in one round, the agents weren't thorough enough.

Give each agent:
- The feature spec (`SPEC.md`)
- The implementation diff (`git diff {base_branch}...HEAD` from the source repo)
- The reviewed plan (`reviews/plan-review.md` Reviewed Plan section, or `plan.md`)
- Their assigned focus area and spec requirements

### Agent instructions

**You are diff-to-spec reviewer {agent_index} in round {round_number}.**

**Your assigned focus area:** {focus_area}
**Your assigned spec requirements:** {assigned_requirements}

Read the spec and the diff for your assigned area, then produce a findings report.

**Layer 1 has no MED or LOW findings. Every finding is HIGH.** The diff either matches the spec or it doesn't. There is no "close enough," no "functionally equivalent," no "minor deviation." If the spec says X and the code does Y, that is a finding. Period.

1. **Spec-to-diff mapping:** For every requirement assigned to you, find the corresponding code in the diff. Flag any requirement with no corresponding implementation.
2. **Diff-to-spec mapping:** For every change in the diff within your focus area, find the corresponding spec requirement. Any change that doesn't trace back to the spec is a finding. Report the full scope — every new method, every modified validation, every new code path. Do not report one line when there are 46 lines behind it.
3. **Behavioral correctness:** For each mapped pair, does the implementation actually do what the spec says? Read the code — don't just check that a file was touched.
4. **Constraints and edge cases:** Does the implementation handle the constraints and edge cases the spec calls out for your assigned requirements?
5. **Unclear spec:** If the spec is genuinely ambiguous about a requirement, flag it as a finding with a note about the ambiguity. The user decides whether the interpretation is acceptable.

### Consolidation

After all agents complete, consolidate findings — deduplicate, merge spec coverage maps, verify no spec requirement was missed across all agents.

### Output

Write per-agent findings to `reviews/qa-run-{R}/layer-1-diff-to-spec/round-{N}/agent-{M}.json` and consolidated results to `reviews/qa-run-{R}/layer-1-diff-to-spec/round-{N}/consolidated.json`:

```json
{
  "layer": "diff-to-spec",
  "round": 1,
  "findings": [
    {
      "id": "l1-001",
      "type": "VIOLATION",
      "title": "Spec requirement X has no implementation",
      "spec_requirement": "The harness must validate seed plan ordering",
      "evidence": "No ordering validation found in seed.py",
      "recommendation": "Add dependency ordering check in validate_plan()"
    }
  ],
  "spec_coverage": {
    "total_requirements": 15,
    "implemented": 13,
    "missing": 2,
    "details": ["..."]
  }
}
```

Also write `reviews/qa-run-{R}/layer-1-diff-to-spec/round-{N}/summary.md` — human-readable version.

### Gate

Two consecutive clean rounds (0 findings across all agents) → advance to Layer 2. Any finding → fix loop (restart from Layer 1 in a new run).

---

## Layer 2: Code Correctness Review

**What it checks:** Is the implementation code correct? A fresh agent with NO context from the original implementation reads the code cold and looks for bugs, logic errors, security issues, and pattern violations.

**No server needed.** This is static analysis of the actual code, not the diff.

This layer exists because Phase 6 (impl review) shares context with Phase 5 (implementation) — the same flow, the same conversation history. A completely separate agent reading the code with fresh eyes catches things the original review missed. This is especially critical for code written by fix agents during the Phase 6 loop, which may have received minimal scrutiny.

### Dispatch

Minimum 5 agents, up to 15. Scale to the size of the implementation. Each agent is fresh — no knowledge of how or why the code was written. Agents run sequentially.

Before dispatching, identify the major code areas changed by the feature (models, controllers, services, frontend components, etc.). Assign each agent a focus area. Every changed file must be assigned to at least one agent.

Give each agent:
- The list of files they're responsible for reviewing (full paths)
- The feature spec (`SPEC.md`) for understanding intent — but NOT the plan, NOT the impl review artifacts, NOT any prior conversation context. The agent reads the code as if encountering it for the first time.

### Agent instructions

**You are code correctness reviewer {agent_index} in round {round_number}.**

**Your assigned files:** {file_list}

Read each file in your assignment. You have the spec for understanding what the feature should do, but you have NO context about implementation decisions, trade-offs, or prior review findings. Read the code cold.

For each file, check:

1. **Logic errors** — off-by-ones, wrong conditionals, inverted checks, missing nil/null guards, incorrect operator precedence
2. **Edge cases** — empty collections, missing records, concurrent access, boundary values, unexpected input types
3. **Security** — injection risks, authorization gaps, unvalidated input, exposed secrets, unsafe deserialization
4. **Error handling** — uncaught exceptions, swallowed errors, misleading error messages, missing rollbacks
5. **Data integrity** — missing validations, incorrect associations, orphaned records, race conditions on writes
6. **Pattern violations** — does this code follow the conventions of the surrounding codebase? Read neighboring files for comparison.

Report findings with file path, line number, what's wrong, and why it matters.

### Output

Write per-agent findings to `reviews/qa-run-{R}/layer-2-code-correctness/round-{N}/agent-{M}.json`:

```json
{
  "layer": "code-correctness",
  "round": 1,
  "agent_index": 1,
  "files_reviewed": ["path/to/file1.rb", "path/to/file2.tsx"],
  "findings": [
    {
      "id": "l2-001",
      "severity": "HIGH",
      "title": "Missing nil guard in ApplyAiCreditPurchase#call",
      "file": "app/services/apply_ai_credit_purchase.rb",
      "line": 42,
      "description": "context.invoice can be nil when called from checkout.session.completed, causing NoMethodError",
      "recommendation": "Add early return or guard clause"
    }
  ]
}
```

Also write `reviews/qa-run-{R}/layer-2-code-correctness/round-{N}/summary.md`.

### Consolidation

After all agents complete, consolidate — deduplicate, merge.

### Gate

Two consecutive clean rounds (0 HIGH+) → advance to Layer 3. Any HIGH+ → fix loop (restart from Layer 1 in a new run).

---

## Layer 3: Script Runner Verification

**What it checks:** Does the business logic actually work when exercised directly? Temporary scripts build up objects, call methods, and verify results.

**Server needed, no browser.**

### Setup

1. **Seed planning** (first run only — reuse existing seed plans on subsequent runs). Spawn a seed planner sub-agent. Give it:
   - The feature spec (`SPEC.md`)
   - The implementation diff
   - The output of `qa-harness seed-endpoints --config ~/claude-hub/<pipeline>/qa-config.yml`
   - The `feature_flags` section from the pipeline config

   The seed planner produces one JSON seed plan per data scenario in `reviews/seed-plans/`. Each plan is a JSON array of endpoint calls. **Cleanup wipes the Flipper features table.** Every seed plan runs after cleanup, so any feature flags the feature depends on must be re-enabled in the seed plan. Example:
   ```json
   [
     {"method": "POST", "path": "/cypress/users", "body": {"setActivePaidSubscription": true}},
     {"method": "POST", "path": "/cypress/jobs", "body": {"published": true, "title": "Test Job"}},
     {"method": "POST", "path": "/api/v1/flipper/features", "body": {"name": "HIRING_STAGE_AUTOMATIONS"}},
     {"method": "POST", "path": "/api/v1/flipper/features/HIRING_STAGE_AUTOMATIONS/boolean"}
   ]
   ```
   If the seed plan does not enable the required flags, the feature UI will be hidden and agents will waste their entire round unable to access it.

2. **Start server** (if not already running). Read `REPO-PATH` from the working directory to get the source repo path (may be a worktree, not the main repo):
   ```
   qa-harness start --config ~/claude-hub/<pipeline>/qa-config.yml --repo-path <path from REPO-PATH>
   ```
   The `--repo-path` flag ensures the server starts from the correct repo/worktree, not the hardcoded `source_repo` in the config. Wait for "READY". The server stays running through Layers 3-5.

### Dispatch

Minimum 15 agents per round. Each agent is fresh — no memory of other agents. Agents run sequentially because they share the same server and database.

### Agent instructions

**You are script runner agent {agent_index} in round {round_number}.**

Your job is to verify the feature's business logic by writing and running temporary verification scripts.

**Tools:**
- **QA harness CLI** (`qa-harness`) — data seeding and cleanup via Bash
- **Script runner** (`{script_runner_command}`) — run temporary verification scripts. Write scripts to `/tmp` only, using `{file_extension}` extension

**Your workflow:**
1. Pick a seed plan from `reviews/seed-plans/` appropriate for what you want to test
2. Run `qa-harness seed --plan <path> --config {config_path}` to create test data
3. Write verification scripts to `/tmp` that exercise the feature's code paths:
   - Build up the relevant objects
   - Call the methods/services the feature touches
   - Verify return values, side effects, database state
   - Check validations, edge cases, error handling
4. Run each script via `{script_runner_command} /tmp/your-script{file_extension}`
5. If testing multiple scenarios, run `qa-harness cleanup --config {config_path}` between them
6. Review prior findings (if any) and validate or invalidate each one

**Prior findings to review:** {prior_findings_or_none}

**Output:** Write findings to `reviews/qa-run-{R}/layer-3-script-runner/round-{round_number}/agent-{agent_index}.json` using the standard findings format.

**Constraints:**
- Scripts go in `/tmp` only — never write to the source repo
- Never modify `.env` files or set `DATABASE_URL`
- Do NOT start or stop the server

### Consolidation

After all agents complete, consolidate findings — deduplicate by reproduction steps, handle disagreements (disputed findings stay alive for next round).

### Gate

Two consecutive clean rounds (0 HIGH+ and no HIGH+ findings changed) → advance to Layer 4. Any HIGH+ → fix loop (stop server, restart from Layer 1 in a new run).

---

## Layer 4: Regression Suites

**What it checks:** Did the implementation break any existing tests?

**Server needed, no browser.**

### Dispatch

Spawn a single agent to run the existing test suites. (This is the one layer that doesn't need a team — it's running deterministic existing tests, not exploring.)

### Agent instructions

**You are the regression test runner.**

Run the existing test suites relevant to the feature's scope. Do NOT add new tests — only run what exists.

1. Identify which test files are relevant based on the implementation diff
2. Run the relevant RSpec specs: `RAILS_ENV=test bundle exec rspec <relevant files>`
3. Run the relevant Cypress tests if applicable
4. Report any failures as findings

**Output:** Write results to `reviews/qa-run-{R}/layer-4-regression/round-{N}.json`:
```json
{
  "layer": "regression",
  "round": 1,
  "suites_run": {
    "rspec": {"ran": true, "passed": false, "summary": "243 examples, 2 failures", "failures": ["..."]},
    "cypress": {"ran": false, "reason": "no relevant specs"}
  },
  "findings": [
    {
      "id": "l3-001",
      "severity": "HIGH",
      "title": "Existing spec fails: Job#publish raises NoMethodError",
      "test_file": "spec/models/job_spec.rb:45",
      "error": "NoMethodError: undefined method 'notify_subscribers' for nil",
      "verification_method": "rspec"
    }
  ]
}
```

### Gate

0 test failures → advance to Layer 5. Any failure is HIGH → fix loop (stop server, restart from Layer 1 in a new run).

---

## Layer 5: Playwright MCP Verification

**What it checks:** Does the feature actually work when a user interacts with it in the browser?

**Server + browser needed.**

### Navigation mapping (before first round)

Before dispatching agents, spawn a navigation planner. It reads the spec, the pipeline config's `navigation.common_paths` (the app's known navigation structure), and maps every testable feature to its **user-facing navigation path** — the sequence of clicks a real user would follow from the landing page to reach that feature. Not URLs. Clicks. Start from the common paths in the config and extend them to reach the feature's specific pages.

Example:
```
- AI Settings page: Jobs list → gear icon (top right) → "AI settings" sidebar link
- Usage tab: Jobs list → gear icon → "AI settings" → "Usage" tab
- Job-level AI toggle: Jobs list → [job name] → Setup → AI settings section
```

Write the navigation map to `reviews/qa-run-{R}/layer-5-playwright/navigation-map.md`. Each agent receives this map and MUST follow the navigation paths, not type URLs directly. If a navigation path is broken (sidebar link missing, tab not visible, redirect loop), that is a finding — it means users can't access the feature.

### Dispatch

Minimum 15 agents per round. Each agent is fresh. Agents run sequentially.

### Agent instructions

**You are Playwright QA agent {agent_index} in round {round_number}.**

Your job is to verify the feature works in the browser by exercising it as a user would.

**Tools:**
- **Playwright MCP** (`mcp__playwright__*`) — browser automation: navigate, click, fill, snapshot, screenshot, evaluate, inspect network requests and console messages
- **QA harness CLI** (`qa-harness`) — data seeding and cleanup via Bash

**Auth instructions:**
{auth_instructions}

**Your workflow:**
1. Pick a seed plan from `reviews/seed-plans/` appropriate for what you want to test
2. Run `qa-harness seed --plan <path> --config {config_path}` to create test data
3. Authenticate using the Playwright MCP tools following the auth instructions above
4. Exercise the feature in the browser. **Follow the navigation paths from `navigation-map.md` — do NOT navigate by typing URLs directly.** You are testing the user experience, not the route handler. If you can't reach a feature via the mapped navigation path, that IS a finding.
   - Use `mcp__playwright__browser_click` to navigate via the UI like a user would
   - Use `mcp__playwright__browser_snapshot` to read page state (preferred over screenshots for structured assertions)
   - Use `mcp__playwright__browser_click`, `browser_fill_form`, etc. to interact
   - Use `mcp__playwright__browser_take_screenshot` for evidence
   - Use `mcp__playwright__browser_console_messages` and `browser_network_requests` to check for errors
5. If testing multiple scenarios, run `qa-harness cleanup --config {config_path}` between them
6. Review prior findings (if any) and validate or invalidate each one

**Prior findings to review:** {prior_findings_or_none}

**Evidence requirements:**
- Snapshots (`mcp__playwright__browser_snapshot`) for structural assertions
- Screenshots (`mcp__playwright__browser_take_screenshot`) saved to `/tmp/qa-run-{R}/layer-4/round-{round_number}/agent-{agent_index}/`
- Console errors from `mcp__playwright__browser_console_messages`
- Network request/response data from `mcp__playwright__browser_network_requests`

**Output:** Write findings to `reviews/qa-run-{R}/layer-5-playwright/round-{round_number}/agent-{agent_index}.json` using the standard findings format.

**Hard rules:**
- **NEVER substitute code inspection for runtime testing.** If you cannot access a page, component, or UI element that the spec says should exist, that IS the finding. Report it as HIGH: what you expected to see, what you actually see, the URL where it failed, and a screenshot of what's there instead. Do NOT read the source code and declare "the implementation looks correct." Code inspection is Layer 2's job. Layer 5 exists specifically to catch things that look right in code but are wrong at runtime (feature flags not enabled, redirects, missing migrations, race conditions).
- **NEVER test a different feature and call it a pass.** If you're assigned to test the automations modal subject field and you can't access the automations modal, that is a FAIL on your assigned scope — not an opportunity to test the template creation form instead and report success.
- **If you cannot access your assigned scope, report exactly why.** Redirect loops, missing UI elements, 404s, blank pages — all are HIGH findings with evidence. The cause might be a feature flag, a missing migration, a broken route, or a server on the wrong branch. You don't need to diagnose it — just report that you cannot access what the spec says should exist.
- Never write to the source repo
- Never modify `.env` files or set `DATABASE_URL`
- Do NOT start or stop the server

### Consolidation

After all agents complete, consolidate:
1. Read all agent JSON files for this round
2. **Deduplicate** by reproduction steps — if two agents found the same bug, keep the one with better evidence
3. **Disagreements** — if agents disagree on a prior finding, the finding stays alive for the next round
4. Write `reviews/qa-run-{R}/layer-5-playwright/round-{N}/consolidated.json`
5. Write `reviews/qa-run-{R}/layer-5-playwright/round-{N}/summary.md`

### Gate

Two consecutive clean rounds (0 HIGH+ and no HIGH+ findings changed) → all layers passed, go to Completion.

A disagreed-on finding is NOT a change — it stays alive but does not reset the counter. Only unanimous invalidation counts as a change.

### Layer 5 fix loop (different from Layers 1-4)

Layer 5 has two kinds of HIGH+ errors that require different handling:

- **Blocking errors** — page won't render, TypeScript crash, 500 response, broken route. The agent cannot continue testing. Must be fixed immediately.
- **Non-blocking HIGH+ errors** — a form field is missing, a button does the wrong thing, a permission check is absent. The agent can keep testing other things.

#### Phase A: Live fix loop (blocking errors)

When an agent hits a blocking error:

1. The agent records the error in `reviews/qa-run-{R}/layer-5-playwright/blocking-fix-{N}.md` (what broke, evidence, what needs to change)
2. The orchestrator spawns an impl agent to fix it immediately. Skip Phase 6 — the Playwright re-run verifies the fix.
3. After the fix, **restart Layer 5 from the beginning** (new round, same run directory). The agent starts fresh, gets further because the blocking error is gone, and may hit the next wall.
4. Repeat until a full team round completes without any agent hitting a blocking error.
5. Every fix is recorded in sequence (`blocking-fix-1.md`, `blocking-fix-2.md`, ...).

#### Phase B: Batch fix loop (non-blocking HIGH+ errors)

Once no more blocking errors occur, the team runs full rounds. Agents that encounter non-blocking HIGH+ issues (missing fields, wrong behavior, broken validations) keep testing and record everything they find.

After each round, consolidate findings. If the consolidated round has non-blocking HIGH+ findings:

1. Write `reviews/qa-run-{R}/layer-5-playwright/batch-fix-{N}.md` with ALL non-blocking HIGH+ findings from the round
2. Spawn an impl agent to fix them all in one pass. Skip Phase 6.
3. After the fix, **restart Layer 5 from the beginning** (new round, same run directory). Re-verify the fixes and continue testing.
4. Repeat until a consolidated round has 0 HIGH+ findings.

#### Phase C: Convergence

Once a round produces 0 HIGH+ findings, run the standard convergence cycle: two consecutive clean rounds (0 HIGH+, no HIGH+ findings changed). MED/LOW findings are collected but don't block.

#### After Layer 5 converges

Check whether ANY fix files were written during Layer 5 (blocking-fix or batch-fix). If yes:

1. Those fixes were quick patches — they have not been verified against the spec (Layer 1), business logic (Layer 2), or regression suites (Layer 3).
2. Restart from **Layer 1** in a new `qa-run-{R+1}/` directory to re-verify everything.

If no fix files exist (Layer 5 passed clean on the first attempt), go directly to Completion.

**Cap:** 50 total fix cycles within Layer 5 (blocking + batch combined). If still hitting errors after 50 fixes, escalate.

---

## Completion

When all five layers pass:

1. Stop the server:
   ```
   qa-harness stop --config ~/claude-hub/<pipeline>/qa-config.yml --repo-path <path from REPO-PATH>
   ```
2. **Final MED consolidated report.** Collect ALL MED findings from ALL layers across ALL runs. Deduplicate aggressively — tiny differences in how agents describe the same concern do NOT make them separate findings. Same area + same concern = one finding, regardless of wording. Write to `reviews/QA-MED-FINDINGS.md`.
3. Write `reviews/QA-COMPLETE.md` with:
   - Final verdict: APPROVED
   - Per-layer summary (rounds run, findings by severity)
   - Number of runs (how many times it restarted from Layer 1)
   - Total agents dispatched across all layers and runs
   - Reference to `QA-MED-FINDINGS.md` for the user to review
4. Phase 8 is complete.

## Escalation

If any layer hits its 50-round cap without converging:

1. Stop the server (if running)
2. Write `reviews/QA-ESCALATION.md` with:
   - Which layer failed to converge
   - All findings and their status across rounds
   - Recommendation
3. Stop and present to the user — do not continue automatically.

## Artifact trail

```
reviews/
  seed-plans/
    solo-user.json
    team-with-candidates.json
    ...
  qa-run-1/
    layer-1-diff-to-spec/
      round-1/
        agent-1.json
        agent-2.json
        ...
        agent-15.json
        consolidated.json
        summary.md
      round-2/
        ...
    layer-2-code-correctness/
      round-1/
        agent-1.json
        ...
        consolidated.json
        summary.md
    layer-3-script-runner/
      round-1/
        agent-1.json
        ...
        agent-15.json
        consolidated.json
        summary.md
    layer-4-regression/
      round-1.json
    layer-5-playwright/
      round-1/
        agent-1.json
        ...
        agent-15.json
        consolidated.json
        summary.md
      blocking-fix-1.md     (if blocking error fixed during Layer 5)
      batch-fix-1.md        (if non-blocking HIGH+ fixed during Layer 5)
    FAILURE-REPORT.md       (if HIGH+ found in Layers 1-4, triggers new run)
  qa-run-2/                 (after fix, restart from Layer 1)
    layer-1-diff-to-spec/
      ...
  QA-COMPLETE.md            (if all layers pass)
  QA-MED-FINDINGS.md        (consolidated MEDs for user review)
  QA-ESCALATION.md          (if any layer hits 50-round cap)
```
