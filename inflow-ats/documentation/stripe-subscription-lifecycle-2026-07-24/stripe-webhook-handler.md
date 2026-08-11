# StripeWebhookHandlerJob — full event map

Source: `app/jobs/stripe_webhook_handler_job.rb` (498 lines), branch `attribution-work-qa` @ `a0d59115d`, read 2026-07-24. Companion doc: `organization-plan-callbacks.md` (same directory).

**Entry chain:** `Api::V1::Public::WebhooksController#stripe` (webhooks_controller.rb:13) verifies the signature via `Stripe::Webhook.construct_event`, enqueues `StripeWebhookHandlerJob.perform_later(event.id)`, and 200s. The job re-retrieves the event by id from the Stripe API (`Stripe::Event.retrieve`, line 20 — ActiveJob can't serialize `Stripe::Event`), rescuing four error classes with bare `return`. Then `handle_stripe_event(event)`.

**On every event:** `log_stripe_changes(event)` (line 50 and again in the `else` branch, 339) — reads `event.data.previous_attributes`, prints old/new per key. Logging only, but it ACCESSES the object; Jessica's warning applies: changing how attributes are accessed for logging can break handlers (Stripe objects raise on some undefined fields; the house-safe forms below).

**House-safe access forms used throughout (preserve these):**
- Metadata: `object.metadata&.[]('key')` — never `object.metadata.key`
- Nested price: `object.items&.data&.first&.price&.lookup_key` / `&.data&.[](0)&.price`
- Structure drift: `phase.respond_to?(:items)` vs `respond_to?(:plans)` — subscription-schedule phases differ by API version/environment (lines 358–379)

---

## Event-by-event

### `checkout.session.completed` (53–103)
1. **AI-credit-pack subscription branch** — `object.metadata&.[]('ai_credit_pack_subscription') == 'true'`: find `OrganizationAiCreditPurchase` by `stripe_checkout_session_id`, `update_columns(stripe_subscription_id:)` (update_columns is DELIBERATE — skips period validations until first invoice.paid; comment lines 61–63). `return`.
2. **Main branch:** find Organization by `stripe_checkout_session_id` → `organization.update(stripe_customer_id:, stripe_subscription_id:)`. **No status, no plan written here.**
3. `Stripe::Customer.update` (owner name / org description).
4. If `object.subscription.present? && mode == 'subscription'`: retrieve subscription; copy the checkout session's metadata onto it when the subscription's metadata is empty.
5. If `mode == 'setup'`: `organization.handle_checkout_setup_intent(object.setup_intent)` (organization.rb:640) — sets Stripe default payment method + `update(stripe_default_payment_method_on_file: true)`.
- Whole main branch wrapped in `rescue StandardError` (prints only).

### `customer.subscription.created` (105–109)
**Nothing.** Logs the plan lookup key. ("we do nothing here")

### `customer.subscription.updated` (111–167)
Fires on plan switches AND status transitions (including trialing→active at trial end).
1. **Credit-pack branch** — `OrganizationAiCreditPurchase.ai_credit_subscription_plan_lookup_key?(lookup_key)`: update the purchase row (lookup key, credits/period via `ai_credit_allocation_for_lookup_key`, status, period start/end, cancel_at_period_end), then `organization&.sync_ai_credits_with_stripe` (→ `SyncAiCreditPurchasesWithStripe`). Explicitly does NOT touch org main-plan fields or `sync_with_stripe`.
2. **Main-plan branch — guarded: only when `object.id == organization&.stripe_subscription_id`** (protects org fields from credit-pack events):
   - `organization.update(stripe_current_period_end_at:, stripe_subscription_status: object.status, stripe_cancel_at_period_end:)` — **this single `update` is what fires the after_commit callbacks**: trialing→active → TrialConvertedToPaid jobs; false→true on cancel_at_period_end → CancellationScheduled jobs (see companion doc).
   - `organization.stripe_update_default_payment_method(object.default_payment_method)` if present.
   - `organization.sync_with_stripe` — may additionally write `plan` (→ plan-change callback), period end, payment-method-on-file.
3. `rescue StandardError` around both branches.

### `customer.subscription.deleted` (169–215)
1. **Credit-pack branch:** purchase → `subscription_status: :canceled` + `subscription_canceled_at`; `sync_ai_credits_with_stripe`. Does NOT touch main-plan fields or fire main-plan jobs (comment 183–186).
2. **Main branch:**
   - `organization&.sync_with_stripe` — only if the deleted sub id matches `organization.stripe_subscription_id` (sync will flip status to 'canceled' → became_canceled callback → DisableAutomationsOnDowngrade).
   - `organization&.update_column(:subscription_canceled_at, ended_at)` — `update_column` is DELIBERATE: no callbacks, avoids double-firing.
   - `Notification::PaidSubscriptionDeletedJob` + `EngagementReport::GeneratorJob(trigger: 'subscription_canceled')`.
   - **Split-responsibility note (organization.rb:1154):** the cancellation NOTIFICATION lives here (webhook is more reliable and has `ended_at`); the automations-disable lives in the org callback (needs app logic hard to reach here).

### `customer.updated` (217–223)
`organization&.sync_with_stripe`. (Fires during checkout when the customer gets a default payment method — one of the ways status first lands on the org.)

### `invoice.paid` (225–309) — **the only event where real money is confirmed** (`object.amount_paid`)
Ordered early-return metadata branches — ORDER IS LOAD-BEARING:
1. `board_wwr_listing_id` → `BoardWwrListing#finalize_stripe_payment` + `create_on_wwr`. `return`.
2. `board_what_jobs_listing_id` → `BoardWhatJobsListing#finalize_stripe_payment` + `broadcast_event('what_jobs_listing_payment_received')` + `create_on_what_jobs`. `return`.
3. `organization_ai_credit_purchase_id` (one-off top-up) → purchase `finalize_stripe_payment` + `grant_credits(invoice:)`. `return`.
4. `Stripe::Subscription.retrieve(object.subscription)`; if its lookup key is a credit-pack key → `handle_subscription_credit_pack_invoice_paid` (475–497): persist `stripe_amount`/`currency`/`stripe_invoice_item_id` on the purchase; `billing_reason == 'subscription_update'` → `ApplyAiCreditUpgrade` else `ApplyAiCreditSubscription`.
5. **Main-plan branch:** `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` (the guard that predates all metadata branches being moved above it — pipeline rule 8's history) → `organization.update(stripe_current_period_end_at:)` → `stripe_update_default_payment_method` → `organization_ai_credit_balance&.reset_ai_credits`.
- **No notification fires here today. No status/plan writes here.** Three-tier rescue: `Stripe::StripeError`, `ActiveRecord::RecordInvalid/RecordNotFound`, `StandardError` — each logs with context.

### `charge.refunded` (310–314, handler 447–473)
`return unless charge.refunded == true`. AI-credit refunds ONLY: payment_intent → (invoice → subscription purchase) | (checkout session → one-off purchase) → `ApplyAiCreditRefund.call`. **Main-plan refunds are a no-op.**

### `customer.source.expiring` / `customer.source.created` (316–321)
No-ops (TODO comments only).

### `customer.subscription.trial_will_end` (323–328)
No-op (fires 3 days before trial end; commented-out ideas only).

### `subscription_schedule.updated` / `subscription_schedule.created` (329–331, handler 345–404)
`handle_subscription_schedule_downgrade`: guards (phases present, >1 phase, not 'released', org found) → compare phase[0]/phase[1] price ids (with the `items`-vs-`plans` `respond_to?` dance) → retrieve both `Stripe::Price`s → `downgrade_detected?` (nil or 'free' next key = downgrade; else tier index in `%w[free starter growth scale enterprise]`) → `Discord::NotifyDowngradeScheduledJob` + `EngagementReport::GeneratorJob(trigger: 'downgrade_scheduled')`.

### `ping` → logs PONG. **else** → logs "we don't handle that Stripe Event Yet".

---

## Conversion timing — the mechanism behind the ~2h differential

At trial end, Stripe flips the subscription `trialing → active` and emits `customer.subscription.updated` IMMEDIATELY — before any money moves. The main-plan branch writes `stripe_subscription_status: 'active'` → the org after_commit fires `Discord::NotifyTrialConvertedToPaidJob`. The invoice for the first paid period is created at the same moment but Stripe finalizes and charges it up to ~1–2 hours later → `invoice.paid` arrives then — the only proof of cash. If the card declines there is NO invoice.paid; instead a later `customer.subscription.updated` moves active → past_due. **So today's "Trial Converted to Paid" Discord message records trial expiry, not payment.**

## Distinguishing trial-conversion vs free→paid from the webhook alone

Signals available inside `invoice.paid` (the handler already retrieves the subscription at step 4):
- `object.amount_paid > 0` — real cash.
- `object.billing_reason` — `'subscription_create'` (first invoice of a new subscription), `'subscription_cycle'` (period renewal — the trial-end charge arrives as this), `'subscription_update'` (proration from a plan change).
- `stripe_subscription.trial_end` — present iff the subscription ever had a trial.

Provisional discrimination (verify against real event payloads before building on it):
- **Trial conversion** = first `invoice.paid` with `amount_paid > 0` on a subscription where `trial_end` is present (the charge lands as `billing_reason: 'subscription_cycle'` at the trial boundary).
- **Free→paid** in this app is usually the SAME subscription upgraded from the free_v2 price via the Billing Portal (`change_subscription_portal_session`) → proration invoice, `billing_reason: 'subscription_update'`, `amount_paid > 0`, no `trial_end`. A direct-to-paid checkout (no trial eligibility) lands as `billing_reason: 'subscription_create'` with `amount_paid > 0`.
- Local corroboration at charge time: the org's `plan` before sync (free_v2 → paid) and `stripe_subscription_status` history.

So yes — distinguishable from the webhook, primarily via `billing_reason` + `trial_end` + `amount_paid`, with the free→paid case identifiable by the proration path. The renewal case (`subscription_cycle` on an already-converted sub) must be excluded by "first paid invoice" logic — idempotency/first-occurrence tracking is required regardless.
