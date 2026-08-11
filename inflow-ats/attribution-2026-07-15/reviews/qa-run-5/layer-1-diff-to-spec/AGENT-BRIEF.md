# Layer 1 (Diff-to-Spec) — Shared Agent Brief — qa-run-4

**Feature:** UTM capture + identify/funnel events (attribution), inflow-ats.
**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` — branch `attribution-work-qa`, HEAD `fc3f047f9`. READ-ONLY: never edit, commit, or run destructive commands in the repo. Never touch `.env`, never set `DATABASE_URL`, never run `psql` or `rails db:*` beyond read-only status commands. No server interaction — this layer is static analysis.
**Reviewed diff range:** `62dd55867..fc3f047f9`, pre-dumped to:
`/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/reviews/qa-run-5/diff-62dd55867-fc3f047f9.txt`
You may also read files at HEAD in the repo and run read-only `git` commands (`git show`, `git grep`, `git log`) to verify claims.

## Authorities (read in this order)

1. **Spec (the Layer 1 authority):** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/SPEC.md` — amended to match Decisions 18/19; the spec as written IS the authority.
2. **Approved decisions:** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/approved-decisions.md` — D1–D19; there is no D11; D12 is VOID (superseded by D18, reverted by D19).
3. **Reviewed plan:** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/reviews/plan-review.md` (section "Reviewed Plan") — context only; the spec wins on any conflict.

## Layer 1 rules (verbatim from the QA prompt)

- **Layer 1 has no MED or LOW findings. Every finding is HIGH.** The diff either matches the spec or it doesn't. There is no "close enough," no "functionally equivalent," no "minor deviation." If the spec says X and the code does Y, that is a finding. Period.
- **Spec-to-diff mapping:** for every requirement assigned to you, find the corresponding code in the diff. Flag any requirement with no corresponding implementation.
- **Diff-to-spec mapping:** for every change in the diff within your focus area, find the corresponding spec requirement. Any change that doesn't trace back to the spec is a finding. Report the full scope — every new method, every modified validation, every new code path.
- **Behavioral correctness:** for each mapped pair, does the implementation actually do what the spec says? Read the code — don't just check that a file was touched.
- **Constraints and edge cases:** does the implementation handle the constraints and edge cases the spec calls out for your assigned requirements?
- **Unclear spec:** if the spec is genuinely ambiguous about a requirement, flag it as a finding with a note about the ambiguity.

## SETTLED RULINGS — re-reporting any of these IS an error

Jessica has already ruled on the following (see `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/reviews/QA-MED-FINDINGS.md` for full text). Do NOT re-flag them, their variants, or their LOW-list siblings:

- **M1 (NO CHANGE):** SSO `session[:oauth_tracking]` ride is untyped/uncapped server-side; cookie-overflow 500 on oversized crafted POSTs is acceptable. No server-side sanitization is the approved design (D3, Spec Risk 2).
- **M2 (LEAVE ALONE):** pre-existing `magic_create` connect-branch nil crash (`organization.id` on nil); the four merge keys in that branch are correct-but-dormant. Not fixed in this PR.
- **M3 (NO CHANGE):** bracket-containing `utm_data` keys can 400 the Google SSO POST (rack rejection of nested-bracket names). Acceptable rejection; no bracket-stripping.
- **M4 (RESOLVED by D18/D19, implemented at fc3f047f9):** the `/auth` event mechanism is gone; email-verified events live on `OnboardingProfile.tsx`.
- **The 9 LOW findings** listed in QA-MED-FINDINGS.md (setup-lambda callback-phase overwrite, key-length uncapped, sanitizer throw on non-string input, decode-uri-component phantom dependency, re-fire on remount, untested setup lambda, rubocop `Metrics/ParameterLists` on `from_omniauth` (approved, D9), etc.).

## KNOWN BASELINES — verified by the orchestrator; do not flag

- `app/javascript/shared/lib/utils.test.js` was DELETED deliberately (Jessica: this codebase does not use Jest; Spec §9 records the ruling). Its absence is correct. Do not recreate it, do not flag its absence, do not require Jest coverage.
- `Auth.tsx` and `app/controllers/hire/confirmations_controller.rb` are correctly ABSENT from the diff (D19 — verified untouched in range).
- Debug `ap` lines in `from_omniauth` are pre-existing context lines, not part of the diff.
- Pre-existing full-suite RSpec failures (~148, AI-credit/AI-summary areas) are out of scope.

## Output format

Write your findings to the output path given in your dispatch message, as JSON:

```json
{
  "layer": "diff-to-spec",
  "round": <round>,
  "agent_index": <index>,
  "focus_area": "<your area>",
  "findings": [
    {
      "id": "l1-r<round>-a<index>-F1",
      "type": "VIOLATION",
      "title": "...",
      "spec_requirement": "SPEC.md §x.y: ...",
      "evidence": "file:line + what the diff actually does",
      "recommendation": "..."
    }
  ],
  "spec_coverage": {
    "assigned_requirements": ["..."],
    "verified": ["..."],
    "missing": ["..."]
  },
  "notes": "anything checked and found conforming, stated concretely"
}
```

An empty `findings` array is a legitimate result ONLY if your `spec_coverage.verified` list shows you actually traced every assigned requirement to concrete diff lines and every diff hunk in your area to a spec section. Show your work in `notes`.

## qa-run-5 delta — SPEC amendment (l1-run4-001) and prior-finding review

This run replaces qa-run-4 after its Layer 1 fix loop. qa-run-4 round 1 (15 agents) produced exactly ONE consolidated finding:

- **l1-run4-001 (resolved 2026-07-17 by spec amendment):** SPEC.md §5.1 rule 2 read bare "truncate to 255 characters" while the shipped `sanitizeTrackingValue` (sanctioned qa-run-2 l2-B1 fix, commit fa51c91a5) drops a trailing lone high surrogate after the slice. The FIX was to SPEC.md text only (sites: §5.1 rule 2, §7 constraint 1, §11 note 4) — the code did not change, the repo was not touched, HEAD is still fc3f047f9. See `reviews/qa-run-4/layer-1-diff-to-spec/FAILURE-REPORT.md`.

**Your duty regarding the prior finding:** verify the amended spec now describes the shipped truncation behavior accurately (if your area touches §5.1/§7.1/§11) — if the amendment is wrong or incomplete, that is a NEW finding; if it is correct, record it as "prior finding l1-run4-001 verified resolved" in your notes. Do not re-report the original mismatch.

All other qa-run-4 round-1 results were clean (0 findings across 14 agents); you may NOT rely on them — re-verify your own area from scratch.
