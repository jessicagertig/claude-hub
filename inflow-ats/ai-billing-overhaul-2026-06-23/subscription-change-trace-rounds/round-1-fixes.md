# Round 1 — Fix log: subscription-change-analog-trace.md

All 39 findings verified against the analog code in `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza` and corrected in `traces/subscription-change-analog-trace.md`. Analog-only; no "ours" content introduced. No code touched.

## Skeleton section (frontend → Stripe chain)

- **Plan-limits gate added** (D1/agent3 D1, D7): item 17 now documents `handleChangeSubscriptionWithGate` calling `checkPlanLimitsGate(plan.lookupKey)` from `usePlanLimitsGate` (imported AccountBillingPlans.tsx:35), branching on `result.shouldProceed`; false branch fires `trackEvent` (:339) + `openModal(<PlanChangeBlockedModal/>)` (:340-348). Added to Unresolved identifiers too.
- **Payment-method fork added** (D2, agent3 D7): item 17 forks on `currentOrganization.stripeDefaultPaymentMethodOnFile` (:326); false branch → `handleUpdateWithPaymentMethod` → `useUpdateWithPaymentMethod` → `updateWithPaymentMethod` → `apiPost('/billing/update_payment_method_and_subscription_portal_session')` (useBilling.ts:61-74; route routes.rb:170). Full alternate path documented as item 18b including the `continue_change_subscription_portal_session` return leg.
- **PlanCard.tsx added** (D3): item 16 now threads the SCREEN render — `<PlanCard onChangeSubscription=.../>` (AccountBillingPlans.tsx:435-457) → button `Styled.Button` (PlanCard.tsx:207-214, with `loading`/`disabled`) → `onClick=handleOnClickSubscriptionAction` (:98) → `handleChangeSubscription` (:101) → `onChangeSubscription(plan)` (:95).
- **getPlansForPeriod match line** (D4, agent3 D6): corrected match expression line from :553 to :560 (:553 is signature). Item 14 + price-model table.
- **priceId fallback** (D5, agent3 D6): corrected `priceId = priceData.id` → `priceId: priceData?.id || null` (:568); added `price: priceData ? priceData.unitAmount/100 : 0` (:564, `:0` fallback). Item 14 + price-model table.
- **getPlansForPeriod pre-filters** (D6): added `planConfigs` period filter (:554) and `planDataMatches` interval filter (:555-557); match runs over `planDataMatches`. Item 14.
- **handleChangeSubscriptionViaStripePortal signature** (D7): item 18 now states explicit input params `{ priceId, subscriptionItemId }` (AccountBillingPlans.tsx:283-289), returnUrl added at :294.
- **Success/error terminals** (D8, agent3 D8): item 18 — `useChangeSubscriptionViaStripePortal` onSuccess invalidates `['currentOrganization']` (useBilling.ts:189); component onSuccess → `window.location.href = data.redirectUrl` (:303); onError → `error?.data?.errors?.general?.[0]` + `addToast({kind:'error'})` (:305-314).
- **Loading terminal** (D9): item 9 — `{ data, isFetching: isFetchingStripeCustomerSubscription }` (:56-61) gates early-return `<LoadingIndicator/>` (:352-354).
- **plan alias table value/key inversion** (D10): price-model table corrected — `value` = full internal name surfaced as `plan.lookupKey` (e.g. `plan_ats_tier_starter_v2`), `key` = short substring matched against Stripe (e.g. `starter_v2`).
- **apiMutate transport** (D11, agent3 D9): item 4 + new transport paragraph + Unresolved entry — `apiPost` (api.ts:25-28) delegates to `apiMutate` (:40-68); CSRF `Rails.csrfToken()` (:50), `allKeysToSnake` (:52), `allKeysToCamel` responses (:67) / errors (:56), `apiGet` camel at :22. Removed mis-attribution of `allKeysToSnake` to `apiPost`.

## Backend controller section (agent2 D1-D12)

- **determine_price_id guard** (D1): `params.key?(:price_id)` (key-existence, :631), not ".present?/when present". Item 23.
- **determine_price_id else-branch return type** (D2): returns a `Stripe::Price` OBJECT (`prices.data.find {...}`), inconsistent with the if-branch String. Item 23.
- **determine_price_id second Stripe read** (D3): `Stripe::Price.list({ limit: 10 })` (:634), distinct from prices' limit 20. Item 23.
- **prices authorize** (D4): `authorize :billing, :prices?` (:536) added. Item 13.
- **prices line citations** (D5): Stripe call corrected to :537; `render json: price_list` terminal at :540. Item 13 + price-model table.
- **customer_subscription branching** (D6, agent4 D3): nil-branch `{ subscription: nil }` (:611), happy `{ subscription: stripe_subscription }` (:614), rescue `{ errors: [...] }` + Sentry (:618). Item 6.
- **customer_subscription no authorize** (D7): documented gating asymmetry. Item 6.
- **update_payment_method action** (D8): documented (route :170, continue_url with determine_price_id :343). Item 18b.
- **continue_change action** (D9): documented (GET route :178, no authorize, `params[:target_price_id]` not determine_price_id, terminal `redirect_to session.url` :457). Item 18b.
- **change_subscription UNUSED action** (D10): added to sibling-actions list (POST :168, Stripe::Subscription.cancel :241 + create :258).
- **rescue line off-by-one** (D11): corrected to keyword lines :314 / :320 / :324 (bodies follow). Item 30.
- **flow_data block range** (D12): relabeled options hash :290-304 (Session.create at :306); inline comments :298/:300 included in the verbatim quote.

## Schema + service section (agent2 DISC, agent4)

- **organizations.plan schema line** (DISC-1, agent4 D2): corrected db/schema.rb:1048 → :1052. Item 8-adjacent / price-model table.
- **stripe_subscription_id schema line** (agent4 D1): corrected :1052 → :1056. Item 8.
- **assign_plan_from_lookup_key terminals** (DISC-2, DISC-5): all three terminals documented — `'plan_simple_ats_free'` (:114), `@organization.plan` (lookup_key nil, :115), find at :117 with `|key|` var, no-match `@organization.plan` fallback (:118). Item 24 + price-model table.
- **all_plan_rules OpenStruct hop** (DISC-3): item 24 + price-model table — `new(OpenStruct.new(plan: nil, stripe_subscription_in_good_standing: true)).send(:plan_rules)` (:73) via `initialize` (:25-28).
- **ValidateSubscriptionChange Organization reads** (DISC-4): the 'create'-branch reads (`stripe_subscription_status`, `stripe_subscription_in_good_standing`, :58) are off the 'change' happy path; noted via the create/change action_type distinction. (Path under trace is `action_type: 'change'`.)
- **Organization#stripe_subscription lines** (agent4 D4): def :474, guard :475, `Stripe::Subscription.retrieve` STRIPE terminal :477. Item 7.
- **PosthogTrackJob DB read** (agent4 D10): `User.find_by(id: user_id)` (posthog_track_job.rb:7, users-table read gating the track). Item 28.
- **ValidateSubscriptionChange jobs DB terminal** (agent4 D11): `organization.jobs.where(status: 'published').count` (:42) labeled DATABASE terminal (`jobs` table, `status` column). Item 24.

## Notes

- DISC-4: the trace's traced path is `action_type: 'change'`; the `'create'`-branch Organization reads at validate_subscription_change.rb:58 are on the non-traced create branch. Flagged the create/change fork rather than adding the create-branch reads to the change happy-path map, to avoid implying the change path reads them.
