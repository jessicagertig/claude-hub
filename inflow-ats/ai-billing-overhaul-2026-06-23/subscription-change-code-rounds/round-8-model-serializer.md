# Round 8 — MODEL + SERIALIZER segment audit

Segment: `app/models/organization_ai_credit_purchase.rb` (`#stripe_subscription`, the subscription lookup, enums, validations) and `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb`, compared against the analog `Organization` methods + render shapes in `traces/subscription-change-analog-trace.md`.

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Chain traced

- `app/models/organization_ai_credit_purchase.rb:260-264` (`#stripe_subscription`) → analog `app/models/organization.rb:474-478` (`Organization#stripe_subscription`); read directly from `app/models/organization.rb:468-483`.
- `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb:1-18` → analog: NO serializer on this flow. `customer_subscription` (trace items 6-7, `billing_controller.rb:606-618`) renders the RAW live Stripe object with no serializer.
- Serializer consumption: `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:9` (`#show`, render_one serializer — W3), `:100` (`#purchase_top_up`, serializer), `:205` (`#cancel`, serializer). `#customer_subscription` (`:420-437`) renders the LIVE `organization_ai_credit_purchase.stripe_subscription`, NOT the serializer.
- SCREEN path: `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:53-73` — `currentSubscription` from the live-Stripe `aiCreditCustomerSubscriptionData.subscription`; `isSubscribed` (`:59-60`) gates on `currentSubscription?.status === "active" || "past_due"` (LIVE Stripe `status`), NOT on the serializer's `subscription_status` enum column.

## Structural comparison

### `#stripe_subscription` — MATCH
ANALOG (trace item 7 / `organization.rb:474-477`): `return if stripe_subscription_id.nil?` then `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`.
OURS (`organization_ai_credit_purchase.rb:260-264`): identical guard + identical `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`.
Verdict: verbatim structural match. The only difference — `stripe_subscription_id` is the purchase row's column rather than the org's — is SANCTIONED #1/#4. This live-Stripe lookup is the fix for the original column-gating symptom; it is present and correct.

### `subscription_status` enum + persisted subscription columns — SANCTIONED
ANALOG: `Organization` carries `stripe_subscription_status` as a plain string column populated by `sync_with_stripe`; the change-flow DISPLAY does not read it (display reads the live Stripe object). OURS adds `enum subscription_status` (`organization_ai_credit_purchase.rb:83-85`, `_prefix: true`) and `subscription_current_period_start/end` columns on the purchase row.
Verdict: covered by SANCTIONED #2 (operates on the `OrganizationAiCreditPurchase` record, not org columns). NOT a deviation reaching the audited display: `AiCreditSubscription.tsx:59-60` derives `isSubscribed` from the live Stripe `currentSubscription.status`, not from this enum. The only backend consumer of the enum is the controller scoping `find_by(subscription_status: [:active, :past_due])` (SANCTIONED #4).

### Serializer existence + exposed attributes — off the audited path
ANALOG: no serializer on the subscription-change/current-tier display flow (`customer_subscription` renders the raw live Stripe object).
OURS: `OrganizationAiCreditPurchaseSerializer` exists, exposing the persisted-row columns (`id`, `kind`, `stripe_*`, `subscription_*`, `one_off_credits_granted`, `refunded_at`, `created_at`). Consumed ONLY by `#show` (W3 — `AccountBillingAiCredits.tsx`, a different view), `#purchase_top_up`, and `#cancel`. The audited subscription-change SCREEN (`AiCreditSubscription.tsx`) consumes the live-Stripe `customer_subscription` payload, never the serializer; its `subscription_status` attribute (`:12`) never reaches the audited gate.
Verdict: the serializer's existence and its `subscription_status` exposure are forced by the persisted-purchase-row data model (SANCTIONED #2 / whitelist W3). It does not feed the audited display and does not gate the active-subscription render on a local column.

### Plan-alias / sync model methods — SANCTIONED (absent by design)
ANALOG `Organization` carries `assign_plan_name_from_lookup_key`, `sync_with_stripe`, `stripe_customer_subscriptions`, plus `PlanFeatureGate` alias keying. OURS' purchase model has none of these.
Verdict: MISSING but SANCTIONED #3 (no `ValidateSubscriptionChange`/`PlanFeatureGate`/job-limit gate) and SANCTIONED #5 / W4 (credits-per-period is AI metadata with no Stripe-resident or alias-resident source; no plan-alias persistence).

## Deviations found (un-sanctioned): NONE

Every structural difference in the model + serializer segment is already covered by SANCTIONED #1/#2/#3/#4/#5 or whitelist W3/W4:
- `#stripe_subscription` is a verbatim structural copy of the analog (purchase-row column scoping = SANCTIONED #1/#4).
- The `subscription_status` enum / period columns = the persisted-purchase-row data model (SANCTIONED #2); they do not feed the audited live-Stripe-gated display.
- The serializer exists for the persisted-row endpoints (`#show` = W3, `#purchase_top_up`, `#cancel`), off the audited subscription-change display path; its `subscription_status` attribute never reaches the audited gate.
- Absent plan-alias/sync methods = SANCTIONED #3/#5 + W4.

deviation_count = 0
