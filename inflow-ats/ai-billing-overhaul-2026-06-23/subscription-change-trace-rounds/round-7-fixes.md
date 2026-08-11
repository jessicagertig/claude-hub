# Round 7 — Trace Fix Log

Subject: ANALOG subscription-change trace (`traces/subscription-change-analog-trace.md`). All 4 findings verified against current code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza` before editing. Analog-only; no "ours" content introduced. No code touched.

## Verification (file:line confirmed in worktree)

- `AccountBillingPlans.tsx:156` — `const currentPlanDisplayName = getPricingDisplayName(currentOrganization.plan);` (reads `currentOrganization.plan`, not `currentSubscription`).
- `AccountBillingPlans.tsx:412-414` — legacy-plan `currentLegacyPlanType` ternary else-branch renders `` the ${currentPlanDisplayName} ${...interval}ly pricing plan``.
- `AccountBillingPlans.tsx:415` — `{isTrialing && !hasCoupon && `Free for ${trialEndDays}.`}` (co-gated by `!hasCoupon`, trailing period).
- `AccountBillingPlans.tsx:339` — `trackEvent("plan_change_blocked_modal_shown", { current_plan_lookup_key: currentPlanLookupKey, target_plan_lookup_key: plan.lookupKey })`.
- `AccountBillingPlans.tsx:443-455` — full `<PlanCard>` prop list confirmed, including `:444` `currentPlanLookupKey`, `:445` `currentPlanBillingPeriod`, `:446` `hasActiveSubscription`, `:447` `hasCoupon`, `:448` `stripePromoCode={currentOrganization.stripePromoCode}`, `:454` `onCreateBillingPortalSession={handleCreateBillingPortalSession}`.
- `PlanCard.tsx:199-205` — `{isCurrentPlan || isFreePlan ? (<ManageBillingActions hasActiveSubscription= hasCoupon= stripePromoCode= onCreateBillingPortalSession= />) : ...}`.

## Fixes applied

1. **DISCREPANCY 1 (omitted consumer)** — Trace item 9 `currentPlanLookupKey` paragraph rewrote to list BOTH consumers: (a) the direct in-component read at `AccountBillingPlans.tsx:339` in `trackEvent('plan_change_blocked_modal_shown', { current_plan_lookup_key: currentPlanLookupKey, ... })` (ANALYTICS terminal on the gate-blocked branch), and (b) the existing `<PlanCard>` prop (`:444`) path. Previously only (b) was documented.

2. **DISCREPANCY 2 (omitted SCREEN terminal)** — Trace item 9 `currentSubscription` render-terminals list gained a new bullet for `currentPlanDisplayName = getPricingDisplayName(currentOrganization.plan)` (`:156`) rendering to SCREEN at `:412` inside the `isOnLegacyPlan` / `currentLegacyPlanType` else-branch. Noted it reads `currentOrganization.plan`, not `currentSubscription`.

3. **DISCREPANCY 3 (incomplete prop enumeration)** — Trace item 16's `<PlanCard>` prop list expanded to include `hasActiveSubscription` (`:446`), `hasCoupon` (`:447`), `stripePromoCode={currentOrganization.stripePromoCode}` (`:448`), and `onCreateBillingPortalSession={handleCreateBillingPortalSession}` (`:454`) (plus the previously-implicit `:444`/`:445`). Added the trace to their terminal: all four feed `<ManageBillingActions>` (`PlanCard.tsx:200-205`, props at `:201-204`), the SCREEN terminal rendered in the `isCurrentPlan || isFreePlan` true-branch.

4. **DISCREPANCY 4 (rendered-string content wrong)** — Trace item 9 `:415` bullet corrected from `Free for ${trialEndDays}` gated only by `isTrialing` to the actual `{isTrialing && !hasCoupon && `Free for ${trialEndDays}.`}` — co-gated by `!hasCoupon` and carrying a trailing period.
