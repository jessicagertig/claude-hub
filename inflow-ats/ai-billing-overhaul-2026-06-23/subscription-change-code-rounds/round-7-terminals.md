# Round 7 — TERMINALS segment (SCREEN / STRIPE / DATABASE)

Adversarial audit of OUR AI-credit subscription-change flow vs the verified ANALOG trace,
restricted to the three terminals: what renders for an ACTIVE subscription (SCREEN), each
`Stripe::` call + args (STRIPE), each DB read/write (DATABASE). Sanctioned deviations
(`SANCTIONED-subscription-change.md` #1-5) and the agent whitelist (`AGENT-WHITELIST-subscription-change.md`
W1-W5) were read fresh and excluded by substance.

## Chains traced

SCREEN (active-subscription display):
`OrganizationAiBilling.tsx → AiCreditSubscription.tsx → AiSubscriptionStatus.tsx → AiSubscriptionTierCard.tsx → aiSubscriptionHelpers.ts → planHelpers.ts`
data feed: `AiCreditSubscription.tsx → useOrganizationAiCreditPurchase.ts (useAiCreditCustomerSubscription / useOrganizationAiCreditPurchasePrices) → api.ts → routes.rb → organization_ai_credit_purchases_controller.rb`

STRIPE / DATABASE:
`organization_ai_credit_purchases_controller.rb (#customer_subscription / #change_subscription_portal_session / #update_payment_method_and_subscription_portal_session / #continue_change_subscription_portal_session / #prices) → organization_ai_credit_purchase.rb (#stripe_subscription) → Stripe gem boundary`

## Symptom verification (core of this round)

The reported symptom — "an active subscription does NOT display; analog derives display from the
live Stripe subscription, ours gates on a local subscription_status column" — is RESOLVED at all
three terminals:

- SCREEN: `isSubscribed` is derived from the LIVE Stripe object's status —
  `currentSubscription?.status === "active" || currentSubscription?.status === "past_due"`
  (`AiCreditSubscription.tsx:59-60`), where `currentSubscription = aiCreditCustomerSubscriptionData.subscription`
  (`:53-55`). No SCREEN-path read of the local `subscription_status` column remains (grep of the
  accountPlatoAi views + the hook + parent returns zero hits). The `isSubscribed` single-boolean
  (vs the analog's per-flag derivation) is whitelisted W5.
- STRIPE: `#customer_subscription` renders `organization_ai_credit_purchase.stripe_subscription`
  (the LIVE Stripe object), `OrganizationAiCreditPurchase#stripe_subscription`
  (`organization_ai_credit_purchase.rb:260-264`) is character-identical to the analog's
  `Organization#stripe_subscription` (`organization.rb:474-478`):
  `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`.
  Purchase-row scoping is SANCTIONED #4.
- DATABASE: the change/portal actions perform no DB write; the only read is the sanctioned
  purchase-row lookup. Matches the analog (no write in the action) modulo SANCTIONED #1/#2/#4.

The terminals structurally match the analog. The deviations below are residual, not the symptom.

---

## D1 — `#prices` authorizes a DIFFERENT policy/method than the analog (SCREEN price-feed terminal)

ANALOG (trace item 13): `BillingController#prices` authorizes `:billing, :prices?`
(`billing_controller.rb:536`) → `BillingPolicy#prices?` → `is_org_user?` (org-USER gate).
| OURS: `#prices` authorizes `:organization_ai_credit_purchase, :show?`
(`organization_ai_credit_purchases_controller.rb:217`) — a different policy class AND a different
policy method (`show?` not `prices?`), at whatever level that policy's `show?` resolves to, not the
analog's org-USER `prices?`.
| file:line: `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:217`

Not covered by SANCTIONED (#5 covers `ai_credit_*` naming, not the authorize target) nor by W1-W5.
The price list feeds the SCREEN cards; its authorize gate is a terminal-adjacent structural choice
the analog makes via `:billing, :prices?`. Flag for owner: confirm the intended gate level for the
AI-credit price list.

## D2 — `#prices` Stripe::Price.list drops the analog's `limit: 20`

ANALOG: `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })`
(`billing_controller.rb:537`).
| OURS: `Stripe::Price.list(lookup_keys: OrganizationAiCreditPurchase.ai_credit_lookup_keys, active: true, expand: ['data.tiers'])`
(`organization_ai_credit_purchases_controller.rb:219`) — the `lookup_keys:` scoping is the
ai_credit_* domain filter (SANCTIONED #5 family / W4), but the analog's `limit: 20` argument is
DROPPED with no replacement. With `lookup_keys:` supplied and Stripe's default `limit` of 10, and
OUR key table currently holding exactly 10 lookup keys (`AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`), the
result sits exactly at the default page boundary — adding a key would silently truncate the price
list (and a SCREEN card) without an explicit `limit`.
| file:line: `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:219`

The `lookup_keys` scoping is sanctioned; the dropped `limit` is not — it is a non-sanctioned omission
of an analog argument with a real (if latent) truncation effect at the SCREEN terminal. Flag:
add an explicit `limit` (>= the key-count) to match the analog's bounded-list structure.

---

## Terminals confirmed MATCHING (no deviation)

For completeness — each verified identifier-by-identifier and found to match the analog (or to be
covered by a sanctioned/whitelisted entry):

- `#customer_subscription` body structure (ap-debug → unconditional `ap …stripe_subscription` →
  nil-branch `render json: { subscription: nil }` → else begin render live → rescue StandardError
  Sentry+logger+`{ errors: ['Unable to load subscription'] }`) matches analog `:606-618`. NO
  `authorize` in either (matches). Purchase-row scoping SANCTIONED #4.
- `OrganizationAiCreditPurchase#stripe_subscription` STRIPE call identical to analog (above).
- `#change_subscription_portal_session`: `authorize :billing, :change_subscription?` matches analog
  org-ADMIN gate; guards (customer_id / subscription_id / subscription_item_id) match; `options`
  `flow_data.subscription = organization_ai_credit_purchase.stripe_subscription_id` is SANCTIONED #1;
  `Stripe::BillingPortal::Session.create(options)` STRIPE terminal + `PosthogTrackJob.perform_later`
  + `render json: { redirectUrl: session.url }` match; absence of `ValidateSubscriptionChange` is
  SANCTIONED #3. No DB write (matches analog).
- `#update_payment_method_and_subscription_portal_session` / `#continue_change_subscription_portal_session`:
  STRIPE `Stripe::BillingPortal::Session.create` shapes (`payment_method_update` →
  `subscription_update_confirm`) and redirect terminals match; `continue_url` base path is W2;
  purchase-row scoping SANCTIONED #4; removal of `ValidateSubscriptionChange` SANCTIONED #3;
  `determine_price_id` raise-else is W1.
- SCREEN `currentSubscription` field reads (`items.data[0].id`, `items.data[0].price`, `plan?.id`,
  `currentPeriodEnd`, `cancelAtPeriodEnd`, `cancelAt`) are all live-Stripe-object reads — match the
  analog's live-object reads. `isCurrentPlan = currentSubscription?.plan?.id === tier.priceId`
  (`AiCreditSubscription.tsx:311`) matches analog `:436`.
- SCREEN active headline `{currentCredits?.toLocaleString()} credits / month`
  (`AiSubscriptionStatus.tsx:35`) sourcing `currentCredits` from the local
  `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` table is W4.
- `AiCreditSubscription` rendered unconditionally from `OrganizationAiBilling.tsx:30` with the
  subscribed/unsubscribed fork inside `AiSubscriptionStatus` is W5.
- `#show` action + serializer render of the persisted row is W3 (outside the audited SCREEN path).
