# AI Credit Subscription-Change — Analog Mirror + Naming Spec

Branch: `ai-feature-work-v5`. Status: PROPOSED — naming open to redline before implementation.

Goal: make the credit subscription-change flow mirror the battle-tested main-plan analog (`BillingController#change_subscription_portal_session`) **structurally, to the iota**, and rename the credit catalog/helpers to a generic, future-proof vocabulary. Source of truth for the structure: `ai-credit-subscription-change-analog-trace.md`.

Naming rules (from Jessica):
1. Generic terms drop "Pack." "Pack"/"top-up" refers to one-offs only (optional).
2. "Plan" refers to **subscriptions only** — a one-off is NOT a plan.
3. The lookup's purpose is to **resolve the plan/definition**; credits is an attribute, not the lookup's identity.
4. The analog uses "plan lookup key" vocabulary (`PLAN_LOOKUP_MAPPING`, `currentPlanLookupKey`) — mirror that spirit.

---

## Part A — Naming manifest (rename throughout: 39 sites, 4 files)

Files: `app/models/organization_ai_credit_purchase.rb`, `app/jobs/stripe_webhook_handler_job.rb`, `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`, `spec/models/organization_ai_credit_purchase_spec.rb`.

Descriptors: every name carries `ai_credit` so it cannot be confused with the main-plan vocabulary (`plan`, `subscription`, `lookup_key` all exist in main billing). Concept terms: an **AI credit subscription plan** (subscription entry) and an **AI credit top-up** (one-off entry).

| Now | Proposed | Rule |
|---|---|---|
| `CREDIT_PACKS_BY_LOOKUP_KEY` | `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` | generic, no "Pack"; `ai_credit` descriptor |
| `registered_keys` | `ai_credit_lookup_keys` | returns the catalog's keys; "registered" was meaningless carryover, dropped |
| `lookup_by_key(key)` | **DROP** — dead code, 0 call sites (only its own def at `organization_ai_credit_purchase.rb:31`) |
| `subscription_key?(key)` | `ai_credit_subscription_plan_lookup_key?(key)` | predicate on a lookup key; "plan" = subscription |
| `one_off_key?(key)` | `ai_credit_top_up_lookup_key?(key)` | top-up implies one-off; AI-credit-qualified |
| `credit_amount_for_key(key)` → integer | `ai_credit_allocation_for_lookup_key(key)` → integer | "allocation" = a fixed allotment (not "count", which implies a moving tally) |

---

## Part B — Lookup keys in the catalog

Add the new keys; KEEP the existing ones alongside so dev keeps working.

New (subscriptions = plans; top-ups = lookup keys):
- `plato_ai_credit_top_up_small`, `plato_ai_credit_top_up_medium`, `plato_ai_credit_top_up_large`
- `plato_ai_credit_subscription_small`, `plato_ai_credit_subscription_medium`, `plato_ai_credit_subscription_large`

Include all six (small/medium/large × 2) now even if only two are wired, so a third is codebase-ready. Plan limits TBD — these are the future plan keys.

Keep the existing keys (`ai_credit_pack_top_up_small`, `ai_credit_pack_top_up_large`, `ai_credit_pack_subscription_small_monthly`, `ai_credit_pack_subscription_large_monthly`) grouped under a code comment marking them **development keys** — kept so local dev keeps working, to be removed before production. The new `plato_ai_credit_*` keys are the production keys.

---

## Part C — Structural mirror (iota-for-iota, from the trace)

The analog flow: frontend fetches the live Stripe subscription → reads `items.data[0].id` + `priceId` → POSTs both → controller drops them straight into `subscription_update_confirm` flow_data. Mirror each piece:

1. **Live-subscription GET endpoint.** Mirror `BillingController#customer_subscription` (`billing_controller.rb:606`) + `Organization#stripe_subscription` (`organization.rb:474`: `Stripe::Subscription.retrieve(id:, expand: ['items.data.price.tiers'])`). Add an equivalent on the credit-pack side that retrieves by `purchase.stripe_subscription_id`. Route: `get` in the `ai_credit_purchases` collection (mirror `routes.rb:177`).
2. **Frontend hook** to fetch it — mirror `useStripeCustomerSubscription` / `useBilling.ts`.
3. **`AiCreditSubscription.tsx`** reads `items.data[0].id` + `priceId` from that live subscription and sends `{ priceId, subscriptionItemId, returnUrl }` — mirror `AccountBillingPlans.tsx:136` + `useBilling.ts:46-57`.
4. **`change_subscription_portal_session` controller** takes `params[:price_id]` + `params[:subscription_item_id]` directly into flow_data; resolves the lookup_key from `price_id` via `Stripe::Price.retrieve.lookup_key` (mirror the analog's resolution) and uses it for the credits lookup (`credit_amount_for_lookup_key`) — the credit-pack equivalent of the analog's plan lookup. **Remove** the server-side `Stripe::Subscription.retrieve` and the lookup-key-direct + `Stripe::Price.list` path.

### The one forced deviation
`flow_data.subscription` = `purchase.stripe_subscription_id` (the credit-pack purchase row), NOT `organization.stripe_subscription_id` (`billing_controller.rb:296`). Forced: the credit pack is a separate Stripe subscription tracked on the purchase row. Everything else mirrors exactly.

---

## Part D — Implementation strategy

1. Freeze this naming manifest (after redline).
2. One coherent implementation pass, worktree-isolated (safe to break) — rename throughout + structural mirror, driven by the frozen manifest. No parallel fan-out (naming consistency is the priority; parallel writers drift).
3. One verification pass: grep for straggler old names, run AI-credit specs, diff the structure against the trace doc.

OK to break mid-flight (Jessica's call) — priority is correct structure + consistent naming from a stable beginning.
