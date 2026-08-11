# Round 2 — MODEL + SERIALIZER segment

Segment: `app/models/organization_ai_credit_purchase.rb` (incl. `#stripe_subscription`, subscription lookup, enums) + `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb`.

Files traced (OURS):
`AiCreditSubscription.tsx:54-66` (live-subscription display source) → `useOrganizationAiCreditPurchase.ts` (`useAiCreditCustomerSubscription` `:168` GET `/ai_credit_purchases/customer_subscription`; `useOrganizationAiCreditPurchase` `:9` GET `/ai_credit_purchases`) → `organization_ai_credit_purchases_controller.rb` (`#customer_subscription:420-437`, `#show:4-13`) → `organization_ai_credit_purchase.rb` (`#stripe_subscription:260-264`, enums `:82-85`, lookup helpers `:59-76`) → `Stripe::Subscription.retrieve` (Stripe boundary). Serializer `organization_ai_credit_purchase_serializer.rb` ← `render_one` in `#show`/`#purchase_top_up`/`#cancel`. Cross-checked: `aiSubscriptionHelpers.ts`, `planHelpers.ts` consumers, `db/schema.rb:965-990`, analog `organization.rb:469-518`, round-1-model-serializer.md, round-1-fixes.md.

ANALOG (trace): the active-subscription display derives ENTIRELY from the LIVE Stripe subscription object (trace items 6/7/9). `customer_subscription` (`billing_controller.rb:606-618`) renders the raw `current_organization.stripe_subscription` (`Organization#stripe_subscription` `organization.rb:474-478` → `Stripe::Subscription.retrieve`), NO serializer. There is no analog serializer in this flow.

---

## Status vs Round 1

Round-1 D1 (the named symptom — active-subscription DISPLAY sourced from the serialized LOCAL `subscription_status`/`subscription_credits_per_period`/`subscription_current_period_end` columns instead of the live Stripe object) was FIXED at the source (round-1-fixes.md F1–F4/D1). The current `AiCreditSubscription.tsx` derives every active-subscription render from the live `currentSubscription`:
- `isSubscribed = currentSubscription?.status === "active" || currentSubscription?.status === "past_due"` (`:60-61`, live Stripe `status`).
- `currentCredits` from the live price lookupKey → `AI_CREDIT_PACK_CREDITS_BY_LOOKUP_KEY` (`:58-65`), not the local `subscription_credits_per_period` column.
- `currentPeriodEnd = currentSubscription?.currentPeriodEnd` (`:66`, live Unix timestamp), formatted via `prettyDate` (`aiSubscriptionHelpers.ts:4-6`).
- `isCurrent = currentSubscription?.plan?.id === tier.priceId` (`:278`, live).

The serializer was intentionally left intact (round-1-fixes.md D6): its `subscription_*` columns are no longer load-bearing for the active-subscription display (they remain serialized only for the separate `AccountBillingAiCredits.tsx` consumer of `#show`). This matches the analog's structure, where `currentOrganization.plan` persists locally but the active-subscription render comes from the live `currentSubscription`.

---

## Deviations found this round

NONE in the model + serializer segment.

---

## Structural verification (no fix needed)

- `OrganizationAiCreditPurchase#stripe_subscription` (`organization_ai_credit_purchase.rb:260-264`) is a VERBATIM structural match to the analog `Organization#stripe_subscription` (`organization.rb:474-478`): identical `return if stripe_subscription_id.nil?` guard and identical `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`. MATCH. (Living on the purchase row instead of the org = SANCTIONED #2/#4.)
- The active-subscription display now sources from the live Stripe subscription (the model's `#stripe_subscription` output, rendered raw by `customer_subscription` with no serializer) — structurally matching the analog. The serializer is no longer the display source.
- `subscription_status` enum (`:83-85`) and the `find_by(subscription_status: [:active, :past_due])` row scoping — SANCTIONED #4 (live-subscription endpoint scoped to the org's active/past_due subscription-kind purchase) and #2 (operate on the `OrganizationAiCreditPurchase` record).
- `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` / `ai_credit_subscription_plan_lookup_key?` / `ai_credit_top_up_lookup_key?` / `ai_credit_allocation_for_lookup_key` / `ai_credit_lookup_keys` (`:4-76`) — SANCTIONED #5 (`ai_credit_*` descriptor naming).
- `OrganizationAiCreditPurchaseSerializer` exposing the local `subscription_*` columns is an EXTRA relative to the analog (which renders raw Stripe with no serializer), but the serializer is no longer on the flow's display path and operating on the local row is SANCTIONED #2. Not a deviation.
- The model's other members (`charge_for_purchase`, `grant_credits`, `broadcast_event`, `broadcast_show_growl`, `finalize_stripe_payment`) belong to the one-off top-up / WWR analog, NOT the subscription-change flow under audit — out of this flow's scope.

## Out-of-segment note (NOT a model/serializer finding)

`#checkout` (`organization_ai_credit_purchases_controller.rb:19,31`) calls `OrganizationAiCreditPurchase.subscription_key?` and `.credit_amount_for_key`, which no longer exist on the model (renamed to `ai_credit_subscription_plan_lookup_key?` / `ai_credit_allocation_for_lookup_key`). This is a stale CALLER in the controller (routes-controller segment), not a model/serializer divergence from the analog, and `#checkout` is not part of the subscription-change flow. Flagged here only for the routes-controller agent's awareness; no model change is warranted (the model's renamed methods are the SANCTIONED #5 current names).
