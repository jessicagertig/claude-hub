# Round 4 — Fix Log (AI-credit subscription-change flow, Flow 5)

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza`
Audit input: `subscription-change-rounds/round-4-audit.md` → **DEVIATION COUNT: 0**

## Result: NO FIXES NEEDED — audit independently re-verified, zero deviations confirmed.

The round-4 audit reported zero deviations. Because this is round 4 and the original
ticket described the four actions as MISSING, I did not trust the bare count — I
independently re-audited the CURRENT code against the ANALOG (`BillingController`) and the
sanctioned/whitelist lists. Findings below.

### Files traced
`config/routes.rb` → `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (OURS)
↔ `app/controllers/api/v1/billing_controller.rb` (ANALOG)
→ `app/models/organization_ai_credit_purchase.rb`
→ `app/javascript/shared/queryHooks/useOrganizationAiCreditPurchase.ts`
→ `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx`

### Presence verification — all four actions + helper exist (re-implemented in a prior round)
- `change_subscription_portal_session` — OURS :233 ↔ ANALOG :268
- `update_payment_method_and_subscription_portal_session` — OURS :290 ↔ ANALOG :331
- `continue_change_subscription_portal_session` — OURS :351 ↔ ANALOG :385
- `customer_subscription` — OURS :426 ↔ ANALOG :606
- `determine_price_id` (private) — OURS :454 ↔ ANALOG :630

### Routing — all four mounted on the AI-credit resource (no shadowing)
`config/routes.rb:190` `resource :ai_credit_purchases, controller: 'organization_ai_credit_purchases'`
collection block (lines 195-200) routes all four. The `billing` resource block (160-185) is the
ANALOG's own and does not shadow ours (distinct resource).

### Model identifiers — all present (verified by grep on the model)
- `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` (:4)
- `ai_credit_subscription_plan_lookup_key?` (:63)
- `ai_credit_allocation_for_lookup_key` (:71)
- `enum kind: { one_off: 0, subscription: 1 }` (:82) → provides the `.subscription` scope used by all four actions
- `enum subscription_status: { active: 0, past_due: 1, ... }` (:83) → `find_by(subscription_status: [:active, :past_due])`
- `def stripe_subscription` (:260) → used by `customer_subscription`

### Structural diff vs analog — every deviation accounted for by an existing list entry

| Aspect | ANALOG | OURS | Status |
|---|---|---|---|
| Subscription source | `current_organization.stripe_subscription_id` | `organization_ai_credit_purchase.stripe_subscription_id` (scoped `.subscription` active/past_due) | SANCTIONED #1/#2/#4 |
| Job-limit gate | `ValidateSubscriptionChange.call` in `change_*` and `continue_*` | absent | SANCTIONED #3 |
| `subscription_item_id` resolution | `params[:subscription_item_id]` (required, raises if blank) | `params[:subscription_item_id].presence \|\| Stripe::Subscription.retrieve(...).items.data.first.id` | SANCTIONED #1/#4 (frontend still posts it; reconstruction is fallback) |
| `continue_url` base path | `/api/v1/billing/...` | `/api/v1/ai_credit_purchases/...` | WHITELIST W2 |
| `determine_price_id` else-branch | `Stripe::Price.list` → `DEFAULT_PRICE_LOOKUP_KEY` | `raise 'Price ID is missing.'` | WHITELIST W1 |
| Descriptor naming | main-plan | `ai_credit_*` / `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` etc. | SANCTIONED #5 |

All other lines (option hashes, `flow_data` shapes, `return_url` construction, rescue ladders,
`PosthogTrackJob` call, `customer_subscription` nil-handling) are byte-faithful to the analog
modulo the AI-credit subscription source and naming.

### Frontend param-shape note (re: original ticket concern)
The ticket said the frontend sends only `{ stripePriceLookupKey, returnUrl }`. CURRENT frontend
(`useOrganizationAiCreditPurchase.ts:46,75`) posts `{ priceId, subscriptionItemId, returnUrl }`
(camelCase → snake_case server-side), and `AiCreditSubscription.tsx:148-149,153-154` populates
both `priceId: tier.priceId` and `subscriptionItemId: currentSubscriptionItemId`. OURS reads
`params[:price_id]` / `params[:subscription_item_id]` / `params[:return_url]` accordingly, with
the `Stripe::Subscription.retrieve` reconstruction as a blank-fallback. Consistent with
SANCTIONED #1/#4; no mismatch.

## Per-deviation disposition
No deviations remained to dispose of. Nothing FIXED, nothing newly WHITELISTED, nothing
CANNOT-MATCH. The two existing whitelist entries (W1, W2) and five sanctioned deviations (#1–#5)
fully account for every divergence from the analog. AGENT-WHITELIST-subscription-change.md was
NOT appended to (no new forced deviation discovered).
