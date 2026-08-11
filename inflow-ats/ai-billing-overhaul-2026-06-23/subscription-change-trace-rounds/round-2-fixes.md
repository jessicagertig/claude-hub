# Round 2 — Trace Fix Log

Fixed all 24 round-2 discrepancies in `traces/subscription-change-analog-trace.md`. Every cited fact verified against the actual analog code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza` before editing. No "ours" content introduced; analog-only.

## Frontend (round-2-frontend.md + terminals D2-D5)

1. **Change button conditional render (D1 / terminals D5)** — Item 16 rewritten: `PlanCard.tsx:199` branches `{isCurrentPlan || isFreePlan ? <ManageBillingActions/> : <Styled.Button/>}`; the change button renders ONLY in the else branch (`:207-214`). `isFreePlan = plan.key === 'free'` at `PlanCard.tsx:151` added.
2. **Free-plan filter before the map (D2)** — Item 15 rewritten: `plansWithButtonText = plans.filter((plan) => plan.key !== 'free').map(...)` at `AccountBillingPlans.tsx:177-178`, drops the free plan before button-text mapping and before render.
3. **Parent component + `.data` unwrap (D3)** — Item 13 + unresolved-identifiers entry: parent is `AccountBilling.tsx`; `useBillingPrices` at `:50`, `billingPrices = billingPricesData != undefined ? billingPricesData.data : []` at `:54` (`[]` fallback), prop passed at `:129-134`. The `billingPrices` prop is the `.data` field, not the raw payload. Marked resolved in unresolved-identifiers.
4. **Destructure rename (D4)** — Item 9 rewritten: `{ data: stripeCustomerSubscriptionData, isFetching: ... }` (`:56-61`); `currentSubscription = stripeCustomerSubscriptionData ? stripeCustomerSubscriptionData.subscription : null` (`:62-64`).
5. **onClick binding line + trackEvent (D5)** — Item 16: `handleOnClickSubscriptionAction` DEFINED at `PlanCard.tsx:98`, `onClick=` binding at `:208`; body first calls `trackEvent('plan_selected', ...)` at `:99`, then branches on `hasActiveSubscription` (`:100`), with the false branch → `onCreateNewSubscription()` (`:103`).
6. **Guarded array access (D6 / terminals D2-D3)** — Item 9: both `currentPriceObject` (`:67`) and `currentSubscriptionItemId` (`:136`) are `currentSubscription && currentSubscription.items.data[0]...`; guard added, feeds falsy SCREEN fallbacks.
7. **plansWithButtonText line precision (D7)** — Item 15: `plans` at `:175`; `plansWithButtonText` at `:177-193`; `...plan` spread at `:189`.
8. **isCurrentPlan derivation (D8 / terminals D4)** — Item 16: `const isCurrentPlan = currentSubscription?.plan?.id === plan.priceId` at `:436`, passed as prop at `:443`; named the load-bearing SCREEN gate for PlanCard's `:199` branch. PlanCard element span corrected to `:439-457` with props at `:443`/`:449`/`:455`.

## Routes + controller (round-2-routes-controller.md + terminals D1, D6)

9. **Unconditional `:608` Stripe retrieve (D1 both reviewers)** — Item 6 rewritten: `ap current_organization.stripe_subscription` (`:608`) invokes `Organization#stripe_subscription` → `Stripe::Subscription.retrieve` UNCONDITIONALLY before the nil-check; happy path calls `stripe_subscription` TWICE (`:608` + `:614`). STRIPE terminal added.
10. **customer_subscription rescue lines (terminals D6)** — Item 6: `rescue StandardError => e` at `:615`, `Sentry.capture_exception(e)` at `:616`, `Rails.logger.error(e)` at `:617`, render error at `:618`.
11. **determine_price_id invocation count (D2)** — Item 23: 8 controller call sites total (`:50,198,252,279,299,311,343,643`); 3× within `change_subscription_portal_session` (`:279`/`:299`/`:311`, each role named) + `:343` in the payment-method fork = 4× across the flow's actions.
12. **continue action redirect terminals (D3)** — Item 18b continue paragraph fully rewritten: all 5 guard/validation redirect terminals (`:392`, `:397`, `:411`, `:427`) + 2 rescue redirects (`:463`, `:469`), each a `redirect_to ...?error=` (NOT raise) — structural difference from `change_subscription_portal_session`'s raise-guards surfaced.
13. **continue return_url construction (D4)** — Item 18b: `return_url` http-prefix logic at `:403-407` with fallback `"#{Variables::AtsRootUrl}/hire/settings/billing"`; noted the two earliest guards (`:392`/`:397`) use RAW `params[:return_url]` computed before `return_url` is assigned.
14. **ap debug callpoints (D5)** — Item 22: `ap` at `:270` between authorize and guards; Item 27: `ap` at `:307-308` between Stripe create and Posthog.
15. **ValidateSubscriptionChange controller call site (D6)** — Item 24: anchored `billing_controller.rb:277-281` call site with `target_price_id: determine_price_id`; Item 25: `unless result.success?` (`:283`) → `render_general_errors` (`:284`) → `return` (`:285`).

## Model + services (round-2-model-services.md)

16. **5 context.fail! exits (LOW-1)** — Item 24: early guards `:23`/`:31`/`:40`, downgrade `:72`, rescues `:79`/`:82`. Note: the actual `context.fail!` calls inside the rescue blocks are at `:79` and `:82` (rescue keywords `:77`/`:80`).
17. **in_good_standing reachable callpoint (LOW-2)** — Item 24: the `'create'` branch (`:58`) reads `stripe_subscription_status` + `stripe_subscription_in_good_standing` → `organization.rb:673` → `SubscriptionStatusChecker#in_good_standing?` (`:90`); noted dead on the `'change'` path.
18. **subscription_nil: kwarg (LOW-3)** — Item 24 + price-model table: `assign_plan_name_from_lookup_key(lookup_key:, subscription_nil: false)` and `assign_plan_from_lookup_key(lookup_key:, subscription_nil: false)`.
19. **sync_with_stripe DB-write terminals (INFO)** — note after options block + unresolved-identifiers entry: `:573` plan assignment (only traced caller passing `subscription_nil` non-default), `:600` `update(changes_to_make)`, `:603-605` `PlanFeatureGate#monthly_ai_credit_allocation` (`plan_feature_gate.rb:134`) → `organization_ai_credit_balance.update_columns`. Kept the correct caveat that `change_subscription_portal_session` does NOT invoke it.

## Verification anchors confirmed in code
- `customer_subscription` `:606-620`; `change_subscription_portal_session` `:268-327`; `continue_change_subscription_portal_session` `:385-470`.
- `ValidateSubscriptionChange` `:6-84` (fail! at `:23,31,40,72,79,82`; comparison `:53`).
- `AccountBillingPlans.tsx` `:56-64,67,136,175-193,435-457`; `PlanCard.tsx` `:93-105,151,199-215`; `AccountBilling.tsx` `:50,54,129-134`.
- `organization.rb:520,573,600,603-606,678`; `subscription_status_checker.rb:90,113-119`; `plan_feature_gate.rb:134`.
