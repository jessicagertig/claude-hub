# Slice map: interactor specs (behavioral truth of the interactors)

All 15 files are NEW (added on develop). They are RSpec specs — no production code lives here — but they encode the exact behavioral contract of the AI-credit and AI-summary interactors. Below is the behavior each spec pins down, useful as the "expected result" oracle during manual QA. Every entry is AI-feature-specific; none touch shared/non-AI production surfaces (they only exercise AI interactors, mailers, jobs). The one cross-cutting production surface referenced is `JobChannel.broadcast_to` (websocket) — the specs assert the status-status interactor does NOT broadcast.

## AI-CREDIT BILLING interactors (grant / consume / reset / refund / subscription)

### GrantAiCredits (grant_ai_credits_spec.rb)
Admin/manual credit grant.
- Adds `amount` to the **addon** bucket only (monthly untouched); writes an `admin_credit` ledger row, bucket `addon`, positive amount, `description` = the reason, `metadata['granted_by_user_id']` = granting user id (nil allowed for automated grants).
- Fails `:invalid_amount` when amount is 0 / negative / nil. Fails `:missing_reason` when reason blank/whitespace. Fails `:record_invalid` (surfaces validation msg) when the ledger row is invalid. Fails `:missing_balance` when org has no `organization_ai_credit_balance`.

### CreateAiCreditBalanceTransaction (create_ai_credit_balance_transaction_spec.rb)
Consumes ONE credit per AI summary. **Bucket priority order: daily → monthly → addon_subscription → addon.** Deducts 1 from the first non-empty bucket in that order; writes an `ai_summary_usage_debit` row (amount −1) tagged with the bucket used; sets `context.transaction`.
- All buckets empty → fails `:insufficient_credits`, writes NO ledger row.
- No balance row → fails `:missing_balance`.
- QA relevance: confirms drain order and that a summary generation costs exactly 1 credit.

### ResetAiCredits (reset_ai_credits_spec.rb)
Monthly plan reset.
- If `monthly_credits_remaining > 0`: writes `plan_monthly_reset_debit` (bucket monthly, amount = −current) to zero it, THEN writes `plan_monthly_allocation_credit` for the new plan allocation. If already 0, skips the reset-debit row.
- Sets `monthly_credits_remaining` to plan allocation (starter_v2 = 50) OR to `monthly_ai_credits_override` when set (test uses 77). Leaves `addon_credits_remaining` untouched.
- Clears `low_credit_notification_sent_at` and `zero_credit_notification_sent_at`; sets `last_reset_at` ≈ now. Missing balance → `:missing_balance`. Double-fire safe (each call re-zeros + re-grants to 50).

### ResetDailyAiCredits (reset_daily_ai_credits_spec.rb)
Daily reset, gated by Flipper `:AI_DAILY_CREDITS` and `PlanFeatureGate#daily_ai_credit_allocation`.
- With allocation N: writes `plan_daily_reset_debit` (−leftover, skipped if 0) then `plan_daily_allocation_credit` (+N); sets `daily_credits_remaining` = N. Idempotent same-day (only one allocation row).
- Allocation nil/zero → no-op (no ledger rows).

### ApplyAiCreditSubscription (apply_ai_credit_subscription_spec.rb)
Post-payment grant for BOTH one-off packs and subscription renewals. Does NOT create the purchase — finds the pre-created `OrganizationAiCreditPurchase`.
- **one_off:** looks up pre-created purchase by (priority) `purchase_id` from invoice metadata → `stripe_checkout_session_id` → `stripe_invoice_id` (direct-charge, no checkout session). Persists `amount_cents_paid` from invoice; grants `one_off_credits_granted` into **addon** bucket via `ai_credit_one_off_purchase_credit` row. Idempotent (duplicate delivery does not double-grant). No matching record → fails `:missing_purchase`. Handles the race where a direct-charge invoice's `stripe_invoice_id` is not yet stamped — metadata `purchase_id` still finds+grants.
- **subscription:** finds by `stripe_subscription_id`; grants `subscription_credits_per_period` into **addon_subscription** bucket via `ai_credit_subscription_purchase_credit` row; persists invoice id. Idempotent keyed on `invoice.id` (same id = no re-grant; different/renewal id = grants again).
- No balance row → `:missing_balance`.

### ApplyAiCreditUpgrade (apply_ai_credit_upgrade_spec.rb)
Handles a Stripe `subscription_update` proration invoice (upgrade small→large).
- Parses invoice lines: one negative (old plan credit), one positive (new plan) line; maps lookup_key → credits; grants the DIFFERENCE (e.g. 2000−500 = 1500) into **addon_subscription** via `ai_credit_subscription_purchase_credit` row whose description contains "Upgrade credit grant", both lookup keys, and "+N credits". Stamps `stripe_invoice_id`; calls `finalize_stripe_payment`; RESETS `sent_low_notification_since_increase` and `sent_zero_notification_since_increase` to false.
- Idempotent on `invoice.id`. Failure errors: `:missing_balance`, `:invalid_invoice_lines` (missing neg or pos line), `:unrecognized_lookup_key`, `:invalid_credit_difference` (new ≤ old).

### CancelAiCreditSubscription (cancel_ai_credit_subscription_spec.rb)
- Calls `Stripe::CancelCreditPackSubscription.cancel(stripe_subscription_id)`; on success sets local purchase `subscription_status` → `canceled` and `subscription_canceled_at` ≈ now. Does NOT touch addon credits.
- On Stripe error → fails `:stripe_error`, local row unchanged (`active`, canceled_at nil).

### ApplyAiCreditRefund (apply_ai_credit_refund_spec.rb)
- **one_off refund:** sets `refunded_at`; writes an `ai_credit_one_off_refund_debit` debit CAPPED at the current bucket balance (untouched=full −50; partly consumed=−remaining; fully consumed=NO ledger row but still sets refunded_at). Drives `addon_credits_remaining` to 0. Already-refunded (refunded_at set) → no-op (no new ledger row).
- **subscription refund:** cancels the subscription (`subscription_status`→`canceled`, `subscription_canceled_at` set), sets `refunded_at`, writes `ai_credit_subscription_refund_debit` (bucket `addon_subscription`).

### CreditConsumptionWithNotifications integration (credit_consumption_with_notifications_spec.rb)
Exercises the real chain CreateAiCreditBalanceTransaction → NotifyZeroAiCredits → NotifyLowAiCredits as the summary job runs it.
- Comfortable balance (50): consumes 1, no notifications.
- Crossing LOW threshold (flat 5; start 6→consume→below): fires `AiCreditNotificationMailer.low_credits(org)`, sets `low_credit_notification_sent_at` + `sent_low_notification_since_increase`; does NOT re-fire on a later consumption.
- Reaching EXACTLY zero (start 1): fires `zero_credits`, not `low`; sets zero flags.
- After ResetAiCredits clears the flags, the zero notification can fire again next period.

### NotifyLowAiCredits (notify_low_ai_credits_spec.rb)
Sends `AiCreditNotificationMailer.low_credits(org)` ONLY when: total remaining is **below threshold AND strictly positive**, org setting `low_ai_credit_notifications_enabled` true, and not already sent this period (`sent_low_notification_since_increase` false). Exactly zero → does NOT send (zero interactor owns that). At/above threshold, already-sent, or disabled → no send. Sets sent_at + flag when it does send.

### NotifyZeroAiCredits (notify_zero_ai_credits_spec.rb)
Sends `AiCreditNotificationMailer.zero_credits(org)` ONLY when total remaining == 0, `zero_ai_credit_notifications_enabled` true, and not already sent (`sent_zero_notification_since_increase`). Positive balance, already-sent, or disabled → no send. Sets zero sent_at + flag when it sends.

## AI-SUMMARY generation interactors

### FindOrCreateAiJobApplicationSummaryStatus (find_or_create_ai_job_application_summary_status_spec.rb)
Creates/updates the one-per-JobApplication `AiJobApplicationSummaryStatus` companion row; `resolve_status` keys off `latest_ai_job_application_summary` and `latest_succeeded_ai_job_application_summary`. Status meanings observed:
- No summary → `none`, summary_id nil.
- Latest summary succeeded (non-stale OR stale — staleness no longer considered) → `current`, adopts that summary's denormalized `score_percentage`/`headline`/`integrated_role_analysis`.
- **Record-exists no-op branch:** if the status row's `ai_job_application_summary` is nil, or the latest summary is not succeeded (e.g. `failed`), the interactor does NOT write and does NOT broadcast on JobChannel.
- **Two KNOWN BUGS documented in the spec (tests assert the DESIRED behavior — may be currently failing/pending):**
  - In-progress summary only (summarizing, no succeeded) → spec wants `initial_summary_pending`, interactor currently yields `none`.
  - Succeeded summary + newer summarizing summary → spec wants `regenerating` (keep showing old succeeded score), interactor currently yields `none`.
  - Both flagged for a separate session. QA relevance: candidate cards may show "no summary" while a summary is actively generating/regenerating.
- Asserts NO JobChannel broadcast from this interactor (status row has no broadcast callback).

### CreateBulkAiSummaryGeneration (create_bulk_ai_summary_generation_spec.rb)
Per-candidate builder used by bulk flow. Given a `validation_result` carrying a `textract_result`:
- Textract-ready, no active summary → builds a **pending** `AiJobApplicationSummary` with `textract_result_id` set and `requested_by_organization_user_id` = current org user; enqueues NO job itself.
- Reuse path: active non-stale summary already exists → returns it, builds nothing.
- Stale path: active summary points at older textract → marks old summary `stale: true`, builds a fresh pending row against the latest textract.

### QueueBulkAiSummaryJobs (queue_bulk_ai_summary_jobs_spec.rb)
Bulk "Generate/Rescore AI summaries" entry point. Gated by Flipper `:AI_APPLICANT_SUMMARY` per org and by available credits.
- Partitions candidates into ready (has succeeded textract) / textract-pending (resume, no textract) / no-resume. Enqueues ONE `BulkGenerateAiSummariesJob` for the ready set; kicks off `SubmitResumeToTextractJob(ja_id)` for each pending; creates `BulkAiSummaryJobApplication(status: processing)` claim rows. Returns `queued_count`, `skipped_count`, `any_textract_pending`.
- Skips candidates already claimed by a different bulk batch (existing processing `BulkAiSummaryJobApplication`).
- `rescore_requested: true` INCLUDES candidates whose status is `current` (normally filtered out); still filters ones being processed by another batch.
- `kind` param passed to job payload (default `single_hiring_stage`; e.g. `all_stages`).
- Feature disabled → fails "AI summaries are not enabled for this organization.", enqueues nothing.
- Out of credits (all 4 buckets 0) → fails with message including "out of AI credits", enqueues nothing.

### ValidateAutoAiSummaryGeneration (validate_auto_ai_summary_generation_spec.rb)
Four gates for auto-generation at application intake: Flipper `:AI_APPLICANT_SUMMARY` on, `job_application.has_resume`, `organization.ai_credits_available?`, and job has a non-blank `description`. All pass → success, `textract_pending: true`, `textract_result: nil`, does NOT itself submit Textract. Any gate fails → failure.
- Intake integration: when `job.auto_generate_ai_summaries: :enabled`, creating a JobApplication produces exactly ONE `AiJobApplicationSummary` in status `textract_processing` with `requested_by_organization_user_id: nil` (auto, no requesting user).

## Cross-feature / regression notes
- `AiCreditNotificationMailer` (`.low_credits`, `.zero_credits`) is the only mailer these specs touch — verify delivery in manual QA.
- `JobChannel.broadcast_to`: specs assert the status interactor is SILENT on it; if manual QA sees stray websocket pushes on that channel, that's a regression.
- Bucket priority (daily→monthly→addon_subscription→addon) and the "1 credit per summary" cost are the load-bearing invariants for the whole credits UI.
