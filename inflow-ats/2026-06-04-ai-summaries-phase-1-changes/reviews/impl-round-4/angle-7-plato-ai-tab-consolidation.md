# Angle 7: Plato AI Tab Consolidation -- Round 4

## Fresh adversarial focus areas

1. **`OrganizationAiBilling` and `OrganizationAiUsage` receive `currentOrganization` prop.** Checked: neither component destructures or uses `currentOrganization`. The extra prop is harmless (spread through `{...props}`). Only `OrganizationAiSettings` uses it. Correct.

2. **Route path matching.** `AccountContainer` renders `<Route path="/hire/settings/plato-ai">` without `exact`. React Router v4/v5 `Route` does prefix matching by default. Sub-paths (`/settings`, `/billing`, `/usage`) inside the container's `Switch` are matched relative to `match.path`. Correct.

3. **`UnsavedChangesGuard` integration.** The container includes `UnsavedChangesGuard` with `hasUnsavedChanges={isDirty}`. All three child components receive `setIsDirty` prop. This prevents navigation away with unsaved changes. Correct.

4. **`aiApplicantSummaryEnabled` gate.** The `adminOrgPathNames` conditionally includes Plato AI only when `aiApplicantSummaryEnabled` is true. `memberPathNames` has no AI entry at all. Non-admins see no Plato AI tab. Correct per spec.

5. **Styled component labels.** `AccountPlatoAiContainer`, `AccountPlatoAiContainer_Sidebar`, `AccountPlatoAiContainer_Content`. Labels match component name pattern. Correct.

## Findings

**No findings.**
