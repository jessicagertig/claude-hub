# Round 6 — Segment: MODEL + SERIALIZER (model-serializer)

Audited: `app/models/organization_ai_credit_purchase.rb` (`#stripe_subscription`, subscription lookup, enums) and `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb`, against the analog `Organization` methods + render shapes in `traces/subscription-change-analog-trace.md`.

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`

## Chain traced

SCREEN → live-Stripe payload → model:
`AiCreditSubscription.tsx:53-73` (currentSubscription / isSubscribed / currentPriceObject / currentCredits / currentPeriodEnd / cancelAtPeriodEnd / cancelAt — all derived from `aiCreditCustomerSubscriptionData.subscription`)
→ `organization_ai_credit_purchases_controller.rb#customer_subscription:420-437` (`render json: { subscription: organization_ai_credit_purchase.stripe_subscription }`)
→ `organization_ai_credit_purchase.rb#stripe_subscription:260-264`
→ `Stripe::Subscription.retrieve({ id:, expand: ['items.data.price.tiers'] })` (stripe-ruby gem boundary — TERMINAL)

Analog counterpart chain:
`AccountBillingPlans.tsx:62-64` → `billing_controller.rb#customer_subscription:614` (`render json: { subscription: current_organization.stripe_subscription }`) → `organization.rb#stripe_subscription:474-477` → `Stripe::Subscription.retrieve(...)`.

## Structural comparison (row by row)

| Element | ANALOG (trace) | OURS | Verdict |
|---|---|---|---|
| `#stripe_subscription` guard | `return if stripe_subscription_id.nil?` (`organization.rb:475`) | `return if stripe_subscription_id.nil?` (`organization_ai_credit_purchase.rb:261`) | SAME |
| `#stripe_subscription` retrieve | `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` (`organization.rb:477`) | identical, scoped to purchase row's `stripe_subscription_id` (`organization_ai_credit_purchase.rb:263`) | SAME (scoping = SANCTIONED #1/#4) |
| current-sub display source | live Stripe object, no serializer (trace item 6, `:614`) | live Stripe object, no serializer (`customer_subscription:430`); SCREEN reads `aiCreditCustomerSubscriptionData.subscription` (`AiCreditSubscription.tsx:53-73`), gated on live `currentSubscription?.status` not the local column | SAME — original column-gating defect is FIXED |
| `subscription_status` enum | analog `Organization` has no such enum (uses `stripe_subscription_status` column) | `enum subscription_status {...} _prefix: true` on the purchase row; only consumer is controller `find_by(subscription_status: [:active, :past_due])` | DIFFERENT but SANCTIONED #2/#4 (purchase-row data model) |
| serializer existence | analog `Organization` has no serializer on this flow (raw live Stripe object) | `OrganizationAiCreditPurchaseSerializer` exists | EXTRA but SANCTIONED #2 / whitelist W3 (persisted purchase row; serves `#show`/`purchase_top_up`/`cancel`, NOT the subscription-change SCREEN) |
| serializer `subscription_status` field reaching SCREEN | n/a | exposed at serializer `:12`, but `AiCreditSubscription.tsx` imports `useAiCreditCustomerSubscription` (live Stripe), NOT the `#show`/serializer-backed `useOrganizationAiCreditPurchase` query — so it never reaches the audited SCREEN | does NOT reintroduce defect (W3) |
| plan-alias model methods (`assign_plan_name_from_lookup_key`, `sync_with_stripe`, `stripe_customer_subscriptions`) | present on analog `Organization` | absent from purchase model | MISSING but SANCTIONED #3 (no PlanFeatureGate/job-limit gate) + W4/SANCTIONED #5 (credits-per-period is AI metadata, no plan-alias persistence) |

## Result

No unsanctioned deviations in this segment. `OrganizationAiCreditPurchase#stripe_subscription` is an exact structural copy of `Organization#stripe_subscription` (guard + identical `Stripe::Subscription.retrieve` with identical `expand`). The subscription-change SCREEN display derives entirely from the live Stripe object returned by `customer_subscription`, matching the analog's structure; it does NOT gate on the local `subscription_status` column. The serializer and `subscription_status` enum are the persisted-purchase-row data-model differences already covered by SANCTIONED #2/#4 and whitelist W3, and the serializer is off the audited display path.

deviation_count: 0
