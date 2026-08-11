# Slice: AI Interactors (`app/interactors/`)

All 16 files are NEW (no pre-existing interactor was modified). Two concerns:
(A) AI-summary generation orchestration; (B) AI-credit billing ledger + notifications.
The ledger model `AiCreditBalanceTransaction` and read-model `OrganizationAiCreditBalance`
are shared plumbing every credit interactor writes to; the bucket columns
(`daily/monthly/addon_subscription/addon_credits_remaining`) are the source of truth.

---

## A. AI SUMMARY GENERATION ORCHESTRATION

### `validate_ai_summary_generation.rb` (single-send / manual path gate)
Gates whether a summary can be generated. Fails (user-visible toast strings) when:
- Job application nil / Organization nil
- Flipper `AI_APPLICANT_SUMMARY` not enabled → "AI summaries are not enabled for this organization."
- No resume (`has_resume` false) → "No resume uploaded for this candidate."
- No AI credits (`organization.ai_credits_available?` false) → "Your organization is out of AI credits. Purchase more credits..."
- Job has no description → "This job needs a description before Plato can review candidates. Add one in Job Setup."

Textract handling (drives async waiting UX):
- No `latest_textract_result` → enqueues `SubmitResumeToTextractJob`, sets `textract_pending=true`.
- Textract text ready → `textract_pending=false` (proceed to generate).
- Latest textract FAILED: if a *previous* textract also failed → fails "Resume processing has failed. Try uploading a different resume file." Otherwise re-submits textract and sets `textract_pending=true`.
- Otherwise (still processing) → `textract_pending=true`.
- NOTE: many `ap` debug-print statements left in (console noise, harmless).

### `validate_auto_ai_summary_generation.rb` (auto-trigger path gate)
Same credit/flipper/resume/description gates as above, but org derived from
`job_application.job.organization`. Always sets `textract_result=nil` + `textract_pending=true`
(auto path runs right after textract was just kicked off, so it's never ready yet).

### `create_ai_summary_generation.rb` (single-send)
Creates/returns the `AiJobApplicationSummary`:
- Reuses an existing non-failed, non-stale summary (latest by created_at) if present.
- If that reuse candidate's `textract_result_id` != job_application's `latest_textract_result.id`,
  marks it `stale: true` (via `update_columns`) and builds fresh.
- `textract_pending` → builds summary `status: :textract_processing` (waits, no job enqueued).
- Else builds `status: :pending`, saves, and enqueues `GenerateAiJobApplicationSummaryJob`
  (keyed by `textract_result_id` + `requesting_organization_user_id`).
- `requested_by_organization_user_id` set from `context.user.current_organization_user.id`.
- `ap` debug prints present.

### `create_bulk_ai_summary_generation.rb` (bulk)
Bulk analog. Deliberately DIFFERS from single-send: no `textract_pending` branch (bulk defers
pending-textract candidates upstream, so status is always `:pending`) and does NOT enqueue
`GenerateAiJobApplicationSummaryJob` (the bulk job drives generation inline — enqueuing here
would double-process). Same stale-reuse logic.

### `queue_bulk_ai_summary_jobs.rb` (bulk fan-out)
Entry point for "Generate AI summaries" bulk action. Behavior:
- Fails with toast if Flipper `AI_APPLICANT_SUMMARY` off, or `organization.ai_credits_available?` false.
- Splits input IDs: `ready_ids` (resume + textract), `pending_textract_ids` (resume, no textract),
  rest silently skipped (no resume). Kicks `SubmitResumeToTextractJob` for pending-textract ones.
- Unless `context.rescore_requested`: drops candidates whose `AiJobApplicationSummaryStatus` is
  `current` (already have a succeeded summary) — removed from BOTH working set and skipped count
  (never reported). Rescore path keeps them (re-generates).
- Drops candidates already `processing` in `BulkAiSummaryJobApplication` (claimed by another batch).
- If working set empty → `queued_count=0`, `skipped_count=input size`, `any_textract_pending` flag.
- Else generates unique `bulk_job_id`, per-row `BulkAiSummaryJobApplication.create` claims
  (rescue `RecordNotUnique` = lost claim race → treated as skipped), then enqueues one
  `BulkGenerateAiSummariesJob` with the claimed IDs, hiring_stage_id/job_id from first candidate,
  `skipped_count`, and `kind` (default `'single_hiring_stage'`).
- Sets `queued_count`, `skipped_count`, `any_textract_pending` (drive the response toast messaging).

### `find_or_create_ai_job_application_summary_status.rb`
Maintains the one-to-one `AiJobApplicationSummaryStatus` read-model row that drives the
candidate-list AI badge/score display. Resolves status from summary state:
- `regenerating` — generation in progress AND a prior succeeded summary exists; copies
  denormalized `ai_job_application_summary_id/score_percentage/headline/integrated_role_analysis`
  from the latest succeeded summary (so prior review stays visible during regen).
- `current` — latest summary succeeded; copies same denormalized fields.
- `initial_summary_pending` — generation in progress, no prior succeeded; stores latest summary id only.
- `none` — latest failed or no summary (NOTE: status enum deliberately has NO `failed` value —
  failures render off the summary, not this row; see project rule #20).
Updates existing row or builds a new one; `rescue ActiveRecord::RecordNotUnique` reloads (companion
record already eagerly created via JobApplication callback). Shared surface: reads/writes the
denormalized columns the frontend candidate list consumes.

---

## B. AI-CREDIT BILLING LEDGER + NOTIFICATIONS

Consumption/bucket order (defined in `create_ai_credit_balance_transaction.rb#determine_bucket`):
**daily → monthly → addon_subscription → addon** (expiring buckets first, never-expire last).

### `create_ai_credit_balance_transaction.rb` (consumption / debit)
`CREDIT_COST=1`. On each AI summary generation debits 1 credit from the first bucket with
`>= 1` remaining. Fails `:missing_balance` (no balance row) or `:insufficient_credits`
(all buckets empty). Writes `entry_type: :ai_summary_usage_debit`, `amount: -1`.

### `grant_ai_credits.rb` (admin/support manual grant)
Adds credits to `addon` bucket (never-expire) with `entry_type: :admin_credit`. Validates
positive amount + non-blank reason + balance exists. Captures `granted_by_user_id` in metadata.
Resets `sent_low/zero_notification_since_increase` flags (via `update_columns`) so notifications re-fire.

### `reset_ai_credits.rb` (monthly anniversary reset)
Called on plan `invoice.paid`. In a txn: zeros out leftover monthly bucket (`plan_monthly_reset_debit`,
only if positive), grants new period allocation (`plan_monthly_allocation_credit`, override beats
`PlanFeatureGate#monthly_ai_credit_allocation`), sets `last_reset_at`, clears notification timestamps
and dedup flags. `addon`/`addon_subscription` buckets intentionally untouched. Exposes `context.balance`.

### `reset_daily_ai_credits.rb` (daily cron)
Per-org from `ai_credits:reset_daily` rake. Returns early unless `PlanFeatureGate#daily_ai_credit_allocation`
positive AND Flipper `AI_DAILY_CREDITS` enabled. Idempotency guard: skips if a `plan_daily_allocation_credit`
already exists today (UTC day). In txn: zeros leftover daily (`plan_daily_reset_debit`), grants
`plan_daily_allocation_credit`.

### `apply_ai_credit_subscription.rb` (Stripe subscription first invoice)
Called from Stripe webhook on `invoice.paid` first invoice (`kind: :subscription`). Idempotent on
`stripe_subscription_id` and short-circuits if `stripe_invoice_id` already matches. Finds org by
`stripe_customer_id`, finds existing `OrganizationAiCreditPurchase` (kind subscription). In txn:
updates purchase to `subscription_status: :active` + period start/end + invoice id, calls
`finalize_stripe_payment`, writes `ai_credit_subscription_purchase_credit` to `addon_subscription`
bucket (amount = `subscription_credits_per_period`), resets notification flags.

### `apply_ai_credit_upgrade.rb` (Stripe subscription upgrade proration)
Called on `invoice.paid` with `billing_reason: 'subscription_update'`. Idempotent on `stripe_invoice_id`.
Reads old (negative amount) + new (positive amount) line items, maps lookup keys via
`OrganizationAiCreditPurchase.ai_credit_allocation_for_lookup_key`, grants the positive DIFFERENCE
as `ai_credit_subscription_purchase_credit` in `addon_subscription`. Fails on missing line items,
unrecognized lookup keys, or non-positive difference. Resets notification flags.

### `apply_ai_credit_refund.rb` (Stripe refund)
Marks purchase `refunded_at` (+ `subscription_status: :canceled` / `subscription_canceled_at` if
subscription). Finds original credit row, caps refund at current bucket balance (NEVER drives a bucket
negative — if credits already consumed, refunds only what's left; logs cap). Writes negative refund
row (`ai_credit_subscription_refund_debit` / `ai_credit_one_off_refund_debit`) unless capped amount is 0.
Idempotent on `refunded_at`.

### `cancel_ai_credit_subscription.rb` (in-app subscription cancel)
Calls `Stripe::CancelCreditPackSubscription.cancel` FIRST (service owns the API call), then sets
local `stripe_cancel_at_period_end: true`. If Stripe raises → `:stripe_error`, local untouched. If
local update fails after Stripe succeeds → `:record_invalid` (webhook reconciles). Does NOT touch
addon credits (never-expire rule; customer keeps consuming through paid period).

### `notify_zero_ai_credits.rb` / `notify_low_ai_credits.rb` (email notifications)
Ordering contract: zero runs BEFORE low; mutually exclusive.
- Zero: guarded by `settings['zero_ai_credit_notifications_enabled']`, dedup flag
  `sent_zero_notification_since_increase`, only when `total_credits_remaining` is 0. Sends
  `AiCreditNotificationMailer.zero_credits(org).deliver_later`, sets timestamp + flag.
- Low: guarded by `settings['low_ai_credit_notifications_enabled']` + positive
  `settings['low_ai_credit_notification_threshold']`, dedup flag, only when remaining is
  `> 0 and <= threshold`. Sends `AiCreditNotificationMailer.low_credits(org).deliver_later`.

---

## SHARED / NON-AI SURFACES TOUCHED (regression risk)
- `Organization#settings` JSON — reads 4 new keys (`zero/low_ai_credit_notifications_enabled`,
  `low_ai_credit_notification_threshold`). Additive reads; no non-AI settings mutated.
- `Organization.stripe_customer_id` lookup in `apply_ai_credit_subscription` — shared Stripe
  customer id column also used by main billing. Read-only here.
- `AiCreditNotificationMailer` — new mailer; both notification interactors correctly chain
  `.deliver_later` (per rule #4).
- `PlanFeatureGate` — new/extended for `monthly_ai_credit_allocation` + `daily_ai_credit_allocation`
  (verify in separate slice; called by reset interactors).
- Stripe webhook handler is the caller for subscription/upgrade/refund/reset — those interactors
  share the webhook control flow; ordering/guard bugs there could misfire credit grants.

## NOTES / SMELLS (for QA, not necessarily bugs)
- Numerous `ap` debug prints left in `validate_ai_summary_generation`, `validate_auto...`,
  `create_ai_summary_generation`, `create_bulk...`, several credit interactors — pollute logs.
- `update_columns` used in several places (`grant_ai_credits`, notification flag resets,
  `create_ai_summary_generation` stale flag) — some outside txns (acceptable per rule #25),
  but `reset_ai_credits`/`apply_*` correctly use `update` inside txns.
- `create_ai_summary_generation` has an empty `if ai_summary.save` / `else context.fail!` block
  (dead-looking but functionally fine).
