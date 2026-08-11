# Spec Review -- Round 3

**File:** `~/claude-hub/inflow-ats/2026-06-11-ai-display/SPEC.md`
**Reviewer pass:** Round 3 (post-amendment verification + new concerns)

## Stale reference sweep results

1. **Snake_case field references:** CLEAN. No remaining `_domain`, `_skills`, `_accomplishments`, `_analysis`, or `_experience` field paths found outside section headings.
2. **Stale time function references:** CLEAN. `timeAgoInWordsShort` appears only in "Do NOT use" warnings (lines 68, 265). No `formatDistanceToNow` or `parseISO` recommendations remain.
3. **Callout table evaluation order vs prose:** CLEAN. Both tables list status-based rows first (PlatoTab rows 1-4, callout rows 1-4), then no-summary rows (5-6). Prose above both tables explicitly states "evaluate in the order listed -- first match wins."
4. **Internal cross-references:** CLEAN. All section references (e.g., "see Shimmer section," "see below," line references to existing files) remain valid after amendments.

## Always-on checks

1. **Known Failure Pattern #1 (`font-size: t.text.`):** CLEAN. The only mention of `font-size:` with `t.text.xs` is line 79, which is an explicit warning AGAINST this pattern, with correct usage shown.
2. **Nullish coalescing (`??`):** CLEAN. None found.
3. **Deliberately set `undefined`:** CLEAN. None found.
4. **Styled component labels:** CLEAN. Line 224 documents the `label: ParentComponent_ComponentName;` convention and line 230 states every styled component must have one.
5. **Import cleanup:** CLEAN. Lines 159-161 correctly remove `AiJobApplicationSummaryFeedItem` and `AiSummaryState` imports and add `PlatoOverviewCallout`.
6. **Backward compatibility:** CLEAN. Lines 271-273 explicitly state old components are left in place, not deleted.

## Findings

- F1 [LOW] Line 68 / `distanceInWords` output includes "about" for approximate durations / The spec says `distanceInWords` produces `"3 days ago"` etc. In reality, `distanceInWords` wraps `formatDistanceToNow` from date-fns without stripping the "about" prefix. For durations that date-fns considers approximate, it produces `"about 3 hours ago"`, `"about 1 month ago"`, etc. The example `"3 days ago"` is technically correct (date-fns does not add "about" for exactly 3 days) but is misleading -- an implementer won't know some timestamps will render with "about." By contrast, `timeAgoInWordsShort` (lines 14-22 of `time.ts`) explicitly strips "about" via `.replace(/about/, "")`. Verified at `app/javascript/shared/lib/time.ts` lines 89-91: `distanceInWords` calls `formatDistanceToNow(new Date(date), { addSuffix })` with no post-processing. / **Fix:** Add a note after "producing '3 days ago' etc." on line 68: "Note: date-fns includes 'about' for approximate durations (e.g., 'about 3 hours ago'). This is acceptable for the provenance line -- do not strip it."

## Verdict

**ZERO MED/HIGH/BLOCKER findings.**

One LOW informational finding (F1) about the "about" prefix in `distanceInWords` output. This is a documentation accuracy note, not a correctness bug -- the provenance line will display correctly either way, and "about 3 hours ago" is arguably better UX than a false-precision timestamp. The fix is optional: adding a note would prevent implementer surprise but is not required for correct behavior.

All Round 1 and Round 2 amendments verified clean. No stale references, no ripple effects, no internal inconsistencies.
