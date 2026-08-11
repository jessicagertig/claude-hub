# Plato AI — Slice map: BE models (summary, status, credit balance/txn/purchase, associations, enums, callbacks)

Source: `git -C /Users/jessica/wrk/wrk-corp/inflow-ats diff production...develop -- app/models/`

## New AI models (all brand-new files)

### `AiJobApplicationSummary` (the per-applicant AI review record)
- `belongs_to :job_application`, `belongs_to :textract_result (optional)`, `has_many :ai_api_requests (polymorphic requestable)`, `has_one :ai_job_application_summary_status`.
- `enum status` (`_prefix: true`): pending, textract_processing, extracting, summarizing, awaiting_job_criteria, scoring, integrating, succeeded, retrying, failed. This is the pipeline stage machine surfaced to the UI.
- `after_commit :handle_after_update_commit, on: :update` runs 3 things whenever status changes:
  1. **update_summary_status_record** — the denormalization into the companion status row. On `succeeded`: sets status row to `current` and copies `score_percentage`, `headline`, `integrated_role_analysis` onto it. On `failed`: `initial_summary_pending → none`; `regenerating → current` (a prior succeeded review stays accessible — matches CLAUDE.md failure-pattern #20). Only touches status row if `job_application.ai_job_application_summary_status` exists.
  2. **broadcast_status_change** — pushes `JobChannel` `ai_summary_status_change` (payload jobApplicationId, aiJobApplicationSummaryId, hiringStageId) for all BROADCAST_STATUSES (everything except `retrying`). This is what live-updates the applicant list/drawer without reload. Rescues StandardError and logs.
  3. **destroy_previous_textract_results** — on `succeeded` with a textract_result present, destroys older non-succeeded textract_results for that job_application.
- Token/cost helpers sum from `ai_api_requests` (input/output tokens, cost).
- **USER-VISIBLE:** score %, headline, role-fit analysis, and live status transitions in the applicant UI. Edge: status row must pre-exist or denormalization silently no-ops.

### `AiJobApplicationSummaryStatus` (companion/read-model row, 1 per job_application)
- `belongs_to :job_application`, `belongs_to :ai_job_application_summary (optional)`.
- `validates :job_application_id, uniqueness: true` (one per applicant).
- `enum status` (`_prefix`): none(0), initial_summary_pending(1), current(2), regenerating(3). **Deliberately NO `failed` state** (per failure-pattern #20).
- Role-fit band scopes by `score_percentage`: poor 0–15, weak 15–35, mixed 35–60, good 60–90, excellent 90+ (lower-inclusive). Drives fit-band filtering.
- **counter_culture on `[:job_application, :job]` → `ai_job_application_summaries_count`**: counts only rows in status `current`(2) or `regenerating`(3). **SHARED SURFACE:** this maintains a denormalized count column on `Job` (`ai_job_application_summaries_count`) — used for the "scored applicants" count badge; miscounts if enum ints drift.

### `AiJobCriteria` (per-job extracted scoring criteria)
- `belongs_to :job`, `has_many :ai_api_requests`.
- `enum status` (`_prefix`): pending, in_progress, succeeded, failed, retrying.
- `after_commit :resume_waiting_summaries, on: :update`: when status changes to `succeeded`, finds all of the job's summaries in `awaiting_job_criteria` and re-enqueues `GenerateAiJobApplicationSummaryJob` for each. **This is the gate that unblocks summaries queued while criteria weren't ready.**
- Note documents Rails mis-singularization: `_ids` accessor is `ai_job_criterium_ids`.

### `AiApiRequest` (usage/cost ledger, polymorphic)
- `belongs_to :organization`, `belongs_to :requestable (polymorphic)`. Validates call_type, provider, model present. Records each LLM call's provider/model/tokens/cost.

### `BulkAiSummaryJobApplication` (internal bulk-batch join)
- `belongs_to :job_application`. `enum status`: processing, done, failed, deferred. Not API-exposed; partial-unique-index idempotency for bulk summary generation.

## New billing models

### `OrganizationAiCreditBalance` (one per org)
- `belongs_to :organization`, `has_many :ai_credit_balance_transactions, dependent: :restrict_with_error` (immutable ledger, never cascade-destroyed).
- 4 buckets: daily, monthly, addon_subscription, addon. `total_credits_remaining` sums all 4 (nil-coalesced to 0). `credits_available?` = total positive.
- `monthly_credit_allocation` = `monthly_ai_credits_override.presence` else `PlanFeatureGate#monthly_ai_credit_allocation`.
- `subscription_period_end_at` from active subscription purchase. `reset_ai_credits` → `ResetAiCredits.call`.

### `AiCreditBalanceTransaction` (immutable ledger, insert-only)
- `belongs_to :organization_ai_credit_balance`, `belongs_to :organization_ai_credit_purchase (optional)`.
- `enum entry_type` (numbered families): plan monthly/daily allocation & reset (0/1/10/11), one-off purchase/refund (20/21), subscription purchase/refund (30/31), admin credit/debit/correction (40–43), `ai_summary_usage_debit` (60).
- `enum bucket`: monthly(0), addon(1), addon_subscription(2), daily(3).
- `validate :entry_type_and_amount_valid`: `_credit` types must be positive, `_debit` must be negative.
- **counter_culture** with dynamic `column_name` = `"#{bucket}_credits_remaining"`, `delta_column: 'amount'` — every ledger insert adjusts the matching bucket column on the balance. This IS the balance-keeping mechanism; DB CHECK constraints are last defense. Insert-only enforced via before_update (comment) so reload/counter_culture still work.
- **USER-VISIBLE:** every AI summary generation writes an `ai_summary_usage_debit` decrementing a bucket; balance shown in billing UI.

### `OrganizationAiCreditPurchase` (subscription + one-off top-up)
- `AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` built from `Variables::AI_CREDIT_ALLOCATIONS`; class helpers classify a Stripe lookup_key as subscription vs one_off and return credit allocation.
- `enum kind`: one_off, subscription. `enum subscription_status` (`_prefix`): active, past_due, canceled, paused, trialing, incomplete, incomplete_expired, unpaid.
- **Lifecycle-conditional validations** (failure-pattern #9): stripe_subscription_id required only for subscription with no checkout session; period start/end required only once subscription_id present; stripe_amount/currency required unless subscription-before-checkout; one_off_credits_granted required for one_off. So the record is legitimately created pre-payment at checkout.
- `charge_for_purchase`: one-off top-up — creates Stripe InvoiceItem + Invoice, pays it, `update_columns(stripe_invoice_id, stripe_invoice_item_id, stripe_amount)`. Idempotent on `stripe_invoice_id + stripe_invoice_paid`; no-op if no stripe_customer_id.
- `grant_credits(invoice:)`: called by `invoice.paid` webhook — idempotency check on existing positive one-off grant, builds `ai_credit_one_off_purchase_credit` addon-bucket txn, resets low/zero notification suppression flags, `broadcast_event` (GlobalChannel `AI_CREDIT_TOP_UP_COMPLETE`) + `broadcast_show_growl` success toast, enqueues `Notification::PaidAiCreditPackPurchasedJob`. Rescues all errors (logs only).
- `sync_subscription_invoice_grant` / `sync_one_off_with_stripe`: reconciliation from Stripe (handles subscription_create/cycle/update proration credits and missed one-off grants). Uses `update_columns` outside transactions.
- **USER-VISIBLE:** top-up purchase completion toast + live balance refresh; subscription credit grants.

## SHARED / non-AI surfaces touched (regression risk)

### `Organization` (heavily modified — non-AI risk)
- New associations: ai_api_requests, organization_ai_credit_balance (restrict_with_error), organization_ai_credit_purchases (restrict_with_error), ai_credit_balance_transactions through balance. **`dependent: :restrict_with_error` means org deletion now blocks if these rows exist.**
- **`after_create :create_ai_credit_state_if_needed`** — NEW synchronous callback on EVERY org creation: `find_or_create_by` balance, sets monthly allocation. Rescued (Sentry + log), tolerated. **Risk: runs in the org-creation transaction for all orgs, AI or not.**
- **`customer_subscription` / stripe sync REWRITTEN (non-AI billing risk):** (a) guard changed from `return if !stripe_customer_id.present? || stripe_subscription_id == 'free_plan'` to `return unless stripe_customer_id.present?` — free_plan orgs are no longer short-circuited. (b) Now **filters OUT** subscriptions whose lookup_key includes `'credit'` or `'plato'` before picking the current plan subscription (trialing → active → first). This prevents an AI-credit subscription from being mistaken for the org's plan subscription. **Regression surface: plan detection for ALL orgs; verify normal plan/trial detection and upgrades still resolve correctly.**
- `sync_customer` now also grants full new-plan monthly allocation via `update_columns(monthly_credits_remaining:)` when `plan` changes.
- Free-trial-started after_commit now also calls `organization_ai_credit_balance&.reset_ai_credits`.
- New default settings keys added to `add_default_settings`: auto_generate_ai_summaries_enabled(false), hiring_team_ai_credits_control_enabled(true), low/zero notification flags/threshold. **SHARED: modifies the org settings jsonb defaults for all new orgs.**
- New helpers: per-bucket/total credit readers, `ai_credits_available?`, `auto_generate_ai_summaries_enabled` (reads settings jsonb), `active_ai_credit_subscription`, `self.process_ai_credit_resets` (cron reset with 6h threshold), `setup_ai_credit_test_subscription` (test-env only), `sync_ai_credits_with_stripe`.

### `Job`
- New associations ai_job_application_summaries (through applications), ai_job_criteria.
- New `enum auto_generate_ai_summaries`: default(0), enabled(1), disabled(2) — per-job override of org setting. `should_auto_generate_ai_summaries?` resolves job override else org `auto_generate_ai_summaries_enabled`.
- **`handle_after_update_commit` now calls `handle_criteria_extraction_after_commit`** — on publish (status → published) OR meaningful description change (sanitized text compare), auto-extracts criteria (Flipper `AI_APPLICANT_SUMMARY` gated; debounces if a pending criteria exists; 30s delay when re-extracting). **SHARED: adds work to the existing job after_commit path — verify publish/edit of a job with the flag off is unaffected.**

### `JobApplication`
- New associations: ai_job_application_summaries, bulk_ai_summary_job_applications, latest_ai_job_application_summary, ai_job_application_summary_status.
- New scopes **`fit_bands`** (left join status, OR of band scopes) and **`unscored`** (score_percentage nil) — drive applicant filtering by fit.
- **`enqueue_new_job_application` MODIFIED (core new-applicant path — high regression risk):** (a) Textract submission now gated on `!resume_is_docx` (docx now submits after PDF conversion in DocxToPdfJob) in addition to the existing Flipper flag. (b) On new applicant, if `job.should_auto_generate_ai_summaries?`, runs `ValidateAutoAiSummaryGeneration` then `CreateAiSummaryGeneration`. (c) Always calls `find_or_create_ai_job_application_summary_status` (creates the companion status row for every new applicant). **Verify non-docx vs docx resume Textract flow and that new applicants still process with AI off.**

### `TextractResult`
- New `has_many :ai_job_application_summaries` (dependent destroy) and **`after_commit :queue_ai_summary_job, on: [:create, :update]`**.
- `queue_ai_summary_job`: only when `textract_job_result_text` present AND `saved_change_to_textract_job_result_text?`. If a summary is `textract_processing`+not stale, validates (`ValidateAiSummaryGeneration`) and enqueues `GenerateAiJobApplicationSummaryJob` (or destroys the waiting summary + broadcasts `AI_SUMMARY_FAILED` growl on validation failure). Else auto-generates if job opted in.
- `generate_ai_summary_with_credit_flow`: full orchestration (thin job dispatches here) — skips if latest summary succeeded and not stale; sets status row to initial_summary_pending; runs `AiJobApplicationAction::Orchestrate`; on success `CreateAiCreditBalanceTransaction` (consumes credit) then `NotifyZeroAiCredits` + `NotifyLowAiCredits`.
- **SHARED: TextractResult now triggers AI work on every create/update where OCR text changes — verify resume OCR for non-AI orgs is unaffected (gated by should_auto_generate_ai_summaries? / waiting-summary presence).**

## Scoring-manifest inputs (from these models)
- Summary pipeline status order: pending → textract_processing → extracting → summarizing → awaiting_job_criteria → scoring → integrating → succeeded (or retrying/failed).
- Criteria pipeline: pending → in_progress → succeeded/failed/retrying; success re-enqueues awaiting summaries.
- LLM calls recorded per-request in `AiApiRequest` (provider, model, call_type, input/output tokens, cost); exact models/prompt roles/call order live in the `AiJobApplicationAction::Orchestrate` service and job/provider files (NOT in these model files — see BE-jobs/services slice).
- Credit consumption: one `ai_credit_balance_transaction` (`ai_summary_usage_debit`, negative) per successful summary via `CreateAiCreditBalanceTransaction`; counter_culture decrements the bucket column.
