# Round 8 — Frontend segment audit (AccountBillingPlans → useBilling → planLookups → api → SCREEN)

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Files traced (chain printed)

- Prices/data origin: `AccountBilling.tsx` → `useBilling.ts` (`useBillingPrices`/`useStripeCustomerSubscription`) → `api.ts` (`apiGet` → axios/Rails boundary)
- Render chain: `AccountBilling.tsx` → `AccountBillingPlans.tsx` → `planLookups.js` (`getPlansForPeriod`/`getPlanButtonText`/`getPlanButtonType`) → `PlanCard.tsx` → `ManageBillingActions` / `Styled.Button` (SCREEN)
- Change request chain: `PlanCard.tsx` (`handleOnClickSubscriptionAction`) → `AccountBillingPlans.tsx` (`handleChangeSubscriptionWithGate` → `handleChangeSubscriptionViaStripePortal` / `handleUpdateWithPaymentMethod`) → `useBilling.ts` (`useChangeSubscriptionViaStripePortal`/`useUpdateWithPaymentMethod` → `changeSubscriptionViaStripePortal`/`updateWithPaymentMethod`) → `api.ts` (`apiPost` → `apiMutate`, `allKeysToSnake`/`allKeysToCamel`/CSRF) → axios/Rails boundary

## Verification result

Every frontend identifier, line citation, prop, const, terminal (SCREEN / ANALYTICS / DEBUG / request-leaves-to-backend), and structural claim in the trace's frontend segment was checked against the actual code, line by line. All cited line numbers, file paths, identifier names, gating conditions, dead-prop claims (`subscriptionItemId`), debug-only terminals (`currentProductPrice`, `currentPlanBillingPeriod`), and the two-SCREEN-terminal claim for `isFetchingStripeCustomerSubscription` are correct as written.

Spot-confirmed exact matches (representative, not exhaustive):
- `useStripeCustomerSubscription` destructure `AccountBillingPlans.tsx:56-61`; `currentSubscription` derive `:62-64`; `currentPriceObject` `:67`.
- `getStripeCustomerSubscription` `useBilling.ts:98`; `apiGet` `api.ts:5`, `allKeysToCamel` `api.ts:22`.
- `currentSubscriptionItemId` `:136`; closure reads `:329`/`:334`; `subscriptionItemId` declared `PlanCard.tsx:71`, absent from destructure `:75-89`, unreferenced in body (DEAD PROP confirmed).
- `getPlansForPeriod` `planLookups.js:553`; `: 0` fallback `:564`; `priceId` `:568`; `lookupKey` `:569`; `key` `:571`.
- `getPlanButtonText` def `planLookups.js:594`; `getPlanButtonType` def `:578`; `buttonText` ternary `AccountBillingPlans.tsx:180-184`.
- `<PlanCard>` element `:439-456`, all 11 props at cited lines (`:443`–`:455`).
- PlanCard button branch `:199`; `ManageBillingActions` `:200-205`; `Styled.Button` `:207-214` (`onClick` `:208`, `loading={isLoadingButton}` `:209`, `disabled={isLoading}` `:210`, `styleType` `:211`, `{plan.buttonText}` `:213`).
- `apiPost` `api.ts:25-28` → `apiMutate` `:40-68`; CSRF `:50`; `allKeysToSnake` `:52`; `allKeysToCamel` responses `:67`/errors `:56`.
- `AccountBilling.tsx` 3-way ternary `:122-134`; `useBillingPrices` `:50`; `billingPrices` unwrap `:54`; props to `AccountBillingPlans` `:129-134`.

## Discrepancies

None. The trace's frontend segment is accurate to the current analog code in this worktree.
