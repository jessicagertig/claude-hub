# Angle 7: Plato AI Tab Consolidation — Round 6

## Review

### `AccountPlatoAiContainer.tsx`

**Admin-only gate:** `useAuthorization({ adminOnly: true })` -- returns null if not authorized. Correct.

**Internal sidebar order:** Settings, Billing, Usage. Uses `NavItem` with `chevron`. All link to `${match.url}/...`. Correct.

**Switch/Route structure:**
- `/settings` renders `OrganizationAiSettings`. Correct.
- `/billing` renders `OrganizationAiBilling`. Correct.
- `/usage` renders `OrganizationAiUsage`. Correct.
- Default `<Redirect to={match.url}/settings} />`. Correct.

**Styled components match `AccountIntegrationsContainer`:**
- `Styled.Container`: `display: flex; height: 100%`. Correct.
- `Styled.Sidebar`: `width: 40vw`, `lg` breakpoint `33.333%`, `border-right`, `padding-top: 0.375rem`. Correct.
- `Styled.Content`: `width: 66.666%; height: 100%; overflow-y: auto`. Correct.

**Helmet:** `<Helmet title="Plato AI" />`. Correct.

**UnsavedChangesGuard:** Present with `isDirty` state. Correct.

### `AccountContainer.tsx`

**Imports:** `OrganizationAiSettings`, `OrganizationAiBilling`, `OrganizationAiUsage` removed. `AccountPlatoAiContainer` added from `./accountPlatoAi/AccountPlatoAiContainer`. Correct.

**`adminOrgPathNames`:** Single entry `"/hire/settings/plato-ai": "Plato AI"`. Wrapped in `aiApplicantSummaryEnabled` feature flipper check. Correct (the feature flipper wrapping is not in the spec but is a reasonable guard for a dev-only feature).

**`memberPathNames`:** No AI entries. Non-admins get no Plato AI tab. Correct.

**Route:** `path="/hire/settings/plato-ai"` rendering `AccountPlatoAiContainer`. Old three AI routes removed. Correct.

### Missing `exact={false}` on Plato AI route

The route at line 207 does NOT have `exact={false}`. The spec says: "Route `exact={false}` on `/hire/settings/plato-ai` so sub-paths are matched." The `AccountIntegrationsContainer` analog at line 149 explicitly sets `exact={false}`.

However, React Router v4.2.2 (the version in use) defaults `<Route>` to non-exact matching when `exact` is not specified. This means sub-paths like `/hire/settings/plato-ai/settings` DO match. The route works correctly without `exact={false}`.

## Findings

### MED F1 -- Missing `exact={false}` on Plato AI route

**File:** `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx:207`

The spec requests `exact={false}` and the analog (`AccountIntegrationsContainer` at line 149) has it. While React Router v4 defaults to non-exact matching (so the route works), the explicit prop should be added for consistency with the codebase pattern and the spec requirement. This is cosmetic, not functional.

### MED F2 -- Plato AI tab behind feature flipper

**File:** `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx:73-75`

The Plato AI entry in `adminOrgPathNames` is wrapped in `aiApplicantSummaryEnabled` feature flipper check. This is not in the spec. However, for a dev-only feature, this is a reasonable guard and likely intentional. Noting for transparency.

## Verdict: PASS (0 HIGH, 2 MED)
