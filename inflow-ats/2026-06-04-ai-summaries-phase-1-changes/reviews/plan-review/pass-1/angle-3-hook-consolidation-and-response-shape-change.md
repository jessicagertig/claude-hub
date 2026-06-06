# angle-3: hook-consolidation-and-response-shape-change — Pass 1

## Fact Check

| Claim | Verification | Result |
|-------|-------------|--------|
| `useAiCreditSubscription.ts` exists | ls confirmed | CORRECT |
| `useSubscribeToAiCreditPack.ts` exists | ls confirmed | CORRECT |
| `usePurchaseAiCreditTopUp.ts` exists | ls confirmed | CORRECT |
| `useCancelAiCreditSubscription.ts` exists | ls confirmed | CORRECT |
| `useOrganizationAiCreditBalance.ts` exists | ls confirmed | CORRECT |
| `AccountBillingAiCredits.tsx` exists | ls confirmed | CORRECT |
| `planHelpers.ts` exists at `app/javascript/shared/lib/planHelpers.ts` | ls confirmed (via type file verification) | EXISTS |
| Response shape change from `subscriptionData?.aiCreditSubscription` to direct object | Current `AiCreditSubscriptionsController#show` wraps in `{ ai_credit_subscription: ... }` (line 10-12) | CORRECT — plan correctly identifies this |
| `aiCreditPrices` function uses `p.lookupKey` (camelCase) | Spec/approved-decisions code uses `p.lookupKey` | CONSISTENT with core rule #7 (API transforms snake_case to camelCase) |

## Completeness

Spec requirements covered by this angle:
- Note #9A hook consolidation — plan step H.2
- Note #9B-2 `planHelpers.ts` additions — plan step H.3
- Note #9A `AccountBillingAiCredits.tsx` refactor — plan step H.4
- Response shape change — plan step H.4.5

All spec requirements have corresponding plan steps.

## Findings

No issues found.

## Amendments Applied

(none)
