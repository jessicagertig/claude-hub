# AI Credit Subscription Change — Iota-for-Iota Structural Trace vs. Analog

Goal: an exact structural map of the ANALOG main-plan subscription-change flow and OURS (credit-pack), so the analog can be replicated exactly. This is a TRACE/SPEC. No code is implemented here.

The ANALOG is the main-plan Billing Portal `subscription_update_confirm` flow (`BillingController#change_subscription_portal_session`, `AccountBillingPlans.tsx`). OURS is the credit-pack flow (`OrganizationAiCreditPurchasesController#change_subscription_portal_session`, `AiCreditSubscription.tsx`).

---

## Analog — full skeleton

The complete file→file→file chain. Two front-end data fetches feed the change call: the live subscription fetch (origin of `subscriptionItemId`) and the prices fetch (origin of the target `priceId`).

Ordered identifier chain (frontend entry → hook → apiPost → route → controller → every identifier → Stripe):

1. `AccountBillingPlans` (component) — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:41`
2. `useStripeCustomerSubscription` (hook) — `app/javascript/shared/queryHooks/useBilling.ts:245`
3. `getStripeCustomerSubscription` (const) — `app/javascript/shared/queryHooks/useBilling.ts:98` → `apiGet`
4. `apiGet` — `app/javascript/shared/queryHooks/api.ts:5` (GET + `allKeysToCamel`)
5. route `GET /api/v1/billing/customer_subscription` — `config/routes.rb:177`
6. `BillingController#customer_subscription` — `app/controllers/api/v1/billing_controller.rb:606` → renders `{ subscription: current_organization.stripe_subscription }` (raw live Stripe object, no serializer)
7. `Organization#stripe_subscription` — `app/models/organization.rb:474` → `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`
8. `Organization#stripe_subscription_id` (column) — `db/schema.rb:1052`
9. Frontend reads `currentSubscription` — `AccountBillingPlans.tsx:62`; `currentSubscriptionItemId = currentSubscription.items.data[0].id` — `AccountBillingPlans.tsx:136`; `currentPriceObject = currentSubscription.items.data[0].price` — `AccountBillingPlans.tsx:67`

PARALLEL target-priceId chain:

10. `useBillingPrices` (hook) — `app/javascript/shared/queryHooks/useBilling.ts:266`
11. `getPrices` (const) — `app/javascript/shared/queryHooks/useBilling.ts:102` → `apiGet({ path: '/billing/prices' })`
12. route `GET /api/v1/billing/prices` — `config/routes.rb:174`
13. `BillingController#prices` — `app/controllers/api/v1/billing_controller.rb:535` → `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })`, renders raw list (`billingPrices` prop)
14. `getPlansForPeriod` — `app/javascript/ats/src/lib/planLookups.js:553` → matches `price.lookupKey.includes(planConfig.key)`, sets `priceId = priceData.id` (`planLookups.js:568`)
15. `plans / plansWithButtonText` — `AccountBillingPlans.tsx:175` (each plan carries `priceId`, `lookupKey`, `key`)

CHANGE call chain (joins `priceId` + `subscriptionItemId`):

16. `handleChangeSubscriptionWithGate` — `AccountBillingPlans.tsx:322` → joins `plan.priceId` + `currentSubscriptionItemId`
17. `handleChangeSubscriptionViaStripePortal` — `AccountBillingPlans.tsx:283` (adds `returnUrl: '/hire/settings/billing'`)
18. `useChangeSubscriptionViaStripePortal` (hook) — `app/javascript/shared/queryHooks/useBilling.ts:181`
19. `changeSubscriptionViaStripePortal` (const) — `app/javascript/shared/queryHooks/useBilling.ts:46` → `apiPost({ path: '/billing/change_subscription_portal_session', variables: { priceId, subscriptionItemId, returnUrl } })` (`allKeysToSnake` → `price_id`, `subscription_item_id`, `return_url`)
20. route `POST /api/v1/billing/change_subscription_portal_session` — `config/routes.rb:169`
21. `BillingController#change_subscription_portal_session` — `app/controllers/api/v1/billing_controller.rb:268`
22. `authorize :billing, :change_subscription?` — `billing_controller.rb:269` → `BillingPolicy#change_subscription?` (`app/policies/billing_policy.rb:24`) → `is_org_admin?` (`app/policies/application_policy.rb:50`)
23. Guards (`billing_controller.rb:272-274`): raise unless `stripe_customer_id`, `stripe_subscription_id`, `params[:subscription_item_id]` present
24. `determine_price_id` — `billing_controller.rb:630` → `params[:price_id]` when present, else `Stripe::Price.list` for `DEFAULT_PRICE_LOOKUP_KEY` (`billing_controller.rb:7`). Invoked 3× (lines 279, 299, 311)
25. `ValidateSubscriptionChange.call(organization:, target_price_id:, action_type: 'change')` — `app/interactors/validate_subscription_change.rb:6`
    - `Stripe::Price.retrieve(target_price_id)` (`:15`) → `target_lookup_key = target_price.lookup_key` (`:16`)
    - `organization.assign_plan_name_from_lookup_key(lookup_key:)` (`:26`) → `app/models/organization.rb:678` → `Stripe::SubscriptionStatusChecker#assign_plan_from_lookup_key` (`app/services/stripe/subscription_status_checker.rb:113`) → `PLAN_LOOKUP_MAPPING` substring match (`subscription_status_checker.rb:16`)
    - `PlanFeatureGate.all_plan_rules` (`app/services/plan_feature_gate.rb:72`) → `plan_rules` (`:142`); reads `target_plan_rules[:job_limit]`
    - `organization.jobs.where(status: 'published').count` (`:42`) vs `target_job_limit` → `context.fail!` or `context.success!`
26. On `!result.success?`: `render_general_errors([result.message])` — `billing_controller.rb:284`, `app/controllers/application_controller.rb:40`
27. `subscription_item_id = params[:subscription_item_id]` — `billing_controller.rb:288`
28. `Stripe::BillingPortal::Session.create(options)` — `billing_controller.rb:306`
29. `PosthogTrackJob.perform_later(current_user.id, 'change_subscription_stripe_portal_opened', { price_id: determine_price_id })` — `billing_controller.rb:311` → `PosthogTrackJob#perform` (`app/jobs/posthog_track_job.rb:6`)
30. `render json: { redirectUrl: session.url }` — `billing_controller.rb:313`
31. Method-level rescues — `billing_controller.rb:315` (`Pundit::NotAuthorizedError`), `:321` (`Stripe::InvalidRequestError` + Sentry), `:325` (`StandardError`, no Sentry)

Stripe BillingPortal flow_data shape, verbatim (`billing_controller.rb:290-306`):

```ruby
{
  customer: current_organization.stripe_customer_id,
  return_url: "#{Variables::AtsRootUrl}#{params[:return_url] || '/account'}",
  flow_data: {
    type: 'subscription_update_confirm',
    subscription_update_confirm: {
      subscription: current_organization.stripe_subscription_id,
      items: [{ id: subscription_item_id, price: determine_price_id, quantity: 1 }]
    }
  }
}
```

Note: no DB record is written in this action. The change is confirmed inside the Stripe-hosted portal; `sync_with_stripe` runs later on the user's return (referenced in the action comment, not invoked here).

---

## Ours — full skeleton

Ordered identifier chain (frontend entry → hook → apiPost → route → controller → every identifier → Stripe):

1. `handleSelectTier` (const) — `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:54` → on subscribed org, `changeSubscription({ stripePriceLookupKey: tier.lookupKey, returnUrl })`. The ONLY identifying datum sent is the lookup key.
2. `isSubscribed` — `AiCreditSubscription.tsx:42` (true when `subscription?.subscriptionStatus` is `active`/`past_due`)
3. `subscription` (var) — `AiCreditSubscription.tsx:28` via `useOrganizationAiCreditPurchase`. Fields available: `subscriptionStatus`, `subscriptionCreditsPerPeriod`, `subscriptionCurrentPeriodEnd`, `stripePriceLookupKey`. NO `stripeSubscriptionId`, NO `subscriptionItemId`.
4. `useOrganizationAiCreditPurchase` (hook) — `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts:9`
5. `getOrganizationAiCreditPurchase` (const) — `useOrganizationAiCreditPurchase.ts:5` → `apiGet({ path: '/ai_credit_purchases' })` (#show)
6. `OrganizationAiCreditPurchase` (TS interface) — `app/javascript/shared/types/organizationAiCreditPurchase.ts:7` (no `stripeSubscriptionId`, no `subscriptionItemId` slot)
7. route `GET /ai_credit_purchases` (#show) — `config/routes.rb:190`
8. `OrganizationAiCreditPurchasesController#show` — `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:4` → `render_one(..., OrganizationAiCreditPurchaseSerializer)`
9. `Api::V1::OrganizationAiCreditPurchaseSerializer` — `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb:3` (14 attrs; `stripe_subscription_id` deliberately NOT exposed)
10. `stripe_subscription_id` column — `db/schema.rb:968` (unique partial index `idx_org_ai_purchases_stripe_sub_id`, `schema.rb:987`)

PARALLEL prices chain (origin of `tier.lookupKey`):

11. `getOrganizationAiCreditPurchasePrices` — `useOrganizationAiCreditPurchase.ts:109` → `apiGet({ path: '/ai_credit_purchases/prices' })`
12. `OrganizationAiCreditPurchasesController#prices` — `organization_ai_credit_purchases_controller.rb:236` → `Stripe::Price.list(lookup_keys: registered_keys, active: true, expand: ['data.product'])`, renders raw catalog price objects
13. `aiCreditPrices` — `app/javascript/shared/lib/planHelpers.ts:86` → maps to `AiPrice { lookupKey, priceId(=price.id), ... }` (price ids only, NOT subscription/item ids)
14. `splitTiers` — `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/aiSubscriptionHelpers.ts:19` → partitions into `subscriptionTiers`/`topUpTiers`; `tier.lookupKey` originates here

CHANGE call chain:

15. `changeAiCreditSubscriptionViaStripePortal` (const) — `useOrganizationAiCreditPurchase.ts:50` → `apiPost({ path: '/ai_credit_purchases/change_subscription_portal_session', variables: { organizationAiCreditPurchase: { stripePriceLookupKey, returnUrl } } })`. Only `stripePriceLookupKey` + `returnUrl` sent.
16. `useChangeAiCreditSubscriptionViaStripePortal` (hook) — `useOrganizationAiCreditPurchase.ts:59`
17. route `POST /api/v1/ai_credit_purchases/change_subscription_portal_session` — `config/routes.rb:194`
18. `OrganizationAiCreditPurchasesController#change_subscription_portal_session` — `organization_ai_credit_purchases_controller.rb:151`
19. `authorize :billing, :change_subscription?` — `controller:152` → `BillingPolicy#change_subscription?` (`app/policies/billing_policy.rb:24`) → `is_org_admin?` (`app/policies/application_policy.rb:50`)
20. `current_organization.organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])` — `controller:154` (`.subscription` = enum scope from `enum kind` at `app/models/organization_ai_credit_purchase.rb:53`)
21. `purchase.stripe_subscription_id` read + guard — `controller:160` (blank → 'Subscription is not yet active in Stripe'). WRITER is the `checkout.session.completed` handler `app/jobs/stripe_webhook_handler_job.rb:58-68` via `purchase.update_columns(stripe_subscription_id: object.subscription)`
22. `OrganizationAiCreditPurchase.subscription_key?(lookup_key)` — `app/models/organization_ai_credit_purchase.rb:35` → `CREDIT_PACKS_BY_LOOKUP_KEY[lookup_key]&.dig(:kind) == :subscription` (`organization_ai_credit_purchase.rb:4`). Invalid → 'Invalid subscription price' (`controller:166-168`)
23. `Stripe::Price.list(lookup_keys: [lookup_key], active: true, limit: 1)` — `controller:171` → `price = prices.data.first`; `price.id` is the new item price
24. `Stripe::Subscription.retrieve(purchase.stripe_subscription_id)` — `controller:178` → `subscription_item_id = subscription.items.data.first&.id` (`controller:179`)
25. `options` / `flow_data` — `controller:185`
26. `Stripe::BillingPortal::Session.create(options)` — `controller:201`
27. `PosthogTrackJob.perform_later(current_user.id, 'change_subscription_stripe_portal_opened', { price_id: price.id })` — `controller` → `PosthogTrackJob#perform` (`app/jobs/posthog_track_job.rb:3/6`)
28. `render json: { redirectUrl: session.url }`
29. `organization_ai_credit_purchase_params` — `controller:250` (permits `:stripe_price_lookup_key`, `:return_url` under `:organization_ai_credit_purchase`)
30. Method-level rescue `Stripe::StripeError => e` — `controller:206` (`Rails.logger.error`, `ap e`, `Sentry.capture_exception`, `render_general_errors`)

Stripe BillingPortal flow_data shape, verbatim (`controller:185-201`):

```ruby
{
  customer: current_organization.stripe_customer_id,
  return_url: "#{Variables::AtsRootUrl}#{params[:return_url] || '/hire/settings/billing'}",
  flow_data: {
    type: 'subscription_update_confirm',
    subscription_update_confirm: {
      subscription: purchase.stripe_subscription_id,
      items: [{ id: subscription_item_id, price: price.id, quantity: 1 }]
    }
  }
}
```

DOWNSTREAM EFFECT: the resulting `customer.subscription.updated` webhook (`stripe_webhook_handler_job.rb:111-148`) reads `object.items.data.first.price.lookup_key`, and on `subscription_key?` rewrites the local row via `purchase.update(stripe_price_lookup_key:, subscription_credits_per_period: credit_amount_for_key(...), subscription_status:, subscription_current_period_start/end:)`.

---

## The price model, traced both ways

### Analog: priceId ↔ lookup_key ↔ plan alias ↔ plan rules

| Hop | Identifier | file:line |
|---|---|---|
| Stripe price catalog → frontend | `Stripe::Price.list({ active: true, limit: 20, expand: ['data.tiers'] })` | `app/controllers/api/v1/billing_controller.rb:535/537` |
| frontend match priceId by lookup_key | `getPlansForPeriod`: `price.lookupKey.includes(planConfig.key)` → `priceId = priceData.id` | `app/javascript/ats/src/lib/planLookups.js:553` / `:568` |
| frontend static alias table | `currentOrganizationPlanOptions` (`key`=Stripe lookup_key substring, `value`=internal plan alias) | `app/javascript/ats/src/lib/planLookups.js:3` |
| frontend plan.lookupKey (= alias, not Stripe key) | `planConfig.value` | `planLookups.js:569` |
| backend priceId → lookup_key (round-trip Stripe) | `determine_price_id` → `determine_product_info` → `get_product_from_price_id` → `Stripe::Price.retrieve({id:, expand:['product']})` → `determine_lookup_key` (`price[:lookup_key]`) | `billing_controller.rb:630` / `:642` / `:649` / `:663` |
| validation-path priceId → lookup_key | `Stripe::Price.retrieve(target_price_id)` → `target_price.lookup_key` | `app/interactors/validate_subscription_change.rb:15` / `:16` |
| lookup_key → plan alias (substring match) | `assign_plan_name_from_lookup_key` → `assign_plan_from_lookup_key` → `PLAN_LOOKUP_MAPPING.keys.find { |k| lookup_key.include?(k) }` → `PLAN_LOOKUP_MAPPING[plan_key]` | `app/models/organization.rb:678` → `app/services/stripe/subscription_status_checker.rb:113` / mapping `:16` |
| persisted plan alias | `organizations.plan` integer enum (default 101 = `plan_no_plan`) | `db/schema.rb:1048`; enum `app/models/organization.rb:94` |
| plan alias → rules (job_limit etc.) | `PlanFeatureGate.all_plan_rules` → `plan_rules` (keyed by alias) | `app/services/plan_feature_gate.rb:72` / `:142` |
| default fallback lookup_key | `DEFAULT_PRICE_LOOKUP_KEY = 'plan_simple_ats_per_job_tiered'` | `billing_controller.rb:7` |

The analog has NO local price-id↔credits/limits table — it round-trips the price id through Stripe (`Stripe::Price.retrieve.lookup_key`), substring-matches the lookup_key against `PLAN_LOOKUP_MAPPING` to derive the internal alias, persists the alias on `organizations.plan`, and `PlanFeatureGate` keys all limits/features/AI-credit allocations off that alias string.

### Ours: lookup_key ↔ credits ↔ Stripe price

| Hop | Identifier | file:line |
|---|---|---|
| local source of truth: lookup_key → credits | `CREDIT_PACKS_BY_LOOKUP_KEY` (4 keys; subscription: `ai_credit_pack_subscription_small_monthly`→`{kind: :subscription, credits_per_period: 500}`, `ai_credit_pack_subscription_large_monthly`→`{kind: :subscription, credits_per_period: 2000}`) | `app/models/organization_ai_credit_purchase.rb:4` |
| is-subscription-key check | `subscription_key?` → `CREDIT_PACKS_BY_LOOKUP_KEY[lookup_key]&.dig(:kind) == :subscription` | `organization_ai_credit_purchase.rb:35` |
| lookup_key → credits bridge | `credit_amount_for_key` → `pack[:credits] || pack[:credits_per_period]` | `organization_ai_credit_purchase.rb:43` |
| lookup_key → live Stripe price | `Stripe::Price.list(lookup_keys: [lookup_key], active: true, limit: 1)` → `price.id` | `organization_ai_credit_purchases_controller.rb:171` |
| catalog (frontend) | `Stripe::Price.list(lookup_keys: registered_keys, active: true, expand: ['data.product'])` → `aiCreditPrices` (`priceId = price.id`) | `controller:236/239` → `app/javascript/shared/lib/planHelpers.ts:86` |
| reconcile credits after change | `customer.subscription.updated` handler calls `credit_amount_for_key` → writes `subscription_credits_per_period` | `app/jobs/stripe_webhook_handler_job.rb:137` |

The dollar amount lives ONLY in Stripe (`Price.unit_amount`); `CREDIT_PACKS_BY_LOOKUP_KEY` stores only credits + name. The lookup_key is the join key between credits (app) and dollar amount (Stripe). `credit_amount_for_key` is NOT called in the change action — it runs downstream in the `customer.subscription.updated` webhook.

---

## Where the subscription_item_id comes from — and why ours lacks it

THE central question.

ANALOG — the frontend HAS the live subscription and its item id before the change call:

- Originating fetch: `useStripeCustomerSubscription` → `getStripeCustomerSubscription` → `apiGet({ path: '/billing/customer_subscription' })` — `app/javascript/shared/queryHooks/useBilling.ts:245` / `:98`
- Backend endpoint: `BillingController#customer_subscription` renders `{ subscription: current_organization.stripe_subscription }` — the **full live Stripe Subscription object, raw, no serializer** — `app/controllers/api/v1/billing_controller.rb:606`
- Live retrieve: `Organization#stripe_subscription` → `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` — `app/models/organization.rb:474` (the `expand: ['items.data...']` is what populates `items.data[].id`)
- Frontend extracts it: `currentSubscriptionItemId = currentSubscription && currentSubscription.items.data[0].id` — `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingPlans.tsx:136`
- It is then sent back to the server: `apiPost(..., variables: { priceId, subscriptionItemId, returnUrl })` — `app/javascript/shared/queryHooks/useBilling.ts:46`, and the controller plugs `params[:subscription_item_id]` directly into `flow_data.items[0].id` — `billing_controller.rb:288`. The analog controller does **NOT** call `Stripe::Subscription.retrieve`.

OURS — the frontend has NO subscription id and NO item id, enumerated:

- The serializer exposes 14 attributes and **deliberately omits `stripe_subscription_id`** even though the column exists — `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb:3` (attrs: id, kind, stripe_checkout_session_id, stripe_price_lookup_key, amount_cents_paid, currency, one_off_credits_granted, subscription_credits_per_period, subscription_status, subscription_current_period_start, subscription_current_period_end, subscription_canceled_at, refunded_at, created_at). Column at `db/schema.rb:968`.
- The TS interface has no slot for either id — `app/javascript/shared/types/organizationAiCreditPurchase.ts:7`
- There is no `subscription_item_id` column anywhere in the schema, so it cannot be serialized.
- The `#prices` endpoint returns catalog Stripe Price objects only (`price.id`, `lookup_key`, etc.), not a subscription object and not subscription items — `organization_ai_credit_purchases_controller.rb:236` / `app/javascript/shared/lib/planHelpers.ts:86`. A price id is a catalog identifier, not a subscription-item id.
- Consequently the client can only send `stripePriceLookupKey` + `returnUrl` — `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts:50`, and `AiCreditSubscription.tsx:54` confirms the lookup key is the only identifying datum available.
- This forces the server-side reconstruction: read the hidden column `purchase.stripe_subscription_id` (`controller:160`), then `Stripe::Subscription.retrieve(purchase.stripe_subscription_id)` purely to obtain `subscription.items.data.first&.id` — `organization_ai_credit_purchases_controller.rb:178` / `:179`.

One-line answer: ours lacks the `subscription_item_id` because there is no `subscription_item_id` column and the serializer (`organization_ai_credit_purchase_serializer.rb:3`) does not expose even `stripe_subscription_id` (and `/ai_credit_purchases` returns no live Stripe subscription object the way the analog's `/billing/customer_subscription` does), so the client never receives the live subscription and the controller must call `Stripe::Subscription.retrieve` itself.

---

## Iota-for-iota mirror target

What OURS must look like to match the analog's skeleton exactly. Each item cites the analog file:line being mirrored.

1. **Add a live-subscription fetch endpoint on the ours side**, mirroring the analog's `GET /billing/customer_subscription` → raw live Stripe Subscription object. The exact mechanism to replicate: a controller action that renders `{ subscription: <live Stripe::Subscription.retrieve(..., expand: ['items.data.price.tiers']) > }` with no serializer, so `items.data[0].id` reaches the client.
   - Mirrors: route `config/routes.rb:177`; action `BillingController#customer_subscription` `app/controllers/api/v1/billing_controller.rb:606`; live retrieve `Organization#stripe_subscription` `app/models/organization.rb:474` (`Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })`).
   - On ours, the `id` to retrieve is `purchase.stripe_subscription_id` (`organization_ai_credit_purchases_controller.rb:160`) rather than `organizations.stripe_subscription_id`.

2. **Add a frontend hook to fetch that live subscription** and surface its item id, mirroring `useStripeCustomerSubscription` + `currentSubscriptionItemId`.
   - Frontend obtains the item id by reading `currentSubscription.items.data[0].id` from the live-subscription fetch — name the exact mechanism: a React Query hook calling `apiGet({ path: '/ai_credit_purchases/customer_subscription' })` (the new endpoint), then `const subscriptionItemId = subscription && subscription.items.data[0].id`.
   - Mirrors: `useBilling.ts:245` (`useStripeCustomerSubscription`), `useBilling.ts:98` (`getStripeCustomerSubscription`), `AccountBillingPlans.tsx:62` (`currentSubscription`), `AccountBillingPlans.tsx:136` (`currentSubscriptionItemId = currentSubscription.items.data[0].id`).

3. **Frontend sends `priceId` + `subscriptionItemId`** (not just lookup_key) on the change call.
   - `handleSelectTier` must join the target `priceId` (from `aiCreditPrices`/`splitTiers`, already holding `priceId = price.id` via `planHelpers.ts:86`) with the `subscriptionItemId` from item 2, and pass both to the mutation.
   - Mirrors: `AccountBillingPlans.tsx:322` (`handleChangeSubscriptionWithGate` joins `plan.priceId` + `currentSubscriptionItemId`), `AccountBillingPlans.tsx:283` (`handleChangeSubscriptionViaStripePortal({ priceId, subscriptionItemId, returnUrl })`).
   - Change the mutation `changeAiCreditSubscriptionViaStripePortal` (`useOrganizationAiCreditPurchase.ts:50`) to send `{ priceId, subscriptionItemId, returnUrl }`, mirroring `changeSubscriptionViaStripePortal` `useBilling.ts:46`.

4. **Controller takes the item id and price id from params**, not from a server-side retrieve.
   - Read `subscription_item_id = params[:subscription_item_id]` directly, mirroring `billing_controller.rb:288`.
   - Plug `params[:subscription_item_id]` into `flow_data.items[0].id` and the target price into `flow_data.items[0].price`, mirroring `billing_controller.rb:299` and the `flow_data` shape `billing_controller.rb:290-306`.

5. **Resolve the credits lookup from `price_id`** (not from a client-sent lookup_key as the direct key), mirroring the analog's priceId→lookup_key round-trip.
   - The controller should resolve the Stripe `lookup_key` FROM the incoming `price_id` (via `Stripe::Price.retrieve(price_id).lookup_key`), mirroring `validate_subscription_change.rb:15-16` and `get_product_from_price_id` `billing_controller.rb:649`, then use that lookup_key for the `CREDIT_PACKS_BY_LOOKUP_KEY` / `subscription_key?` / `credit_amount_for_key` checks (`organization_ai_credit_purchase.rb:4/35/43`).

6. **Drop the server-side `Stripe::Subscription.retrieve`** (`organization_ai_credit_purchases_controller.rb:178`) and the `subscription.items.data.first&.id` derivation (`:179`) — the analog controller has no such call; the item id arrives in params.

7. **Drop the lookup-key-direct path**: stop using the client-sent `stripePriceLookupKey` as the change identifier and stop resolving the price via `Stripe::Price.list(lookup_keys: [lookup_key], ...)` (`controller:171`). The analog uses `params[:price_id]` directly (`determine_price_id` string branch, `billing_controller.rb:631-633`) and resolves lookup_key from the price, not the reverse.

### Blockers / open gaps

- **`flow_data.subscription` source on ours**: the analog uses `current_organization.stripe_subscription_id` (an Organization column). Ours uses `purchase.stripe_subscription_id`, a column on `organization_ai_credit_purchases` that is **not serialized** to the client. For the new `/customer_subscription`-style endpoint to do the live retrieve, the backend reads it from the DB (it already does at `controller:160`); no client exposure of `stripe_subscription_id` is required if the live retrieve happens in a dedicated GET endpoint server-side. This is the genuine structural difference forced by the data: the analog's subscription id lives on `organizations`, ours lives on the purchase row — the new fetch endpoint must scope the retrieve to the org's active/past_due subscription-kind `OrganizationAiCreditPurchase` (`controller:154`) instead of `current_organization.stripe_subscription`.
- The analog runs `ValidateSubscriptionChange` (job-limit downgrade gate, `validate_subscription_change.rb:6`) before opening the portal. Ours has no analogous credit-pack validation interactor. This is an EXTRA the analog has and ours lacks; whether a credit-pack equivalent is wanted is a product decision, not a forced mirror.
- The dollar amount per lookup_key is not in app source on either side (lives in Stripe `Price.unit_amount`); not assertable from the codebase.

---

## Unresolved identifiers

Union of all five traces' openGaps:

- `context.fail!`/`context.success!`/`context.success?`/`context.message` → `interactor` gem 3.1.2 (`Gemfile.lock:251`) — framework boundary.
- `Stripe::Price.retrieve` / `Stripe::Price.list` / `Stripe::BillingPortal::Session.create` / `Stripe::Subscription.retrieve` → stripe-ruby gem — framework boundary.
- `Posthog::Track#track` → posthog client — not traced; outside path scope.
- `sync_with_stripe` — mentioned in the analog action comment as running on the user's return, but NOT invoked within `change_subscription_portal_session`; body not traced for this path.
- `is_org_owner?` (called by `is_org_admin?`) — sibling helper in `application_policy.rb`; not load-bearing on the org-admin-true branch, not opened.
- `current_user` (used by `current_organization` and `authorize`) — Devise/BaseController helper — framework boundary.
- `allKeysToCamel`/`allKeysToSnake` (from `@ats/src/lib/utils/structure`, imported `api.ts:2`) — snake↔camel transform; established by CLAUDE.md API-layer rule and field-name correspondence; util boundary not further traced.
- `ValidateSubscriptionChange` (analog frontend trace) — opened in the analog backend trace; gates the change but does not affect where subscription/item-id/price data originates.
- `DEFAULT_PRICE_LOOKUP_KEY` — exists with identical value `'plan_simple_ats_per_job_tiered'` in TWO places (`billing_controller.rb:7` and `organization.rb:176`), independent duplicated constants; the `organization.rb:176` copy was not found to be read by any traced path (possibly dead/legacy). The active default is `billing_controller.rb:7`. The actual Stripe Price carrying that lookup_key is configured in the Stripe dashboard, outside the codebase.
- `SubscriptionRequiredModalNew.tsx:27` and `StartFreeTrialModal` define their own `DEFAULT_PRICE_LOOKUP_KEY = 'plan_ats_tier_apollo_monthly'` (a DIFFERENT value), used only by those modals, not the AccountBilling main-plan flow.
- The exact set of Stripe lookup_key strings actually configured in Stripe (e.g. whether `plan_ats_tier_starter_v2_monthly` exists verbatim) is external to the repo; substring-matching in `PLAN_LOOKUP_MAPPING` (backend) and `getPlansForPeriod` (frontend) assumes these conventions but cannot be verified from source.
- The ancestor component that calls `useBillingPrices` and passes `billingPrices` down to `AccountBillingPlans` was not opened; the hook/endpoint chain producing the data is confirmed, but not the exact parent file.
- No code enforces a single active credit-pack subscription per org; `find_by(subscription_status: [:active, :past_due])` (`organization_ai_credit_purchases_controller.rb:154` and `:216`) returns the first match if multiple exist — no uniqueness validation/partial index found in the files read.
- The price-model dollar amount per lookup_key lives only in Stripe (`Price.unit_amount`), not in the codebase; `CREDIT_PACKS_BY_LOOKUP_KEY` stores only credits + name, so the amount↔credits ratio is not assertable from app source.
- The `customer.subscription.updated` reconciliation (`stripe_webhook_handler_job.rb:137` `credit_amount_for_key`) is documented as the downstream effect of the portal change, but the proration `invoice.paid` → credit-granting path (`ApplyAiCreditPurchase`) was referenced in comments but not traced in this scope.
- `render_one` and `render_general_errors` — BaseController/ApplicationController helpers; behavior established (render serializer / render json errors), framework-adjacent, not re-read.
- The Stripe webhook handler that populates `stripe_subscription_id` (`stripe_webhook_handler_job.rb`) was not opened in the ours-frontend trace (asserted from schema/validation + scope); does not affect the conclusion that the client never receives the id. (It IS opened in the ours-backend trace at `:58-68`.)
- `apiGet`/`apiPost`/`apiPut` (`api.ts`) — snake↔camel transform layer, Files-You-Should-Never-Edit infra module; behavior is the documented automatic key transform.
