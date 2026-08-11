# Hardening report — attribution-identifiers (Phase 7)

Source material: reviews/spec-round-1/ (7 MED + 5 LOW, all amended at spec level), reviews/plan-review/pass-1/ (1 MED amended, 2 LOW notes), reviews/impl-round-1/ (1 LOW note). No impl FAILURE-REPORT.md files exist — the implementation review converged in one clean round.

## Rules Added

Three rules appended to `/Users/jessica/claude-hub/inflow-ats/CLAUDE.md` "Known Failure Patterns" (existing rules untouched; cursor_rules/ untouched).

### 33. `document.cookie` reads: exact name match, split on the FIRST `=` only, empty value = absent

- Cookie name = substring before the first `=`, compared by exact equality; prefix matching only for genuinely dynamic families (`_ga_<CONTAINER>`). Bare `startsWith("_ga")` matches `_ga_ABC123XYZ` first.
- Cookie value = everything after the FIRST `=`; `useCookieValue.ts:10`'s `cookie.split("=")[1]` truncation is the one real defect not to inherit. Its `` startsWith(`${cookieKey}=`) `` name match (line 8) is NOT a shadowing defect — do not re-report it.
- Empty-value cookie = absent; never store `""`.

Motivating findings: spec-round-1 per-identifier-capture-contract F3 (MED), nil-absence-semantics F2 (LOW), plan-review pass-1 per-identifier-capture-contract F1 (MED — a review agent asserted a nonexistent defect in `useCookieValue`; the rule pins both the real defect and the false one).

### 34. query-string v6.1.0 presence semantics: `?x` → null, `?x=` → "", repeated → array — "present" guards must test non-empty string

Companion to rule 28 (same installed library, different parse facts). The analog `!== undefined` guard in `sanitizeTrackingParams` is key-presence, not value-presence — `null`/`""` count as present under it. Conditional construct/fallback logic must use the house guard `typeof x === "string" && x.length > 0`; URL-sourced scalar fields must take the first occurrence of a repeated param (array passthrough diverges: Rails scalar permit drops it, form input stringifies it).

Motivating findings: spec-round-1 nil-absence-semantics F1 (MED), per-identifier-capture-contract F1 (MED).

### 35. Behavior removals/inversions: the spec must direct updating existing test examples and comments that pin the OLD behavior

A NEW assertion is not enough; sweep existing spec files for examples asserting the old behavior (self-catch red, then get fixed unreviewed) and header comments documenting it (never self-catch). Extends rule 6's rename-cascade discipline to behavior changes.

Motivating findings: spec-round-1 collection-point-move F1 / always-on-checks F2 (MED, found independently by two angles).

## Existing Rules That Were Violated

None. No finding in any round cited a violation of an existing CLAUDE.md rule; spec-round-1 sso-session-ride explicitly verified rules 30/31 hygiene already correct in both touched spec files, and impl-round-1 verified rule 15 (committed-diff review) and the rule 14/analog structural manifest clean.

## Findings Skipped (with reasons)

1. **capture F2 (MED, dotless `_gcl_aw` contributes nothing — no raw fallback)** — feature-local parse rule for one cookie; recorded in SPEC §4 where the next implementer of THIS pipeline will find it.
2. **capture F4 (LOW, 1024 cap applies to the final field value)** — feature-local ordering clause.
3. **collection F2 / always-on F5 (MED/LOW, T9 line enumeration orphaned the comment at line 33)** — one-off line-range error in a task list.
4. **sso F1 / always-on F1 (MED, stale `from_omniauth` two-file grep count carried from the prior spec)** — no work was missed (§10 already covered both spec files); the spec already mandates re-running the grep at implementation time; the hub-level "Stale references after amendments" pattern covers the class.
5. **sso F2 / always-on F3 (LOW, second exhaustive `.with(...)` expectation needs the eight nil keywords)** — self-catching (fails red at dispatch); feature-local.
6. **always-on F4 (LOW, stale "five attribution values" counts in spec-file comments/example names)** — feature-local editorial staleness.
7. **migrations-and-schema-hygiene F1 (LOW, schema corruption not observable in the clean tree)** — environment note; the §3 hunk-level staging hard rule already lives in the feature docs and was honored at commit time.
8. **plan-review LOW 1 (Jest exists but is unused)** — house ruling already recorded (2026-07-16); no failure occurred.
9. **plan-review LOW 2 (pre-commit runs the full `yarn cy:run` suite)** — codebase fact, no failure.
10. **impl-round-1 LOW (inverted org-controller example cannot isolate the permit removal; `#update` uncovered)** — falsifiability nuance already covered by rule 26's spirit; note-only per harness-profile test priorities.
11. **Candidate: nested-jsonb keys mangled by `allKeysToSnake` (`_.snakeCase('_ga_ABC123XYZ')` → `ga_abc_123_xyz`)** — assessed and rejected: no agent erred; the spec's §5.2 jsonb-rejection rationale handled it correctly at design time and produced zero findings. Adding a rule for a mistake never made is speculative; the mechanism is recorded in the feature's SPEC.
