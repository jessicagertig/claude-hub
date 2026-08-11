# Round 1 — TERMINALS segment (SCREEN / STRIPE / DATABASE)

Adversarial audit of OUR AI-credit subscription-change flow against the verified analog trace
(`traces/subscription-change-analog-trace.md`). Sanctioned (`SANCTIONED-subscription-change.md`)
and whitelisted (`AGENT-WHITELIST-subscription-change.md`) deviations are NOT reported.

Files traced:
- SCREEN: `AiCreditSubscription.tsx` → `useOrganizationAiCreditPurchase.ts` (`useOrganizationAiCreditPurchase`, `useAiCreditCustomerSubscription`) → `aiSubscriptionHelpers.ts` → `planHelpers.ts` (`aiCreditPrices`) → `AiSubscriptionStatus.tsx`
- Controller: `organization_ai_credit_purchases_controller.rb` (`#show`, `#customer_subscription`, `#change_subscription_portal_session`, `#update_payment_method_and_subscription_portal_session`, `#continue_change_subscription_portal_session`)
- Model: `organization_ai_credit_purchase.rb` (`#stripe_subscription`)
- Serializer: `organization_ai_credit_purchase_serializer.rb`
- Routes: `config/routes.rb:190-202`

Analog terminal references: trace items 6, 9, 22, 26, 27, 28; controller `billing_controller.rb`.

---

## D1 — SCREEN (active-subscription display): the ACTIVE-subscription render gates on the LOCAL `subscription_status` column, not the live Stripe `currentSubscription`. [THE SYMPTOM]

ANALOG (trace items 9, 26, 28-34): every active-subscription SCREEN render is derived from
`currentSubscription = stripeCustomerSubscriptionData ? stripeCustomerSubscriptionData.subscription : null`
— the LIVE Stripe subscription returned by `customer_subscription` (`AccountBillingPlans.tsx:62-64`).
The "what renders for an active subscription" terminals (`<CurrentSubscription>` blocks, the
trialing/cancelAtPeriodEnd blocks, `isCurrentPlan`, the current-plan badge) ALL gate on
`currentSubscription` (the live Stripe object). The analog NEVER gates the active-subscription
display on a local DB status column. `currentOrganization.plan` is read only for the legacy-plan
display name, never as the "is there an active subscription" gate.

OURS: the active-subscription banner is gated on `isSubscribed`, which is derived from the LOCAL
`subscription_status` column, not from the live Stripe `currentSubscription`:
- `AiCreditSubscription.tsx:30` `const { data: subscription } = useOrganizationAiCreditPurchase()` — `#show` returns the serialized local row (column `subscription_status`).
- `AiCreditSubscription.tsx:59` `isSubscribed = subscription?.subscriptionStatus === "active" || subscription?.subscriptionStatus === "past_due"` — gates on the LOCAL column.
- `AiCreditSubscription.tsx:261` `<AiSubscriptionStatus isSubscribed={isSubscribed} ... />` and `AiSubscriptionStatus.tsx:28` `{isSubscribed ? (<Active subscription ...>) : (<No active subscription>)}` — the active-subscription SCREEN block renders off the local column.
- `AiCreditSubscription.tsx:268` `{isSubscribed ? "Change your plan" : "Choose a credit subscription"}` — subtitle off the local column.
- `AiCreditSubscription.tsx:60` `currentCredits = isSubscribed ? subscription?.subscriptionCreditsPerPeriod || null : null` and `:263` `periodEndsAt={subscription?.subscriptionCurrentPeriodEnd}` — credits / renew-date off the local columns, not the live Stripe price/period.

The live `currentSubscription` IS fetched in OURS (`:55-57`, via `useAiCreditCustomerSubscription`)
but is used ONLY for `currentSubscriptionItemId` (`:58`) and the per-tier `isCurrent` badge (`:272`).
The analog's structure routes the entire active-subscription display through `currentSubscription`;
OURS routes it through the local `subscription_status` column. This is the documented user-facing
symptom: an active subscription does not display because the gate is the local column, not the live
Stripe subscription.

OURS file:line — `AiCreditSubscription.tsx:30, 59, 60, 261, 263, 268` + `AiSubscriptionStatus.tsx:28-48`
ANALOG file:line — `AccountBillingPlans.tsx:62-64` (derive from live Stripe) + trace items 9, 28-34.

---

## D2 — STRIPE: `change_subscription_portal_session` adds an un-analog second Stripe call to reconstruct `subscription_item_id`.

ANALOG (trace item 26, `billing_controller.rb:288`): `subscription_item_id = params[:subscription_item_id]`
— a single direct param read. The action has already raised in its entry guards
(`billing_controller.rb:274`) `unless params[:subscription_item_id].present?`, so the item id is
guaranteed present from the param; no Stripe call is made to obtain it.

OURS (`organization_ai_credit_purchases_controller.rb:244-247`):
```
subscription_item_id =
  params[:subscription_item_id].presence ||
  Stripe::Subscription.retrieve(organization_ai_credit_purchase.stripe_subscription_id).items.data.first.id
raise StandardError, 'Subscription item ID is missing.' unless subscription_item_id.present?
```
OURS introduces an EXTRA `Stripe::Subscription.retrieve` STRIPE call (a fallback that the analog
does not have) and moves the presence guard AFTER the fallback. The analog's structure is: guard on
`params[:subscription_item_id]` first (raise if absent), then read the param. OURS does not guard the
param up front and instead silently substitutes a fresh Stripe retrieve. This is an EXTRA Stripe
terminal + a different guard order than the analog. Not covered by any sanctioned/whitelist entry
(those cover the subscription being on the purchase row, not adding a Stripe retrieve to source the
item id).

OURS file:line — `organization_ai_credit_purchases_controller.rb:244-247`
ANALOG file:line — `billing_controller.rb:274` (guard) + `:288` (direct param read).

---

## D3 — STRIPE: `update_payment_method_and_subscription_portal_session` has the same un-analog `subscription_item_id` Stripe-reconstruction fallback.

ANALOG (trace item 18b, `billing_controller.rb:337` + `:339`): entry guard
`raise StandardError, 'Subscription item ID is missing.' unless params[:subscription_item_id].present?`
FIRST, then `subscription_item_id = params[:subscription_item_id]`. No Stripe call to obtain the item id.

OURS (`organization_ai_credit_purchases_controller.rb:299-302`): same pattern as D2 — the item id is
`params[:subscription_item_id].presence || Stripe::Subscription.retrieve(...).items.data.first.id`,
guard moved after the fallback. Adds an EXTRA `Stripe::Subscription.retrieve` STRIPE terminal absent
from the analog and changes the guard ordering.

OURS file:line — `organization_ai_credit_purchases_controller.rb:299-302`
ANALOG file:line — `billing_controller.rb:337` (guard first) + `:339` (direct param read).

---

## D4 — STRIPE/structure: `change_subscription_portal_session` is missing the analog's three entry guards.

ANALOG (trace item 22, `billing_controller.rb:272-274`): THREE entry guards, in order:
`raise ... unless current_organization.stripe_customer_id.present?`,
`raise ... unless current_organization.stripe_subscription_id.present?`,
`raise ... unless params[:subscription_item_id].present?`.

OURS (`organization_ai_credit_purchases_controller.rb:239-247`) keeps the first two (customer +
subscription present, the latter on the purchase row per sanctioned #1/#4) but DROPS the third guard
(`params[:subscription_item_id].present?`) as a standalone up-front guard, replacing it with the
post-fallback guard described in D2. The analog guards the PARAM before doing any work; OURS guards a
locally-derived value after a Stripe call. (Reported jointly with D2 as the structural cause; listing
separately because the missing third entry guard is itself an analog-structure deviation.)

OURS file:line — `organization_ai_credit_purchases_controller.rb:239-247`
ANALOG file:line — `billing_controller.rb:272-274`.

---

## D5 — DATABASE / structure: `customer_subscription` adds a local-DB `subscription_status` gate the analog does not have, and the nil-branch terminal differs in shape.

ANALOG (trace item 6, `billing_controller.rb:608-618`): `customer_subscription` reads ONLY
`current_organization.stripe_subscription_id` (a column) for the branch, then either renders
`{ subscription: nil }` (when `stripe_subscription_id.nil?`) or the live
`current_organization.stripe_subscription` (the Stripe object). The DB read is a single column
(`stripe_subscription_id`); there is NO `subscription_status` filter.

OURS (`organization_ai_credit_purchases_controller.rb:429`):
`organization_ai_credit_purchase = current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])`
— this scopes the lookup by the local `subscription_status` column (`[:active, :past_due]`) as part of
selecting WHICH subscription row to read. The org/purchase-row scoping is sanctioned (#4), but the
`subscription_status: [:active, :past_due]` DB filter is an ADDED local-status gate not present in the
analog (which keys solely off `stripe_subscription_id`). Consequence: a purchase row whose live Stripe
subscription is active but whose local `subscription_status` column is stale/unsynced (`nil`, or not yet
flipped to active) is excluded by the `find_by`, so `customer_subscription` returns
`{ subscription: nil }` and the SCREEN shows no subscription — reinforcing the D1 symptom at the
endpoint level. The analog avoids this by never consulting a local status column.

OURS file:line — `organization_ai_credit_purchases_controller.rb:429, 432`
ANALOG file:line — `billing_controller.rb:609` (branch on `stripe_subscription_id.nil?` only, no status filter).

---

## D6 — DATABASE / structure: `#show` (the local subscription source feeding the SCREEN) gates on `subscription_status: [:active, :past_due]` and feeds the active-subscription display — an entire data source the analog does not have.

ANALOG: there is no analog `#show` action whose local DB `subscription_status` feeds the
active-subscription SCREEN. The analog's active-subscription state is the live Stripe
`customer_subscription` ONLY (trace item 9). `currentOrganization.plan` (a persisted column) feeds
only the legacy-plan display NAME, never the "is subscribed / which credits / renew date" terminals.

OURS (`organization_ai_credit_purchases_controller.rb:7`):
`subscription = current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])`
serialized by `OrganizationAiCreditPurchaseSerializer` (exposing `subscription_status`,
`subscription_credits_per_period`, `subscription_current_period_end`). This serialized LOCAL row is
what `useOrganizationAiCreditPurchase()` returns and what drives `isSubscribed`/`currentCredits`/
`periodEndsAt` on the SCREEN (D1). The analog derives those from the live Stripe subscription; OURS
derives them from this DB row. The existence of a local-status-gated data source feeding the
active-subscription display is the structural root of D1. (Distinct from the sanctioned data-model
deviations, which cover OPERATING on the purchase row, not gating the SCREEN's active-subscription
display on its local `subscription_status` column instead of the live Stripe subscription.)

OURS file:line — `organization_ai_credit_purchases_controller.rb:7` + serializer `:12-14` + `AiCreditSubscription.tsx:30, 59-60, 261-268`
ANALOG file:line — trace item 9 (live Stripe is the active-subscription source); `AccountBillingPlans.tsx:156` (`currentOrganization.plan` is name-only).
