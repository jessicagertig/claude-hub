# Pass 1 -- Angle 1: Routing, Navigation, and Feature-Flag Gating

## Fact Check

### File paths
- `JobApplicationContainer.tsx` at `app/javascript/ats/src/views/jobApplications/JobApplicationContainer.tsx` -- VERIFIED (335 lines)
- `JobApplicationSidebar.tsx` at `app/javascript/ats/src/views/jobApplications/JobApplicationSidebar.tsx` -- VERIFIED (413 lines)
- `NavItem.tsx` at `app/javascript/ats/src/components/shared/NavItem.tsx` -- VERIFIED (118 lines)
- `FeatureFlipper.tsx` at `app/javascript/ats/src/components/shared/FeatureFlipper.tsx` -- VERIFIED (130 lines)

### Line numbers
- `possiblePaths` at line 151 in `JobApplicationContainer.tsx` -- VERIFIED: `const possiblePaths = ["overview", "resume", "messages", "files", "notes"];`
- `redirector()` at lines 185-191 -- VERIFIED
- Route insertion after `/notes` route (line 272) and before `{redirector()}` (line 275) -- VERIFIED: notes Route ends at line 272, `{redirector()}` is at line 275
- `linkStyles` at `NavItem.tsx` lines 56-95 -- VERIFIED
- `StyledLabel` at `NavItem.tsx` lines 103-118 -- VERIFIED: lines 103-118
- `Features.AI_APPLICANT_SUMMARY` at line 128 -- VERIFIED: `FeatureFlipper.tsx` line 128

### Behavior claims
- Plan claims `useFeatureFlipper` is used as: `const isFeatureEnabled = useFeatureFlipper(); isFeatureEnabled({ feature: Features.AI_APPLICANT_SUMMARY })` (Task 5.2). The codebase convention (AccountContainer.tsx line 44-45) uses an inline pattern: `const flag = useFeatureFlipper()({ feature: Features.X })`. Both are functionally correct; the two-step approach works fine.
- Plan claims `isAiEnabled` must be added to the useEffect dependency array (Task 5.3). VERIFIED: Currently `[location]` at line 158. This is correct -- `isAiEnabled` is referenced inside the effect and must be in the dep array.
- Plan claims wrapping `<Route>` inside `<FeatureFlipper>` inside `<Switch>` (Task 5.4). This needs investigation -- see Findings.

### Import claims
- Plan Task 5.1: `import { FeatureFlipper, useFeatureFlipper, Features } from "@ats/src/components/shared/FeatureFlipper"` -- VERIFIED: all three exports exist at lines 110 and 112 of FeatureFlipper.tsx
- Plan Task 6.1: `NavLink` not currently imported in `JobApplicationSidebar.tsx` -- VERIFIED: the file uses `withRouter` (line 4) but does not import `NavLink` directly
- Plan Task 6.1: `isPropValid`, `Box`, `Text`, `breakpoint` are new imports -- VERIFIED: none of these are currently imported in `JobApplicationSidebar.tsx`

## Completeness

- Spec requirement: `"ai"` conditionally in `possiblePaths` -- ADDRESSED in plan Task 5.3
- Spec requirement: FeatureFlipper wrapping the route -- ADDRESSED in plan Task 5.4 (but see findings)
- Spec requirement: redirect to `/overview` when flag is off -- ADDRESSED via conditional `possiblePaths`
- Spec requirement: PlatoNavItem copies `linkStyles` verbatim -- ADDRESSED in plan Task 6.3
- Spec requirement: `NavLink` for keyboard navigation -- ADDRESSED in plan Task 6.3 (styled NavLink)

## Findings

### F1 [HIGH] FeatureFlipper wrapping Route inside Switch -- React Router v5 compatibility issue

**Where:** Plan Task 5.4
**What:** The plan instructs wrapping `<Route path={.../ai}>` inside `<FeatureFlipper>` inside the `<Switch>` block. In React Router v5, `<Switch>` only inspects its **direct children** for `path` and `from` props to determine which child to render. A `<FeatureFlipper>` wrapper between `<Switch>` and `<Route>` means `<Switch>` does not see the `<Route>`'s `path` prop. This can cause the wrapped component to match any URL (acting as a default route) or behave unpredictably depending on render order.

**Evidence:** The codebase's existing pattern in `AccountIntegrationsContainer.tsx` (lines 47-81 sidebar, lines 87-155 Switch) confirms this: `<FeatureFlipper>` wraps `NavItem`s in the sidebar but the corresponding `<Route>` elements inside `<Switch>` are registered **unconditionally** (e.g., the LinkedIn, Slack, Discord, Zapier routes are not wrapped in FeatureFlipper inside the Switch).

**Fix:** Remove the `<FeatureFlipper>` wrapper from around the `<Route>` inside the `<Switch>`. The route should be registered unconditionally. The feature-flag gating is already correctly handled by: (a) conditionally including `"ai"` in `possiblePaths`, which controls the redirect behavior, and (b) the `<FeatureFlipper>` around the sidebar nav item, which controls visibility. If a user navigates directly to `/ai` with the flag off, the `redirector()` function will redirect them to `/overview` because `"ai"` won't be in `possiblePaths`. The route itself can safely exist even when the flag is off -- it just won't be reachable.

### F2 [LOW] useFeatureFlipper call style does not match codebase convention

**Where:** Plan Task 5.2
**What:** Plan uses two-step: `const isFeatureEnabled = useFeatureFlipper(); const isAiEnabled = isFeatureEnabled(...)`. Codebase convention (AccountContainer.tsx lines 44-45, AccountApiKeys.tsx line 34) uses inline: `const isAiEnabled = useFeatureFlipper()({ feature: Features.AI_APPLICANT_SUMMARY })`.
**Evidence:** All existing usages in AccountContainer, AccountApiKeys use the inline pattern.
**Fix:** Use inline pattern for consistency. Functionally equivalent, but the plan instructs implementers with a non-standard form.
