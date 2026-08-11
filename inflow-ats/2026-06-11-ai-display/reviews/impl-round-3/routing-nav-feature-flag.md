# Angle: Routing, Navigation, and Feature-Flag Gating

## Verdict: PASS

### Route registration

`JobApplicationContainer.tsx` line 278: The `/ai` route is a direct child of `<Switch>`, not wrapped in `<FeatureFlipper>`. This matches the plan review correction (React Router v5's `<Switch>` only inspects direct children for `path` props).

### possiblePaths conditional inclusion

Line 155: `possiblePaths` conditionally includes `"ai"` via `...(isAiEnabled ? ["ai"] : [])`. `isAiEnabled` is in the useEffect dependency array (line 162). When the flag is off, `/ai` is not a recognized path, so `redirector()` at line 189 falls through to `Redirect to={match.url}/overview}`. No infinite loop.

### useFeatureFlipper hook

Lines 45-46: `useFeatureFlipper` is called at the component top level (before useEffect), returning `isFeatureEnabled`. Then `isAiEnabled = isFeatureEnabled({ feature: Features.AI_APPLICANT_SUMMARY })` uses the `Features` enum, not a string literal. Correct.

### Sidebar nav item

`JobApplicationSidebar.tsx` lines 99-107: `PlatoNavItem` is wrapped in `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">`. The nav item uses `NavLink` (line 100) with `to={match.url}/ai}`. Keyboard navigation and `aria-current` come for free from `NavLink`.

### PlatoNavItem styling

Lines 429-468: `platoNavLinkStyles` is a verbatim copy of `linkStyles` from NavItem.tsx lines 56-95. Same height (40px/32px), same radii, same margins, same `.active` state, same `:hover` gating behind `breakpoint.sm`, same `> svg` opacity transitions for chevron. `shouldForwardProp: isPropValid` prevents `chevron` from leaking to the DOM.

### PlatoNavLabel

Lines 472-488: Replicates `StyledLabel` from NavItem.tsx lines 103-118. Adapts `svg { margin-right: 8px; }` to `> span:first-of-type { margin-right: 8px; flex-shrink: 0; }` since PlatoChip is a `<span>`, not an `<svg>`. Correct adaptation.

### Overview callout FeatureFlipper

`JobApplicationActivity.tsx` lines 394-399: `PlatoOverviewCallout` is wrapped in `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">`. When the flag is off, neither the callout nor the nav item renders.

### No findings.
