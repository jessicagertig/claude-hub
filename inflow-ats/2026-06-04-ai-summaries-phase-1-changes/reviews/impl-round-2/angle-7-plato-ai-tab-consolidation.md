# Angle 7: Plato AI Tab Consolidation -- Round 2

## Scope

`AccountPlatoAiContainer.tsx`, `AccountContainer.tsx` sidebar and route changes. Round 1 H2 found missing `currentOrganization` prop.

## Findings

### F1 (CLEAR) -- Round 1 H2 fix: `currentOrganization` now passed from `useCurrentSession()`

`AccountPlatoAiContainer.tsx:14,20`: imports and calls `useCurrentSession()`, extracts `currentOrganization`. Lines 51-55, 62-66, 73-77: passes `currentOrganization={currentOrganization}` to all three child components. This resolves the `TypeError: Cannot read properties of undefined` crash.

### F2 (CLEAR) -- Admin-only gate

Line 21-22: `useAuthorization()`, `isAuthorized({ adminOnly: true })`. Returns null for non-admins.

### F3 (CLEAR) -- Internal sidebar order

Lines 33-35: Settings, Billing, Usage. Matches spec.

### F4 (CLEAR) -- Default redirect

Line 81: `<Redirect to={`${match.url}/settings`} />`. Correct.

### F5 (CLEAR) -- Styled components match analog

`Styled.Container` (flex, height 100%), `Styled.Sidebar` (40vw, 33.333% at lg, border-right, padding-top 0.375rem), `Styled.Content` (66.666%, overflow-y auto). Labels match component name: `AccountPlatoAiContainer`, `AccountPlatoAiContainer_Sidebar`, `AccountPlatoAiContainer_Content`.

### F6 (CLEAR) -- `AccountContainer.tsx` route change

`/hire/settings/plato-ai` route with no `exact` prop (React Router `<Route>` defaults to path-prefix matching when `exact` is absent, which is equivalent to `exact={false}` for sub-route matching). The three old AI routes are removed. `memberPathNames` no longer includes `ai-usage`.

### F7 (CLEAR) -- Helmet title

Line 30: `<Helmet title="Plato AI" />`.

## Verdict: 0 findings. PASS for this angle.
