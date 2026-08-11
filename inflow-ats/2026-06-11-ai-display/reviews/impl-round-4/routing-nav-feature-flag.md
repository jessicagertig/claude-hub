# Angle: Routing, Navigation, and Feature-Flag Gating

## Files checked
- `JobApplicationContainer.tsx` -- route at lines 278-287, `possiblePaths` at line 155, `useFeatureFlipper` at lines 45-46
- `JobApplicationSidebar.tsx` -- `PlatoNavItem` at lines 99-107, `FeatureFlipper` wrapping, `platoNavLinkStyles` at lines 429-468, `PlatoNavLabel` at lines 472-488
- `NavItem.tsx` -- `linkStyles` lines 56-95, `StyledLabel` lines 103-118 (analog)
- `FeatureFlipper.tsx` -- `AI_APPLICANT_SUMMARY` enum, `useFeatureFlipper` hook

## Findings

No findings.

## Verification

1. **Route registration:** The `/ai` Route is a direct child of `<Switch>` (lines 278-287), NOT wrapped in `<FeatureFlipper>`. This matches the plan-review correction (Pass 1 F1) and the `AccountIntegrationsContainer.tsx` pattern. Route matching works correctly.

2. **Conditional possiblePaths:** `"ai"` is conditionally included via `...(isAiEnabled ? ["ai"] : [])` at line 155. `isAiEnabled` is in the `useEffect` dependency array at line 162. When the flag is off, navigating to `/ai` will not match `possiblePaths`, so `currentViewPath` stays as previous value, and `redirector()` redirects to the correct path (no infinite loop).

3. **useFeatureFlipper at top level:** `isFeatureEnabled` is called at line 45, `isAiEnabled` at line 46, both at component top level before any `useEffect`. Hooks rule satisfied.

4. **PlatoNavItem linkStyles verbatim copy:** `platoNavLinkStyles` is byte-identical to `linkStyles` from `NavItem.tsx` (confirmed via diff). Only the function name and type annotation differ.

5. **PlatoNavLabel adaptation:** Uses `> span:first-of-type { margin-right: 8px; flex-shrink: 0; }` instead of `svg { margin-right: 8px; }` because `PlatoChip` renders as `<span>`, not `<svg>`. Correct adaptation.

6. **shouldForwardProp:** `PlatoNavItem` uses `isPropValid` from `@emotion/is-prop-valid`, matching `NavItem.tsx` line 101. The `chevron` prop is available in the styles function (Emotion passes all props to the style function before filtering) but filtered from the DOM.

7. **FeatureFlipper on sidebar nav:** The `PlatoNavItem` block (lines 99-107) is wrapped in `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">`. When the flag is off, no Plato nav item appears.

8. **NavLink usage:** `PlatoNavItem` is `styled(NavLink)`, providing proper `aria-current` and keyboard navigation support.
