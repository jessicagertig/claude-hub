# Slice map: BE model specs — validations, enums, lifecycle

All 13 files are **new spec files** (none modified). They add no production code themselves, but they pin down the intended behavior of the AI models. Below is the behavior each spec asserts, framed for manual QA. No shared/non-AI surface is *modified* here (specs only), but several specs exercise shared models (`Organization`, `Job`, `JobApplication`, `TextractResult`) whose AI callbacks can affect non-AI flows — flagged below.

---

## AI credits — balance & ledger

### `ai_credit_balance_transaction_spec.rb` → `AiCreditBalanceTransaction`
- **Ledger is immutable & append-only.** Updates and destroys raise `ActiveRecord::ReadOnlyRecord`. QA: you cannot edit/delete a credit transaction once written.
- **`entry_type` enum (13 values):** `plan_monthly_allocation_credit`, `plan_monthly_reset_debit`, `plan_daily_allocation_credit`, `plan_daily_reset_debit`, `ai_credit_one_off_purchase_credit`, `ai_credit_one_off_refund_debit`, `ai_credit_subscription_purchase_credit`, `ai_credit_subscription_refund_debit`, `admin_credit`, `admin_debit`, `admin_correction_credit`, `admin_correction_debit`, `ai_summary_usage_debit`.
- **`bucket` enum (4 values):** `monthly`, `addon`, `addon_subscription`, `daily`.
- **Sign rule (`entry_type_and_amount_valid`):** `*_debit`/`*_reset_debit`/`*_usage_debit` entries must have a **negative** amount; `*_credit`/`admin_credit` entries must be **positive**. Wrong sign → invalid. `amount` is required.
- **counter_culture cache:** each transaction increments/decrements the matching bucket column on `OrganizationAiCreditBalance` (monthly credit → `monthly_credits_remaining`; addon purchase → `addon_credits_remaining`; usage debit from monthly → decrements monthly). QA angle: consuming a credit and buying credits should move the visible remaining-credit counters by the transaction amount, per bucket.
- `organization_ai_credit_purchase` association is **optional** (usage/admin entries have none).

### `organization_ai_credit_balance_spec.rb` → `OrganizationAiCreditBalance`
- **`total_credits_remaining` = daily + monthly + addon_subscription + addon**, nil buckets treated as 0.
- **`credits_available?`** true if ANY bucket > 0; false only if all four are 0.
- **DB check constraint:** setting any of the 4 bucket columns negative raises `ActiveRecord::StatementInvalid` (`check constraint`). Balance can never go below zero at the DB level.
- `ai_credit_balance_transactions` association is `dependent: :restrict_with_error` (can't delete a balance that has ledger rows).

### `organization_ai_credits_spec.rb` → `Organization` (AI credit helpers)
- Associations: `has_one organization_ai_credit_balance`, `has_many organization_ai_credit_purchases`, `has_many ai_credit_balance_transactions through: organization_ai_credit_balance`.
- Helper reads: `monthly_ai_credits_remaining`, `addon_ai_credits_remaining`, `total_ai_credits_remaining` (= monthly + addon), `ai_credits_available?`.
- **Missing-balance safety:** if the balance record is absent, `monthly_ai_credits_remaining` returns **0** (does not error). QA: an org with no balance row shows 0 credits, not a crash.

### `organization_ai_credits_lifecycle_spec.rb` → `Organization` setup
- **On org create, `create_ai_credit_state_if_needed` runs** (after_create callback) and builds an `OrganizationAiCreditBalance` seeded with `monthly_credits_remaining = PlanFeatureGate::MINIMUM_AI_CREDIT_ALLOCATION`, `addon_credits_remaining = 0`. **Idempotent** — never creates a duplicate balance.
- **`add_default_settings` sets 5 AI setting keys** at their defaults:
  - `auto_generate_ai_summaries_enabled` → **false**
  - `hiring_team_ai_credits_control_enabled` → **true**
  - `low_ai_credit_notifications_enabled` → **false**
  - `low_ai_credit_notification_threshold` → **0**
  - `zero_ai_credit_notifications_enabled` → **true**
- **SHARED-SURFACE RISK:** these live in the `Organization#settings` JSONB and are set in the shared org-setup path (`complete_setup_workers` / `add_default_settings`) and a new `after_create` callback `create_ai_credit_state_if_needed`. A new org (any signup, not just AI) now creates a balance row and writes 5 keys. Regression to watch: org creation flow, org settings serialization.

---

## AI credit purchases (one-off + subscription)

### `organization_ai_credit_purchase_spec.rb` → `OrganizationAiCreditPurchase`
- **`kind` enum:** `one_off`, `subscription`. **`subscription_status` enum:** `active`, `past_due`, `canceled`, `paused`.
- **Conditional validations (lifecycle-gated):**
  - **one_off:** requires `stripe_checkout_session_id`, `stripe_price_lookup_key`, `one_off_credits_granted` (> 0), `amount_cents_paid` (present, **0 allowed for promo**), `currency`. Does NOT require subscription fields.
  - **subscription, fully linked (has `stripe_subscription_id`):** requires `stripe_subscription_id` (when checkout session blank), `subscription_credits_per_period` (> 0), `subscription_current_period_start` & `_end`.
  - **subscription, pre-checkout (only `stripe_checkout_session_id`, no `stripe_subscription_id`):** valid WITHOUT period dates, amount, or currency — these are populated later on `invoice.paid`. (Matches the two-step checkout handshake.)
- **`AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` — 4 packs** (2 one_off, 2 subscription):
  - `ai_credit_pack_top_up_small` → one_off, **100** credits
  - `ai_credit_pack_top_up_large` → one_off, **1000** credits
  - `ai_credit_pack_subscription_small_monthly` → subscription, **500**/period
  - `ai_credit_pack_subscription_large_monthly` → subscription, **2000**/period
  - Class helpers: `ai_credit_lookup_keys`, `ai_credit_subscription_plan_lookup_key?`, `ai_credit_top_up_lookup_key?`, `ai_credit_allocation_for_lookup_key` (nil for unknown key).
- `ai_credit_balance_transactions` association `dependent: :restrict_with_error`.

### `organization_ai_credit_purchase_charge_spec.rb` → `OrganizationAiCreditPurchase#charge_for_purchase`
- Create-then-charge method (mirrors `BoardWwrListing#charge_for_listing`). Purchase already exists; method:
  1. Resolves amount from Stripe Price via `Stripe::Price.list(lookup_keys: [key], active: true, limit: 1)`.
  2. Creates `Stripe::InvoiceItem` (customer, amount, currency, description e.g. `"AI Credit Top-Up — Credit Pack Top-Up — Small"`, metadata `{organization_ai_credit_purchase_id: id}`).
  3. Creates `Stripe::Invoice` (`collection_method: 'charge_automatically'`, description `'AI Credit Top-Up'`, same metadata).
  4. `Stripe::Invoice.pay(invoice_id)`.
  5. Stamps `stripe_invoice_id`, `stripe_invoice_item_id`, resolved `stripe_amount`, `currency` via `update_columns`.
- **Does NOT grant credits inline** — credit granting is deferred to the `invoice.paid` webhook (routed via the invoice metadata). QA: after purchase, credits appear only once Stripe fires `invoice.paid`.
- **Early-return guards (no charge):** Price not found for lookup key; purchase already charged (`stripe_invoice_id` present) — idempotent; org has no `stripe_customer_id`.
- Stripe errors propagate (caller rescues).
- **SHARED-SURFACE RISK:** touches Stripe invoicing; `invoice.paid` webhook routing now has an AI-credit branch keyed on `organization_ai_credit_purchase_id` metadata — verify non-AI invoices (WWR listings, subscriptions) still route correctly.

---

## AI summaries — lifecycle, status record, broadcasts

### `ai_job_application_summary_spec.rb` → `AiJobApplicationSummary`
- **`status` enum (10, ordered):** `pending`(0), `textract_processing`(1), `extracting`(2), `summarizing`(3), `awaiting_job_criteria`(4), `scoring`(5), `integrating`(6), `succeeded`(7), `retrying`(8), `failed`(9).
- **`broadcast_status_change` after_commit:** on any status **change** to a status in `BROADCAST_STATUSES`, broadcasts `JobChannel` event `ai_summary_status_change` with payload `{jobApplicationId, aiJobApplicationSummaryId, hiringStageId}`. Does NOT broadcast on create, and does NOT broadcast when status is unchanged (e.g. only `stale` toggled). QA: candidate-card AI status updates live via websocket as the pipeline advances.
- **`update_summary_status_record`:** on transition to `succeeded`, **denormalizes** `score_percentage`, `headline`, `integrated_role_analysis` onto the eagerly-created `AiJobApplicationSummaryStatus`, sets its `status` to `current` and its `ai_job_application_summary_id`. Uses the **unified** `ai_summary_status_change` broadcast (no separate `ai_summary_succeeded` event).
- **`destroy_previous_textract_results`:** on transition to `succeeded`, destroys older **non-succeeded** `TextractResult` rows for the job_application, keeps the summary's own textract_result. Safe when `textract_result_id` is nil.
  - **SHARED-SURFACE RISK:** deletes `TextractResult` rows — a shared model. Verify resume-text extraction history / any non-AI consumer of TextractResult isn't harmed.

### `ai_job_application_summary_status_spec.rb` → `AiJobApplicationSummaryStatus`
- **Uniqueness on `job_application_id`** (one status row per application).
- **Defaults:** `status` → `none`; `ai_job_application_summary_id` nullable.
- **Score-band scopes (lower-inclusive, upper-exclusive):** `poor` 0…15, `weak` 15…35, `mixed` 35…60, `good` 60…90, `excellent` ≥90. Boundary value belongs to the band it opens (15→weak, 35→mixed, 60→good, 90→excellent). **nil score excluded from every band.** QA: candidate list score-band filters bucket exactly on these cutoffs.

### `job_application_ai_summary_status_spec.rb` → `JobApplication#enqueue_new_job_application`
- **Every new job application eagerly creates an `AiJobApplicationSummaryStatus` with status `none`.**
  - **SHARED-SURFACE RISK:** `enqueue_new_job_application` is the core new-applicant path (all applications, AI or not). Now always creates a companion status row. Regression watch: applicant creation, bulk imports, apply flow.

---

## AI job-criteria extraction lifecycle

### `ai_job_criteria_spec.rb` → `AiJobCriteria`
- **`status` enum (5):** `pending`(0), `in_progress`(1), `succeeded`(2), `failed`(3), `retrying`(4). `belongs_to :job`.
- **`resume_waiting_summaries` after_commit:** when criteria transition to **`succeeded`**, re-enqueues `GenerateAiJobApplicationSummaryJob` for every `AiJobApplicationSummary` on that job in status `awaiting_job_criteria`, threading `requesting_organization_user_id` (nil or the requesting user, read from `requested_by_organization_user_id`). Handles multiple waiting summaries. Transition to `failed` enqueues nothing; no waiting summaries → nothing. QA: summaries that were parked waiting for criteria resume automatically once criteria finish.

### `job_criteria_lifecycle_spec.rb` → `Job#extract_job_criteria` + `#description_meaningfully_changed?`
- **`extract_job_criteria` gated by Flipper `:AI_APPLICANT_SUMMARY`** (per-org). Disabled → no criteria created.
- **Debounce:** if latest criteria is `pending`, returns without enqueuing (no duplicate). If latest is `in_progress`/`succeeded`/`failed`, creates a NEW `pending` record and enqueues `ExtractJobCriteriaJob(new_id)` — prior record untouched.
- **`description_meaningfully_changed?`** driven by `saved_change_to_description`; `sanitize_for_compare` strips HTML, downcases, removes non-[a-z]. So HTML-only, whitespace-only, number-only, case-only edits → **false** (no re-extraction). Real text change → **true**.
  - **SHARED-SURFACE RISK:** `Job#description` is a core field. Editing a job description now can trigger AI criteria re-extraction. Regression watch: job edit/save flow, and that trivial edits don't spam extraction.

### `job_ai_settings_spec.rb` → `Job#should_auto_generate_ai_summaries?`
- **`auto_generate_ai_summaries` per-job enum cascade:**
  - `:default` → follows org setting `auto_generate_ai_summaries_enabled` (true→true, false→false; **missing JSONB key → falsy**).
  - `:enabled` → true even if org default false (per-job override wins).
  - `:disabled` → false even if org default true (per-job opt-out wins).

### `textract_result_ai_trigger_spec.rb` → `TextractResult#queue_ai_summary_job`
- **On create with `textract_job_result_text` present** → enqueues `GenerateAiJobApplicationSummaryJob`. No text → no enqueue.
- **On update:** re-enqueues ONLY when the text actually changes (resume replacement). Timestamp `touch` or `textract_job_status`-only change → no enqueue.
- **Manual-trigger path (a `textract_processing` summary is waiting):**
  - Success path (`ValidateAiSummaryGeneration` success) → enqueues job with `requesting_organization_user_id`.
  - Failure path (validate fails, e.g. no credits) → **destroys the waiting summary** and broadcasts `GlobalChannel` to the requesting user `{action: 'AI_SUMMARY_FAILED'}`. QA: a manual "generate summary" with no credits removes the pending summary and shows a failure toast to that user.
- **Auto-generate gate cascade** (org default × per-job override), gated through `Job#should_auto_generate_ai_summaries?`:
  - org OFF + job `:default` → no enqueue
  - org ON + job `:default` → enqueue
  - org OFF + job `:enabled` → enqueue (override)
  - org ON + job `:disabled` → no enqueue (opt-out)
  - **SHARED-SURFACE RISK:** `TextractResult` create/update is the resume-OCR pipeline (all applicants with resumes). AI summary enqueue now hangs off its create/update callback + a text-diff guard. Regression watch: resume upload/re-upload, textract completion.
