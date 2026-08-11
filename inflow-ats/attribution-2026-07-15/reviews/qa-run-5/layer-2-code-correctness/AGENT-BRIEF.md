# Layer 2 (Code Correctness) — Shared Agent Brief — qa-run-5

**Feature:** UTM capture + funnel events (attribution), inflow-ats.
**Repo:** /Users/jessica/wrk/wrk-corp/inflow-ats — branch attribution-work-qa, HEAD fc3f047f9. READ-ONLY: never edit, commit, or run destructive commands. Never touch .env, never set DATABASE_URL, no psql, no rails db:* writes, no server interaction — this layer is static analysis.

You are a FRESH code-correctness reviewer. You have NO context about implementation decisions, trade-offs, or prior reviews. Read the code cold, as if encountering it for the first time. You get the spec for INTENT only: /Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/SPEC.md
Do NOT read the plan, impl-review artifacts, or other agents' outputs.

The feature's change set (context for what is new vs pre-existing): `git diff 62dd55867..fc3f047f9 -- <file>` shows what this feature changed in your files. Pre-existing defects in untouched code are MED (report, do not treat as feature defects).

## What to check in each assigned file

1. **Logic errors** — off-by-ones, wrong conditionals, inverted checks, missing nil/null guards, operator precedence
2. **Edge cases** — empty collections, missing records, concurrent access, boundary values, unexpected input types
3. **Security** — injection, authorization gaps, unvalidated input, exposed secrets
4. **Error handling** — uncaught exceptions, swallowed errors, misleading messages, missing rollbacks
5. **Data integrity** — missing validations, incorrect associations, orphaned records, write races
6. **Pattern violations** — does the code follow the conventions of the surrounding codebase? Read neighboring files for comparison.
7. **Analog structural matching** — if the codebase has an analog for this code, grep for it, read it, compare STRUCTURALLY (parameter interfaces, guard ordering, callback patterns, error-handling shapes). A structural mismatch is BLOCKER.

## Severity scale

- BLOCKER: feature broken/unusable. HIGH: wrong behavior, missing functionality, lost input, or incorrect results in any reasonable workflow — this feature introduced it.
- MED: report, do not fix — pre-existing; spec-compliant-but-imperfect; consistent with existing patterns; backend edge case with tradeoffs; out of scope; needs a design decision; performance.
- LOW: nitpick/observation.
- Spec-implementation mismatch is NEVER MED (HIGH+; but Layer 1 has twice-verified spec conformance at this HEAD — if you believe you see a spec mismatch, re-read the spec text carefully first, including its amendments).

## SETTLED RULINGS — re-reporting any of these IS an error

Jessica has ruled (full text: /Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/reviews/QA-MED-FINDINGS.md). Do NOT re-flag these or their variants/siblings:
- M1 (NO CHANGE): SSO session[:oauth_tracking] ride untyped/uncapped server-side; cookie-overflow 500 on crafted POSTs acceptable; no server-side sanitization is the approved design.
- M2 (LEAVE ALONE): pre-existing magic_create connect-branch nil crash (organization.id on nil); the four merge keys there are correct-but-dormant.
- M3 (NO CHANGE): bracket-containing utm_data keys can 400 the SSO POST (rack rejection). Acceptable; no bracket-stripping.
- M4 (RESOLVED by D18/D19, implemented at this HEAD).
- The 9 LOW findings recorded there (setup-lambda callback-phase overwrite; key-length uncapped; sanitizer throw on non-string/'?'-less input — unreachable from callers; decode-uri-component phantom dependency + its 0.2.0 CVE note; degenerate id/email guard passes (D12-era, now moot); event re-fire on remount; untested setup lambda; rubocop Metrics/ParameterLists on from_omniauth (approved D9) and the now-removed eslint warning).
- KNOWN BASELINES: utils.test.js deliberately absent (no Jest in this codebase — do not request Jest coverage); pre-existing `ap` debug lines in from_omniauth; ~148 pre-existing full-suite RSpec failures in AI-credit/AI-summary areas.

## Output format

Write JSON to the output path in your dispatch message:
{"layer": "code-correctness", "round": <R>, "run": 5, "agent_index": <N>, "files_reviewed": [...], "findings": [{"id": "l2-r<R>-a<N>-F1", "severity": "HIGH", "title": "...", "file": "...", "line": <n>, "description": "...", "recommendation": "..."}], "notes": "what you checked and found sound, concretely"}

An empty findings array is legitimate only if notes shows real scrutiny (what you traced, which analogs you compared, which edge cases you walked).
