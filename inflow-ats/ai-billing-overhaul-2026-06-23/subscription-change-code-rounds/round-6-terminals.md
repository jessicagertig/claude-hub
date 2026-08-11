# Round 6 — TERMINALS segment (SCREEN / STRIPE / DATABASE)

Adversarial audit of OUR AI-credit subscription-change flow against the verified analog trace
(`traces/subscription-change-analog-trace.md`), for the three terminal classes in this segment:
the SCREEN (what renders for an ACTIVE subscription), every STRIPE:: call + args, and every
DATABASE read/write. Sanctioned deviations (`SANCTIONED-subscription-change.md` #1–#5 and
`AGENT-WHITELIST-subscription-change.md` W1–W5) are excluded by substance.

## Files traced (chains)

SCREEN chain:
`OrganizationAiBilling.tsx` → `AiCreditSubscription.tsx` → `AiSubscriptionStatus.tsx` /
`AiSubscriptionTierCard.tsx` → `aiSubscriptionHelpers.ts` → `planHelpers.ts`
→ `useOrganizationAiCreditPurchase.ts` → `api.ts`

STRIPE / DATABASE chain:
`organization_ai_credit_purchases_controller.rb` (`#customer_subscription`,
`#change_subscription_portal_session`, `#update_payment_method_and_subscription_portal_session`,
`#continue_change_subscription_portal_session`) → `organization_ai_credit_purchase.rb`
(`#stripe_subscription`) → `Stripe::Subscription.retrieve` / `Stripe::BillingPortal::Session.create`
→ `organization_ai_credit_purchase_serializer.rb`

---

## Terminal-by-terminal comparison

### SCREEN: active-subscription display gate (the symptom)

ANALOG (trace item 6/9/16): the current-subscription display derives from the LIVE Stripe object —
`customer_subscription` renders `current_organization.stripe_subscription` (raw live Stripe object,
no serializer; `billing_controller.rb:614`); `currentSubscription =
stripeCustomerSubscriptionData ? stripeCustomerSubscriptionData.subscription : null`
(`AccountBillingPlans.tsx:62-64`); SCREEN gates (`currentSubscription?.status === "trialing"`,
`cancelAtPeriodEnd`, `isCurrentPlan = currentSubscription?.plan?.id === plan.priceId`) all read off
the live object.

OURS: `customer_subscription` renders `organization_ai_credit_purchase.stripe_subscription` (raw
live Stripe object, no serializer;
`organization_ai_credit_purchases_controller.rb:430`); `currentSubscription =
aiCreditCustomerSubscriptionData ? aiCreditCustomerSubscriptionData.subscription : null`
(`AiCreditSubscription.tsx:53-55`); `isSubscribed = currentSubscription?.status === "active" ||
currentSubscription?.status === "past_due"` (`AiCreditSubscription.tsx:59-60`); `isCurrent =
currentSubscription?.plan?.id === tier.priceId` (`AiCreditSubscription.tsx:287`); period/cancel
fields read off the live object (`:71-73`).

VERDICT: MATCH. The active-subscription SCREEN display terminates on the LIVE Stripe subscription
object (status / plan.id / currentPeriodEnd / cancelAtPeriodEnd / cancelAt), NOT on a local
`subscription_status` column. The original symptom (column-gated display) is resolved. The
data-row scoping (purchase row vs org) is SANCTIONED #4; the single dual-mode component + the
live-Stripe `isSubscribed` derivation is SANCTIONED by W5. No unsanctioned deviation.

### SCREEN: current-plan credits headline

ANALOG: current plan's per-period value derives off the live Stripe price object / persisted plan
alias (`PlanFeatureGate`); no local price→credits table.

OURS: `{currentCredits?.toLocaleString()} credits / month` (`AiSubscriptionStatus.tsx:35`)
terminates on `currentCredits` (`AiCreditSubscription.tsx:66-70`), resolved by matching the live
`currentPlanLookupKey` (`currentPriceObject?.lookupKey`, off the live Stripe price) against
`subscriptionTiers`, whose `credits` come from the local `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY`
table (`planHelpers.ts:74-87`, injected at `aiCreditPrices` `planHelpers.ts:115`).

VERDICT: MATCH (sanctioned). The live `lookupKey` IS sourced from the live Stripe price object; the
credits-per-period table is the WHITELIST W4 / SANCTIONED #5 local table (no Stripe-resident or
alias-resident source for AI-credit per-period counts). No unsanctioned deviation.

### STRIPE: live-subscription retrieve (customer_subscription happy path)

ANALOG: `Organization#stripe_subscription` → `Stripe::Subscription.retrieve({ id:
stripe_subscription_id, expand: ['items.data.price.tiers'] })` (`organization.rb:477`).

OURS: `OrganizationAiCreditPurchase#stripe_subscription` → `Stripe::Subscription.retrieve({ id:
stripe_subscription_id, expand: ['items.data.price.tiers'] })`
(`organization_ai_credit_purchase.rb:263`); guard `return if stripe_subscription_id.nil?`
(`:261`) mirrors the analog guard (`organization.rb:475`).

VERDICT: MATCH. Identical Stripe call + args + expand; identical nil-guard. The receiver being the
purchase row instead of the org is SANCTIONED #4/#1.

### STRIPE: change-portal session create (change_subscription_portal_session)

ANALOG: `Stripe::BillingPortal::Session.create(options)` (`billing_controller.rb:306`) with
`flow_data.type='subscription_update_confirm'`,
`subscription_update_confirm.subscription = current_organization.stripe_subscription_id`,
`items:[{ id: subscription_item_id, price: determine_price_id, quantity: 1 }]`,
`return_url: "#{AtsRootUrl}#{params[:return_url] || '/account'}"`.

OURS: `Stripe::BillingPortal::Session.create(options)`
(`organization_ai_credit_purchases_controller.rb:261`) — same `flow_data` shape; `subscription =
organization_ai_credit_purchase.stripe_subscription_id` (SANCTIONED #1); `items` block identical;
`return_url` literal identical.

VERDICT: MATCH (only the SANCTIONED #1 subscription-id source differs).

### STRIPE: payment-method-update session + continue confirmation

ANALOG: payment-method fork (`billing_controller.rb:331-380`) builds `continue_url` to
`/api/v1/billing/continue_change_subscription_portal_session` and a `payment_method_update`
portal session; the continue action (`:385-470`) builds a `subscription_update_confirm` session.

OURS: `update_payment_method_and_subscription_portal_session`
(`organization_ai_credit_purchases_controller.rb:286-338`) builds `continue_url` to
`/api/v1/ai_credit_purchases/continue_change_subscription_portal_session` (WHITELIST W2) and the
`payment_method_update` portal session (`:309-325`); `continue_change_subscription_portal_session`
(`:345-415`) builds the `subscription_update_confirm` session
(`subscription = organization_ai_credit_purchase.stripe_subscription_id`, SANCTIONED #1;
`price: target_price_id`).

VERDICT: MATCH. Both Stripe session shapes match the analog; the route literal (W2), the
purchase-row subscription source (#1), and the absence of the `ValidateSubscriptionChange` gate
(SANCTIONED #3) are all whitelisted. The continue action's `return_url`-pre-`:403`-raise caveat
from the analog (`:464-469`) is reproduced structurally (`return_url` assigned `:364-368`, after
the two blank-guards `:351-359`).

### DATABASE: reads/writes in the audited actions

ANALOG: `customer_subscription` does one DB read (`current_organization.stripe_subscription_id`
column). No DB WRITE in any of the four change-flow actions (the change is confirmed inside the
Stripe-hosted portal; `sync_with_stripe` runs later on return, not invoked here).

OURS: each action reads
`current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status:
[:active, :past_due])` (SANCTIONED #4 — purchase-row scoping) then reads its
`stripe_subscription_id` column. No DB WRITE in any of the four actions.

VERDICT: MATCH. DB write-absence matches the analog exactly; the extra read of the scoped purchase
row is SANCTIONED #4.

---

## Deviations found in this segment

NONE (zero unsanctioned terminal deviations).

Every SCREEN / STRIPE / DATABASE terminal in the audited subscription-change flow either matches the
analog structurally or differs only by a deviation already covered by SANCTIONED #1–#5 or WHITELIST
W1–W5. Critically, the original user-facing symptom — an active subscription not displaying because
the display gated on a local `subscription_status` column — is RESOLVED: the active-subscription
SCREEN terminals (`isSubscribed`, `isCurrent`, period/cancel fields, current credits) all derive
from the LIVE Stripe subscription object returned by `customer_subscription`
(`organization_ai_credit_purchases_controller.rb:430` → `OrganizationAiCreditPurchase#stripe_subscription`
→ `Stripe::Subscription.retrieve`), exactly as the analog derives them from
`current_organization.stripe_subscription`.

## Out-of-segment note (not a terminals finding)

`#checkout` (`:19`/`:31`) calls `OrganizationAiCreditPurchase.subscription_key?` and
`.credit_amount_for_key`, but the model defines `ai_credit_subscription_plan_lookup_key?` and
`ai_credit_allocation_for_lookup_key` (the renamed names per SANCTIONED #5). These would raise
`NoMethodError`. This is the SUBSCRIBE-NEW (`#checkout`) flow, NOT a SCREEN/STRIPE/DATABASE terminal
of the subscription-CHANGE flow under audit, so it is outside this segment — flagging only so the
controller-segment reviewer can confirm it is caught there.
