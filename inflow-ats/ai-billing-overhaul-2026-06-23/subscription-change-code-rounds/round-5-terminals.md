# Round 5 — TERMINALS segment (SCREEN / STRIPE / DATABASE)

Adversarial audit of OUR AI-credit subscription-change flow terminals vs the verified analog trace.
Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`.

Files traced (chain), each followed to its terminal (SCREEN render / Stripe call / DB read-write):
`OrganizationAiBilling.tsx → AiCreditSubscription.tsx → AiSubscriptionStatus.tsx / AiSubscriptionTierCard.tsx / aiSubscriptionHelpers.ts → planHelpers.ts (aiCreditPrices + AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY + AI_CREDIT_PACK_DISPLAY_NAMES) → useOrganizationAiCreditPurchase.ts → api.ts → config/routes.rb → organization_ai_credit_purchases_controller.rb → organization_ai_credit_purchase.rb (#stripe_subscription) → organization_ai_credit_purchase_serializer.rb`
vs `traces/subscription-change-analog-trace.md`
(analog chain `AccountBilling.tsx → AccountBillingPlans.tsx → PlanCard.tsx → planLookups.js → useBilling.ts → api.ts → billing_controller.rb → organization.rb#stripe_subscription`).

Both `SANCTIONED-subscription-change.md` and `AGENT-WHITELIST-subscription-change.md` re-read fresh this round.

## DEVIATION COUNT: 0

No unsanctioned terminal-level deviation found at the SCREEN, STRIPE, or DATABASE.

---

## Independent terminal trace this round — verdicts

### SCREEN (what renders for an ACTIVE subscription)

The symptom path ("active subscription does not display; analog derives display from the LIVE Stripe subscription, ours gated on a local `subscription_status` column") is traced to its terminal and is CORRECT — every display gate flows off the live Stripe object, none off a local column:

- `currentSubscription = aiCreditCustomerSubscriptionData ? aiCreditCustomerSubscriptionData.subscription : null` (`AiCreditSubscription.tsx:53-55`) — the LIVE Stripe object returned by `customer_subscription` (`organization_ai_credit_purchases_controller.rb:430` renders `organization_ai_credit_purchase.stripe_subscription`, the raw retrieved Stripe subscription, no serializer). MATCHES analog `currentSubscription = stripeCustomerSubscriptionData ? stripeCustomerSubscriptionData.subscription : null` (`AccountBillingPlans.tsx:62-64`).
- `isSubscribed = currentSubscription?.status === "active" || currentSubscription?.status === "past_due"` (`:59-60`) — reads the LIVE Stripe `status`, not a DB column. Drives the `AiSubscriptionStatus` `isSubscribed ? … : …` branch (`AiSubscriptionStatus.tsx:32-52`, SCREEN terminal: "Active subscription" / `{currentCredits?.toLocaleString()} credits / month` headline at `:34-35`), the cancel-button gate (`AiSubscriptionStatus.tsx:54`), and the subtitle ternary `{isSubscribed ? "Change your plan" : "Choose a credit subscription"}` (`AiCreditSubscription.tsx:283`). The `=== active || past_due` predicate tracks the sanctioned #4 row-scoping (the scoped subscription row is `active`/`past_due`); a live Stripe object is only present when that scoped row exists, so the recheck is redundant-but-consistent, NOT a relapse to local-column gating. Analog gates its render terminals on the live `currentSubscription` and derived flags (`AccountBillingPlans.tsx:370-396`, `:415`, `:424-431`); structural match.
- `currentPeriodEnd = currentSubscription?.currentPeriodEnd` (`:71`), `cancelAtPeriodEnd = currentSubscription?.cancelAtPeriodEnd` (`:72`), `cancelAt = currentSubscription?.cancelAt` (`:73`) — all off the LIVE object (camelCased by `allKeysToCamel`, `api.ts:22`). Feed `AiSubscriptionStatus` "Scheduled to cancel on {formatResetDate(cancelAt)}" / "Renews {formatResetDate(periodEndsAt)} · unused monthly credits roll over" (`AiSubscriptionStatus.tsx:36-44`, SCREEN terminals). Analog's analogous cancel/trial terminals (`AccountBillingPlans.tsx:370-396`) likewise read the live object.
- per-tier `isCurrent = currentSubscription?.plan?.id === tier.priceId` (`:287`) — LIVE Stripe `plan.id`, matching analog `isCurrentPlan = currentSubscription?.plan?.id === plan.priceId` (`AccountBillingPlans.tsx:436`). Drives the `Current plan` tag vs change `Styled.Button` branch (`AiSubscriptionTierCard.tsx:60-71`), the analog's `isCurrentPlan`-gated PlanCard branch (`PlanCard.tsx:199`).
- change button `loading={isLoadingButton}` ← `isFetchingAiCreditCustomerSubscription` (`:300`), `disabled={isLoading}` ← combined mutation flags (`:299`) — matches analog PlanCard `loading`/`disabled` wiring (`PlanCard.tsx:209-210`).
- loading early-return `<LoadingIndicator label="Loading..." />` on `isFetchingAiCreditCustomerSubscription` (`:267-269`) — matches analog early-return (`AccountBillingPlans.tsx:352-354`).
- `currentCredits` headline value sourced from the LOCAL `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` table (`AiCreditSubscription.tsx:66-70` → `planHelpers.ts:74-87/:115`) — WHITELIST W4 (AI-credit per-period allocation is not carried on the Stripe price object); NOT flagged.

### STRIPE (each Stripe:: call + args on the subscription-change flow)

- `OrganizationAiCreditPurchase#stripe_subscription` (`organization_ai_credit_purchase.rb:260-264`): guard `return if stripe_subscription_id.nil?` → `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`. Byte-for-byte match to analog `Organization#stripe_subscription` (`organization.rb:475/:477`).
- `customer_subscription` double-invokes `stripe_subscription` (`ap` debug `:424`, then render `:430`) on the happy path — matches the analog double-call (`billing_controller.rb:608` + `:614`). The `&.` guard at `:424` is the sanctioned #4 row-scoping; it does not change the call count.
- `change_subscription_portal_session` options block (`:245-259`): `Stripe::BillingPortal::Session.create` with `flow_data.type = 'subscription_update_confirm'`, `subscription: organization_ai_credit_purchase.stripe_subscription_id` (SANCTIONED #1), `items: [{ id: subscription_item_id, price: determine_price_id, quantity: 1 }]`, top-level `return_url`. Matches analog options shape (`billing_controller.rb:290-306`); `subscription` source is the sanctioned row column.
- `update_payment_method_and_subscription_portal_session` (`:309-321`): `payment_method_update` flow with `after_completion.redirect.return_url: continue_url` and top-level `return_url: final_return_url`. Matches analog (`billing_controller.rb:351-363`). `continue_url` points at `/api/v1/ai_credit_purchases/...` — WHITELIST W2.
- `continue_change_subscription_portal_session` (`:381-397`): `subscription_update_confirm` confirmation session reading `params[:subscription_item_id]`/`params[:target_price_id]` (`:361-362`, NOT `determine_price_id`), `subscription: organization_ai_credit_purchase.stripe_subscription_id`. Matches analog (`billing_controller.rb:400-401/:403-452`).
- `prices` (`:219`): `Stripe::Price.list(lookup_keys: …, active: true, expand: ['data.tiers'])` — `expand` matches analog `prices` (`billing_controller.rb:537`); `lookup_keys:` domain filter is sanctioned #5 family.
- rescue-Sentry asymmetry preserved: `change_subscription_portal_session` StandardError rescue WITHOUT Sentry (`:278-280`) ↔ analog `:324-326`; `update_payment_method_*` StandardError rescue WITH Sentry (`:334-337`) ↔ analog `:376-377`.
- `determine_price_id` (`:448-454`): keeps analog `params.key?(:price_id)` guard; else-branch raises — WHITELIST W1. Called 2× in `change_subscription_portal_session` (options `:254`, PosthogTrackJob `:265`) vs analog 3× — the dropped 3rd was the removed `ValidateSubscriptionChange` arg (SANCTIONED #3).

### DATABASE (each read/write on the subscription-change flow)

- `customer_subscription` / `change_subscription_portal_session` / `update_payment_method_and_subscription_portal_session` / `continue_change_subscription_portal_session` all READ the scoped subscription row via `current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])` (`:423`, `:237`, `:290`, `:348`) — SANCTIONED #2/#4. No other DB read on the path beyond the `current_user.id`/`current_organization` framework reads.
- NO DB WRITE in any of the four subscription-change actions — matches the analog note "no DB record is written in this action; the change is confirmed inside the Stripe-hosted portal; `sync_with_stripe` runs later on the user's return." OURS' DB-write terminal (the credit-pack equivalent of `sync_with_stripe`) lives in the webhook/sync path, outside the four audited actions, exactly as the analog.
- `customer_subscription` null-branch gate `organization_ai_credit_purchase.nil? || organization_ai_credit_purchase.stripe_subscription_id.nil?` (`:426`) → `render json: { subscription: nil }` else raw live object — matches analog `stripe_subscription_id.nil?` branch (`billing_controller.rb:609/:611/:614`); the row-nil disjunct is the sanctioned #4 row-scoping.

---

## Sanctioned / whitelisted and therefore NOT flagged (re-verified against both lists this round)

- All four change/continue/customer_subscription actions scoped to the `OrganizationAiCreditPurchase` subscription row via `find_by(subscription_status: [:active, :past_due])` — SANCTIONED #2/#4.
- `flow_data.subscription` = `organization_ai_credit_purchase.stripe_subscription_id` (change `:251` + continue `:387`) — SANCTIONED #1.
- No `ValidateSubscriptionChange` / job-limit gate; `determine_price_id` 2× in change vs analog 3× — SANCTIONED #3.
- `ai_credit_*` naming, `ap` debug-string text changes — SANCTIONED #5.
- `determine_price_id` else-branch raising (`:452`) — WHITELIST W1.
- `continue_url` → `/api/v1/ai_credit_purchases/...` (`:304`) — WHITELIST W2.
- `#show` action rendering the persisted row (`:4-13`) — different view, not on this SCREEN path — WHITELIST W3.
- Local `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` credits table feeding the active-subscription credits headline — WHITELIST W4.
- `AiCreditSubscription` rendered unconditionally (`OrganizationAiBilling.tsx:30`) + single dual-mode component (no free-trial/unsubscribed siblings), `isSubscribed` derived from the LIVE Stripe object — WHITELIST W5.

No terminal deviation outside the sanctioned/whitelisted set.
