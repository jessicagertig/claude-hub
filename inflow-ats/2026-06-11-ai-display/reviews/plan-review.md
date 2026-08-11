# Plan Review: Plato AI Review Tab

## Verdict: NEEDS-REVISION

Both passes found HIGH findings which were corrected inline. The plan is now correct and complete with all amendments applied directly to `plan.md`.

---

## Pass 1 Summary

**1 HIGH, 2 LOW, 0 BLOCKER**

### HIGH

**F1 (Angle 1):** Task 5.4 wrapped `<Route>` inside `<FeatureFlipper>` inside a `<Switch>`. React Router v5's `<Switch>` only inspects direct children for `path` props -- a non-Route wrapper breaks path matching. The codebase pattern (AccountIntegrationsContainer.tsx) registers feature-flagged routes unconditionally in the Switch and gates only the sidebar nav items with FeatureFlipper. The conditional `possiblePaths` (Task 5.3) already handles the redirect-when-flag-is-off case.

**Amendment:** Removed `<FeatureFlipper>` from around the Route. Updated import at Task 5.1 to remove `FeatureFlipper`. Updated "Why conditional" text in Task 5.3 to remove stale reference.

### LOW

- Angle 1 F2: `useFeatureFlipper` two-step call style vs codebase inline convention. Functionally equivalent.
- Angle 3 F1: `useAiJobApplicationSummary` with id=0 produces 3 failed network requests in console. Acknowledged in plan Risks.

---

## Pass 2 Summary

**1 HIGH (amended), 1 LOW**

### HIGH

**F1 (Angle 1, fresh scrutiny):** Task 7.5 `onOpen` handler used `${match.url}/ai`. The `match` in `JobApplicationActivity` comes from `{...renderProps}` at the overview Route, so `match.url` ends with `/overview`. `${match.url}/ai` would navigate to `.../overview/ai` instead of `.../ai`.

**Amendment:** Changed to `match.url.replace(/\/[^/]+$/, "")/ai` with clear explanation of why the strip is needed.

### LOW

- Angle 5 F1: Plan omits `loading`/`disabled` props on Generate/Try again buttons. The analog (`AiSummaryState.tsx`) includes these for double-click prevention. UX polish, not a spec requirement.

---

## Amendments Applied to plan.md

All corrections are applied directly to `/Users/jessica/claude-hub/inflow-ats/2026-06-11-ai-display/plan.md`:

1. **Task 5.1:** Removed `FeatureFlipper` from import (only `useFeatureFlipper` and `Features` needed)
2. **Task 5.3:** Updated "Why conditional" explanation to remove stale FeatureFlipper reference
3. **Task 5.4:** Removed `<FeatureFlipper>` wrapper, added "Do NOT wrap" instruction with reasoning
4. **Task 7.5:** Changed `${match.url}/ai` to `${match.url.replace(/\/[^/]+$/, "")}/ai` with explanation

---

## Compliance

No CLAUDE.md compliance violations. All cursor_rules requirements verified. Known Failure Patterns addressed. The Route-outside-FeatureFlipper amendment is a justified spec deviation (React Router v5 technical constraint) documented in the plan.

---

## Open items carried forward from spec review

These were flagged as LOW during spec review and remain LOW:
1. `distanceInWords` includes "about" for approximate durations. Acceptable UX.
2. Kebab icon button in tab header has no dropdown/action defined. Acceptable for v1.
3. `structuredData` typed as nullable but always present when succeeded. Use optional chaining.
