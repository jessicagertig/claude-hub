# Angle 1: Routing, Navigation, and Feature-Flag Gating

## Findings

### No findings (PASS)

**Route registration:** The `/ai` Route is placed as a direct child of `<Switch>` (JobApplicationContainer.tsx lines 278-287), NOT wrapped in `<FeatureFlipper>`. This correctly addresses the plan-review HIGH finding (React Router v5 `<Switch>` only inspects direct children for `path` props).

**possiblePaths conditional inclusion:** `"ai"` is conditionally included via `...(isAiEnabled ? ["ai"] : [])` at line 155. The `useFeatureFlipper` hook is called at the top level (lines 45-46) and `isAiEnabled` is included in the useEffect dependency array (line 162). When the flag is off, `currentViewPath` will not match `"ai"`, and `redirector()` will redirect to `/overview`. Verified: no infinite loop.

**Feature flag usage:** Uses `useFeatureFlipper` and `Features.AI_APPLICANT_SUMMARY` (enum value, not string literal) at line 46. This matches the codebase convention.

**PlatoNavItem in sidebar:** Wrapped in `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">` at line 99. Uses `NavLink` via `styled(NavLink, { shouldForwardProp: isPropValid })` at line 470. This is correct for keyboard navigation and screen reader support.

**linkStyles comparison:** The `platoNavLinkStyles` function (lines 429-468) is a verbatim copy of `NavItem.tsx` `linkStyles` (lines 56-95). Both use the same properties: 40px height, `radii.sm`, `.active` state with `subtleHover`, `breakpoint.sm` responsive gate, `> svg` opacity transitions. The only difference is the function uses `props.theme.poly.*` instead of a destructured `t` -- this is functionally identical since they access the same theme object.

**PlatoNavLabel:** Lines 472-488 replicate the `StyledLabel` pattern from `NavItem.tsx` lines 103-118, correctly substituting `> span:first-of-type` for `svg` since PlatoChip renders a `<span>`.

**match.url navigation:** The `onOpen` callback in JobApplicationActivity.tsx (line 397) correctly strips the last segment: `match.url.replace(/\/[^/]+$/, "")/ai`. This addresses the plan-review HIGH finding (match.url includes `/overview`).

**Note:** The original `NavItem.tsx` `linkStyles` also lacks a `label:` property in the template-literal CSS function. The `PlatoNavItem` follows this same convention -- consistent, not a violation.
