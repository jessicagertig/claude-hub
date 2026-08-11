# Round 7 — MODEL + SERIALIZER segment audit

Segment: `app/models/organization_ai_credit_purchase.rb` (`#stripe_subscription`, enums, validations) and `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb`, compared against the analog `Organization` methods + render shapes in `traces/subscription-change-analog-trace.md`.

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Chain traced

- `app/models/organization_ai_credit_purchase.rb:260-264` (`#stripe_subscription`) → analog `app/models/organization.rb:474-478` (`Organization#stripe_subscription`); analog supporting methods `:469-471` (`#stripe_customer`), `:481-482` (`#stripe_customer_subscriptions`).
- `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb:1-18` → analog: NO serializer on this flow. `customer_subscription` (trace items 6-7, `billing_controller.rb:606-618`) renders the RAW live Stripe object with no serializer.
- Consumption check: `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:420-437` (`#customer_subscription`, renders live `stripe_subscription`), `:4-13` (`#show`, renders serializer — W3), `:72-107` (`#purchase_top_up`, renders serializer), `:193-214` (`#cancel`, renders serializer).
- SCREEN path: `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts:165` (`/ai_credit_purchases/customer_subscription`) → `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:53-70` — `currentSubscription` from the live-Stripe payload; `isSubscribed` (`:59-60`) gates on `currentSubscription?.status === "active" | "past_due"` (LIVE Stripe `status`), NOT on the serializer's `subscription_status` enum column.

## Structural comparison

### `#stripe_subscription` — MATCH
ANALOG (trace item 7): `Organization#stripe_subscription` (`organization.rb:474-478`) — `return if stripe_subscription_id.nil?` then `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`.
OURS: `OrganizationAiCreditPurchase#stripe_subscription` (`organization_ai_credit_purchase.rb:260-264`) — identical guard + identical `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })`.
Verdict: verbatim structural match. The only difference — `stripe_subscription_id` is the purchase row's column rather than the org's — is SANCTIONED #1/#4. The live-Stripe lookup (the fix for the original column-gating symptom) is present and correct.

### `subscription_status` enum + persisted subscription columns — SANCTIONED
ANALOG: `Organization` carries `stripe_subscription_status` as a plain STRING column populated by `sync_with_stripe`; the change-flow DISPLAY does not read it (display reads the live Stripe object). OURS adds `enum subscription_status` (`organization_ai_credit_purchase.rb:83-85`) and `subscription_current_period_start/end` columns on the purchase row.
Verdict: covered by SANCTIONED #2 (operates on the `OrganizationAiCreditPurchase` record, not org columns) — the persisted-purchase-row data model. Crucially NOT a deviation that reaches the audited display: `AiCreditSubscription.tsx:59-60` derives `isSubscribed` from the live Stripe `currentSubscription.status`, not from this enum, so the enum does not reintroduce the local-column-gating defect.

### Serializer existence — off the audited path
ANALOG: no serializer on the subscription-change/current-tier display flow (`customer_subscription` renders the raw live Stripe object).
OURS: `OrganizationAiCreditPurchaseSerializer` exists but is consumed ONLY by `#show` (W3 — a different view, `AccountBillingAiCredits.tsx`), `#purchase_top_up`, and `#cancel` — none of which is the audited subscription-change current-tier SCREEN. The audited SCREEN (`AiCreditSubscription.tsx`) consumes the live-Stripe `customer_subscription` payload, never the serializer.
Verdict: the serializer's existence is forced by the persisted-purchase-row data model (W3 family / SANCTIONED #2). It does not feed the audited display and does not gate the active-subscription render on a local column. No deviation against the analog for THIS flow.

## Deviations found (un-sanctioned): NONE

Every structural difference in the model + serializer segment is already covered by SANCTIONED #1/#2/#4 or whitelist W3:
- `#stripe_subscription` is a verbatim match to the analog (purchase-row column scoping = SANCTIONED #1/#4).
- The `subscription_status` enum / period columns = the persisted-purchase-row data model (SANCTIONED #2); they do not feed the audited live-Stripe-gated display.
- The serializer exists for the persisted-row endpoints (`#show` = W3, plus `#purchase_top_up`/`#cancel`), off the audited subscription-change display path.

deviation_count = 0
