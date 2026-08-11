# FAILURE REPORT — qa-run-4, Layer 1 (Diff-to-Spec), Round 1

**Date:** 2026-07-17 | **HEAD:** fc3f047f9 (attribution-work-qa) | **Diff:** 62dd55867..fc3f047f9
**Consolidated finding:** 1 (l1-run4-001, HIGH). Full detail: round-1/consolidated.json and round-1/summary.md.

## l1-run4-001 — SPEC.md 5.1 rule 2 does not record the sanctioned surrogate-safe truncation semantics

**Code (correct, do NOT change):** `app/javascript/shared/lib/utils.js`, `sanitizeTrackingValue` — after `.slice(0, TRACKING_VALUE_MAX_LENGTH)` the helper checks the last code unit and drops a trailing lone high surrogate (0xD800-0xDBFF), yielding 254 code units at that boundary. These 3 lines are the sanctioned qa-run-2 Layer-2 l2-B1 HIGH fix, commit fa51c91a5: a `.slice(0,255)` splitting a surrogate pair made ES2019 `JSON.stringify` emit a lone `\udXXX` escape which Rails json 2.6.1 rejects — the entire signup POST 400'd. The fix was adversarially delta-reviewed and approved in the prior run (reviews/QA-COMPLETE.md). Reverting the code would reintroduce the 400.

**Spec (stale, the defect):** SPEC.md 5.1 sanitization rule 2 still reads bare "Truncate string values to 255 characters." — the Layer 1 authority does not describe the shipped, sanctioned behavior. A re-implementer following the spec literally would reintroduce the defect.

**Found by:** agent 8 (l1-r1-a8-F1, empirical) and agent 14 (l1-r1-a14-F1, reverse mapping) independently; corroborated by agent 15.

## Required fix (MINIMUM change — spec text only)

1. **Amend SPEC.md 5.1 rule 2 (line 174)** to record the approved semantics: truncate to 255 code units via slice, then drop a trailing lone high surrogate left by the slice (so a truncated value is 254 code units in that case — never an unpaired surrogate that would serialize as an unparsable `\udXXX` escape and 400 the signup POST). Include provenance inline: sanctioned by qa-run-2 Layer-2 finding l2-B1, fix commit fa51c91a5.
2. **Same-amendment stale-reference sweep (mandatory):** grep SPEC.md for every other truncation reference and make each consistent with the recorded semantics. Known sites: line 252 (7 constraint 1 "255-char truncation per value") and line 322 (11 note 4 "the 255-char cap"). Line 320 (Risk 2 "~12 values of <=255 chars") is a worst-case size estimate and stays valid — verify, adjust only if inconsistent. After editing, re-grep for "255" and confirm no remaining text contradicts the amendment.

## Hard constraints on the fix agent

- **NO source-repo changes.** The fix is entirely in `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/SPEC.md` (scratchpad hub). Do not touch `/Users/jessica/wrk/wrk-corp/inflow-ats` — no commits, no file edits, nothing.
- **No code changes, no new tests, no new decisions.** The amendment records an already-sanctioned behavior; it must not introduce new requirements, rules, or scope. (Jessica's Jest ruling stands: no Jest coverage for the helper — do not add or request any.)
- Minimum change: edit only the sentences that state the truncation rule. Do not restructure sections, renumber, or rewrite adjacent text.
