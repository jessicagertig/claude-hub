# Organization plan/status callbacks + sync_with_stripe — full map

Source: `app/models/organization.rb` (1739 lines), `app/services/stripe/subscription_status_checker.rb`, `app/controllers/api/v1/billing_controller.rb`, read 2026-07-24 on `attribution-work-qa` @ `a0d59115d`. Companion doc: `stripe-webhook-handler.md`.

## Callback registry (organization.rb:51–58)

| Hook | Method | What |
|---|---|---|
| `after_create` | `create_ai_credit_state_if_needed` | Synchronous (deliberately NOT after_commit — comment 51–54); `find_or_create_by` balance, seed allocation. Deliberately unguarded to keep the association cache clean (comment 193–199). |
| `after_commit on: :create` | `complete_setup_workers` (180) | `create_careers_page` (main thread), `OrgSetupJob` (→ `complete_setup`: settings, process template, clearbit, categories, templates, `create_stripe_customer`, `set_default_plan` — `update_columns(plan: 'plan_simple_ats_free')`, NO callbacks — zapier key, partner source), `NotifyNewOrganizationJob` (Slack), `Discord::NotifyNewOrganizationJob` |
| `before_update` | `handle_before_update` (1012) | `update_column` writes: website_url normalize, linkedin/x change timestamps |
| `after_commit on: :update` | `handle_after_commit_on_update` (1023) | The five handlers below, in this order |

## The five update handlers (order as invoked, 1024–1028)

### 1. `handle_subscription_status_change_after_commit` (1103–1156)
Gate: `saved_changes.key?('stripe_subscription_status')`. Sequential non-exclusive `if`s — ORDER AND SHAPE ARE LOAD-BEARING:
1. `subscription_became_past_due_after_commit?` (≠past_due → past_due) → `handle_stripe_subscription_past_due`: `StripeSubscriptionMailer.past_due` + `Notification::PaidSubscriptionPastDueJob`.
2. `current_status == 'active'` → `update_column(:can_send_bulk_messages, true)`, `update_column(:can_enable_linkedin, true)` (update_column: no callback re-entry).
3. `past_due → active` → PastDueSubscriptionPaid jobs (Slack + Discord).
4. `subscription_started_trial_after_commit?` — **exactly `nil → 'trialing'`** → **FreeTrialStarted jobs (Slack + Discord)** + `organization_ai_credit_balance&.reset_ai_credits`.
5. `trial_converted_to_paid_after_commit?` — **exactly `'trialing' → 'active'`** → **TrialConvertedToPaid jobs (Slack + Discord)**. ⚠️ This is the mis-timed "conversion" signal: it fires when Stripe flips status at trial end, ~1–2h BEFORE `invoice.paid` proves cash, and fires even if the card later declines (see companion doc).
6. `subscription_became_active_after_commit?` ([nil, 'canceled', 'incomplete'] → ['active','trialing']) → log line only ("No longer sending subscription created notifications").
7. `subscription_became_canceled_after_commit?` (≠canceled → canceled) → `DisableAutomationsOnDowngrade` only. The cancellation NOTIFICATION deliberately lives in the webhook's `subscription.deleted` branch instead (comment 1154: webhook is more reliable + has `ended_at`; automations logic is easier here).

### 2. `handle_plan_change_after_commit` (1072–1101)
Gate: `saved_changes.key?('plan')` and values differ.
- `Notification::SubscriptionPlanChangedJob` + `Discord::NotifySubscriptionPlanChangedJob` — **ONLY when `stripe_subscription_status` did NOT also change in the same commit** (1087). This is today's de-facto free→paid signal: a portal upgrade of the free_v2 subscription changes `plan` while status stays 'active'.
- `log_assigned_free_plan_event` (1231): if `assigned_free_plan?` (now on free_v2, coming from plan_no_plan / plan_simple_ats_free / nil, or via cancellation) → `CreateSubscriptionEvent.call(event_type: created_at > 15.minutes.ago ? 'assigned_free_plan_on_creation' : 'assigned_free_plan', from_plan:, to_plan:)`.
- `DisableAutomationsOnDowngrade` with previous status/plan.

### 3. `handle_name_change_after_commit` → `update_stripe_customer`.
### 4. `handle_linkedin_company_id_change_after_commit` → LinkedinCompanyIdChanged jobs (Slack + Discord).
### 5. `handle_cancellation_scheduled_after_commit` (1045) — `stripe_cancel_at_period_end` exactly `false → true` → CancellationScheduled jobs (Slack + Discord) + `EngagementReport::GeneratorJob(trigger: 'cancellation_scheduled')`.

## The SubscriptionEvent ledger — smaller than it looks

`SubscriptionEvent` (app/models/subscription_event.rb): enum `assigned_free_plan_on_creation, assigned_free_plan, converted_to_paid, canceled_subscription, downgraded_to_free, upgraded_plan, downgraded_plan`. **The ONLY production producer is `log_assigned_free_plan_event`** → `CreateSubscriptionEvent` (interactor; 5-minute same-params dedupe). `converted_to_paid`, `canceled_subscription`, `downgraded_*`, `upgraded_plan` are defined but NEVER created anywhere. The ledger currently records free-plan assignments only.

## Every writer of `stripe_subscription_status` (= callback trigger set)

1. Webhook `customer.subscription.updated` main-plan branch (guarded by sub-id match) — `update`, fires callbacks.
2. `sync_with_stripe` (below) — `update` with only-changed keys, fires callbacks.
3. `Api::V1::BillingController#customer` (568–604): on every billing-page customer GET, for `paid_plan?` orgs, re-reads the customer's subscriptions and `update(stripe_subscription_status: ...)` — a third status writer most people forget. The same action also enqueues `SyncWithStripeJob` on EVERY call (571).
4. Test-env helpers (`setup_*_test_subscription`, 787–876) — Cypress only.
5. `stripe_delete_customer` / `destroy_stripe` — nils/cancels (non-production / console).

Writers of `plan`: `sync_with_stripe` (via `assign_plan_name_from_lookup_key`), `set_default_plan` (update_columns — silent), `give_away_for_time` (`plan_simple_ats_paid!` — fires plan callback; 'free_plan' sentinel subscription id), admin/console paths.

## `sync_with_stripe` (organization.rb:521–611) — the reconciler ("third source")

Guards: `stripe_customer_id.present?`; customer not deleted. Reads `stripe_customer_subscriptions` (`Stripe::Subscription.list, limit: 3, status: 'all'`), REJECTS subs whose lookup key contains `credit` or `plato`, picks `trialing` first, then `active`, then `[0]`. Builds attributes: `stripe_subscription_id`, `stripe_subscription_status`, `stripe_current_period_end_at` (only when a subscription exists), and ALWAYS `plan` = `assign_plan_name_from_lookup_key` (nil subscription → `'plan_simple_ats_free'`; unknown/nil lookup key → keep current plan). Sets default payment method when customer lacks one; `stripe_default_payment_method_on_file`. **Diffs each attribute against current and updates ONLY changed keys in one `update`** → one after_commit batch. On a plan change with a balance: `update_columns(monthly_credits_remaining: new allocation)` (full re-grant).

Callers: webhook (`subscription.updated` main branch, `subscription.deleted` on id match, `customer.updated`); `BillingController#create_subscription` (existing-sub short-circuit AND post-create), `#change_subscription` (unused), `#sync_with_stripe` endpoint (frontend calls it on checkout return); `SyncWithStripeJob` (enqueued by every `#customer` GET); `create_free_stripe_subscription_for_new_org` (organization.rb:235 — **no production caller found in app/, lib/, or db/**; console-only as of this read).

## How a trial starts (end-to-end)

`BillingController#checkout` (30–130): Checkout Session with `subscription_data.trial_period_days: TRIAL_PERIOD_DAYS` when `eligible_for_free_trial?` — organization.rb:699: status blank OR (`free_plan_with_one_job?` AND lifetime `Stripe::Invoice.list... amount_paid` sum == 0 — an API-paging loop over up to 100 invoices). Fires PostHog `subscription_checkout_started`. After payment, `checkout.session.completed` stores customer/subscription ids (no status); status `'trialing'` lands on the org via whichever reconciler runs first — the frontend's sync on return, `customer.updated`'s sync, or `#customer`'s SyncWithStripeJob — and that `nil → 'trialing'` transition fires FreeTrialStarted.

## `Stripe::SubscriptionStatusChecker` — CRITICAL-marked class

File carries an all-caps "CRITICAL BUSINESS LOGIC — HANDLE WITH EXTREME CARE" header. `PLAN_LOOKUP_MAPPING` (substring match, `.find` over keys — ordering of the hash matters for overlapping substrings), `PAID_PLANS`, `FREE_PLANS_WITH_ONE_JOB` (free, free_v2). `in_good_standing?`: (paid or free-with-one-job plan) AND sub id present AND `stripe_current_period_end_at + 2.days > now` AND status in `['trialing','active','incomplete','past_due','unpaid']` — 'canceled' and 'paused' deliberately excluded. Test-env sentinels: `test_subscription_*` ids and `'free_plan'`.

## Existing server-side PostHog events in this area (all via `PosthogTrackJob`)

- `subscription_checkout_started` — `#checkout` (billing_controller.rb:115)
- `paid_subscription_created` — `#create_subscription` only (213; the legacy payment-method-on-file path, NOT the checkout path)
- `change_subscription_stripe_portal_opened` — `#change_subscription_portal_session` (311)
- (signup funnel events live in registrations/omniauth controllers)

## Delicacy notes (why "minor" changes break this)

- The status handlers key on EXACT transition pairs from `saved_changes` — reordering ifs or widening a pair changes which notifications fire; several `if`s are non-exclusive by design (a nil→active jump hits #2 and #6 but neither trial handler).
- `update` vs `update_column`/`update_columns` choices are all deliberate: `update_column(:subscription_canceled_at, ...)` in the webhook avoids re-firing status callbacks; `set_default_plan` uses `update_columns` so initial plan assignment is silent; `sync_with_stripe`'s only-changed-keys diff keeps callback firing minimal and batched.
- Stripe object attribute access must stay in the house-safe forms (`&.[]`, `respond_to?` structure checks) — see companion doc.
- The webhook's credit-pack guards (`ai_credit_subscription_plan_lookup_key?`, sub-id match) are what keep AI-credit subscriptions from clobbering main-plan fields; any new branch must respect them.
- Status can be written from THREE live paths (webhook, sync, billing#customer) that race within seconds of each other; the saved_changes gates make the callbacks fire exactly once for a given transition regardless of which writer lands it, and `CreateSubscriptionEvent` adds a 5-minute dedupe on top for the ledger.
