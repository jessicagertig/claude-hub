# QA — COMPLETE (attribution-identifiers)

**Final verdict: APPROVED**
**Date:** 2026-07-24
**Branch/diff:** `attribution-work-qa`, committed diff `b4cb4463a..a0d59115d` (no `-qa` branch per Jessica's directive; the only working-tree residue is the expected unstaged db/schema.rb corruption, untouched)
**Runs:** 1 (no fix loops, no restarts)
**Agents dispatched:** 13 (Layer 1: 11 · Layer 4: 1 · Layer 5: 1)

## Per-layer summary

| Layer | Rounds | Result |
|---|---|---|
| 1 — Diff-to-spec | 1 | CLEAN. 11 agents (8 per-identifier chains, collection-point removal, tests-vs-spec, reverse direction). 1 finding filed → INVALIDATED (below). Terminal per harness-profile one-clean-round rule. |
| 2 — Code correctness | — | **SKIPPED** per harness-profile (Jessica's trimmed profile, recorded here explicitly). |
| 3 — Script runner | — | **SKIPPED** per harness-profile (recorded here explicitly). |
| 4 — Regression | 1 | CLEAN for the feature. Four extended spec files green within `23 examples, 1 failure` (the 1 failure is pre-existing, out of feature scope → MED-1). Cypress `registration.cy.js`: 2 passing. |
| 5 — Playwright browser | 1 | CLEAN. One agent, one pass, all 7 scenario steps PASS, 0 findings, no fix files. Both signup paths verified end-to-end: magic-link (user 40390) and /register password (user 40391); all eight columns exact per SPEC §4 on both users; Organization 36489 carries identical copies; org-create request body contained no attribution keys. SSO not browser-testable (real Google OAuth) — covered by RSpec (`user_from_omniauth_spec.rb`, `omniauth_callbacks_controller_spec.rb`, Layer 4 green). |

## Layer 1 invalidated finding — surfaced for Jessica

**l1-a3-001 (agent 3):** the fbclid capture guard is `parsedParams.fbclid !== undefined`, so degenerate `?fbclid` (parses to `null`) / `?fbclid=` (parses to `""`) ride to the server as `null`/`""` (the `""` case persists an empty string on `users.fbclid`). **Invalidated** because the implementation follows the spec's explicit direction: SPEC §4 mandates "the same handling `adct` gets" (byte-identical to the analog), the non-empty "present" test is deliberately scoped to the three conditional rules (fbc construction and the two URL-first fallbacks — all verified to use the house guard), and this exact question was raised and resolved at spec review (spec-round-1 nil-absence-semantics F1/F2) and re-verified at impl review ("Verified NOT a deviation"). Agent 11 independently assessed the same code as a neutral note. If ruled otherwise, the change is one line (reuse `fbclidParamValue` under the house guard).

## Layer 5 runtime facts of note

- For a NEW email the magic-link dev workaround link is `/email_confirmation?confirmation_token=...` (not `magic_links/validate` as the login-flow config describes) — followed and confirmed in-UI; no script-runner confirmation was needed.
- Constructed `fbc` timestamps were distinct per capture (`fb.1.1784941195091.TestFbclid123` / `fb.1.1784941349666.TestFbclid123`), pinning genuine `Date.now()` construction.
- Evidence: /tmp/qa-run-1/layer-5/agent-1/ (17 files — network POST bodies for magic_login/sign_up/organizations, script-runner outputs, screenshots, console logs).

## MED findings

See `reviews/QA-MED-FINDINGS.md` — 1 MED (pre-existing `organization_ai_credits_lifecycle_spec.rb:33` failure, full trace inside), plus LOW console-noise notes.

## Artifact trail

- reviews/qa-run-1/feature.diff (the reviewed diff, byte-verified against the committed range)
- reviews/qa-run-1/layer-1-diff-to-spec/round-1/agent-{1..11}.json + consolidated.json
- reviews/qa-run-1/layer-4-regression/round-1.json (with orchestrator disposition)
- reviews/qa-run-1/layer-5-playwright/round-1/agent-1.json
- reviews/seed-plans/attribution-flags.json

Server stopped (`qa-harness stop`). Phase 8 complete.
