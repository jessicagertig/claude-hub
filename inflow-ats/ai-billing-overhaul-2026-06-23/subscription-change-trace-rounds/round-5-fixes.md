# Round 5 — Fix log (subscription-change analog trace)

Worktree verified against: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`. Only the trace file `traces/subscription-change-analog-trace.md` was edited; no code touched, no git commands. All 7 findings confirmed against actual code before editing.

## Fixes applied

1. **currentProductPrice is NOT a SCREEN terminal (frontend D1)** — Item 9 rewritten. `currentProductPrice` (`AccountBillingPlans.tsx:137-142`) now correctly traced to its ONLY consumer, the `window.logger` debug-object literal (`currentProductPrice` key `:200`, literal `:195-209`); never referenced in JSX. The tiered (`:140`), non-tiered (`:141`), and `null` (`:142`) branches all terminate at `window.logger`, not the SCREEN. Removed the "TIERED SCREEN branch"/"value-to-SCREEN path" mischaracterization.

2. **False "ONLY ... downstream of guard" claim (frontend D2)** — Item 9 now lists the `currentPriceObject`-derived consts that DO reach the SCREEN: `currentPlanLookupKey` (`:68`) → PlanCard prop `:444` + `getPlanButtonText` `:181`; `currentPlanBillingInterval` (`:69-70`) → `currentPlanBillingPeriod` (`:71-76`) → PlanCard prop `:445`; raw interval rendered in legacy-plan copy `:408`/`:413`. Removed the false "ONLY ... is currentProductPrice" assertion.

3. **getPlanButtonText / getPlanButtonType omitted (frontend D3)** — Item 15 extended. Added the import (`AccountBillingPlans.tsx:34`), `buttonText` production (`:180-184`, `getPlanButtonText` def `planLookups.js:594`), `buttonType` production (`:186`, `getPlanButtonType` def `planLookups.js:578`), and their SCREEN terminals in PlanCard: label `{plan.buttonText}` (`PlanCard.tsx:213`) and `styleType={plan.buttonType || "secondary"}` (`:211`).

4. **currentSubscription SCREEN terminals omitted (frontend D4)** — Item 9 now enumerates the additional `currentSubscription` SCREEN renders: trialing block `prettyDate(trialEnd)` (`:370-382`); cancelAtPeriodEnd block `prettyDate(cancelAt)` (`:384-396`); `isTrialing`/`trialEndDays` (`:158-163`) rendered at `:415`; `hasCoupon`/`discount`/`coupon` (`:165-170`) rendered `{coupon.percentOff}% off until {prettyDate(discount.end)}` (`:424-431`); `isCurrentPlan` gate (`:436`).

5. **null branch presented as SCREEN fallback (frontend D5)** — Folded into the item 9 rewrite: the `:142` `null` else-branch is explicitly stated to terminate at `window.logger` (`:200`), with no SCREEN fallback.

6. **sync_with_stripe column-set overstated as unconditional (terminals D1, LOW)** — Trace line 119 corrected: `plan` (`:573`) and `stripe_default_payment_method_on_file` (`:580`) unconditional; `stripe_subscription_id`/`stripe_subscription_status`/`stripe_current_period_end_at` only inside `if current_subscription.present?` (`:567-571`); `changes_to_make` diff-built (`:585-595`) so `update` (`:600`) writes only the differing subset. The five-column list reframed as a SUPERSET of POSSIBLE writes. The matching "Unresolved identifiers" `sync_with_stripe` summary (trace line ~159) updated to stay consistent.

7. **continue-action rescue return_url may be nil (terminals D2, LOW)** — Item 18b continue-action rescues annotated: `return_url` is assigned at `:403-407`, AFTER the early customer/subscription-blank guards (`:390-398`, which use RAW `params[:return_url]`); a pre-`:403` raise into the `:458`/`:464` rescues leaves `return_url` nil, making the `:463`/`:469` redirect terminal host-relative `"?error=subscription_update_failed"`. Noted that in practice the raise-prone code runs after `:403`.

## Segments with zero findings (no edits needed)
- model-services (Organization/ValidateSubscriptionChange/PlanFeatureGate/SubscriptionStatusChecker/policies/schema): DISCREPANCY COUNT 0.
- routes-controller (routes + all in-flow BillingController actions + determine_price_id): NONE.
