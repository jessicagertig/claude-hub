# Pass 2 -- Angle 1: Routing, Navigation, and Feature-Flag Gating

## Pass 1 Correction Verification

### F1 (HIGH) -- FeatureFlipper removed from Route inside Switch

VERIFIED: Plan Task 5.4 now reads "Do NOT wrap in `<FeatureFlipper>`" with clear reasoning. The code block shows an unwrapped `<Route>`. The "Why conditional" text in Task 5.3 has been updated to remove the stale reference to the route being "gated by FeatureFlipper." The import at Task 5.1 correctly removes `FeatureFlipper` and keeps only `useFeatureFlipper` and `Features`.

No new issues introduced by the correction.

## Fresh Scrutiny

### match.url in JobApplicationActivity onOpen handler

FOUND in Pass 2: Plan Task 7.5 originally used `history.push(\`${match.url}/ai\`)`. The `match` prop in `JobApplicationActivity` comes from `{...renderProps}` at the overview route's render callback, meaning `match.url` includes `/overview` (e.g., `/jobs/1/stages/2/applicants/3/overview`). This would navigate to `/jobs/1/stages/2/applicants/3/overview/ai` instead of `/jobs/1/stages/2/applicants/3/ai`.

VERIFIED AMENDMENT: Task 7.5 now uses `match.url.replace(/\/[^/]+$/, "")/ai` with clear explanation. This correctly strips the trailing segment.

### Redirect behavior when flag is off

When `isAiEnabled` is false, `"ai"` is not in `possiblePaths`, so `setCurrentViewPath` is never called with `"ai"`. If a user has `"ai"` as their `currentViewPath` from a previous session and the flag is then turned off, the useEffect will re-run (because `isAiEnabled` changed) and `currentView` will still be `"ai"` from the URL. But `possiblePaths` won't include `"ai"`, so `setCurrentViewPath` won't be called, and `currentViewPath` retains its previous value.

Wait -- actually, looking at the code: the useEffect runs on `[location, isAiEnabled]`. If the user is on `/ai` and the flag is turned off, the effect fires. `currentView` from `locations[0]` will be `"ai"`. `possiblePaths` won't include `"ai"`, so `setCurrentViewPath` is NOT called. `currentViewPath` stays as `"ai"` (from the previous render). Then `redirector()` redirects to `${match.url}/ai` -- which renders `PlatoTab` since the Route is unconditional. This means the user stays on the Plato tab even after the flag is turned off.

However, this is an extreme edge case (flag toggled while user is on the page) and the existing codebase has no precedent for handling this scenario for any route. The next page load/navigation will resolve it. Not a finding.

### useFeatureFlipper hook rules

The hook is called at component top level (Task 5.2), before the useEffect. Since `JobApplicationContainer` is a function component (not a class), this is valid per React's rules of hooks. The result `isAiEnabled` is a plain boolean that can be referenced inside the useEffect callback and in the dependency array. CORRECT.

## Findings

### F1 [HIGH] match.url in onOpen handler includes /overview segment -- AMENDED

**Where:** Plan Task 7.5
**What:** The `match` from `{...renderProps}` at the overview Route has `url` ending in `/overview`. The original `${match.url}/ai` would navigate to the wrong path.
**Status:** AMENDED in plan. Now uses `match.url.replace(/\/[^/]+$/, "")/ai`.
