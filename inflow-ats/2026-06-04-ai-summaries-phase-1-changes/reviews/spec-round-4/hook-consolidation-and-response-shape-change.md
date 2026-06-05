# angle-3: hook-consolidation-and-response-shape-change — Round 4

## Finding 1

**[LOW]** Type file `aiCreditSubscription.ts` not mentioned in spec

**Where:** `app/javascript/shared/types/aiCreditSubscription.ts`

**What:** The `AiCreditSubscription` interface in this file defines the shape of the serialized `OrganizationAiCreditPurchase`. It's imported by `useAiCreditSubscription.ts` (being deleted). The new `useOrganizationAiCreditPurchase.ts` hook will need this type. The spec doesn't mention renaming or updating this type file. The implementing agent will handle it naturally when building the new hook, but for completeness: the type should be renamed to `OrganizationAiCreditPurchase` in a file named `organizationAiCreditPurchase.ts` (matching the codebase convention of camelCase type files matching model names).

No BLOCKER or HIGH.
