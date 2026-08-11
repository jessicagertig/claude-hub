# Round 4 — TERMINALS segment (SCREEN / STRIPE / DATABASE)

Adversarial audit of OUR AI-credit subscription-change flow terminals vs the verified analog trace.
Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Files traced (chain):
`OrganizationAiBilling.tsx → AiCreditSubscription.tsx → AiSubscriptionStatus.tsx / AiSubscriptionTierCard.tsx / aiSubscriptionHelpers.ts → planHelpers.ts (aiCreditPrices + AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY) → useOrganizationAiCreditPurchase.ts → api.ts → config/routes.rb → organization_ai_credit_purchases_controller.rb → organization_ai_credit_purchase.rb (#stripe_subscription) → organization_ai_credit_purchase_serializer.rb`
vs `traces/subscription-change-analog-trace.md`
(analog chain `AccountBilling.tsx → AccountBillingPlans.tsx → PlanCard.tsx → planLookups.js → useBilling.ts → api.ts → billing_controller.rb → organization.rb#stripe_subscription`).

Both `SANCTIONED-subscription-change.md` and `AGENT-WHITELIST-subscription-change.md` re-read this round.

## DEVIATION COUNT: 0

No unsanctioned terminal-level deviation found at the SCREEN, STRIPE, or DATABASE.

---

## Prior-round terminal findings — disposition this round

- **Round-3 D1** (current-subscription credits sourced from the LOCAL `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` table, not the live Stripe price object) — now WHITELISTED as **W4**. The credits headline `{currentCredits?.toLocaleString()} credits / month` (`AiSubscriptionStatus.tsx:35`) still terminates on `currentCredits` (`AiCreditSubscription.tsx:70`) resolved via `subscriptionTiers.find(tier.lookupKey === currentPlanLookupKey)` (`:66-68`) whose `credits` is injected from the local table (`planHelpers.ts:74-87`, injected `:115`). W4 explains: AI-credit per-period allocation is AI-domain metadata not carried on the Stripe price object, so no live-Stripe source exists. NOT flagged.
- **Round-3 D2** (`AiCreditSubscription` rendered UNCONDITIONALLY in `OrganizationAiBilling.tsx:30`; subscribed/unsubscribed fork relocated into the single dual-mode component vs the analog's parent 3-way `hasActiveSubscription` ternary) — now WHITELISTED as **W5**. `isSubscribed` is derived from the LIVE Stripe object (`AiCreditSubscription.tsx:59-60`, the exact terminal whose column-gated mismatch produced the original symptom — now correct). NOT flagged.
- **Round-3 D3** (`prices` Stripe call expanded `['data.product']`, an unused expand with no consumer/analog basis) — RESOLVED. Current code expands `['data.tiers']` (`organization_ai_credit_purchases_controller.rb:219`), matching the analog's `prices` expand; the `lookup_keys:` domain filter is sanctioned (#5 family). No remaining divergence.

---

## Sanctioned / whitelisted and therefore NOT flagged (verified against both lists this round)

- All change/continue/customer_subscription endpoints scoped to the `OrganizationAiCreditPurchase` subscription row via `find_by(subscription_status: [:active, :past_due])` instead of `current_organization.stripe_subscription_id` — SANCTIONED #2/#4.
- `flow_data.subscription` = `organization_ai_credit_purchase.stripe_subscription_id` (change `:251` + continue `:387`) — SANCTIONED #1.
- No `ValidateSubscriptionChange` / job-limit gate in change/continue actions; `determine_price_id` called 2× in `change_subscription_portal_session` (options `:254`, PosthogTrackJob `:265`) rather than the analog's 3× (the 3rd was the removed ValidateSubscriptionChange call) — SANCTIONED #3.
- `ai_credit_*` naming, `ap` debug-string text changes — SANCTIONED #5.
- `determine_price_id` else-branch raising `'Price ID is missing.'` (`:452`) — WHITELIST W1.
- `continue_url` pointing at `/api/v1/ai_credit_purchases/...` (`:304`) — WHITELIST W2.
- `#show` action rendering the persisted row (`:4-13`) — consumed by a different view, not on this SCREEN path — WHITELIST W3.
- Local `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` credits table — WHITELIST W4.
- Unconditional render + single dual-mode component (no free-trial/unsubscribed siblings) — WHITELIST W5.

---

## Verified MATCHES at the terminals this round (no deviation)

- **STRIPE**: `OrganizationAiCreditPurchase#stripe_subscription` → `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` (`organization_ai_credit_purchase.rb:263`) matches analog `Organization#stripe_subscription` (`organization.rb:477`) byte-for-byte (same `expand` path, same nil guard).
- **STRIPE**: `customer_subscription` double-invokes `stripe_subscription` (once at `ap` debug `:424`, once in the render branch `:430`) exactly as the analog double-call structure (`billing_controller.rb:608` + `:614`); the `&.` guard (forced by SANCTIONED #4 row-scoping) does not change the call count on the happy path.
- **STRIPE**: `change_subscription_portal_session` `flow_data.subscription_update_confirm` options (`:245-259`) match the analog options shape verbatim (`type`, `subscription`, `items:[{id, price, quantity:1}]`). `update_payment_method_and_subscription_portal_session` builds the `payment_method_update` flow with `after_completion.redirect.return_url: continue_url` (`:309-319`) matching the analog shape (`billing_controller.rb:351-361`). `continue_change_subscription_portal_session` builds the `subscription_update_confirm` confirmation session reading `params[:subscription_item_id]`/`params[:target_price_id]` (`:361-362`, NOT `determine_price_id`), matching the analog (`billing_controller.rb:400-401`).
- **STRIPE**: rescue-Sentry asymmetry preserved — `change_subscription_portal_session` StandardError rescue WITHOUT Sentry (`:278-280`) matches analog `:324`; `update_payment_method_*` StandardError rescue WITH Sentry (`:334-337`) matches analog `:376`.
- **STRIPE**: `prices` expand `['data.tiers']` (`:219`) matches the analog `prices` expand (`billing_controller.rb:537`); `lookup_keys:` filter is the sanctioned domain scoping.
- **DATABASE**: change + continue + customer_subscription actions write NO DB record (matches analog note "no DB record is written in this action"; the Stripe-hosted portal confirms, sync runs later on return).
- **DATABASE**: `customer_subscription` branches on `organization_ai_credit_purchase.nil? || organization_ai_credit_purchase.stripe_subscription_id.nil?` (`:426`) → `render json: { subscription: nil }` (null branch) vs `render json: { subscription: organization_ai_credit_purchase.stripe_subscription }` (raw live Stripe object, no serializer) — matches the analog `stripe_subscription_id.nil?` branch (`billing_controller.rb:609/:611/:614`); the row-nil disjunct is the sanctioned #4 row-scoping.
- **SCREEN**: per-tier `isCurrent = currentSubscription?.plan?.id === tier.priceId` (`AiCreditSubscription.tsx:287`) reads the LIVE Stripe object exactly as analog `isCurrentPlan` (`AccountBillingPlans.tsx:436`).
- **SCREEN**: `isSubscribed`, `currentPriceObject`, `currentPlanLookupKey`, `currentPeriodEnd`, `cancelAtPeriodEnd`, `cancelAt`, `currentSubscriptionItemId` all derive from the LIVE Stripe `currentSubscription` object (`AiCreditSubscription.tsx:53-73`), matching the analog principle (display derived from the live Stripe subscription, not a local `subscription_status` column). The original "active subscription does not display" symptom — local-column gating — is not present: every render gate (`AiSubscriptionStatus` `isSubscribed ? … : …`, subtitle ternary `:283`, cancel-button gate) flows off the live object.
- **SCREEN**: the change `Styled.Button` (`AiSubscriptionTierCard.tsx:63-70`, `loading={isLoadingButton}` ← `isFetchingAiCreditCustomerSubscription`, `disabled={isLoading}` ← combined mutation loading flags) mirrors the analog PlanCard change button's `loading`/`disabled` wiring (`PlanCard.tsx:209-210`); the `isCurrentPlan` branch renders a `Current plan` tag in place of the change button (analog renders `ManageBillingActions` in the same branch — relocated to `AiSubscriptionStatus`'s cancel control per W5).
- **SCREEN**: loading early-return `<LoadingIndicator label="Loading..." />` gated on `isFetchingAiCreditCustomerSubscription` (`AiCreditSubscription.tsx:267-269`) matches the analog early-return loading terminal (`AccountBillingPlans.tsx:352-354`).
