# Spec Review: Routing, Navigation, and Feature-Flag Gating

Reviewer angle: routing, navigation, and feature-flag gating (Sections 4, 5, Authorization, Constraints).

## Findings

- F1 [HIGH] **Flag-off + `/ai` in `possiblePaths` = infinite redirect loop.**
  - **Where:** Section 4 (JobApplicationContainer.tsx changes), lines 123-125 of spec.
  - **What:** The spec says (a) add `"ai"` to `possiblePaths` at line 151, AND (b) wrap the `/ai` Route in `<FeatureFlipper>` so it returns `null` when the flag is off. When the flag is off and a user navigates to `/ai`, the Route does not render. The `<Switch>` falls through to `{redirector()}` (line 275). `redirector()` (lines 185-191 of the source file) checks `currentViewPath` -- which IS set to `"ai"` because the `useEffect` at lines 150-158 checks `possiblePaths.includes(currentView)` and `"ai"` is now in that array. So `redirector()` returns `<Redirect to="${match.url}/ai" />`, which redirects back to `/ai`, which again does not match any Route, which again falls through to `redirector()` -- infinite loop.
  - **Evidence:** `redirector` definition at lines 185-191: `if (currentViewPath != undefined) { return <Redirect to={match.url/${currentViewPath}} />; }`. The `possiblePaths` useEffect at lines 150-158 sets `currentViewPath` to `"ai"` because the spec adds `"ai"` to the array.
  - **Fix:** The spec's constraint "the `/ai` route must redirect to `/overview`" (line 195) cannot be satisfied by wrapping the Route in `FeatureFlipper` alone. Two options: (1) Do NOT add `"ai"` to `possiblePaths` -- this means `currentViewPath` stays unset when on `/ai`, and `redirector()` falls through to the else branch (`<Redirect to="${match.url}/overview" />`), achieving the desired redirect. The tradeoff: `currentViewPath` won't be `"ai"` when switching candidates, so the view won't persist across candidate switches for the Plato tab. (2) Add `"ai"` to `possiblePaths` conditionally (only when the feature flag is on), and use `useFeatureFlipper` to gate both the `possiblePaths` inclusion and the Route. This preserves view persistence while avoiding the loop. Option 2 is the correct fix since the spec clearly intends view persistence ("so that navigating directly to `/ai` is recognized as a valid view path and preserved across candidate switches").

- F2 [MED] **`match` not in `JobApplicationActivity` Props type or destructuring -- `onOpen` callback needs it.**
  - **Where:** Section 6 (JobApplicationActivity.tsx changes), lines 156-158 of spec.
  - **What:** The spec says the `onOpen` callback should navigate to `${match.url}/ai` using `history.push`. It acknowledges "`match` is not [currently available]" but then claims "Since `JobApplicationActivity` is rendered via `<Route render={...}>`, `match` is already passed via `renderProps` spread." This is partially true -- `{...renderProps}` does spread `match` onto the JSX element (JobApplicationContainer.tsx line 230). However, `JobApplicationActivity`'s Props type (lines 34-38) only declares `{ jobApplication, orgAdminJobsListUrl, history }`, and the function destructures only those three (line 40). So `match` is silently available on the props object but not typed or destructured. The spec must explicitly state: add `match: any` to the Props type and add `match` to the destructuring.
  - **Evidence:** Props type at lines 34-38 of JobApplicationActivity.tsx: `type Props = { jobApplication: any; orgAdminJobsListUrl: string; history: any; };`. Function signature at line 40: `function JobApplicationActivity({ jobApplication, orgAdminJobsListUrl, history }: Props)`.
  - **Fix:** Add to Section 6's "Changes" list: "Add `match: any` to the `Props` type. Add `match` to the function parameter destructuring." Alternatively, the spec could use `history.push(history.location.pathname.replace(/\/overview$/, '/ai'))` or a `useRouteMatch` hook, but adding `match` to the destructuring is simplest and consistent with how other tabs receive it.

- F3 [LOW] **Spec says custom PlatoNavItem should use `NavLink` -- should use `NavLink` with `shouldForwardProp` to match existing pattern.**
  - **Where:** Section 5 (JobApplicationSidebar.tsx changes), lines 140-146 of spec.
  - **What:** The spec says "Use `NavLink` from `react-router-dom`" for the custom PlatoNavItem. The existing NavItem component wraps `NavLink` via `styled(NavLink, { shouldForwardProp: isPropValid })` (NavItem.tsx line 101). Using a raw `NavLink` without `shouldForwardProp` will forward all custom styled-component props (like `chevron` if used) to the DOM, producing React warnings. This is a minor detail since the spec also says to match `linkStyles` from NavItem.tsx, but the spec should explicitly note the `shouldForwardProp: isPropValid` pattern or the implementer may miss it.
  - **Evidence:** NavItem.tsx line 101: `const StyledNavLinkComponent = styled(NavLink, { shouldForwardProp: isPropValid })(linkStyles);`. Line 1: `import isPropValid from "@emotion/is-prop-valid";`.
  - **Fix:** In Section 5, add: "Wrap `NavLink` with `styled(NavLink, { shouldForwardProp: isPropValid })` using `isPropValid` from `@emotion/is-prop-valid`, matching the pattern at NavItem.tsx line 101."

- F4 [LOW] **Spec correctly uses `match.path` for Route and `match.url` for links -- verified, no issue.**
  - **Where:** Section 4 (Route uses `${match.path}/ai`), Section 5 (link uses `${match.url}/ai`).
  - **What:** Verified against codebase: all Routes use `match.path` (lines 226, 238, 250, 256, 262 of JobApplicationContainer.tsx). All NavItem `to` props use `match.url` (lines 80-92 of JobApplicationSidebar.tsx). The spec is correct on both counts.
  - **Disposition:** No finding. Recorded for completeness.

- F5 [LOW] **Existing NavItems all pass `chevron` prop -- spec's chevron-right instruction is consistent.**
  - **Where:** Section 5, line 145 of spec ("Render a `chevron-right` icon on the right").
  - **What:** Every existing NavItem in JobApplicationSidebar.tsx passes `chevron` (or `chevron` is explicitly set): lines 80, 81, 86, 91, 92. NavItem.tsx renders `<Icon name="chevron-right" />` when `props.chevron` is truthy (line 44). The spec's instruction to render a chevron-right icon on the custom PlatoNavItem is consistent with existing behavior.
  - **Disposition:** No finding. Recorded for completeness.

## Summary

| Severity | Count |
|----------|-------|
| BLOCKER  | 0     |
| HIGH     | 1     |
| MED      | 1     |
| LOW      | 2 (findings) + 2 (verified-ok) |

F1 is the only finding that would cause a runtime defect if implemented as-written. F2 would cause a TypeScript error or silent failure in the navigation callback.
