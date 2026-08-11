# Slice: BE Serializers — Frontend Data Contract

Scope: what the frontend receives for Plato AI (summaries, scoring, credits) plus AI fields grafted onto shared job/job-application serializers.

## New AI serializers (all net-new files)

### AiJobApplicationSummarySerializer (full)
Attributes: `id, status, headline, summary_text, structured_data, job_application_id, stale, created_at, score_percentage, criteria_results, integrated_role_analysis`.
- **`criteria_results` override is a final display sanitizer.** It maps over the array and strips any leading `[tier_N]` label (regex `\A\s*\[tier_\d+\]\s*:?\s*`, case-insensitive) off each entry's `criterion_text`. This is a runtime cleanup applied on every serialization, including already-persisted records, so the model-leaked tier label can never reach the candidate-facing criterion display. Returns `results` untouched if not an Array; skips entries that aren't a Hash or lack `criterion_text`.
- User-visible: criteria breakdown rows in the AI scoring UI show clean criterion text; score bar / percentage; headline; integrated role analysis narrative.

### AiJobApplicationSummaryShallowSerializer (list/lightweight)
Attributes: `id, status, headline, summary_text, stale, created_at, score_percentage, integrated_role_analysis`. No `criteria_results`, no `structured_data`, no `job_application_id`. Used where a lighter payload is needed (lists). Note: shallow does NOT apply the `[tier_N]` strip because it omits `criteria_results` entirely.

### AiJobApplicationSummaryStatusSerializer (companion status record)
Attributes: `id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp`.
- `published_at_timestamp` = `object.updated_at.to_i` (epoch seconds) — used by the frontend to detect fresh publishes / cache-bust or ordering. Carries the denormalized `score_percentage / headline / integrated_role_analysis` so the row can render a summary state without loading the full summary.

### OrganizationAiCreditBalanceSerializer (billing balance)
Attributes: `id, daily_credits_remaining, monthly_credits_remaining, addon_subscription_credits_remaining, addon_credits_remaining, total_credits_remaining, monthly_credit_allocation, current_period_end_at, subscription_period_end_at`.
- `total_credits_remaining` override just delegates to the model method (sum of buckets). Drives the credit balance widget (per-bucket + total remaining, allocation, period-end dates).

### OrganizationAiCreditPurchaseSerializer (billing purchase/subscription record)
Attributes: `id, kind, stripe_checkout_session_id, stripe_price_lookup_key, stripe_amount, currency, one_off_credits_granted, subscription_credits_per_period, subscription_status, subscription_current_period_start, subscription_current_period_end, subscription_canceled_at, refunded_at, created_at`.
- `kind` distinguishes one-off purchase vs subscription. Drives billing history / subscription-status display (active/canceled, period dates, refund state, credits granted per period).

## SHARED / non-AI surfaces touched (regression risk)

### JobApplicationSerializer (shared — every candidate/application render)
- New attribute `bulk_ai_summary_processing` = `object.bulk_ai_summary_job_applications.status_processing.exists?` — an extra DB EXISTS query per application serialized. **Regression risk: N+1 / query-count increase** on any endpoint returning many job applications (candidate lists, pipeline views), since this is not preloaded here.
- New `has_one :ai_job_application_summary_status` association embedded via the status serializer — adds the AI status object to every job application payload. Frontend now expects this key on all applications; also potential N+1 if not eager-loaded.
- No existing attributes removed; additive only.

### ShallowJobApplicationSerializer (shared — lightweight application lists)
- Same two additions as the full serializer: `bulk_ai_summary_processing` (per-record EXISTS query) and `has_one :ai_job_application_summary_status`. Same N+1 / query-count regression concern, and this serializer is used exactly where large collections are returned, so higher risk.

### JobSerializer (shared — every job render)
- New attributes: `auto_generate_ai_summaries` (raw column), `ai_job_application_summaries_count` (counter), `should_auto_generate_ai_summaries` (delegates to `object.should_auto_generate_ai_summaries?`).
- Drives the job-level "auto-generate AI summaries" toggle state and the summaries count badge. Additive; `should_auto_generate_ai_summaries?` model logic gates whether the toggle shows as effectively on.

## Conditions / edge cases
- `criteria_results` strip only fires on Array-of-Hash entries with a `criterion_text` key; malformed/nil data passes through unchanged (safe).
- `bulk_ai_summary_processing` reflects whether a bulk AI summary job is currently `status_processing` for that application — drives a per-row "processing" indicator; flips to false once the bulk job leaves processing.
- `published_at_timestamp` is derived from `updated_at`, so any touch of the status record changes it.

## Spec added
`organization_ai_credit_balance_serializer_spec.rb` — asserts presence of `monthly_credit_allocation`, `current_period_end_at`, and the existing bucket keys (`daily/monthly/addon_subscription/addon/total _credits_remaining`). Uses `create_credit_test_organization` helper.
