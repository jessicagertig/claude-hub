# Angle 7: Plato AI Tab Consolidation -- Round 3

## Files reviewed

- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AccountPlatoAiContainer.tsx` (new)
- `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx`

## Round 1 defects (resolved)

- H2 (missing `currentOrganization` prop) -- FIXED. `AccountPlatoAiContainer` now imports `useCurrentSession` and passes `currentOrganization` explicitly to all three child components.

## Findings

**No new findings.**

Container correctly implements the analog pattern:
- `useAuthorization({ adminOnly: true })` gate
- `useCurrentSession()` for `currentOrganization`
- `Styled.Container` with `display: flex; height: 100%`
- `Styled.Sidebar` with `40vw` / `33.333%` at lg, border-right, `padding-top: 0.375rem`
- `Styled.Content` with `66.666%`, `overflow-y: auto`
- Styled component labels match component name (e.g., `AccountPlatoAiContainer_Sidebar`)
- NavItems: Settings, Billing, Usage -- relative paths using `${match.url}/...`
- Switch/Route for settings/billing/usage with correct components
- `Redirect` to `${match.url}/settings`
- `Helmet title="Plato AI"`
- `UnsavedChangesGuard` integrated
- `AccountContainer` removes 3 AI routes, adds 1 Plato AI route
- `memberPathNames` no longer includes AI usage entry
- `adminOrgPathNames` has single `"/hire/settings/plato-ai": "Plato AI"` entry
- Route does not specify `exact` (default is `exact={false}` for path matching)
