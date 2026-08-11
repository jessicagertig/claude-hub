# Angle 8: Spec Compliance

## Findings

### H1 (HIGH): PlatoOverviewCallout state evaluation order differs from spec

(Cross-referenced from state-machine.md H1)

The spec table (SPEC.md lines 106-112) lists states in a specific evaluation order. The implementation (PlatoOverviewCallout.tsx lines 21-51) evaluates stale-succeeded before non-stale-succeeded. The behavior is logically identical but the code order differs from the spec.

Per Known Failure Pattern: "Spec-implementation mismatch is HIGH even if functionally equivalent."

### Spec compliance checklist -- all other items verified:

**New file paths -- correct:**
- `PlatoMark.tsx` at `app/javascript/ats/src/components/shared/PlatoMark.tsx`
- `PlatoTab.tsx` at `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`
- `PlatoOverviewCallout.tsx` at `app/javascript/ats/src/views/jobApplications/PlatoOverviewCallout.tsx`

**PlatoMark exports -- correct:**
Two named exports: `PlatoMark` and `PlatoChip` (line 86). Props match spec: variant/size/color for PlatoMark, size/radius/variant for PlatoChip.

**PlatoChip properties -- correct:**
- Star size: `Math.round(size * 0.62)` (line 81)
- Star color: `colors.gray[900]` always (line 81)
- Gradient: `linear-gradient(120deg, #fbd7ff 10%, #ffdec1 90%)` (line 99)
- Hairline: `inset 0 0 0 1px rgba(0,0,0,0.07)` (line 100)
- `flex-shrink: 0` (line 98)
- `aria-hidden="true"` on SVG (line 65)

**PlatoTab 6 states -- correct:**
All 6 states render with correct content. Each zero state uses the correct icon/chip, heading, and body text matching the spec exactly.

**Succeeded layout sections (10 items) -- all present:**
1. Provenance line with `distanceInWords` (not `timeAgoInWordsShort`)
2. Stale banner conditional on `stale === true`
3. Headline h1 with correct styling
4. Domain label with 3px filled circle separator
5. Fit-for-role card with gradient bar and fallback
6. Notable achievements with award icons
7. Relevant experience prose
8. Gaps to probe prose
9. Skills with key-skill sorting and emphasis
10. Footer disclaimer

**PlatoOverviewCallout -- correct structure:**
- `styled.button` card with reset CSS
- Gradient bar
- PlatoChip (32px, 8px radius)
- Text column with title/subtitle
- CTA label with chevron-right
- Connector tick ::after
- Hover transition on border-color

**Modified files -- correct changes:**
- `JobApplicationContainer.tsx`: Route added, possiblePaths conditional, useFeatureFlipper hook
- `JobApplicationSidebar.tsx`: PlatoNavItem added with FeatureFlipper wrapper
- `JobApplicationActivity.tsx`: Old imports removed, PlatoOverviewCallout added, match prop added
- `aiJobApplicationSummary.ts`: AiAssessment interface added, assessment type narrowed

**Backward compatibility -- correct:**
Old `AiJobApplicationSummaryFeedItem.tsx` and `AiSummaryState.tsx` are NOT deleted, just no longer imported.

**monthsByDomain bar chart -- correctly omitted:**
No rendering of `monthsByDomain`, `totalMonthsExperience`, or `overlapSummary`.

**No backend changes -- correct.**

**Eyebrow style:** Uses `${[t.text.xs]}` standalone (line 670) with `text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; color: ${t.poly.color.secondaryText}`. Matches spec exactly (spec intentionally upgrades from analog's `t.dark` ternary to Poly DS `secondaryText` token).
