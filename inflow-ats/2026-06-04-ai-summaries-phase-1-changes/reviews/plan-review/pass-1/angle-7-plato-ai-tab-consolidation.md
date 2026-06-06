# angle-7: plato-ai-tab-consolidation — Pass 1

## Fact Check

| Claim | Verification | Result |
|-------|-------------|--------|
| `AccountIntegrationsContainer.tsx` exists at stated path | ls confirmed | CORRECT |
| `AccountContainer.tsx` exists at stated path | ls confirmed | CORRECT |
| `OrganizationAiSettings.tsx` exists | ls confirmed | CORRECT |
| `OrganizationAiBilling.tsx` exists | ls confirmed | CORRECT |
| `OrganizationAiUsage.tsx` exists | ls confirmed | CORRECT |
| Plan I.1 creates `accountPlatoAi/AccountPlatoAiContainer.tsx` | Plan step | Present |
| Plan I.1.5 matches `AccountIntegrationsContainer` styled components | Analog file exists | Will follow analog |
| Plan I.1.1 uses `useAuthorization({ adminOnly: true })` | Plan step | Consistent with spec |
| Plan I.1.4 defaults redirect to `${match.url}/settings` | Plan step | Consistent with spec |
| Plan I.2.3 replaces three AI entries with one `"/hire/settings/plato-ai": "Plato AI"` | Plan step | Consistent with spec |
| Plan I.2.4 removes AI usage from `memberPathNames` | Plan step | Consistent with spec |
| Plan I.2.5 adds route with `exact={false}` | Plan step | Consistent with spec |

## Completeness

Spec requirements covered by this angle:
- Note #16 new container creation — plan step I.1
- Note #16 AccountContainer changes — plan step I.2
- Admin-only gate — plan step I.1.1
- Non-admin removal — plan step I.2.4
- Old route removal — plan step I.2.5

All spec requirements have corresponding plan steps.

## Findings

No issues found.

## Amendments Applied

(none)
