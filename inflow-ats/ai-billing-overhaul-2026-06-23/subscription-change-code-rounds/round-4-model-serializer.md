# Round 4 — MODEL + SERIALIZER segment audit

Segment: `app/models/organization_ai_credit_purchase.rb` (`#stripe_subscription`, subscription lookup, enums) and `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb`, compared to the analog `Organization` methods + render shapes in `traces/subscription-change-analog-trace.md`.

Files traced:
`organization_ai_credit_purchase.rb` → `organization.rb` (analog `#stripe_subscription` :474-478, `#stripe_customer` :469-472) → `organization_ai_credit_purchases_controller.rb` (consumers: `#customer_subscription` :420-437, `#change_subscription_portal_session` :233-281) → `db/schema.rb` (:965-993) → `subscription-change-analog-trace.md` (items 6, 7, 22; trace lines 24, 125).

## Verdict: 0 deviations against the analog (excluding sanctioned/whitelisted)

### Confirmed MATCHES (no finding)

1. **`OrganizationAiCreditPurchase#stripe_subscription`** (`organization_ai_credit_purchase.rb:260-264`) is structurally IDENTICAL to the analog `Organization#stripe_subscription` (`organization.rb:474-478`, trace item 7 / line 24):
   - same guard `return if stripe_subscription_id.nil?`
   - same terminal `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })` (STRIPE terminal).
   This is the live-subscription model method the change-flow display ultimately depends on. EXACT match — the model provides the live-Stripe display path the analog uses, NOT a local-column gate.

2. **`#stripe_subscription_id` column** exists (`db/schema.rb:968`), matching the analog's `Organization#stripe_subscription_id` column (trace item 8). The change flow reads it the same way.

3. **The model does NOT reintroduce the column-gating defect.** The user-facing symptom (active subscription not displaying because OURS gated on a local `subscription_status` column) is NOT present at the model layer: the change-flow display terminal is `stripe_subscription` (live Stripe object). The local `subscription_status` enum (`:83-85`) is used only for row-scoping the active/past_due purchase (`organization_ai_credit_purchases.subscription.find_by(subscription_status: [:active, :past_due])`) — SANCTIONED #4 (live-subscription endpoint retrieves by `purchase.stripe_subscription_id`, scoped to the active/past_due subscription-kind purchase). Not a display gate; not a deviation.

4. **Serializer is NOT on the subscription-change SCREEN path.** The analog serves the current-subscription display exclusively via `customer_subscription` rendering the RAW live Stripe object, no serializer (trace item 6, line 22 / line 24). OURS' `customer_subscription` (`organization_ai_credit_purchases_controller.rb:430`) likewise renders `organization_ai_credit_purchase.stripe_subscription` RAW (no serializer). `Api::V1::OrganizationAiCreditPurchaseSerializer` is consumed only by `#show` (W3-whitelisted, different view `AccountBillingAiCredits.tsx`), `#purchase_top_up`, and `#cancel` — all outside the audited subscription-change flow. Its attribute list therefore has no analog counterpart to match against in this flow and is not a deviation. (The analog `Organization` has no serializer in this flow either.)

5. **`ai_credit_*` naming on the model** (`AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY`, `ai_credit_subscription_plan_lookup_key?`, `ai_credit_allocation_for_lookup_key`, `ai_credit_lookup_keys`) — SANCTIONED #5 (ai_credit_* descriptor naming with these exact identifiers). Not flagged.

## NOTE (NOT a model/serializer deviation — belongs to the controller segment)

The model defines the SANCTIONED post-rename names `ai_credit_subscription_plan_lookup_key?` (`:63`) and `ai_credit_allocation_for_lookup_key` (`:71`) — correct per SANCTIONED #5. However the controller's `checkout` action calls the OLD pre-rename names that DO NOT exist on the model:
- `OrganizationAiCreditPurchase.subscription_key?` (`organization_ai_credit_purchases_controller.rb:19`)
- `OrganizationAiCreditPurchase.credit_amount_for_key` (`organization_ai_credit_purchases_controller.rb:31`)

Both would raise `NoMethodError` at runtime. This is a stale-caller bug in the `checkout` (subscribe/create) action — the MODEL side is correct (uses the new sanctioned names). It is NOT in the audited subscription-CHANGE flow (`change_subscription_portal_session` / `customer_subscription` / `update_payment_method_and_subscription_portal_session` / `continue_change_subscription_portal_session` do not call these). Recorded here for the controller-segment fix agent; it is not a deviation of the model or serializer against the analog.
