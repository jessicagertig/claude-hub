# QA COMPLETE — qa-run-5 (attribution feature)

**Verdict: APPROVED**
**Date:** 2026-07-20 | **Branch:** attribution-work-qa | **HEAD:** fc3f047f9 (unchanged throughout — no fix loop was triggered, so no restart from Layer 1)
**Feature:** UTM capture + PostHog funnel events (attribution), inflow-ats.

This run RESUMED a full-rigor qa-run-5 that a usage-credit outage had killed mid-Layer-2. Layer 1 had already converged at this HEAD (two clean rounds). The partial Layer 2 round-1 (a single agent) was VOIDed (see layer-2-code-correctness/round-1/VOID.md) and Layer 2 was restarted from a fresh full round. No code changed during QA, so all layers stand at fc3f047f9.

## Per-layer outcome

| Layer | Rounds | Team | Result |
|---|---|---|---|
| 1 — Diff-to-Spec | round-1 + round-2 (both clean) | 15 agents/round | CONVERGED (pre-resume; stands at fc3f047f9) |
| 2 — Code Correctness | round-2 + round-3 (both clean) | 15 agents/round | CONVERGED |
| 3 — Script Runner (live test server) | round-1 + round-2 (both clean) | 15 agents/round, sequential | CONVERGED |
| 4 — Regression (RSpec) | round-1 | 1 agent | PASS — 17 examples, 0 failures, 0 pending |
| 5 — Playwright MCP | — | — | OMITTED (Jessica's standing instruction) |

- **Layer 1** (round-1 was VOID; single agent) — restarted; round-2 and round-3 each 15 fresh general-purpose reviewers, full-rigor. Two consecutive clean rounds (0 HIGH+). Findings collected: 3 LOW total (utm_data two-in-memory-types latent-fragility note; two test-strengthening notes on the "ignores body"/"does not modify" specs). None blocks; none re-flags a settled ruling.
- **Layer 3** — 15 sequential agents/round against a live RAILS_ENV=test server (port 5007) + sidekiq. Each agent ran `qa_harness cleanup` + seed, then exercised real code paths via `test_frr` (rails runner) and live HTTP POSTs to `/api/v1/sign_up`, `/api/v1/magic_login`, and direct `User.from_omniauth`. Two consecutive fully-clean rounds (0 findings at any severity). Notable runtime proofs: utm_data jsonb persists as a clean string-keyed JSON object across all four write paths (verified by raw SQL — no stringified `ActionController::Parameters`, no wrapper, nil for absent, never `{}`); values stored raw (case preserved, no enum mapping, 300-char stored uncapped per D3); existing users/orgs never modified on later login; org copy from `current_user` faithful; `organization_params` rejects body-supplied utm_*.
- **Layer 4** — the 5 new attribution spec files run together: `17 examples, 0 failures, 0 pending` (seed 10894). `git grep` confirmed no additional pre-existing specs reference the changed identifiers. No intersection with the ~148 pre-existing AI-credit/AI-summary baseline failures (those specs were not run). Cypress not run (known baseline 56/56, heavy, not required).

## Fix loops

**None.** No HIGH+ or BLOCKER finding was raised in any layer, so no fix agent ran, no commit was made, and no restart-from-Layer-1 (qa-run-6) occurred. HEAD remained fc3f047f9 for the entire run.

## Findings summary (by severity, this run)

- BLOCKER: 0
- HIGH: 0
- MED: 0 new (agents correctly recognized the pre-existing MEDs M1–M4 as settled and did not re-report them)
- LOW: 3 (all non-blocking, collected below)

### LOW findings collected (no action required)

1. **l2-r2-a1-F1** — `utm_data` reaches the jsonb column as two in-memory types across `#create` (Parameters → `.to_h` → HashWithIndifferentAccess) vs `#magic_create` (raw nested Parameters). Provably correct at Rails 6.1.7.7 via the `as_json`→`@parameters` delegation; independently re-verified by Layer 2 agent-12 AND proven safe at runtime by Layer 3 agent-12 via raw SQL on all paths. Latent-fragility note only.
2. **l2-r2-a14-F1** — the org "ignores attribution values sent in the request body" spec proves the copy-from-user override wins but not independently that `organization_params` rejects a body `utm_source`. No gap (utm_* genuinely not permitted — Layer 3 agents 10/11 confirmed permitted keys exclude all four). Optional test strengthening.
3. **l2-r3-a14-F1** — the existing-user `magic_create` "does not modify" tests seed nil utm, so they assert nil→nil; falsifiable against an overwrite defect (not a ghost test) but could seed non-nil to prove preservation. Optional.

### Pre-existing / out-of-scope observations (surfaced at runtime, not feature defects)

- `POST /api/v1/sign_up` 500s when a `name` JSON key is sent (`User` has no `name=` setter; `sign_up_params` permits `:name`). Reproduced with zero utm params → pre-existing, unrelated to attribution. (Layer 3 agent-13.)
- New SSO user has `previously_new_record? == false` (from_omniauth's post-block `user.update`), so the controller fires `user_logged_in` for a fresh SSO signup. Pre-existing (commit 9d3f2c98a7); SPEC note 7/311 leaves SSO server events untouched. (Layer 3 agent-14.)
- Pre-existing Clearbit after-save callback raises `Nestful::UnauthorizedAccess` 401 (test-env invalid API key) but does not block org save. (Layer 3 agents 10/11/15.)

Settled MED rulings (M1 SSO session ride; M2 magic_create connect-branch nil crash; M3 bracket-key SSO 400; M4 resolved by D18/D19) remain as recorded in `reviews/QA-MED-FINDINGS.md` — Jessica's dispositions there are authoritative and were NOT modified by this run.

## Run statistics

- Runs (restarts from Layer 1): 1 (qa-run-5; no fix-triggered restart).
- Agents dispatched this resume: Layer 2 = 30 (15 × 2 rounds); Layer 3 = 30 (15 × 2 rounds); Layer 4 = 1. Plus Layer 1's 30 (pre-resume, 15 × 2). Total across the converged run ≈ 91 review/verification agents.
- Server lifecycle: started once (rails pid 99344 / sidekiq 99345 → puma 99939 / sidekiq 99940); test data wiped via `DELETE /cypress/cleanup`; wrapper stopped; orphaned puma+sidekiq grandchildren terminated; port 5007 confirmed free.

## Cleanup confirmation

- `DELETE /cypress/cleanup` run (test data wiped).
- `qa_harness stop` sent SIGTERM to the server + sidekiq wrappers (99344/99345, confirmed gone).
- Orphaned grandchildren puma 99939 + sidekiq 99940 (spawned by my harness start, ppid 1) terminated via SIGTERM; port 5007 verified FREE.
- No `.env` touched, no `DATABASE_URL` set, no `psql`, no `rails db:*` destructive command, RAILS_ENV=test throughout.

## Verdict

**APPROVED** — all executed verification layers (1–4) passed/converged at fc3f047f9 with zero HIGH+ findings; Layer 5 omitted per standing instruction. The reference `reviews/QA-MED-FINDINGS.md` holds the settled MED dispositions for Jessica's review; the 3 LOWs above are optional and non-blocking.
