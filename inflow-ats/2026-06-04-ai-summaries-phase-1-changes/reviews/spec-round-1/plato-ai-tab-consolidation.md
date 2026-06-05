# angle-7: plato-ai-tab-consolidation — Round 1

Verified against source:
- `AccountIntegrationsContainer.tsx` confirmed as the pattern analog — it exists at the specified path
- `AccountContainer.tsx` confirmed: three AI routes exist (`/ai`, `/ai-billing`, `/ai-usage`) with corresponding imports for `OrganizationAiSettings`, `OrganizationAiBilling`, `OrganizationAiUsage`
- `memberPathNames` confirmed: `/hire/settings/ai-usage` entry exists conditionally for non-admins (line 57)
- `adminOrgPathNames` confirmed: three AI entries exist at lines 78-80
- Route order in Switch: `ai-billing` before `ai-usage` before `ai` (lines 212-228) — correct ordering with specific routes first

No BLOCKER, HIGH, or MED findings for this angle. The spec correctly describes the current state and the target state.
