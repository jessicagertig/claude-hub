# Spec review — Round 1 verdict

Branch verified at review time: `attribution-work-qa` @ `b4cb4463a` — matches spec-time tip, no drift.

## Per-angle results

| Angle | Findings |
|---|---|
| per-identifier-capture-contract | 3 MED (F1 repeated-param rule, F2 dotless `_gcl_aw`, F3 exact cookie-name matching), 1 LOW (F4 cap ordering) |
| collection-point-move | 2 MED (F1 §10.4 existing-example inversion, F2 T9 line range) |
| sso-session-ride | 1 MED (F1 §6.6 stale four-file grep), 1 LOW (F2 second `.with(...)` expectation) |
| wire-format-integrity | Clean — all eight lodash `snakeCase` transforms verified empirically; four-way name chain holds |
| nil-absence-semantics | 1 MED (F1 "present" undefined for conditional rules), 1 LOW (F2 empty-value cookies) |
| creation-time-only-and-existing-behavior-unchanged | Clean (2 notes) |
| migrations-and-schema-hygiene | 1 LOW (F1 schema corruption not currently observable — note only, hard rule stands) |
| always-on-checks | 2 MED (F1 = sso F1; F2 = collection F1), 3 LOW (F3 = sso F2; F4 stale count comments; F5 = collection F2) |

**Deduped: 7 MED, 5 LOW. Zero HIGH, zero BLOCKER. No §13 contradiction, no ESCALATE condition.**

All three Phase-1 candidate findings confirmed against source (candidates 1→sso F1/always-on F1; 2→collection F1/always-on F2; 3→collection F2/always-on F5).

## Amendments applied (SPEC.md)

1. §4 fbclid row — "same handling as `gclid`/`adct`" replaced with the explicit first-occurrence + 1024-cap rule. (capture F1)
2. §4 gclid row — dotless `_gcl_aw` contributes nothing (analog `... : null`); no raw fallback. (capture F2)
3. §4 Notes — new bullet: repeated-URL-param first-occurrence rule for `fbclid`/`li_fat_id`/`gclid`; `fbc` construction uses the first occurrence. (capture F1)
4. §4 Notes — new bullet: "present" for the conditional rules = non-empty string (`typeof x === "string" && x.length > 0`); `?fbclid` (null) / `?fbclid=` ("") never construct `fbc` nor suppress cookie fallbacks. (nil-absence F1)
5. §5.1 cookie-parsing rule — exact cookie-NAME matching for the six named cookies; `_ga_` prefix only for `gaSessionId`; empty-value cookie = absent. (capture F3, nil-absence F2)
6. §5.1 cap paragraph — cap applies to the FINAL field value (post-strip/construction/join). (capture F4)
7. §6.6 call-site check — four-file grep result named (definition, sole APP call site, two spec files with direct calls and exhaustive `.with(...)` expectations); "convert" → "extend". (sso F1 / always-on F1)
8. §10 preamble — stale count references in spec-file comments/example names updated as part of the extension. (always-on F4)
9. §10.3 — both exhaustive `have_received(:from_omniauth).with(...)` expectations must be extended; the no-tracking example (lines 69-83) gains eight nil keywords. (sso F2 / always-on F3)
10. §10.4 — the existing `'stores adroll_first_party_cookie from the request body'` example (lines 59-69) is INVERTED and must be updated; header comment (lines 10-12) rewritten. (collection F1 / always-on F2)

## Amendments applied (code-task-list.md)

11. T4a — exact-name matching + empty-value-cookie rule. (5)
12. T4d — first-occurrence + cap wording. (1/3)
13. T4f/T4g/T4h — "present" = non-empty string; T4h dotless-cookie contributes nothing. (2/4)
14. T4j — cap on final field value. (6)
15. T9 — removal restated as the single range "lines 24-36" per §5.7 (was "24-31" + "line 34", orphaning the comment at line 33). (collection F2 / always-on F5)
16. T16 — "convert any other call site" → "extend every call site and keyword expectation (four files, see §6.6)". (7)
17. T19 — both `.with(...)` expectations extended, nil example named. (9)
18. T20 — existing example update + header-comment rewrite added. (10)

Post-amendment stale-reference sweep run over both documents: no remaining references to the old grep count, "convert" call-site language, or the T9 split line ranges; remaining "verbatim"/"genuinely present" uses are consistent with the new §4 definitions.

## Verdict

**PASS WITH AMENDMENTS — all findings amended in round 1.** Zero HIGH/BLOCKER → per harness-profile.md, no verification round (spec-round-2) is required. Proceed to SPEC-REVIEW-COMPLETE.md.
