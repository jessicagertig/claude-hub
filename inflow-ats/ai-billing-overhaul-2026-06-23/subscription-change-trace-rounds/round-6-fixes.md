# Round 6 — Fix Log (subscription-change analog trace)

All 9 findings verified against `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza` and corrected in `traces/subscription-change-analog-trace.md`. Analog-only; no "ours" content introduced; no code touched.

## D1 — `currentPlanBillingPeriod` is not a SCREEN terminal (item 9)
Verified `PlanCard.tsx`: prop destructured at `:80`, used ONLY in `window.logger` debug-object literal (`:157`), never rendered in JSX. Trace now labels it a DEBUG terminal, not SCREEN.

## D2 — `currentPlanLookupKey` is not a SCREEN terminal (item 9)
Verified: destructured `PlanCard.tsx:79`, reaches only `trackEvent('plan_selected', ...)` PostHog (`:99`, ANALYTICS) and `window.logger` (`:156`, DEBUG). Noted that the current-plan lookup_key DOES reach the SCREEN, but via the separate `getPlanButtonText(currentPriceObject.lookupKey, ...)` path (`:181`, item 15), not this prop.

## D3 — `subscriptionItemId` is a DEAD PROP (item 9)
Verified: declared in `PlanCardProps` (`PlanCard.tsx:71`), never destructured (absent from `:75-89`), never referenced in body. Trace now states the prop reaches no terminal; the backend item-id is the closure-captured `currentSubscriptionItemId` read inside `handleChangeSubscriptionWithGate` (`AccountBillingPlans.tsx:329`/`:334`), not routed through PlanCard.

## D4 — `isCurrentPlan` has more SCREEN terminals than the button branch (item 9)
Verified: via `showCurrentPlanBadge = isCurrentPlan || isFreePlan` (`PlanCard.tsx:160`) it gates the `Current plan` SavingsBadge (`:167`), the savings Tooltip (`:168-176`), and the `Save $X/year` badge (`:177-179`), in addition to the `ManageBillingActions`-vs-`Styled.Button` branch (`:199`). All four enumerated.

## D5 — `plan.price` thread stopped two hops short of SCREEN (item 14)
Verified: `price` (`planLookups.js:564`) → `displayPrice` (`PlanCard.tsx:90`) and `savings` (`:91`) → rendered at `${displayPrice}` (`:183`), `You are saving ${savings} per year` (`:170`), `Save ${savings}/year` (`:178`). Trace now traces to the actual SCREEN terminals.

## D6 — omitted `window.logger` in both change-hook onSuccess callbacks (items 18 / 18b)
Verified: `useChangeSubscriptionViaStripePortal` onSuccess emits `window.logger` at `useBilling.ts:185-188` before `invalidateQueries` (`:189`); `useUpdateWithPaymentMethod` onSuccess emits `window.logger` at `:198-201` before `invalidateQueries` (`:202`). Both logger statements added as DEBUG terminals.

## prices? policy not traced to terminal (item 6 / item 13)
Verified `BillingPolicy#prices?` (`billing_policy.rb:4-6`) returns `is_org_user?` (`application_policy.rb:54-56`), NOT `is_org_admin?`. Item 6 rewritten as a THREE-WAY gating asymmetry: no-authorize (customer_subscription `:606`, continue `:385`); org-USER (prices `:535`); org-ADMIN (the two change actions). Item 13 now resolves `:prices?` → `is_org_user?`.

## omitted Rails.logger.error on third guard (item 18b)
Verified `continue_change_subscription_portal_session` third guard (`:409`) emits `Rails.logger.error 'Missing required parameters: subscription_item_id or target_price_id'` (`:410`) before the `:411` redirect. Added to match the `:391`/`:396` loggers on the first two guards.

## price-model table determine_lookup_key citation (price model table)
Verified: `:663` is only the `def` line; actual read is `product_info[:price][:lookup_key]` at `:667` (off `product_info[:price]`, not a bare `price` local); the Stripe read is `Stripe::Price.retrieve({ id:, expand: ['product'] })` at `:652` returning `{ product:, price: }` (`:657-660`). Table row corrected with full chain (`:663`/`:642`/`:630`/`:649`/`:652`/`:667`) and flagged as a REFERENCE chain, NOT on the `change_subscription_portal_session` happy path.
