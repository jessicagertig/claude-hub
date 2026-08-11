# Round 8 — TERMINALS segment (SCREEN / STRIPE / DATABASE)

Adversarial audit of OUR AI-credit subscription-change flow vs the verified ANALOG trace
(`traces/subscription-change-analog-trace.md`), restricted to the three terminals: what renders for
an ACTIVE subscription (SCREEN), each `Stripe::` call + args (STRIPE), each DB read/write (DATABASE).
Sanctioned deviations (`SANCTIONED-subscription-change.md` #1-5) and the agent whitelist
(`AGENT-WHITELIST-subscription-change.md` W1-W5) were read fresh and excluded by substance.

## Chains traced (terminal by terminal)

SCREEN (active-subscription display), data feed → render:
`OrganizationAiBilling.tsx → AiCreditSubscription.tsx → AiSubscriptionStatus.tsx → AiSubscriptionTierCard.tsx`
helpers: `aiSubscriptionHelpers.ts → planHelpers.ts`
fetch transport: `AiCreditSubscription.tsx → useOrganizationAiCreditPurchase.ts (useAiCreditCustomerSubscription / useOrganizationAiCreditPurchasePrices) → api.ts → config/routes.rb → organization_ai_credit_purchases_controller.rb`

STRIPE / DATABASE:
`organization_ai_credit_purchases_controller.rb (#customer_subscription / #change_subscription_portal_session / #update_payment_method_and_subscription_portal_session / #continue_change_subscription_portal_session / #prices) → organization_ai_credit_purchase.rb (#stripe_subscription) → Stripe gem boundary`
`config/routes.rb:190-202` (collection block) confirms every action above is routed.

## Symptom verification (core of this round) — RESOLVED at all three terminals

Symptom: "active subscription does NOT display; analog derives display from the live Stripe
subscription, ours gates on a local subscription_status column."

- SCREEN: `isSubscribed` is derived from the LIVE Stripe object's status —
  `currentSubscription?.status === "active" || currentSubscription?.status === "past_due"`
  (`AiCreditSubscription.tsx:59-60`), where
  `currentSubscription = aiCreditCustomerSubscriptionData ? aiCreditCustomerSubscriptionData.subscription : null`
  (`:53-55`). Grep of the accountPlatoAi views + the hook + parent for `subscriptionStatus` /
  `subscription_status` returns ZERO SCREEN-path hits — no read of the local `subscription_status`
  column remains on the audited path. (The single-boolean `isSubscribed` vs the analog's per-flag
  derivation is W5.)
- STRIPE: `#customer_subscription` renders `organization_ai_credit_purchase.stripe_subscription`
  (the LIVE Stripe object). `OrganizationAiCreditPurchase#stripe_subscription`
  (`organization_ai_credit_purchase.rb:260-264`) is character-identical to the analog's
  `Organization#stripe_subscription` (`organization.rb:474-478`):
  `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`
  with guard `return if stripe_subscription_id.nil?`. Purchase-row scoping is SANCTIONED #4.
- DATABASE: the change/portal/customer-subscription actions perform no DB write; the only reads are
  the sanctioned purchase-row lookups
  (`current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])`).
  Matches the analog (no write in the action) modulo SANCTIONED #1/#2/#4.

## Round 7 residuals — both confirmed FIXED in current code

- D1 (`#prices` authorize method): now `authorize :organization_ai_credit_purchase, :prices?`
  (`organization_ai_credit_purchases_controller.rb:217`) — dedicated `prices?` method matching the
  analog's `BillingController#prices` → `:prices?` structure. RESOLVED.
- D2 (`#prices` Stripe::Price.list): now carries `limit: 20`
  (`organization_ai_credit_purchases_controller.rb:219`) matching the analog's bounded list. RESOLVED.

## Terminals confirmed MATCHING (no deviation) — re-verified identifier by identifier this round

- `#customer_subscription` body (`:420-437`): `ap` debug → unconditional `ap …&.stripe_subscription`
  (`:424`, the `&.` is forced by the nullable purchase row, SANCTIONED #4; analog `:608` uses bare
  `current_organization.stripe_subscription` because the org is always present) → nil-branch
  `render json: { subscription: nil }` (`:427`) → else `begin` render LIVE object (`:430`, calls
  `stripe_subscription` a 2nd time, matching the analog's twice-call) → `rescue StandardError` Sentry
  + logger + `{ errors: ['Unable to load subscription'] }` (`:431-435`). Matches analog `:606-618`.
  The branch predicate adds `organization_ai_credit_purchase.nil? ||` ahead of the analog's
  `stripe_subscription_id.nil?` — forced by the nullable purchase row (SANCTIONED #4). NO `authorize`
  in either (matches).
- `#change_subscription_portal_session`: `authorize :billing, :change_subscription?` (org-ADMIN)
  matches; guards (customer_id / `organization_ai_credit_purchase&.stripe_subscription_id` /
  `params[:subscription_item_id]`) match analog `:272-274` modulo SANCTIONED #1/#2/#4;
  `flow_data.subscription = organization_ai_credit_purchase.stripe_subscription_id` is SANCTIONED #1;
  `Stripe::BillingPortal::Session.create(options)` (`:261`) + `PosthogTrackJob.perform_later`
  (`:265`) + `render json: { redirectUrl: session.url }` (`:267`) match; absence of
  `ValidateSubscriptionChange` is SANCTIONED #3. No DB write (matches analog).
- `#update_payment_method_and_subscription_portal_session` (`:286-338`): `payment_method_update`
  portal options with `after_completion.redirect.return_url: continue_url` (`:315`) and top-level
  `return_url: final_return_url` (`:318`); `Stripe::BillingPortal::Session.create` (`:321`);
  `render json: { redirectUrl: session.url }` (`:325`). `continue_url` base path is W2;
  `determine_price_id` raise-else is W1; purchase-row scoping SANCTIONED #4. Matches analog `:331-380`.
- `#continue_change_subscription_portal_session` (`:345-415`): redirect-style guards (RAW
  `params[:return_url]` on the first two blank guards `:353`/`:358`, computed `return_url` after),
  `subscription_update_confirm` portal session, `redirect_to session.url` (`:402`) happy terminal,
  Stripe + StandardError rescues redirecting `?error=subscription_update_failed`. Removal of
  `ValidateSubscriptionChange` is SANCTIONED #3; purchase-row scoping SANCTIONED #4. Matches analog
  `:385-470` structure modulo the sanctioned gate removal.
- `#prices` (`:216-226`): `Stripe::Price.list(lookup_keys: …ai_credit_lookup_keys, active: true,
  limit: 20, expand: ['data.tiers'])` → `render json: price_list`. `lookup_keys:` scoping is W4 /
  SANCTIONED #5 family; everything else matches analog `:535-540`.
- SCREEN `currentSubscription` field reads — all LIVE-Stripe-object reads (post-`allKeysToCamel`):
  `items.data[0].id` (`:56`), `items.data[0].price` (`:57`), `price.lookupKey` (`:58`),
  `status` (`:60`), `currentPeriodEnd` (`:71`), `cancelAtPeriodEnd` (`:72`), `cancelAt` (`:73`),
  `plan?.id` (`:311`). Match the analog's live-object reads (item 9/26). `isCurrentPlan =
  currentSubscription?.plan?.id === tier.priceId` (`:311`) matches analog `:436`.
- SCREEN loading flag `isFetchingAiCreditCustomerSubscription` has TWO terminals — early-return
  `<LoadingIndicator label="Loading..." />` (`:291-293`) AND `isLoadingButton=` on the tier card
  (`:324` → `AiSubscriptionTierCard.tsx:75` `loading={isLoadingButton}`). Matches the analog's
  two-terminal `isFetchingStripeCustomerSubscription` (item 9 / item 16).
- SCREEN active headline `{currentCredits?.toLocaleString()} credits / month`
  (`AiSubscriptionStatus.tsx:35`) sourcing `currentCredits` (`AiCreditSubscription.tsx:66-70`) from
  the local `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` table (`planHelpers.ts:74-87`) is W4.
- SCREEN subscribed/unsubscribed fork inside `AiSubscriptionStatus` (`:32-52`) + the cancel action
  relocated there (`:54-58`) instead of the analog's parent 3-way `hasActiveSubscription` ternary and
  `ManageBillingActions` is W5. `AiCreditSubscription` rendered unconditionally from
  `OrganizationAiBilling.tsx:30` is W5. The tier card's `isCurrentPlan ? <CurrentTag> : <Button>`
  branch (`AiSubscriptionTierCard.tsx:70-81`) — vs the analog's `isCurrentPlan || isFreePlan ?
  <ManageBillingActions> : <Button>` (`PlanCard.tsx:199`) — is the same W5 product simplification
  (no free-plan branch, no `ManageBillingActions` sibling; manage/cancel lives in AiSubscriptionStatus).
- `deriveTierButtonText` (`aiSubscriptionHelpers.ts:30-37`): `"Subscribe"` gated on `!isSubscribed`
  ALONE, subscribed lookup-miss falls through to `"Change plan"` — matches the analog's state-only
  unsubscribed gate + `!currentPlan → "Change plan"` fallback (Round 7 D1 fix holds).
- `#show` action + `OrganizationAiCreditPurchaseSerializer` render of the persisted row (incl. the
  `subscription_status` attribute) is W3 — outside the audited SCREEN path
  (`AiCreditSubscription.tsx` does not import `useOrganizationAiCreditPurchase`; it reads the live
  `customer_subscription` payload only).

## Result

Zero non-sanctioned, non-whitelisted deviations remain at the SCREEN / STRIPE / DATABASE terminals.
Every terminal identifier was traced to its terminal state (SCREEN render, `Stripe::` call, DB
read/write, or framework/gem boundary) and matches the analog or a sanctioned/whitelisted entry.
The reported symptom is resolved on the live-Stripe path. Round 7's two residuals are confirmed
fixed. No new whitelist entries warranted.

deviation_count: 0
