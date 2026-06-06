# angle-7: plato-ai-tab-consolidation — Round 5

## Findings

- F1 [MED] `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx` / Plato AI tab is behind `aiApplicantSummaryEnabled` feature flipper -- not in spec / The spec says nothing about feature-flipping the Plato AI tab. It says: "In `adminOrgPathNames`: replace the three AI entries with one `/hire/settings/plato-ai: Plato AI`." The implementation wraps it in `...(aiApplicantSummaryEnabled ? { ... } : {})`. While this is arguably a reasonable guard, it deviates from spec. The spec says "Non-admins get no Plato AI tab at all" (which is handled by the container's `useAuthorization`), not "gate behind feature flipper." This is likely intentional design by the implementer since the whole AI feature is feature-flipped, but it was not specified.

- F2 [MED] `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx` / Plato AI route missing `exact={false}` / The spec explicitly states: "Route `exact={false}` on `/hire/settings/plato-ai` so sub-paths are matched." The AccountIntegrations route has `exact={false}` explicitly. The Plato AI route does not. React Router v5's `Route` defaults to `exact={false}` so sub-paths WILL still match, but the spec requirement is explicit and the analog (`AccountIntegrationsContainer`) sets it explicitly. This should be added for clarity and spec compliance.

- F3 [MED] `app/javascript/ats/src/views/accountAdmin/AccountContainer.tsx` / Old `memberPathNames` AI entry not removed / The spec says "In `memberPathNames`: remove `/hire/settings/ai-usage: AI usage`." Let me verify this was actually done -- since the diff only shows additions, the old three routes might still exist.

Let me verify F3 more carefully.

**Update after verification:** The diff shows the old AI routes were NOT present in the pre-existing `AccountContainer.tsx` on develop (there are no deletions of `/hire/settings/ai` entries in the diff). This means the three AI sidebar entries never existed in the base -- they were part of the new code being added. So there is nothing to remove. F3 is NOT a finding.

Revised findings: F1 and F2 as MED.
