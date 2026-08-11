# Round 3 — MODEL + SERIALIZER segment

Segment: `app/models/organization_ai_credit_purchase.rb` (`#stripe_subscription`, the subscription lookup, enums) + `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb`.

Files traced (OURS), full chain to terminal:
`AiCreditSubscription.tsx:53-73` (live-subscription display derivation) → `useOrganizationAiCreditPurchase.ts` (`useAiCreditCustomerSubscription` `:168` GET `/ai_credit_purchases/customer_subscription`; `useOrganizationAiCreditPurchase` `:9` GET `/ai_credit_purchases`) → `organization_ai_credit_purchases_controller.rb` (`#customer_subscription:420-437`, `#show:4-13`) → `organization_ai_credit_purchase.rb` (`#stripe_subscription:260-264`, enums `:82-85`, lookup helpers `:59-76`) → `Stripe::Subscription.retrieve` (STRIPE boundary). Serializer `organization_ai_credit_purchase_serializer.rb:1-18` ← `render_one` in `#show`/`#purchase_top_up`/`#cancel` only. Cross-checked: `aiSubscriptionHelpers.ts:1-41` (display helpers — no local-column dependency), `db/schema.rb:965-993` (column ↔ attribute mapping), analog `organization.rb:469-518`, and prior rounds (round-1-model-serializer.md D1, round-1-fixes.md, round-2-model-serializer.md).

ANALOG (trace items 6/7/9): the active-subscription display derives ENTIRELY from the LIVE Stripe subscription object. `customer_subscription` (`billing_controller.rb:606-618`) renders the raw `current_organization.stripe_subscription` (`Organization#stripe_subscription` `organization.rb:474-478` → `Stripe::Subscription.retrieve`), with NO serializer. There is no analog serializer in this flow.

---

## Status vs prior rounds

Round-1 D1 (the named symptom — active-subscription DISPLAY sourced from the serialized LOCAL `subscription_status` / `subscription_credits_per_period` / `subscription_current_period_end` columns instead of the live Stripe object) was FIXED at the source. Round 2 found NONE. Round 3 independently re-traced and confirms the fix holds:

- `AiCreditSubscription.tsx:53-55` `currentSubscription = aiCreditCustomerSubscriptionData ? aiCreditCustomerSubscriptionData.subscription : null` — the live Stripe object (from `#customer_subscription`), mirroring the analog `AccountBillingPlans.tsx:62-64`.
- `isSubscribed = currentSubscription?.status === "active" || currentSubscription?.status === "past_due"` (`:59-60`, live Stripe `status`).
- `currentSubscriptionTier`/`currentCredits` (`:66-70`) derive from the live `currentPriceObject.lookupKey` matched against the Stripe-prices `subscriptionTiers` — not the local `subscription_credits_per_period` column.
- `currentPeriodEnd = currentSubscription?.currentPeriodEnd` (`:71`), `cancelAtPeriodEnd`/`cancelAt` (`:72-73`), `isCurrent = currentSubscription?.plan?.id === tier.priceId` (`:287`) — all live Stripe.

The serializer is no longer on the active-subscription display path; the display sources from the live Stripe object rendered raw by `#customer_subscription`.

---

## Deviations found this round

NONE in the model + serializer segment.

---

## Structural verification (no fix needed)

- `OrganizationAiCreditPurchase#stripe_subscription` (`organization_ai_credit_purchase.rb:260-264`) is a VERBATIM structural match to the analog `Organization#stripe_subscription` (`organization.rb:474-477`): identical `return if stripe_subscription_id.nil?` guard and identical `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`. MATCH. (Operating on the purchase row's `stripe_subscription_id` instead of the org's = SANCTIONED #1/#4.)
- OUR `#customer_subscription` (`controller:420-437`) renders the raw `organization_ai_credit_purchase.stripe_subscription` with NO serializer — matches the analog `#customer_subscription` render shape (raw live Stripe object, no serializer). MATCH.
- `subscription_status` enum (`:83-85`) + the `find_by(subscription_status: [:active, :past_due])` row scoping used by the controller lookups — SANCTIONED #4 (live-subscription endpoint scoped to the org's active/past_due subscription-kind purchase) and #2 (operate on the `OrganizationAiCreditPurchase` record). The enum's existence/storage is not a model deviation; the lookup gating lives in the controller (other segment), and is itself sanctioned.
- `kind` enum (`:82`) supplies the `.subscription` scope used by the lookups — domain data-model structure, SANCTIONED #2.
- `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` / `ai_credit_subscription_plan_lookup_key?` / `ai_credit_top_up_lookup_key?` / `ai_credit_allocation_for_lookup_key` / `ai_credit_lookup_keys` (`:4-76`) — SANCTIONED #5 (`ai_credit_*` descriptor naming). The analog has no local price↔credits table (it round-trips through Stripe); OURS' local table is the AI-credit data-model difference, SANCTIONED #2/#5.
- `OrganizationAiCreditPurchaseSerializer` (`:1-18`) exposing the local `subscription_*` columns is an EXTRA relative to the analog (which renders raw Stripe with no serializer in this flow), but the serializer is NOT on the flow's active-subscription display path and operating on the local row is SANCTIONED #2. All 13 attributes map to real columns (`db/schema.rb:965-993`). Not a deviation.
- The model's other members (`charge_for_purchase`, `grant_credits`, `broadcast_event`, `broadcast_show_growl`, `finalize_stripe_payment`) belong to the one-off top-up / WWR analog, NOT the subscription-change flow under audit — out of this flow's scope.
