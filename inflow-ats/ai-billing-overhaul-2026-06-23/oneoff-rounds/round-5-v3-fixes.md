# One-Off Purchase — Round 5 Fixes (v3)

My two changes are confirmed present and minimal:
1. Controller: variant-aware `invoice_description` replacing the static `'AI Credit Top-Up'` literal in `create_top_up_checkout_session`'s `invoice_data.description`.
2. Frontend comment: corrected the stale `AiCreditPolicy#purchase_top_up?` reference in `AccountBillingAiCredits.tsx`.

Everything else in the diff is the pre-existing refactor that was already on the branch before this session (the controller two-action split, interactor, model `charge_for_purchase`/`broadcast_purchase_complete`, webhook AI branch, policy, routes, migration, schema, and all the specs).

Both findings are now resolved. Here is my summary.

---

## Summary of changes

Two findings were genuine; I fixed both. The findings' "context" section was correct: the working tree was already a substantial refactor matching the WWR/WhatJobs analog (two-action split `charge_top_up` + `create_top_up_checkout_session`, webhook keyed on `organization_ai_credit_purchase_id`, in-handler `finalize_stripe_payment` choke point, model `charge_for_purchase`, completion-tail `broadcast_purchase_complete`). That pre-existing refactor was already on the branch and was not my work.

### FIX 1 — Checkout-session invoice description (Finding #1, genuine deviation)
File: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (`create_top_up_checkout_session`)

The analog's checkout path computes a variant-aware `@final_invoice_description` (plan/upgrade + discount) before `Stripe::Checkout::Session.create` and passes it as `invoice_data.description`. Ours hardcoded `description: 'AI Credit Top-Up'`, while ours' own direct-charge model method (`charge_for_purchase`) already builds a per-pack description — so the two top-up paths were internally inconsistent and the checkout path diverged from the analog.

Changed the checkout-session `invoice_data.description` from the static literal to the same per-pack-name description the direct-charge model method builds:
```ruby
invoice_description = "AI Credit Top-Up — #{OrganizationAiCreditPurchase::AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY.dig(lookup_key, :name) || lookup_key}"
```
This is byte-identical to the model method's description (model uses the `stripe_price_lookup_key` column; controller uses the `lookup_key` local — same value). No frontend counterpart: an invoice description never travels to the frontend. No webhook change: the webhook reads only `organization_ai_credit_purchase_id` off the invoice.

### FIX 2 — Stale documentation reference (surfaced per anti-stale-reference rule)
File: `/Users/jessica/wrk/wrk-corp/inflow-ats.billing-bonanza/app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBillingAiCredits.tsx:30-31`

The comment referenced `AiCreditPolicy#purchase_top_up?` — that policy and action do not exist (verified: no `AiCreditPolicy` file; only `billing_policy.rb`, `organization_ai_credit_balance_policy.rb`, `organization_ai_credit_purchase_policy.rb`), and `purchase_top_up` was the old single-action name now split into `charge_top_up` + `create_top_up_checkout_session`. The comment also mischaracterized a frontend visibility rule as a backend gate. Rewrote it to state the real frontend condition (`subscription?.subscriptionStatus === "active"`) and the real backend authorization on the endpoint it calls (`BillingPolicy#checkout?`). Grepped `app/ spec/ config/ lib/ db/` for any other `purchase_top_up` / `AiCreditPolicy` references — none remain.

### WHITELIST — Finding #2 (metadata shape) NOT changed
WHITELIST: `invoice_data.metadata` missing `organization_id`: the finding's premise is factually wrong against the analog code. I read both analogs. The WWR analog's `invoice_data.metadata` is `{ board_wwr_listing_id, job_id }` (`board_wwr_listings_controller.rb:105-108`) and WhatJobs' is `{ board_what_jobs_listing_id, job_id }` (`board_what_jobs_listings_controller.rb:246-249`) — **neither carries `organization_id` in `invoice_data.metadata`**. The analog invariant is: the record id is in all three metadata blocks; `organization_id` is in `payment_intent_data.metadata` and top-level `metadata` only. Ours already satisfies this exactly:
- `payment_intent_data.metadata`: `organization_ai_credit_purchase_id` + `organization_id` ✓
- `invoice_data.metadata`: `organization_ai_credit_purchase_id` (analog's `job_id` is forced-absent — org-scoped, no job) ✓
- top-level `metadata`: `organization_ai_credit_purchase_id` + `organization_id` ✓

Adding `organization_id` to ours' `invoice_data.metadata` would make ours DIVERGE from the analog (whose invoice_data has no `organization_id`). The finding itself notes this key is "not load-bearing for the happy path." Since the rule is "make OURS match the analog," and ours already matches the analog's actual `invoice_data.metadata` shape, no change was made.

### Verification
- `ruby -c` on the edited controller: Syntax OK.
- Confirmed `OrganizationAiCreditPurchasePolicy#create?` → `is_org_admin?` exists (analog parity for `authorize purchase` in `charge_top_up`).
- All other items the findings examined (two-action split, params shapes, direct-charge auth, three-call Invoice pattern, webhook convergence, interactor grant-once + completion tail, frontend split hooks, Button `loading`/`disabled` props) were already analog-correct on the branch and were not touched.
