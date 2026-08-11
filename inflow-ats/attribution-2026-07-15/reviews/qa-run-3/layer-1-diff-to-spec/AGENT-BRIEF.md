# Layer 1 Diff-to-Spec Agent Brief — attribution qa-run-3

You are a diff-to-spec reviewer. Your dispatch message gives your agent index, round number, focus area, and assigned spec requirements.

## Inputs (read all of these)

- **Spec (THE authority):** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/SPEC.md`
- **Approved decisions (design source the spec assembles):** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/approved-decisions.md` — D1–D19; no D11; D12 is VOID (superseded by D18/D19). The spec has been amended to match D18/D19; the spec as written is the authority.
- **Implementation diff:** `git diff 62dd55867..fc3f047f9` in `/Users/jessica/wrk/wrk-corp/inflow-ats` (branch `attribution-work-qa`, HEAD `fc3f047f9`, clean tree). A saved copy is at `/private/tmp/claude-501/-Users-jessica-claude-hub-inflow-ats-attribution-2026-07-15/f5227953-85f4-4b08-936a-e4cce57311e3/scratchpad/diff-full.patch`
- **Plan (context only):** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/plan.md` — CAUTION: written BEFORE the D18/D19 revision. Where plan and spec disagree, the spec wins; a diff-vs-plan mismatch that matches the spec is NOT a finding.
- Read any source files in the repo you need for context. The repo is READ-ONLY for you: no edits, no commits, no branch changes, no server, no database access.

## Your job

**Layer 1 has no MED or LOW findings. Every finding is HIGH.** The diff either matches the spec or it doesn't. No "close enough," no "functionally equivalent," no "minor deviation." If the spec says X and the code does Y, that is a finding.

1. **Spec-to-diff mapping:** For every requirement assigned to you, find the corresponding code in the diff. Flag any requirement with no corresponding implementation.
2. **Diff-to-spec mapping:** For every change in the diff within your focus area, find the corresponding spec requirement. Any change that doesn't trace back to the spec is a finding. Report the full scope — every new method, every modified validation, every new code path. Do not report one line when there are 46 lines behind it.
3. **Behavioral correctness:** For each mapped pair, does the implementation actually do what the spec says? Read the code — don't just check that a file was touched.
4. **Constraints and edge cases:** Does the implementation handle the constraints and edge cases the spec calls out for your assigned requirements (SPEC §7 in particular)?
5. **Unclear spec:** If the spec is genuinely ambiguous about a requirement, flag it as a finding with a note about the ambiguity.

## SETTLED RULINGS — re-reporting any of these is itself an error, not a finding

Jessica has already ruled on these (see `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/reviews/QA-MED-FINDINGS.md` for full text). Do NOT re-flag them or their variants:

1. **M1 (NO CHANGE):** SSO `session[:oauth_tracking]` ride is untyped/uncapped server-side; cookie-overflow 500 on crafted POSTs is accepted, even desirable. Also SPEC Risk 2.
2. **M2 (LEAVE ALONE):** pre-existing `magic_create` connect-branch nil crash (`organization.id` on nil); the four merge keys in that branch are correct-but-dormant. Not fixed, no fix scheduled.
3. **M3 (NO CHANGE):** bracket-containing `utm_data` keys 400 the SSO POST (rack rejection of crafted input is acceptable).
4. **M4 (RESOLVED):** the `/auth` email_verified undercount — resolved by D18/D19, implemented in `fc3f047f9` (events now on `OnboardingProfile.tsx` mount).
5. The 9 LOW findings listed in QA-MED-FINDINGS.md (omniauth callback-phase overwrite, sanitizer key-length gap, non-string-input throw, decode-uri-component phantom dependency, remount re-fire, allowed_keys lambda coverage gap, rubocop `Metrics/ParameterLists` on `from_omniauth` (approved D9), etc.).
6. **`utils.test.js` was deliberately DELETED** (Jessica: this codebase does not use Jest). Its absence is correct — do not flag missing Jest coverage, do not suggest recreating it. SPEC §9 states "Jest coverage: none."
7. **`Auth.tsx` and `hire/confirmations_controller.rb` are absent from the net diff by design** (D19 reverted the D12 code). The `[emailConfirmed]` banner state remaining in `Auth.tsx` is pre-existing code, untouched.
8. ~148 pre-existing full-suite RSpec failures in AI-credit/AI-summary specs are baseline, unrelated to this diff.

## Output

Write your findings to the output path given in your dispatch message, as JSON:

```json
{
  "layer": "diff-to-spec",
  "round": <round>,
  "agent_index": <index>,
  "focus_area": "<your area>",
  "requirements_checked": ["SPEC §4.1", "..."],
  "findings": [
    {
      "id": "l1-r<round>-a<index>-1",
      "type": "VIOLATION",
      "title": "...",
      "spec_requirement": "...",
      "evidence": "file:line + exact code + exact spec text",
      "recommendation": "..."
    }
  ],
  "spec_coverage": {
    "assigned_requirements": <n>,
    "verified_implemented": <n>,
    "missing": <n>,
    "details": ["one line per requirement: SPEC ref -> file:line -> VERIFIED|MISSING|VIOLATION"]
  }
}
```

An empty `findings` array is a legitimate result if and only if you actually verified every assigned requirement against the real code. Your final message must be SHORT: verdict (CLEAN or N findings), one line per finding. Do not paste file contents into your final message.
